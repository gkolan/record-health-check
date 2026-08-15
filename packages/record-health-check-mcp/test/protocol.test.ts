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
});
