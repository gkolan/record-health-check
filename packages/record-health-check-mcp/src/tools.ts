import { randomUUID } from "node:crypto";

import { McpServer } from "@modelcontextprotocol/server";

import {
  CONTRACT_VERSION,
  OPERATION_CHECK,
  OPERATION_CHECK_SET,
  toolInputSchema,
  toolOutputSchema,
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
    version: "0.1.0"
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
          ? "Use when the user asks for the actual result of one specifically named Record Health Check on one Salesforce record. Supply one record ID and the exact Check QualifiedApiName copied from Salesforce; never guess, translate a label, or retry namespace variants. Read success before status: FAIL is a completed business finding and SKIPPED is not PASS. Never treat UNABLE_TO_EVALUATE or ERROR as healthy. Use only the bounded reason and diagnosis fields returned by the tool."
          : "Use when the user asks for the overall health, readiness, completeness, or quality of one Salesforce record under one specifically named Record Health Check Set. Supply one record ID and the exact Check Set QualifiedApiName copied from Salesforce; never guess, translate a label, or retry namespace variants. Read success before status and report every count: FAIL is a completed business finding, SKIPPED is not PASS. Never treat UNABLE_TO_EVALUATE or ERROR as healthy. Use only the bounded diagnosis fields returned by the tool.",
      inputSchema: toolInputSchema,
      outputSchema: toolOutputSchema,
      annotations: {
        readOnlyHint: true,
        destructiveHint: false,
        idempotentHint: true,
        openWorldHint: true
      }
    },
    async (input) => {
      const started = Date.now();
      const effectiveInput = {
        ...input,
        correlationId: input.correlationId ?? `mcp-${randomUUID()}`
      };
      try {
        const result = await client.evaluate({ operation, ...effectiveInput });
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
            correlationId: effectiveInput.correlationId,
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
            correlationId: effectiveInput.correlationId,
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
  const summary = summarizeResult(result);
  return {
    isError: !result.success,
    content: [{ type: "text" as const, text: summary }],
    structuredContent: result
  };
}

function summarizeResult(result: AgentToolResponse): string {
  if (!result.success) {
    return `${result.errorType}: ${result.errorMessage} No health conclusion was reached. Correlation ID: ${result.correlationId}.`;
  }
  const details = [
    `${result.operation} completed with status ${result.status}.`
  ];
  if (result.operation === OPERATION_CHECK_SET) {
    details.push(
      `Counts: passed=${result.passed}, failed=${result.failed}, skipped=${result.skipped}, unable=${result.unable}, systemError=${result.systemError}.`
    );
  } else if (result.reasonCode) {
    details.push(`Reason code: ${result.reasonCode}.`);
  }
  if (result.diagnosticSummary) {
    details.push(`Diagnosis: ${result.diagnosticSummary}`);
  }
  if (result.recommendedAction) {
    details.push(`Recommended action: ${result.recommendedAction}`);
  }
  if (result.diagnosticId) {
    details.push(`Diagnostic ID: ${result.diagnosticId}.`);
  }
  details.push(`Correlation ID: ${result.correlationId}.`);
  return details.join(" ");
}
