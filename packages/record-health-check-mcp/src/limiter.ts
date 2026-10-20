export class ConcurrencyLimiter {
  private active = 0;
  private readonly waiting: Array<() => void> = [];

  constructor(
    private readonly maximum: number,
    private readonly maximumWaiting = maximum
  ) {}

  async run<T>(operation: () => Promise<T>): Promise<T> {
    await this.acquire();
    try {
      return await operation();
    } finally {
      this.release();
    }
  }

  private async acquire(): Promise<void> {
    if (this.active < this.maximum) {
      this.active += 1;
      return;
    }
    if (this.waiting.length >= this.maximumWaiting) {
      throw new ConcurrencyLimitError();
    }
    await new Promise<void>((resolve) => this.waiting.push(resolve));
  }

  private release(): void {
    const next = this.waiting.shift();
    if (next) {
      next();
      return;
    }
    this.active -= 1;
  }
}

export class ConcurrencyLimitError extends Error {
  constructor() {
    super("Concurrency limit reached.");
    this.name = "ConcurrencyLimitError";
  }
}

const WINDOW_MS = 60_000;

/**
 * Fixed one-minute request budget per authenticated client.
 * ponytail: in-memory per replica; behind more than one replica, enforce the
 * quota at the gateway or move these counters to a shared store.
 */
export class ClientRateLimiter {
  private readonly windows = new Map<
    string,
    { start: number; count: number }
  >();

  constructor(
    private readonly perMinute: number,
    private readonly now: () => number = Date.now
  ) {}

  /** Returns 0 when the request is admitted, otherwise seconds to wait. */
  admit(clientId: string): number {
    const now = this.now();
    let window = this.windows.get(clientId);
    if (!window || now - window.start >= WINDOW_MS) {
      if (this.windows.size >= 10_000) this.evictExpired(now);
      window = { start: now, count: 0 };
      this.windows.set(clientId, window);
    }
    if (window.count >= this.perMinute) {
      return Math.max(1, Math.ceil((window.start + WINDOW_MS - now) / 1000));
    }
    window.count += 1;
    return 0;
  }

  private evictExpired(now: number): void {
    for (const [clientId, window] of this.windows) {
      if (now - window.start >= WINDOW_MS) this.windows.delete(clientId);
    }
  }
}
