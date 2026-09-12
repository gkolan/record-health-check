import { createServer } from "node:http";

import {
  Client,
  StreamableHTTPClientTransport
} from "@modelcontextprotocol/client";
import { afterEach, describe, expect, it, vi } from "vitest";

import { createApp } from "../src/app.js";
import { ServiceError } from "../src/errors.js";
import { ConcurrencyLimitError } from "../src/limiter.js";
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
  it("advertises OAuth protected-resource metadata and challenges unauthenticated clients", async () => {
    const config = testConfig({
      authMode: "jwt",
      authIssuer: "https://issuer.example.test",
      authAudience: "record-health-check",
      authJwksUrl: new URL("https://issuer.example.test/.well-known/jwks.json")
    });
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
    const baseUrl = `http://127.0.0.1:${address.port}`;

    const metadata = await fetch(
      `${baseUrl}/.well-known/oauth-protected-resource/mcp`
    );
    expect(metadata.status).toBe(200);
    expect(await metadata.json()).toEqual({
      resource: config.serverUrl.href,
      authorization_servers: [config.authIssuer],
      scopes_supported: [config.requiredScope],
      bearer_methods_supported: ["header"]
    });

    const unauthorized = await fetch(`${baseUrl}/mcp`, {
      method: "POST",
      headers: {
        accept: "application/json, text/event-stream",
        "content-type": "application/json"
      },
      body: JSON.stringify({
        jsonrpc: "2.0",
        id: 1,
        method: "initialize",
        params: {
          protocolVersion: "2025-11-25",
          capabilities: {},
          clientInfo: { name: "auth-discovery-test", version: "1.0.0" }
        }
      })
    });
    expect(unauthorized.status).toBe(401);
    expect(unauthorized.headers.get("www-authenticate")).toContain(
      `resource_metadata="${config.serverUrl.origin}/.well-known/oauth-protected-resource/mcp"`
    );
    expect(unauthorized.headers.get("www-authenticate")).toContain(
      `scope="${config.requiredScope}"`
    );
  });

  it("handles GET on the Streamable HTTP endpoint with an explicit 405", async () => {
    const app = createApp(
      testConfig(),
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

    const response = await fetch(`http://127.0.0.1:${address.port}/mcp`, {
      headers: { accept: "text/event-stream" }
    });
    expect(response.status).toBe(405);
    expect(response.headers.get("allow")).toBe("POST");
  });

  it("rejects request bodies above the service limit before tool dispatch", async () => {
    const evaluate = vi.fn();
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

    const response = await fetch(`http://127.0.0.1:${address.port}/mcp`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ value: "x".repeat(33 * 1024) })
    });

    expect(response.status).toBe(413);
    expect(evaluate).not.toHaveBeenCalled();
  });

  it("returns a structured LIMIT response for local concurrency exhaustion", async () => {
    const evaluate = vi.fn().mockRejectedValue(new ConcurrencyLimitError());
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

    const client = new Client({ name: "limit-test", version: "1.0.0" });
    await client.connect(
      new StreamableHTTPClientTransport(
        new URL(`http://127.0.0.1:${address.port}/mcp`)
      )
    );
    const result = await client.callTool({
      name: "run_record_health_check",
      arguments: {
        recordId: "001000000000001AAA",
        qualifiedApiName: "Check_One",
        correlationId: "corr-limit"
      }
    });

    expect(result.isError).toBe(true);
    expect(result.structuredContent).toEqual({
      contractVersion: "1.0",
      correlationId: "corr-limit",
      success: false,
      errorType: "LIMIT",
      errorMessage:
        "The service is at its concurrency limit. Retry the request later."
    });
    await client.close();
  });

  it("returns a structured failure for a bounded Salesforce adapter error", async () => {
    const evaluate = vi
      .fn()
      .mockRejectedValue(
        new ServiceError(
          "UPSTREAM_CONTRACT",
          "Salesforce returned an invalid response.",
          502
        )
      );
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

    const client = new Client({ name: "adapter-error-test", version: "1.0.0" });
    await client.connect(
      new StreamableHTTPClientTransport(
        new URL(`http://127.0.0.1:${address.port}/mcp`)
      )
    );
    const result = await client.callTool({
      name: "run_record_health_check",
      arguments: {
        recordId: "001000000000001AAA",
        qualifiedApiName: "Check_One",
        correlationId: "corr-adapter-error"
      }
    });

    expect(result.isError).toBe(true);
    expect(result.structuredContent).toEqual({
      contractVersion: "1.0",
      correlationId: "corr-adapter-error",
      success: false,
      errorType: "EXECUTION",
      errorMessage: "Salesforce returned an invalid response."
    });
    await client.close();
  });

  it("M09 Tool failure keeps effective correlation", async () => {
    const evaluate = vi
      .fn()
      .mockRejectedValue(
        new ServiceError(
          "UPSTREAM_CONTRACT",
          "Salesforce returned an invalid response.",
          502
        )
      );
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

    const client = new Client({ name: "correlation-test", version: "1.0.0" });
    await client.connect(
      new StreamableHTTPClientTransport(
        new URL(`http://127.0.0.1:${address.port}/mcp`)
      )
    );
    const result = await client.callTool({
      name: "run_record_health_check",
      arguments: {
        recordId: "001000000000001AAA",
        qualifiedApiName: "Check_One"
      }
    });

    const forwarded = evaluate.mock.calls[0]?.[0] as {
      correlationId: string;
    };
    expect(forwarded.correlationId).toMatch(/^mcp-[0-9a-f-]{36}$/);
    expect(result.isError).toBe(true);
    expect(result.structuredContent).toMatchObject({
      success: false,
      errorType: "EXECUTION",
      correlationId: forwarded.correlationId
    });
    await client.close();
  });

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
    for (const tool of tools.tools) {
      const inputProperties = tool.inputSchema.properties as Record<
        string,
        { description?: string }
      >;
      const outputProperties = tool.outputSchema?.properties as
        Record<string, { description?: string }> | undefined;
      expect(tool.description).toContain("Never treat UNABLE_TO_EVALUATE");
      expect(
        inputProperties.qualifiedApiName?.description?.toLowerCase()
      ).toContain("exact");
      expect(outputProperties?.status?.description).toContain("health status");
      expect(outputProperties?.diagnosticSummary?.description).toContain(
        "disclosure-safe"
      );
    }
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
      const firstContent = result.content[0];
      expect(firstContent?.type).toBe("text");
      if (!firstContent || firstContent.type !== "text") {
        throw new Error("Expected a text tool-result summary.");
      }
      expect(firstContent.text).toContain(
        `Diagnosis: ${resultBody.diagnosticSummary}`
      );
      await client.close();
    }
  );
});
