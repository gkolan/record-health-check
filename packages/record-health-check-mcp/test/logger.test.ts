import { describe, expect, it, vi } from "vitest";

import { JsonLogger } from "../src/logger.js";

describe("structured logger", () => {
  it("serializes only the fixed safe field set supplied by typed callers", () => {
    const write = vi.spyOn(process.stdout, "write").mockReturnValue(true);
    new JsonLogger().log("info", "MCP tool call completed.", {
      event: "tool_completed",
      operation: "RUN_CHECK",
      correlationId: "corr-1",
      durationMs: 12,
      buildId: "revision-123"
    });
    const output = String(write.mock.calls[0]?.[0]);
    expect(output).toContain('"event":"tool_completed"');
    for (const canary of [
      "fake-client-secret",
      "fake-access-token",
      "001-private-record"
    ]) {
      expect(output).not.toContain(canary);
    }
  });
});
