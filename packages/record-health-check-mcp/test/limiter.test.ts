import { describe, expect, it } from "vitest";

import { ConcurrencyLimiter } from "../src/limiter.js";

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
});
