import { z } from "zod";

export const CONTRACT_VERSION = "1.0" as const;
export const OPERATION_CHECK = "RUN_CHECK" as const;
export const OPERATION_CHECK_SET = "RUN_CHECK_SET" as const;

export const recordIdSchema = z
  .string()
  .regex(
    /^[a-zA-Z0-9]{15}(?:[a-zA-Z0-9]{3})?$/,
    "Expected a 15- or 18-character Salesforce ID"
  );

export const qualifiedApiNameSchema = z
  .string()
  .min(1)
  .max(255)
  .regex(
    /^[a-zA-Z][a-zA-Z0-9_]*(?:__[a-zA-Z][a-zA-Z0-9_]*)?$/,
    "Expected an exact Check or Check Set QualifiedApiName"
  );

export const correlationIdSchema = z
  .string()
  .min(1)
  .max(120)
  .regex(/^[a-zA-Z0-9._:-]+$/);

export const toolInputSchema = z
  .object({
    recordId: recordIdSchema,
    qualifiedApiName: qualifiedApiNameSchema,
    correlationId: correlationIdSchema.optional()
  })
  .strict();

export type ToolInput = z.infer<typeof toolInputSchema>;

const statusSchema = z.enum([
  "PASS",
  "FAIL",
  "SKIPPED",
  "UNABLE_TO_EVALUATE",
  "ERROR"
]);
const responseBase = z.object({
  contractVersion: z.literal(CONTRACT_VERSION),
  correlationId: correlationIdSchema
});

const diagnosisFields = {
  diagnosticId: z.string().min(1).max(255).optional(),
  diagnosticCategory: z.string().min(1).max(80).optional(),
  diagnosticSummary: z.string().min(1).max(1000).optional(),
  recommendedAction: z.string().min(1).max(1000).optional()
};

export const checkSuccessSchema = responseBase
  .extend({
    success: z.boolean(),
    operation: z.literal(OPERATION_CHECK),
    status: statusSchema,
    reasonCode: z.string().min(1).max(80).optional(),
    ...diagnosisFields
  })
  .strict()
  .superRefine((value, context) => {
    const shouldSucceed = !["UNABLE_TO_EVALUATE", "ERROR"].includes(
      value.status
    );
    if (value.success !== shouldSucceed) {
      context.addIssue({
        code: "custom",
        message: `Success ${value.success} does not match status ${value.status}`,
        path: ["success"]
      });
    }
    if (!shouldSucceed) requireDiagnosis(value, context);
  });

export const checkSetSuccessSchema = responseBase
  .extend({
    success: z.boolean(),
    operation: z.literal(OPERATION_CHECK_SET),
    status: statusSchema,
    passed: z.number().int().min(0).max(25),
    failed: z.number().int().min(0).max(25),
    skipped: z.number().int().min(0).max(25),
    unable: z.number().int().min(0).max(25),
    systemError: z.number().int().min(0).max(25),
    ...diagnosisFields
  })
  .strict()
  .superRefine((value, context) => {
    const expected = strongestStatus(value);
    if (value.status !== expected) {
      context.addIssue({
        code: "custom",
        message: `Status ${value.status} does not match count-derived status ${expected}`,
        path: ["status"]
      });
    }
    const shouldSucceed = value.systemError === 0 && value.unable === 0;
    if (value.success !== shouldSucceed) {
      context.addIssue({
        code: "custom",
        message: `Success ${value.success} does not match diagnostic counts`,
        path: ["success"]
      });
    }
    if (!shouldSucceed) requireDiagnosis(value, context);
  });

export const failureSchema = responseBase
  .extend({
    success: z.literal(false),
    errorType: z.enum(["AUTHORIZATION", "VALIDATION", "LIMIT", "EXECUTION"]),
    errorMessage: z.string().min(1).max(1000)
  })
  .strict();

export const agentToolResponseSchema = z.union([
  checkSuccessSchema,
  checkSetSuccessSchema,
  failureSchema
]);

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

function requireDiagnosis(
  value: Record<string, unknown>,
  context: z.RefinementCtx
): void {
  for (const field of [
    "diagnosticId",
    "diagnosticCategory",
    "diagnosticSummary",
    "recommendedAction"
  ]) {
    if (!value[field]) {
      context.addIssue({
        code: "custom",
        message: `${field} is required for an inconclusive result`,
        path: [field]
      });
    }
  }
}
