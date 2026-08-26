import { EventEmitter } from "node:events";

import { describe, expect, it, vi } from "vitest";

import { attachStartupErrorHandler, safeStartupError } from "../src/startup.js";

function nodeError(code: string, message: string): Error & { code: string } {
  return Object.assign(new Error(message), { code });
}

describe("startup errors", () => {
  it("explains an occupied address without exposing its value", () => {
    const message = safeStartupError(
      nodeError("EADDRINUSE", "listen EADDRINUSE: 127.0.0.1:43123")
    );

    expect(message).toContain("already in use");
    expect(message).not.toContain("127.0.0.1");
    expect(message).not.toContain("43123");
  });

  it("explains a bind permission failure without exposing its value", () => {
    const message = safeStartupError(
      nodeError("EACCES", "listen EACCES: 0.0.0.0:80")
    );

    expect(message).toContain("cannot bind");
    expect(message).not.toContain("0.0.0.0");
  });

  it("uses a generic message for unknown failures", () => {
    expect(safeStartupError(new Error("secret runtime detail"))).toBe(
      "MCP service could not start."
    );
  });

  it("reports an asynchronous server error through the safe formatter", () => {
    const server = new EventEmitter();
    const report = vi.fn();
    const terminate = vi.fn();
    attachStartupErrorHandler(server, report, terminate);

    server.emit("error", nodeError("EADDRINUSE", "sensitive bind detail"));

    expect(report).toHaveBeenCalledOnce();
    expect(report).toHaveBeenCalledWith(
      "MCP service could not start because the configured address is already in use."
    );
    expect(terminate).toHaveBeenCalledOnce();
    expect(terminate).toHaveBeenCalledWith(1);
  });

  it("writes and terminates through the production defaults", () => {
    const server = new EventEmitter();
    const stderr = vi
      .spyOn(process.stderr, "write")
      .mockImplementation(() => true);
    const exit = vi
      .spyOn(process, "exit")
      .mockImplementation((() => undefined) as never);
    attachStartupErrorHandler(server);

    server.emit("error", nodeError("EACCES", "sensitive bind detail"));

    expect(stderr).toHaveBeenCalledWith(
      "MCP service could not start because it cannot bind the configured address.\n"
    );
    expect(exit).toHaveBeenCalledWith(1);
    stderr.mockRestore();
    exit.mockRestore();
  });
});
