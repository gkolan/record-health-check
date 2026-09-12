import { z } from "zod";

export const CONTRACT_VERSION = "1.0" as const;
export const OPERATION_CHECK = "RUN_CHECK" as const;
export const OPERATION_CHECK_SET = "RUN_CHECK_SET" as const;

export const recordIdSchema = z
  .string()
  .regex(
    /^[a-zA-Z0-9]{15}(?:[a-zA-Z0-9]{3})?$/,
    "Expected a 15- or 18-character Salesforce ID"
  )
  .describe(
    "Exact 15- or 18-character ID of the one Salesforce record to evaluate."
  );

export const qualifiedApiNameSchema = z
  .string()
  .min(1)
  .max(255)
  .regex(
    /^[a-zA-Z][a-zA-Z0-9_]*(?:__[a-zA-Z][a-zA-Z0-9_]*)?$/,
    "Expected an exact Check or Check Set QualifiedApiName"
  )
  .describe(
    "Exact Check or Check Set QualifiedApiName copied from Salesforce; never infer a label or add, remove, or retry a namespace."
  );

export const correlationIdSchema = z
  .string()
  .min(1)
  .max(120)
  .regex(/^[a-zA-Z0-9._:-]+$/)
  .describe(
    "Optional disclosure-safe operational identifier; do not include record data, user text, tokens, or secrets."
  );

export const toolInputSchema = z
  .object({
    recordId: recordIdSchema,
    qualifiedApiName: qualifiedApiNameSchema,
    correlationId: correlationIdSchema.optional()
  })
  .strict();

export type ToolInput = z.infer<typeof toolInputSchema>;

const statusSchema = z
  .enum(["PASS", "FAIL", "SKIPPED", "UNABLE_TO_EVALUATE", "ERROR"])
  .describe(
    "Completed health status. FAIL is a business finding; SKIPPED is not a pass; UNABLE_TO_EVALUATE and ERROR never prove health."
  );
const responseBase = z.object({
  contractVersion: z.literal(CONTRACT_VERSION),
  correlationId: correlationIdSchema
});

const diagnosisFields = {
  diagnosticId: z
    .string()
    .min(1)
    .max(255)
    .optional()
    .describe("Disclosure-safe identifier for a completed diagnosis."),
  diagnosticCategory: z
    .string()
    .min(1)
    .max(80)
    .optional()
    .describe("Broad disclosure-safe category for a completed diagnosis."),
  diagnosticSummary: z
    .string()
    .min(1)
    .max(1000)
    .optional()
    .describe(
      "Bounded disclosure-safe explanation for a completed inconclusive or error result; it is not a raw administrator diagnostic."
    ),
  recommendedAction: z
    .string()
    .min(1)
    .max(1000)
    .optional()
    .describe(
      "Disclosure-safe first corrective step for the completed diagnosis."
    )
};

export const checkSuccessSchema = responseBase
  .extend({
    success: z
      .literal(true)
      .describe("True only when a completed health evaluation exists."),
    operation: z.literal(OPERATION_CHECK),
    status: statusSchema,
    reasonCode: z
      .string()
      .min(1)
      .max(80)
      .optional()
      .describe("Stable reason code for a completed single-Check result."),
    ...diagnosisFields
  })
  .strict();

export const checkSetSuccessSchema = responseBase
  .extend({
    success: z
      .literal(true)
      .describe("True only when a completed health evaluation exists."),
    operation: z.literal(OPERATION_CHECK_SET),
    status: statusSchema,
    passed: z
      .number()
      .int()
      .min(0)
      .max(25)
      .describe("Checks that completed with PASS."),
    failed: z
      .number()
      .int()
      .min(0)
      .max(25)
      .describe("Checks with a FAIL business finding."),
    skipped: z
      .number()
      .int()
      .min(0)
      .max(25)
      .describe("Skipped Checks; these are not passes."),
    unable: z
      .number()
      .int()
      .min(0)
      .max(25)
      .describe(
        "Checks that could not be evaluated; these do not prove health."
      ),
    systemError: z
      .number()
      .int()
      .min(0)
      .max(25)
      .describe("Checks with system errors; these do not prove health."),
    ...diagnosisFields
  })
  .strict()
  .superRefine((value, context) => {
    const total =
      value.passed +
      value.failed +
      value.skipped +
      value.unable +
      value.systemError;
    if (total > 25) {
      context.addIssue({
        code: "custom",
        message: `Count total ${total} exceeds the maximum Check Set size 25`,
        path: ["passed"]
      });
    }
    const expected = strongestStatus(value);
    if (value.status !== expected) {
      context.addIssue({
        code: "custom",
        message: `Status ${value.status} does not match count-derived status ${expected}`,
        path: ["status"]
      });
    }
  });

export const failureSchema = responseBase
  .extend({
    success: z.literal(false).describe("No health conclusion can be reported."),
    errorType: z.enum(["AUTHORIZATION", "VALIDATION", "LIMIT", "EXECUTION"]),
    errorMessage: z
      .string()
      .min(1)
      .max(1000)
      .describe("Safe adapter explanation when success is false.")
  })
  .strict();

export const agentToolResponseSchema = z.union([
  checkSuccessSchema,
  checkSetSuccessSchema,
  failureSchema
]);

// Discovery and runtime validation share the same strict response alternatives.
// JSON Schema expresses shape constraints; count arithmetic is additionally
// enforced by checkSetSuccessSchema at the service boundary.
export const toolOutputSchema = agentToolResponseSchema.describe(
  "Structured Record Health Check result. Read success before interpreting status or counts."
);

export type AgentToolResponse = z.infer<typeof agentToolResponseSchema>;
export type AgentToolFailure = z.infer<typeof failureSchema>;
export type Operation = typeof OPERATION_CHECK | typeof OPERATION_CHECK_SET;

function strongestStatus(value: {
  passed: number;
  failed: number;
  skipped: number;
  unable: number;
  systemError: number;
}): z.infer<typeof statusSchema> {
  if (value.systemError > 0) return "ERROR";
  if (value.unable > 0) return "UNABLE_TO_EVALUATE";
  if (value.failed > 0) return "FAIL";
  if (value.passed > 0) return "PASS";
  return "SKIPPED";
}
