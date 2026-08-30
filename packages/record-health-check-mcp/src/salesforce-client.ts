import { setTimeout as delay } from "node:timers/promises";

import { z } from "zod";

import type { ServiceConfig } from "./config.js";
import {
  agentToolResponseSchema,
  correlationIdSchema,
  type AgentToolResponse,
  type Operation,
  qualifiedApiNameSchema,
  recordIdSchema
} from "./contract.js";
import { ServiceError } from "./errors.js";
import { ConcurrencyLimiter } from "./limiter.js";
import type { OperationalLogger } from "./logger.js";

const tokenSchema = z
  .object({
    access_token: z.string().min(1),
    instance_url: z.string().url(),
    expires_in: z.coerce.number().int().positive().optional()
  })
  .passthrough();
const salesforceRestErrorSchema = z
  .array(
    z
      .object({
        errorCode: z.string().min(1).max(120),
        message: z.string().min(1).max(1000)
      })
      .passthrough()
  )
  .min(1)
  .max(25);

type Token = {
  accessToken: string;
  instanceUrl: URL;
  expiresAt: number;
  generation: number;
};
type EvaluationRequest = {
  operation: Operation;
  recordId: string;
  qualifiedApiName: string;
  correlationId?: string | undefined;
};

export class SalesforceClient {
  private token: Token | undefined;
  private tokenPromise: Promise<Token> | undefined;
  private tokenGeneration = 0;
  private readonly limiter: ConcurrencyLimiter;

  constructor(
    private readonly config: ServiceConfig,
    private readonly logger: OperationalLogger,
    private readonly fetcher: typeof fetch = fetch
  ) {
    this.limiter = new ConcurrencyLimiter(config.salesforce.maxConcurrentCalls);
    this.assertAllowedHttps(config.salesforce.loginUrl);
  }

  evaluate(input: EvaluationRequest): Promise<AgentToolResponse> {
    const parsed = z
      .object({
        operation: z.enum(["RUN_CHECK", "RUN_CHECK_SET"]),
        recordId: recordIdSchema,
        qualifiedApiName: qualifiedApiNameSchema,
        correlationId: correlationIdSchema.optional()
      })
      .strict()
      .parse(input);
    return this.limiter.run(() => this.execute(parsed));
  }

  private async execute(input: EvaluationRequest): Promise<AgentToolResponse> {
    let authRefreshed = false;
    let retryCount = 0;
    while (true) {
      const token = await this.getToken();
      const target = new URL(
        this.config.salesforce.restPath,
        token.instanceUrl
      );
      this.assertAllowedHttps(target);
      const response = await this.request(target, {
        method: "POST",
        redirect: "error",
        headers: {
          authorization: `Bearer ${token.accessToken}`,
          "content-type": "application/json",
          accept: "application/json"
        },
        body: JSON.stringify(input)
      });
      if (response.status === 401 && !authRefreshed) {
        await this.discardResponse(response);
        await this.refreshToken(token.generation);
        authRefreshed = true;
        continue;
      }
      if (
        [429, 502, 503, 504].includes(response.status) &&
        retryCount < this.config.salesforce.maxRetries
      ) {
        await this.discardResponse(response);
        retryCount += 1;
        this.logger.log("warn", "Salesforce request will be retried.", {
          httpStatus: response.status,
          retryCount,
          operation: input.operation,
          ...(input.correlationId ? { correlationId: input.correlationId } : {})
        });
        await delay(Math.min(100 * 2 ** (retryCount - 1), 500));
        continue;
      }
      const body = await this.readBoundedJson(response);
      const parsed = agentToolResponseSchema.safeParse(body);
      if (!parsed.success) {
        const salesforceErrors = salesforceRestErrorSchema.safeParse(body);
        if (
          salesforceErrors.success &&
          salesforceErrors.data.some(
            (error) => error.errorCode === "REQUEST_LIMIT_EXCEEDED"
          )
        ) {
          throw new ServiceError(
            "UPSTREAM_LIMIT",
            "Salesforce is at its request limit.",
            503
          );
        }
        if ([401, 403].includes(response.status)) {
          throw new ServiceError(
            "SALESFORCE_AUTH",
            "Salesforce authorization failed.",
            502
          );
        }
        if (response.status === 429) {
          throw new ServiceError(
            "UPSTREAM_LIMIT",
            "Salesforce is at its request limit.",
            503
          );
        }
        if (response.status >= 500) {
          throw new ServiceError(
            "UPSTREAM_UNAVAILABLE",
            "Salesforce is temporarily unavailable.",
            503
          );
        }
        throw new ServiceError(
          "UPSTREAM_CONTRACT",
          "Salesforce returned an invalid response.",
          502
        );
      }
      if (!response.ok && parsed.data.success) {
        throw new ServiceError(
          "UPSTREAM_CONTRACT",
          "Salesforce returned an inconsistent response.",
          502
        );
      }
      return parsed.data;
    }
  }

  private async getToken(): Promise<Token> {
    if (this.token && this.token.expiresAt - 60_000 > Date.now())
      return this.token;
    if (this.tokenPromise) return this.tokenPromise;
    this.tokenPromise = this.fetchToken();
    try {
      this.token = await this.tokenPromise;
      return this.token;
    } finally {
      this.tokenPromise = undefined;
    }
  }

  private async refreshToken(staleGeneration: number): Promise<Token> {
    if (this.token && this.token.generation !== staleGeneration) {
      return this.token;
    }
    this.token = undefined;
    return this.getToken();
  }

  private async fetchToken(): Promise<Token> {
    const target = new URL(
      "/services/oauth2/token",
      this.config.salesforce.loginUrl
    );
    this.assertAllowedHttps(target);
    const form = new URLSearchParams({
      grant_type: "client_credentials",
      client_id: this.config.salesforce.clientId,
      client_secret: this.config.salesforce.clientSecret
    });
    const response = await this.request(target, {
      method: "POST",
      redirect: "error",
      headers: {
        "content-type": "application/x-www-form-urlencoded",
        accept: "application/json"
      },
      body: form
    });
    if (!response.ok) {
      throw new ServiceError(
        "SALESFORCE_AUTH",
        "Salesforce authentication failed.",
        502
      );
    }
    const parsed = tokenSchema.safeParse(await this.readBoundedJson(response));
    if (!parsed.success) {
      throw new ServiceError(
        "SALESFORCE_AUTH",
        "Salesforce authentication returned an invalid response.",
        502
      );
    }
    const instanceUrl = new URL(parsed.data.instance_url);
    this.assertAllowedHttps(instanceUrl);
    return {
      accessToken: parsed.data.access_token,
      instanceUrl,
      expiresAt: Date.now() + (parsed.data.expires_in ?? 900) * 1000,
      generation: ++this.tokenGeneration
    };
  }

  private async request(url: URL, init: RequestInit): Promise<Response> {
    try {
      return await this.fetcher(url, {
        ...init,
        signal: AbortSignal.timeout(this.config.salesforce.timeoutMs)
      });
    } catch {
      throw new ServiceError(
        "UPSTREAM_UNAVAILABLE",
        "Salesforce is temporarily unavailable.",
        503
      );
    }
  }

  private async readBoundedJson(response: Response): Promise<unknown> {
    const declared = Number(response.headers.get("content-length") ?? 0);
    if (declared > this.config.salesforce.maxResponseBytes) {
      throw new ServiceError(
        "UPSTREAM_LIMIT",
        "Salesforce response exceeded the size limit.",
        502
      );
    }
    const reader = response.body?.getReader();
    const chunks: Uint8Array[] = [];
    let total = 0;
    if (reader) {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        total += value.byteLength;
        if (total > this.config.salesforce.maxResponseBytes) {
          await reader.cancel();
          throw new ServiceError(
            "UPSTREAM_LIMIT",
            "Salesforce response exceeded the size limit.",
            502
          );
        }
        chunks.push(value);
      }
    }
    const bytes = new Uint8Array(total);
    let offset = 0;
    for (const chunk of chunks) {
      bytes.set(chunk, offset);
      offset += chunk.byteLength;
    }
    try {
      return JSON.parse(new TextDecoder().decode(bytes));
    } catch {
      throw new ServiceError(
        "UPSTREAM_CONTRACT",
        "Salesforce returned invalid JSON.",
        502
      );
    }
  }

  private async discardResponse(response: Response): Promise<void> {
    try {
      await response.body?.cancel();
    } catch {
      // Response cleanup must never hide the upstream status being handled.
    }
  }

  private assertAllowedHttps(url: URL): void {
    if (
      url.protocol !== "https:" ||
      !this.config.salesforce.allowedHosts.includes(url.hostname)
    ) {
      throw new ServiceError(
        "DESTINATION_REJECTED",
        "The Salesforce destination is not permitted.",
        500
      );
    }
  }
}
