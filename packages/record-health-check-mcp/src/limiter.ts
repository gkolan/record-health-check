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
    this.active += 1;
  }

  private release(): void {
    this.active -= 1;
    this.waiting.shift()?.();
  }
}

export class ConcurrencyLimitError extends Error {
  constructor() {
    super("Concurrency limit reached.");
    this.name = "ConcurrencyLimitError";
  }
}
