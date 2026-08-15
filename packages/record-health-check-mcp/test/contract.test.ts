import { describe, expect, it } from "vitest";

import { agentToolResponseSchema, toolInputSchema } from "../src/contract.js";

describe("public contract", () => {
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

  it("accepts all five single-check statuses", () => {
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
          status
        }).success
      ).toBe(true);
    }
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
