type NodeError = Error & { code?: string };
type ErrorEmitter = {
  once(event: "error", listener: (error: Error) => void): unknown;
};

/** Returns a stable startup failure without exposing runtime details. */
export function safeStartupError(error: unknown): string {
  const code = error instanceof Error ? (error as NodeError).code : undefined;
  if (code === "EADDRINUSE") {
    return "MCP service could not start because the configured address is already in use.";
  }
  if (code === "EACCES") {
    return "MCP service could not start because it cannot bind the configured address.";
  }
  return "MCP service could not start.";
}

/** Attaches the listener required to keep asynchronous bind failures controlled. */
export function attachStartupErrorHandler(
  server: ErrorEmitter,
  report: (message: string) => void = (message) => {
    process.stderr.write(`${message}\n`);
  },
  terminate: (exitCode: number) => void = (exitCode) => process.exit(exitCode)
): void {
  server.once("error", (error) => {
    report(safeStartupError(error));
    terminate(1);
  });
}
