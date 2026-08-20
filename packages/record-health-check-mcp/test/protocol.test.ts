import { createServer } from "node:http";

import {
  Client,
  StreamableHTTPClientTransport
} from "@modelcontextprotocol/client";
import { afterEach, describe, expect, it, vi } from "vitest";

import { createApp } from "../src/app.js";
import type { SalesforceClient } from "../src/salesforce-client.js";
import { testConfig } from "./helpers.js";

const servers: Array<ReturnType<typeof createServer>> = [];
afterEach(async () => {
  await Promise.all(
    servers
      .splice(0)
      .map(
        (server) =>
          new Promise<void>((resolve) => server.close(() => resolve()))
      )
  );
});

describe("MCP Streamable HTTP", () => {
  it("lists exactly two tools and returns structured Salesforce results", async () => {
    const evaluate = vi.fn().mockResolvedValue({
      contractVersion: "1.0",
      correlationId: "corr-1",
      success: true,
      operation: "RUN_CHECK",
      status: "PASS"
    });
    const config = testConfig();
    const app = createApp(config, { evaluate } as unknown as SalesforceClient, {
      log: vi.fn()
    });
    const httpServer = createServer(app);
    servers.push(httpServer);
    await new Promise<void>((resolve) =>
      httpServer.listen(0, "127.0.0.1", resolve)
    );
    const address = httpServer.address();
    if (!address || typeof address === "string")
      throw new Error("Test server did not bind.");

    const client = new Client({ name: "protocol-test", version: "1.0.0" });
    const transport = new StreamableHTTPClientTransport(
      new URL(`http://127.0.0.1:${address.port}/mcp`)
    );
    await client.connect(transport);
    const tools = await client.listTools();
    expect(tools.tools.map((tool) => tool.name)).toEqual([
      "run_record_health_check",
      "run_record_health_check_set"
    ]);
    const result = await client.callTool({
      name: "run_record_health_check",
      arguments: {
        recordId: "001000000000001AAA",
        qualifiedApiName: "Check_One",
        correlationId: "corr-1"
      }
    });
    expect(result.structuredContent).toMatchObject({
      status: "PASS",
      correlationId: "corr-1"
    });
    expect(evaluate).toHaveBeenCalledWith({
      operation: "RUN_CHECK",
      recordId: "001000000000001AAA",
      qualifiedApiName: "Check_One",
      correlationId: "corr-1"
    });
    const invalid = await client.callTool({
      name: "run_record_health_check",
      arguments: {
        recordId: "not-a-salesforce-id",
        qualifiedApiName: "Check_One",
        unexpected: true
      }
    });
    expect(invalid.isError).toBe(true);
    expect(evaluate).toHaveBeenCalledTimes(1);
    await client.close();
  });

  it("honors the kill switch without disclosing configuration", async () => {
    const config = testConfig({ killSwitch: true });
    const app = createApp(
      config,
      { evaluate: vi.fn() } as unknown as SalesforceClient,
      { log: vi.fn() }
    );
    const httpServer = createServer(app);
    servers.push(httpServer);
    await new Promise<void>((resolve) =>
      httpServer.listen(0, "127.0.0.1", resolve)
    );
    const address = httpServer.address();
    if (!address || typeof address === "string")
      throw new Error("Test server did not bind.");
    const response = await fetch(`http://127.0.0.1:${address.port}/healthz`);
    expect(response.status).toBe(503);
    expect(await response.json()).toEqual({
      status: "disabled",
      buildId: "test"
    });
  });

  it.each([
    ["run_record_health_check", "RUN_CHECK", "UNABLE_TO_EVALUATE", "FORMULA"],
    ["run_record_health_check", "RUN_CHECK", "ERROR", "APEX_EXCEPTION"],
    [
      "run_record_health_check_set",
      "RUN_CHECK_SET",
      "UNABLE_TO_EVALUATE",
      "QUERY"
    ],
    ["run_record_health_check_set", "RUN_CHECK_SET", "ERROR", "APEX_CONTRACT"]
  ] as const)(
    "preserves diagnosis fields for %s %s",
    async (toolName, operation, status, category) => {
      const resultBody = {
        contractVersion: "1.0",
        correlationId: `mcp-${category.toLowerCase()}`,
        success: true,
        operation,
        status,
        ...(operation === "RUN_CHECK"
          ? {
              reasonCode:
                status === "ERROR" ? "PLUGIN_THREW" : "INVALID_FORMULA"
            }
          : {
              passed: 0,
              failed: 0,
              skipped: 0,
              unable: status === "UNABLE_TO_EVALUATE" ? 1 : 0,
              systemError: status === "ERROR" ? 1 : 0
            }),
        diagnosticId: `diag-${category.toLowerCase()}`,
        diagnosticCategory: category,
        diagnosticSummary: "The seeded bad configuration was diagnosed.",
        recommendedAction: "Correct the named configuration and rerun."
      };
      const evaluate = vi.fn().mockResolvedValue(resultBody);
      const app = createApp(
        testConfig(),
        { evaluate } as unknown as SalesforceClient,
        { log: vi.fn() }
      );
      const httpServer = createServer(app);
      servers.push(httpServer);
      await new Promise<void>((resolve) =>
        httpServer.listen(0, "127.0.0.1", resolve)
      );
      const address = httpServer.address();
      if (!address || typeof address === "string")
        throw new Error("Test server did not bind.");
      const client = new Client({
        name: "diagnostic-matrix",
        version: "1.0.0"
      });
      await client.connect(
        new StreamableHTTPClientTransport(
          new URL(`http://127.0.0.1:${address.port}/mcp`)
        )
      );

      const result = await client.callTool({
        name: toolName,
        arguments: {
          recordId: "001000000000001AAA",
          qualifiedApiName: "RHC_Diagnostic_Bad_Fixture",
          correlationId: resultBody.correlationId
        }
      });

      expect(result.isError).toBe(false);
      expect(result.structuredContent).toEqual(resultBody);
      expect(result.content).toEqual([
        {
          type: "text",
          text: `${operation} completed with status ${status}. Correlation ID: ${resultBody.correlationId}.`
        }
      ]);
      await client.close();
    }
  );
});
