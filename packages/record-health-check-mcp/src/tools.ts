import { randomUUID } from "node:crypto";

import { McpServer } from "@modelcontextprotocol/server";

import {
  CONTRACT_VERSION,
  OPERATION_CHECK,
  OPERATION_CHECK_SET,
  toolInputSchema,
  type AgentToolFailure,
  type AgentToolResponse
} from "./contract.js";
import { ServiceError, type ServiceErrorType } from "./errors.js";
import { ConcurrencyLimitError } from "./limiter.js";
import type { OperationalLogger } from "./logger.js";
import type { SalesforceClient } from "./salesforce-client.js";

export function createToolServer(
  client: SalesforceClient,
  logger: OperationalLogger
): McpServer {
  const server = new McpServer({
    name: "record-health-check",
    version: "1.0.0"
  });
  register(server, client, logger, "run_record_health_check", OPERATION_CHECK);
  register(
    server,
    client,
    logger,
    "run_record_health_check_set",
    OPERATION_CHECK_SET
  );
  return server;
}

export function errorTypeForServiceError(
  code: ServiceErrorType
): AgentToolFailure["errorType"] {
  if (code === "SALESFORCE_AUTH") return "AUTHORIZATION";
  if (code === "DESTINATION_REJECTED") return "VALIDATION";
  if (code === "UPSTREAM_LIMIT") return "LIMIT";
  return "EXECUTION";
}

function register(
  server: McpServer,
  client: SalesforceClient,
  logger: OperationalLogger,
  name: "run_record_health_check" | "run_record_health_check_set",
  operation: typeof OPERATION_CHECK | typeof OPERATION_CHECK_SET
): void {
  server.registerTool(
    name,
    {
      title:
        operation === OPERATION_CHECK
          ? "Run Record Health Check"
          : "Run Record Health Check Set",
      description:
        operation === OPERATION_CHECK
          ? "Evaluate one configured Record Health Check against one Salesforce record."
          : "Evaluate one configured Record Health Check Set against one Salesforce record.",
      inputSchema: toolInputSchema,
      annotations: {
        readOnlyHint: true,
        destructiveHint: false,
        idempotentHint: true,
        openWorldHint: true
      }
    },
    async (input) => {
      const started = Date.now();
      try {
        const result = await client.evaluate({ operation, ...input });
        logger.log("info", "MCP tool call completed.", {
          event: "tool_completed",
          operation,
          correlationId: result.correlationId,
          durationMs: Date.now() - started
        });
        return toolResult(result);
      } catch (error) {
        if (error instanceof ConcurrencyLimitError) {
          const failure: AgentToolFailure = {
            contractVersion: CONTRACT_VERSION,
            correlationId: input.correlationId ?? `mcp-${randomUUID()}`,
            success: false,
            errorType: "LIMIT",
            errorMessage:
              "The service is at its concurrency limit. Retry the request later."
          };
          logger.log("warn", "MCP tool call reached the concurrency limit.", {
            event: "tool_limited",
            operation,
            correlationId: failure.correlationId,
            durationMs: Date.now() - started
          });
          return toolResult(failure);
        }
        const serviceError = error instanceof ServiceError ? error : undefined;
        if (serviceError) {
          const failure: AgentToolFailure = {
            contractVersion: CONTRACT_VERSION,
            correlationId: input.correlationId ?? `mcp-${randomUUID()}`,
            success: false,
            errorType: errorTypeForServiceError(serviceError.code),
            errorMessage: serviceError.safeMessage
          };
          logger.log("error", "MCP tool call failed.", {
            event: "tool_failed",
            operation,
            correlationId: failure.correlationId,
            durationMs: Date.now() - started,
            errorType: serviceError.code
          });
          return toolResult(failure);
        }
        logger.log("error", "MCP tool call failed.", {
          event: "tool_failed",
          operation,
          durationMs: Date.now() - started,
          errorType: "INTERNAL"
        });
        return {
          isError: true,
          content: [
            {
              type: "text",
              text: "The tool could not complete the request."
            }
          ]
        };
      }
    }
  );
}

function toolResult(result: AgentToolResponse) {
  const summary =
    "operation" in result
      ? `${result.operation} completed with status ${result.status}. Correlation ID: ${result.correlationId}.`
      : `${result.errorType}: ${result.errorMessage} Correlation ID: ${result.correlationId}.`;
  return {
    isError: !result.success,
    content: [{ type: "text" as const, text: summary }],
    structuredContent: result
  };
}
