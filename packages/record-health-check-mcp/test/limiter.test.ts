import { describe, expect, it } from "vitest";

import { ClientRateLimiter, ConcurrencyLimiter } from "../src/limiter.js";

describe("concurrency limiter", () => {
  it("queues only the configured number of requests and then sheds load", async () => {
    const limiter = new ConcurrencyLimiter(1, 1);
    let release: (() => void) | undefined;
    const first = limiter.run(
      () => new Promise<void>((resolve) => (release = resolve))
    );
    const second = limiter.run(() => Promise.resolve(undefined));
    await expect(limiter.run(() => Promise.resolve(undefined))).rejects.toThrow(
      "Concurrency limit"
    );
    release?.();
    await Promise.all([first, second]);
  });

  it("transfers a released slot without admitting a fresh caller twice", async () => {
    const limiter = new ConcurrencyLimiter(1, 1);
    let active = 0;
    let peak = 0;
    let releaseFirst: (() => void) | undefined;
    let releaseQueued: (() => void) | undefined;
    const firstGate = new Promise<void>((resolve) => (releaseFirst = resolve));
    const queuedGate = new Promise<void>(
      (resolve) => (releaseQueued = resolve)
    );
    const tracked = async (gate: Promise<void>) => {
      active += 1;
      peak = Math.max(peak, active);
      await gate;
      active -= 1;
    };

    const first = limiter.run(() => tracked(firstGate));
    await Promise.resolve();
    const second = limiter.run(() => tracked(queuedGate));
    const waiting = (limiter as unknown as { waiting: Array<() => void> })
      .waiting;
    const wakeQueuedCaller = waiting[0];
    if (!wakeQueuedCaller) {
      throw new Error("Expected the second operation to be queued.");
    }
    let third: Promise<void> | undefined;
    waiting[0] = () => {
      wakeQueuedCaller();
      third = limiter.run(() => tracked(queuedGate));
    };
    releaseFirst?.();
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();

    expect(peak).toBe(1);
    releaseQueued?.();
    await Promise.all([first, second, third!]);
    expect(active).toBe(0);
  });
});

describe("client rate limiter", () => {
  it("keeps each client's budget separate and resets after one minute", () => {
    let now = 1_000_000;
    const limiter = new ClientRateLimiter(2, () => now);
    expect(limiter.admit("a")).toBe(0);
    expect(limiter.admit("a")).toBe(0);
    expect(limiter.admit("a")).toBe(60);
    expect(limiter.admit("b")).toBe(0);
    now += 59_500;
    expect(limiter.admit("a")).toBe(1);
    now += 500;
    expect(limiter.admit("a")).toBe(0);
  });

  it("tracks a bounded number of clients and admits new ones as windows expire", () => {
    let now = 1_000_000;
    const limiter = new ClientRateLimiter(5, () => now, 2);
    const tracked = () =>
      (limiter as unknown as { windows: Map<string, unknown> }).windows.size;
    expect(limiter.admit("a")).toBe(0);
    now += 10_000;
    expect(limiter.admit("b")).toBe(0);
    // Both windows are live, so a third client waits for the oldest to expire.
    expect(limiter.admit("c")).toBe(50);
    expect(tracked()).toBe(2);
    expect(limiter.admit("a")).toBe(0);
    now += 50_000;
    expect(limiter.admit("c")).toBe(0);
    expect(tracked()).toBe(2);
  });
});
