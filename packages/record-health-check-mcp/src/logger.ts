export type LogLevel = "info" | "warn" | "error";
export type SafeLogFields = {
  buildId?: string;
  correlationId?: string;
  durationMs?: number;
  errorType?: string;
  event?: string;
  httpStatus?: number;
  operation?: string;
  retryCount?: number;
};

export interface OperationalLogger {
  log(level: LogLevel, message: string, fields?: SafeLogFields): void;
}

export class JsonLogger implements OperationalLogger {
  log(level: LogLevel, message: string, fields: SafeLogFields = {}): void {
    process.stdout.write(
      `${JSON.stringify({ timestamp: new Date().toISOString(), level, message, ...fields })}\n`
    );
  }
}
