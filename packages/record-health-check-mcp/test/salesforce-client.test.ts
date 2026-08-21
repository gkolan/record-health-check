import { describe, expect, it, vi } from "vitest";

import { SalesforceClient } from "../src/salesforce-client.js";
import { testConfig } from "./helpers.js";

const logger = { log: vi.fn() };
const success = {
  contractVersion: "1.0",
  correlationId: "corr-1",
  success: true,
  operation: "RUN_CHECK",
  status: "PASS"
};

function json(value: unknown, status = 200): Response {
  return new Response(JSON.stringify(value), {
    status,
    headers: { "content-type": "application/json" }
  });
}

describe("Salesforce client", () => {
  it("reuses a client-credentials token and sends only the fixed contract", async () => {
    const fetcher = vi
      .fn<typeof fetch>()
      .mockResolvedValueOnce(
        json({
          access_token: "access-token",
          instance_url: "https://instance.salesforce.test",
          expires_in: 900
        })
      )
      .mockImplementation(() => Promise.resolve(json(success)));
    const client = new SalesforceClient(testConfig(), logger, fetcher);
    const input = {
      operation: "RUN_CHECK" as const,
      recordId: "001000000000001AAA",
      qualifiedApiName: "Check_One",
      correlationId: "corr-1"
    };
    await client.evaluate(input);
    await client.evaluate(input);
    expect(fetcher).toHaveBeenCalledTimes(3);
    expect(fetcher.mock.calls[1]?.[1]?.body).toBe(JSON.stringify(input));
    expect(fetcher.mock.calls[1]?.[1]?.headers).toMatchObject({
      authorization: "Bearer access-token"
    });
  });

  it("refreshes once after an upstream 401", async () => {
    const fetcher = vi
      .fn<typeof fetch>()
      .mockResolvedValueOnce(
        json({
          access_token: "one",
          instance_url: "https://instance.salesforce.test"
        })
      )
      .mockResolvedValueOnce(json({ error: "expired" }, 401))
      .mockResolvedValueOnce(
        json({
          access_token: "two",
          instance_url: "https://instance.salesforce.test"
        })
      )
      .mockResolvedValueOnce(json(success));
    const client = new SalesforceClient(testConfig(), logger, fetcher);
    await expect(
      client.evaluate({
        operation: "RUN_CHECK",
        recordId: "001000000000001AAA",
        qualifiedApiName: "Check_One"
      })
    ).resolves.toMatchObject({ status: "PASS" });
    expect(fetcher).toHaveBeenCalledTimes(4);
  });

  it("maps an exhausted 401 refresh and request limit safely", async () => {
    const input = {
      operation: "RUN_CHECK" as const,
      recordId: "001000000000001AAA",
      qualifiedApiName: "Check_One"
    };
    const token = {
      access_token: "token",
      instance_url: "https://instance.salesforce.test"
    };
    const authFetcher = vi
      .fn<typeof fetch>()
      .mockResolvedValueOnce(json(token))
      .mockResolvedValueOnce(json({ error: "expired" }, 401))
      .mockResolvedValueOnce(json(token))
      .mockResolvedValueOnce(json({ error: "revoked" }, 401));
    await expect(
      new SalesforceClient(testConfig(), logger, authFetcher).evaluate(input)
    ).rejects.toMatchObject({ code: "SALESFORCE_AUTH" });

    const limitFetcher = vi
      .fn<typeof fetch>()
      .mockResolvedValueOnce(json(token))
      .mockResolvedValueOnce(json({ error: "busy" }, 429))
      .mockResolvedValueOnce(json({ error: "still-busy" }, 429));
    await expect(
      new SalesforceClient(testConfig(), logger, limitFetcher).evaluate(input)
    ).rejects.toMatchObject({ code: "UPSTREAM_LIMIT" });
  });

  it("rejects an unapproved Salesforce instance host", async () => {
    const fetcher = vi.fn<typeof fetch>().mockResolvedValue(
      json({
        access_token: "token",
        instance_url: "https://attacker.example"
      })
    );
    const client = new SalesforceClient(testConfig(), logger, fetcher);
    await expect(
      client.evaluate({
        operation: "RUN_CHECK",
        recordId: "001000000000001AAA",
        qualifiedApiName: "Check_One"
      })
    ).rejects.toMatchObject({ code: "DESTINATION_REJECTED" });
  });

  it("rejects oversized and semantically invalid responses", async () => {
    const config = testConfig();
    config.salesforce.maxResponseBytes = 1024;
    const token = json({
      access_token: "token",
      instance_url: "https://instance.salesforce.test"
    });
    const oversized = new Response(JSON.stringify({ value: "x".repeat(2000) }));
    const fetcher = vi
      .fn<typeof fetch>()
      .mockResolvedValueOnce(token)
      .mockResolvedValueOnce(oversized);
    const client = new SalesforceClient(config, logger, fetcher);
    await expect(
      client.evaluate({
        operation: "RUN_CHECK",
        recordId: "001000000000001AAA",
        qualifiedApiName: "Check_One"
      })
    ).rejects.toMatchObject({ code: "UPSTREAM_LIMIT" });
  });

  it("accepts completed diagnostic results returned by the Salesforce boundary", async () => {
    const diagnostic = {
      contractVersion: "1.0",
      correlationId: "mcp-bad-apex",
      success: true,
      operation: "RUN_CHECK",
      status: "ERROR",
      reasonCode: "PLUGIN_THREW",
      diagnosticId: "diag-bad-apex",
      diagnosticCategory: "APEX_EXCEPTION",
      diagnosticSummary: "The configured Apex evaluator threw an exception.",
      recommendedAction: "Correct the evaluator and rerun the Check."
    };
    const fetcher = vi
      .fn<typeof fetch>()
      .mockResolvedValueOnce(
        json({
          access_token: "token",
          instance_url: "https://instance.salesforce.test"
        })
      )
      .mockResolvedValueOnce(json(diagnostic));
    const client = new SalesforceClient(testConfig(), logger, fetcher);

    await expect(
      client.evaluate({
        operation: "RUN_CHECK",
        recordId: "001000000000001AAA",
        qualifiedApiName: "RHC_Diag_Apex_Throws",
        correlationId: "mcp-bad-apex"
      })
    ).resolves.toEqual(diagnostic);
  });

  it("retries only a transient Salesforce response", async () => {
    const fetcher = vi
      .fn<typeof fetch>()
      .mockResolvedValueOnce(
        json({
          access_token: "token",
          instance_url: "https://instance.salesforce.test"
        })
      )
      .mockResolvedValueOnce(json({ error: "busy" }, 429))
      .mockResolvedValueOnce(json(success));
    const client = new SalesforceClient(testConfig(), logger, fetcher);
    await expect(
      client.evaluate({
        operation: "RUN_CHECK",
        recordId: "001000000000001AAA",
        qualifiedApiName: "Check_One"
      })
    ).resolves.toMatchObject({ status: "PASS" });
    expect(fetcher).toHaveBeenCalledTimes(3);
    expect(logger.log).toHaveBeenCalledWith(
      "warn",
      "Salesforce request will be retried.",
      expect.objectContaining({ httpStatus: 429, retryCount: 1 })
    );
  });

  it("maps OAuth, timeout, malformed JSON, and contract-version failures safely", async () => {
    const input = {
      operation: "RUN_CHECK" as const,
      recordId: "001000000000001AAA",
      qualifiedApiName: "Check_One"
    };
    const authFailure = new SalesforceClient(
      testConfig(),
      logger,
      vi
        .fn<typeof fetch>()
        .mockResolvedValue(json({ error: "invalid_client" }, 401))
    );
    await expect(authFailure.evaluate(input)).rejects.toMatchObject({
      code: "SALESFORCE_AUTH"
    });

    const timeout = new SalesforceClient(
      testConfig(),
      logger,
      vi
        .fn<typeof fetch>()
        .mockRejectedValue(new Error("seeded network detail"))
    );
    await expect(timeout.evaluate(input)).rejects.toMatchObject({
      code: "UPSTREAM_UNAVAILABLE",
      safeMessage: "Salesforce is temporarily unavailable."
    });

    for (const response of [
      new Response("not-json"),
      json({ ...success, contractVersion: "9.9" })
    ]) {
      const fetcher = vi
        .fn<typeof fetch>()
        .mockResolvedValueOnce(
          json({
            access_token: "token",
            instance_url: "https://instance.salesforce.test"
          })
        )
        .mockResolvedValueOnce(response);
      const client = new SalesforceClient(testConfig(), logger, fetcher);
      await expect(client.evaluate(input)).rejects.toMatchObject({
        code: "UPSTREAM_CONTRACT"
      });
    }
  });
});
