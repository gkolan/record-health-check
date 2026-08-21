import { describe, expect, it } from "vitest";

import { agentToolResponseSchema, toolInputSchema } from "../src/contract.js";
import { errorTypeForServiceError } from "../src/tools.js";

describe("public contract", () => {
  it("distinguishes destination policy from Salesforce authorization", () => {
    expect(errorTypeForServiceError("DESTINATION_REJECTED")).toBe("VALIDATION");
    expect(errorTypeForServiceError("SALESFORCE_AUTH")).toBe("AUTHORIZATION");
    expect(errorTypeForServiceError("UPSTREAM_LIMIT")).toBe("LIMIT");
    expect(errorTypeForServiceError("UPSTREAM_UNAVAILABLE")).toBe("EXECUTION");
  });
  it("rejects unknown input fields and invalid identifiers", () => {
    expect(
      toolInputSchema.safeParse({
        recordId: "001000000000001AAA",
        qualifiedApiName: "Check_One",
        extra: true
      }).success
    ).toBe(false);
    expect(
      toolInputSchema.safeParse({
        recordId: "bad",
        qualifiedApiName: "Check One"
      }).success
    ).toBe(false);
  });

  it("accepts all five single-check statuses with required diagnostics", () => {
    for (const status of [
      "PASS",
      "FAIL",
      "SKIPPED",
      "UNABLE_TO_EVALUATE",
      "ERROR"
    ]) {
      expect(
        agentToolResponseSchema.safeParse({
          contractVersion: "1.0",
          correlationId: "corr-1",
          success: true,
          operation: "RUN_CHECK",
          status,
          ...(["UNABLE_TO_EVALUATE", "ERROR"].includes(status)
            ? {
                diagnosticId: `diag-${status}`,
                diagnosticCategory: "CONFIG",
                diagnosticSummary:
                  "The configured evaluation could not finish.",
                recommendedAction: "Correct the configured field and rerun."
              }
            : {})
        }).success
      ).toBe(true);
    }
  });

  it("accepts completed inconclusive results without an optional diagnosis", () => {
    expect(
      agentToolResponseSchema.safeParse({
        contractVersion: "1.0",
        correlationId: "corr-check",
        success: true,
        operation: "RUN_CHECK",
        status: "ERROR",
        reasonCode: "PLUGIN_THREW"
      }).success
    ).toBe(true);
    expect(
      agentToolResponseSchema.safeParse({
        contractVersion: "1.0",
        correlationId: "corr-set",
        success: true,
        operation: "RUN_CHECK_SET",
        status: "UNABLE_TO_EVALUATE",
        passed: 0,
        failed: 0,
        skipped: 0,
        unable: 3,
        systemError: 0
      }).success
    ).toBe(true);
  });

  it("rejects a set status inconsistent with its counts", () => {
    expect(
      agentToolResponseSchema.safeParse({
        contractVersion: "1.0",
        correlationId: "corr-1",
        success: true,
        operation: "RUN_CHECK_SET",
        status: "PASS",
        passed: 1,
        failed: 1,
        skipped: 0,
        unable: 0,
        systemError: 0
      }).success
    ).toBe(false);
  });
});
