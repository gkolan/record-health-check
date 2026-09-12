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
        qualifiedApiName: "Check_One",
        correlationId: "corr-1"
      })
    ).resolves.toMatchObject({ status: "PASS" });
    expect(fetcher).toHaveBeenCalledTimes(4);
  });

  it("refreshes an expired token even when transient retries are disabled", async () => {
    const config = testConfig();
    config.salesforce.maxRetries = 0;
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

    await expect(
      new SalesforceClient(config, logger, fetcher).evaluate({
        operation: "RUN_CHECK",
        recordId: "001000000000001AAA",
        qualifiedApiName: "Check_One",
        correlationId: "corr-1"
      })
    ).resolves.toMatchObject({ status: "PASS" });
  });

  it("keeps an authentication refresh available after a transient retry", async () => {
    const config = testConfig();
    config.salesforce.maxRetries = 1;
    const fetcher = vi
      .fn<typeof fetch>()
      .mockResolvedValueOnce(
        json({
          access_token: "one",
          instance_url: "https://instance.salesforce.test"
        })
      )
      .mockResolvedValueOnce(json({ error: "busy" }, 503))
      .mockResolvedValueOnce(json({ error: "expired" }, 401))
      .mockResolvedValueOnce(
        json({
          access_token: "two",
          instance_url: "https://instance.salesforce.test"
        })
      )
      .mockResolvedValueOnce(json(success));

    await expect(
      new SalesforceClient(config, logger, fetcher).evaluate({
        operation: "RUN_CHECK",
        recordId: "001000000000001AAA",
        qualifiedApiName: "Check_One",
        correlationId: "corr-1"
      })
    ).resolves.toMatchObject({ status: "PASS" });
  });

  it("single-flights a forced refresh across concurrent expired-token responses", async () => {
    let tokenCalls = 0;
    const fetcher = vi.fn<typeof fetch>((url, init) => {
      const target =
        typeof url === "string" ? url : url instanceof URL ? url.href : url.url;
      if (target.endsWith("/services/oauth2/token")) {
        tokenCalls += 1;
        return Promise.resolve(
          json({
            access_token: tokenCalls === 1 ? "stale" : "fresh",
            instance_url: "https://instance.salesforce.test"
          })
        );
      }
      const authorization = (init?.headers as Record<string, string>)
        .authorization;
      return Promise.resolve(
        authorization === "Bearer stale"
          ? json({ error: "expired" }, 401)
          : json(success)
      );
    });
    const client = new SalesforceClient(testConfig(), logger, fetcher);
    const input = {
      operation: "RUN_CHECK" as const,
      recordId: "001000000000001AAA",
      qualifiedApiName: "Check_One",
      correlationId: "corr-1"
    };

    await expect(
      Promise.all([client.evaluate(input), client.evaluate(input)])
    ).resolves.toHaveLength(2);
    expect(tokenCalls).toBe(2);
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

  it("distinguishes Salesforce API exhaustion from a normal 403 permission failure", async () => {
    const input = {
      operation: "RUN_CHECK" as const,
      recordId: "001000000000001AAA",
      qualifiedApiName: "Check_One"
    };
    const token = {
      access_token: "token",
      instance_url: "https://instance.salesforce.test"
    };
    const limitFetcher = vi
      .fn<typeof fetch>()
      .mockResolvedValueOnce(json(token))
      .mockResolvedValueOnce(
        json(
          [
            {
              message: "TotalRequests Limit exceeded.",
              errorCode: "REQUEST_LIMIT_EXCEEDED"
            }
          ],
          403
        )
      );

    await expect(
      new SalesforceClient(testConfig(), logger, limitFetcher).evaluate(input)
    ).rejects.toMatchObject({ code: "UPSTREAM_LIMIT" });

    const permissionFetcher = vi
      .fn<typeof fetch>()
      .mockResolvedValueOnce(json(token))
      .mockResolvedValueOnce(
        json(
          [
            {
              message: "You do not have access to the Apex class.",
              errorCode: "INSUFFICIENT_ACCESS"
            }
          ],
          403
        )
      );

    await expect(
      new SalesforceClient(testConfig(), logger, permissionFetcher).evaluate(
        input
      )
    ).rejects.toMatchObject({ code: "SALESFORCE_AUTH" });
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
        qualifiedApiName: "Check_One",
        correlationId: "corr-1"
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

  it("cancels an oversized response stream as soon as the bound is crossed", async () => {
    const config = testConfig();
    config.salesforce.maxResponseBytes = 256;
    const cancel = vi.fn();
    let sent = false;
    const oversized = new Response(
      new ReadableStream<Uint8Array>({
        pull(controller) {
          if (!sent) {
            sent = true;
            controller.enqueue(new TextEncoder().encode("x".repeat(257)));
          }
        },
        cancel
      })
    );
    const fetcher = vi
      .fn<typeof fetch>()
      .mockResolvedValueOnce(
        json({
          access_token: "token",
          instance_url: "https://instance.salesforce.test"
        })
      )
      .mockResolvedValueOnce(oversized);

    await expect(
      new SalesforceClient(config, logger, fetcher).evaluate({
        operation: "RUN_CHECK",
        recordId: "001000000000001AAA",
        qualifiedApiName: "Check_One"
      })
    ).rejects.toMatchObject({ code: "UPSTREAM_LIMIT" });
    expect(cancel).toHaveBeenCalledOnce();
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
        qualifiedApiName: "Check_One",
        correlationId: "corr-1"
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

  it("M01 Wrong operation", async () => {
    const fetcher = vi
      .fn<typeof fetch>()
      .mockResolvedValueOnce(
        json({
          access_token: "token",
          instance_url: "https://instance.salesforce.test"
        })
      )
      .mockResolvedValueOnce(
        json({
          contractVersion: "1.0",
          correlationId: "corr-wrong-operation",
          success: true,
          operation: "RUN_CHECK_SET",
          status: "SKIPPED",
          passed: 0,
          failed: 0,
          skipped: 0,
          unable: 0,
          systemError: 0
        })
      );

    await expect(
      new SalesforceClient(testConfig(), logger, fetcher).evaluate({
        operation: "RUN_CHECK",
        recordId: "001000000000001AAA",
        qualifiedApiName: "Check_One",
        correlationId: "corr-wrong-operation"
      })
    ).rejects.toMatchObject({
      code: "UPSTREAM_CONTRACT",
      safeMessage: "Salesforce returned an invalid response."
    });
  });

  it("M02 Wrong supplied correlation", async () => {
    const fetcher = vi
      .fn<typeof fetch>()
      .mockResolvedValueOnce(
        json({
          access_token: "token",
          instance_url: "https://instance.salesforce.test"
        })
      )
      .mockResolvedValueOnce(
        json({
          ...success,
          correlationId: "corr-from-another-request"
        })
      );

    await expect(
      new SalesforceClient(testConfig(), logger, fetcher).evaluate({
        operation: "RUN_CHECK",
        recordId: "001000000000001AAA",
        qualifiedApiName: "Check_One",
        correlationId: "corr-supplied"
      })
    ).rejects.toMatchObject({ code: "UPSTREAM_CONTRACT" });
  });

  it("M03 Generated retry correlation", async () => {
    const requestBodies: string[] = [];
    const fetcher = vi.fn<typeof fetch>((url, init) => {
      const requestUrl = url instanceof Request ? url.url : url;
      if (new URL(requestUrl).pathname === "/services/oauth2/token") {
        return Promise.resolve(
          json({
            access_token: "token",
            instance_url: "https://instance.salesforce.test"
          })
        );
      }
      const body = init?.body;
      if (typeof body !== "string") throw new Error("Expected JSON body.");
      requestBodies.push(body);
      if (requestBodies.length === 1)
        return Promise.resolve(json({ error: "busy" }, 429));
      const request = JSON.parse(body) as { correlationId: string };
      return Promise.resolve(
        json({ ...success, correlationId: request.correlationId })
      );
    });

    const result = await new SalesforceClient(
      testConfig(),
      logger,
      fetcher
    ).evaluate({
      operation: "RUN_CHECK",
      recordId: "001000000000001AAA",
      qualifiedApiName: "Check_One"
    });

    expect(result.correlationId).toMatch(/^[0-9a-f-]{36}$/);
    expect(requestBodies).toHaveLength(2);
    expect(requestBodies[1]).toBe(requestBodies[0]);
  });

  it("M04 Impossible counts", async () => {
    const fetcher = vi
      .fn<typeof fetch>()
      .mockResolvedValueOnce(
        json({
          access_token: "token",
          instance_url: "https://instance.salesforce.test"
        })
      )
      .mockResolvedValueOnce(
        json({
          contractVersion: "1.0",
          correlationId: "corr-impossible-counts",
          success: true,
          operation: "RUN_CHECK_SET",
          status: "FAIL",
          passed: 25,
          failed: 25,
          skipped: 0,
          unable: 0,
          systemError: 0
        })
      );

    await expect(
      new SalesforceClient(testConfig(), logger, fetcher).evaluate({
        operation: "RUN_CHECK_SET",
        recordId: "001000000000001AAA",
        qualifiedApiName: "Set_One",
        correlationId: "corr-impossible-counts"
      })
    ).rejects.toMatchObject({ code: "UPSTREAM_CONTRACT" });
  });

  it("M07 Late response and queue cleanup", async () => {
    const config = testConfig();
    config.salesforce.maxConcurrentCalls = 1;
    const token = {
      access_token: "token",
      instance_url: "https://instance.salesforce.test"
    };
    let rejectFirst: ((reason?: unknown) => void) | undefined;
    const firstRequest = new Promise<Response>((_resolve, reject) => {
      rejectFirst = reject;
    });
    const fetcher = vi
      .fn<typeof fetch>()
      .mockResolvedValueOnce(json(token))
      .mockReturnValueOnce(firstRequest)
      .mockImplementationOnce((_url, init) => {
        const body = JSON.parse(init?.body as string) as {
          correlationId: string;
        };
        return Promise.resolve(
          json({ ...success, correlationId: body.correlationId })
        );
      });
    const client = new SalesforceClient(config, logger, fetcher);
    const first = client.evaluate({
      operation: "RUN_CHECK",
      recordId: "001000000000001AAA",
      qualifiedApiName: "Check_One",
      correlationId: "corr-timeout"
    });
    const second = client.evaluate({
      operation: "RUN_CHECK",
      recordId: "001000000000002AAA",
      qualifiedApiName: "Check_Two",
      correlationId: "corr-next"
    });

    rejectFirst?.(new DOMException("timed out", "AbortError"));
    await expect(first).rejects.toMatchObject({ code: "UPSTREAM_UNAVAILABLE" });
    await expect(second).resolves.toMatchObject({
      success: true,
      correlationId: "corr-next"
    });
  });

  it("M08 Legacy correct client", async () => {
    const fetcher = vi
      .fn<typeof fetch>()
      .mockResolvedValueOnce(
        json({
          access_token: "token",
          instance_url: "https://instance.salesforce.test"
        })
      )
      .mockImplementationOnce((_url, init) => {
        const body = JSON.parse(init?.body as string) as {
          correlationId: string;
        };
        return Promise.resolve(
          json({
            ...success,
            operation: "RUN_CHECK_SET",
            correlationId: body.correlationId
          })
        );
      })
      .mockImplementationOnce((_url, init) => {
        const body = JSON.parse(init?.body as string) as {
          correlationId: string;
        };
        return Promise.resolve(
          json({ ...success, correlationId: body.correlationId })
        );
      });
    const client = new SalesforceClient(testConfig(), logger, fetcher);
    const legacyInput = {
      operation: "RUN_CHECK" as const,
      recordId: "001000000000001AAA",
      qualifiedApiName: "Check_One"
    };

    await expect(client.evaluate(legacyInput)).rejects.toMatchObject({
      code: "UPSTREAM_CONTRACT"
    });
    await expect(client.evaluate(legacyInput)).resolves.toMatchObject({
      success: true,
      operation: "RUN_CHECK"
    });
    const firstBody = JSON.parse(
      fetcher.mock.calls[1]?.[1]?.body as string
    ) as {
      correlationId: string;
    };
    const secondBody = JSON.parse(
      fetcher.mock.calls[2]?.[1]?.body as string
    ) as {
      correlationId: string;
    };
    expect(secondBody.correlationId).not.toBe(firstBody.correlationId);
  });
});

describe("response stream failure cleanup", () => {
  const input = {
    operation: "RUN_CHECK" as const,
    recordId: "001000000000001AAA",
    qualifiedApiName: "Check_One",
    correlationId: "corr-1"
  };
  const token = {
    access_token: "token",
    instance_url: "https://instance.salesforce.test"
  };

  it.each(["token", "evaluation"])(
    "cancels an oversized declared %s body",
    async (stage) => {
      const cancel = vi.fn();
      const response = new Response(new ReadableStream({ cancel }), {
        headers: { "content-length": "2048" }
      });
      const fetcher = vi.fn<typeof fetch>();
      if (stage === "evaluation") fetcher.mockResolvedValueOnce(json(token));
      fetcher.mockResolvedValueOnce(response);
      const config = testConfig();
      config.salesforce.maxResponseBytes = 1024;
      await expect(
        new SalesforceClient(config, logger, fetcher).evaluate(input)
      ).rejects.toMatchObject({ code: "UPSTREAM_LIMIT" });
      expect(cancel).toHaveBeenCalledOnce();
      expect(response.body?.locked).toBe(false);
    }
  );

  it("cancels a rejected token body without masking authentication failure", async () => {
    const cancel = vi
      .fn()
      .mockRejectedValue(new Error("private cleanup detail"));
    const response = new Response(new ReadableStream({ cancel }), {
      status: 401
    });
    const fetcher = vi.fn<typeof fetch>().mockResolvedValue(response);
    await expect(
      new SalesforceClient(testConfig(), logger, fetcher).evaluate(input)
    ).rejects.toMatchObject({
      code: "SALESFORCE_AUTH",
      safeMessage: "Salesforce authentication failed."
    });
    expect(cancel).toHaveBeenCalledOnce();
  });

  it.each(["token", "evaluation"])(
    "maps interrupted %s reads safely and releases the next request",
    async (stage) => {
      const response = new Response(
        new ReadableStream({
          start(controller) {
            controller.error(
              new DOMException("private stream detail", "AbortError")
            );
          }
        })
      );
      const fetcher = vi.fn<typeof fetch>();
      if (stage === "evaluation") fetcher.mockResolvedValueOnce(json(token));
      fetcher.mockResolvedValueOnce(response);
      if (stage === "token") fetcher.mockResolvedValueOnce(json(token));
      fetcher.mockResolvedValueOnce(json(success));
      const config = testConfig();
      config.salesforce.maxConcurrentCalls = 1;
      const client = new SalesforceClient(config, logger, fetcher);
      const first = client.evaluate(input);
      const next = client.evaluate(input);
      await expect(first).rejects.toMatchObject({
        code: "UPSTREAM_UNAVAILABLE",
        safeMessage: "Salesforce is temporarily unavailable."
      });
      await expect(next).resolves.toEqual(success);
      expect(response.body?.locked).toBe(false);
    }
  );

  it("preserves the size error when stream cancellation rejects", async () => {
    const cancel = vi
      .fn()
      .mockRejectedValue(new Error("private cancellation detail"));
    const response = new Response(
      new ReadableStream({
        start(controller) {
          controller.enqueue(new Uint8Array(2048));
        },
        cancel
      })
    );
    const fetcher = vi
      .fn<typeof fetch>()
      .mockResolvedValueOnce(json(token))
      .mockResolvedValueOnce(response);
    const config = testConfig();
    config.salesforce.maxResponseBytes = 1024;
    await expect(
      new SalesforceClient(config, logger, fetcher).evaluate(input)
    ).rejects.toMatchObject({ code: "UPSTREAM_LIMIT" });
    expect(cancel).toHaveBeenCalledOnce();
    expect(response.body?.locked).toBe(false);
  });
});
