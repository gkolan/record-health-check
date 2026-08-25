#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import Ajv2020 from "ajv/dist/2020.js";

const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../.."
);
const contractRoot = path.join(root, "contracts/agent-tool/1");
const readJson = (relativePath) =>
  JSON.parse(fs.readFileSync(path.join(contractRoot, relativePath), "utf8"));
const ajv = new Ajv2020({ allErrors: true, strict: true });
const requestSchema = readJson("request.schema.json");
const responseSchema = readJson("response.schema.json");
const validators = {
  request: ajv.compile(requestSchema),
  response: ajv.compile(responseSchema)
};
const failures = [];
const validExamples = readJson("examples/valid.json");

for (const example of validExamples) {
  const validate = validators[example.schema];
  if (!validate || !validate(example.value)) {
    failures.push(
      `Expected valid ${example.schema} example to pass: ${ajv.errorsText(validate?.errors)}`
    );
  }
}
for (const example of readJson("examples/invalid.json")) {
  const validate = validators[example.schema];
  if (!validate) {
    failures.push(`Unknown schema name: ${example.schema}`);
  } else if (validate(example.value)) {
    failures.push(`Expected invalid example to fail: ${example.reason}`);
  }
}

const diagnosisFields = [
  "diagnosticId",
  "diagnosticCategory",
  "diagnosticSummary",
  "recommendedAction"
];
const successResponseVariants = responseSchema.oneOf.filter(
  (variant) => variant.properties?.success?.const === true
);
const failureResponseVariants = responseSchema.oneOf.filter(
  (variant) => variant.properties?.success?.const === false
);
for (const field of diagnosisFields) {
  for (const variant of successResponseVariants) {
    if (!Object.hasOwn(variant.properties ?? {}, field)) {
      failures.push(
        `Successful response schema variant ${variant.properties?.operation?.const ?? "unknown"} is missing ${field}.`
      );
    }
    if ((variant.required ?? []).includes(field)) {
      failures.push(
        `Successful response schema variant ${variant.properties?.operation?.const ?? "unknown"} incorrectly requires ${field}.`
      );
    }
    if (
      !validExamples.some(
        (example) =>
          example.schema === "response" &&
          example.value.success === true &&
          example.value.operation === variant.properties?.operation?.const &&
          Object.hasOwn(example.value, field)
      )
    ) {
      failures.push(
        `Valid ${variant.properties?.operation?.const ?? "unknown"} response examples do not exercise ${field}.`
      );
    }
  }
  for (const variant of failureResponseVariants) {
    if (Object.hasOwn(variant.properties ?? {}, field)) {
      failures.push(
        `Adapter failure response schema incorrectly allows ${field}.`
      );
    }
  }
}

const apexResponseSource = fs.readFileSync(
  path.join(
    root,
    "packages/record-health-check/force-app/main/default/classes/RecordHealthCheckAgentRestResource.cls"
  ),
  "utf8"
);
const apexResponseBody = apexResponseSource.match(
  /global class AgentToolResponse\s*\{([\s\S]*?)\n\s{2}\}/
)?.[1];
if (!apexResponseBody) {
  failures.push("Apex REST AgentToolResponse class could not be inspected.");
} else {
  const apexFields = new Set(
    [...apexResponseBody.matchAll(/^\s*global\s+\w+\s+(\w+)\s*;/gm)].map(
      (match) => match[1]
    )
  );
  const schemaFields = new Set(
    responseSchema.oneOf.flatMap((variant) =>
      Object.keys(variant.properties ?? {})
    )
  );
  for (const field of apexFields) {
    if (!schemaFields.has(field)) {
      failures.push(
        `Apex REST response field ${field} is absent from the schema.`
      );
    }
  }
  for (const field of schemaFields) {
    if (!apexFields.has(field)) {
      failures.push(`Response schema field ${field} is absent from Apex REST.`);
    }
  }
}

const mcpContractSource = fs.readFileSync(
  path.join(root, "packages/record-health-check-mcp/src/contract.ts"),
  "utf8"
);
const mcpDiagnosisBody = mcpContractSource.match(
  /const diagnosisFields = \{([\s\S]*?)\n\};/
)?.[1];
if (!mcpDiagnosisBody) {
  failures.push("MCP response diagnosis fields could not be inspected.");
} else {
  const mcpDiagnosisConstraints = new Map(
    [
      ...mcpDiagnosisBody.matchAll(
        /^\s*(\w+):\s*z\.string\(\)\.min\((\d+)\)\.max\((\d+)\)\.optional\(\),?$/gm
      )
    ].map((match) => [
      match[1],
      { minLength: Number(match[2]), maxLength: Number(match[3]) }
    ])
  );
  for (const field of diagnosisFields) {
    const mcpConstraints = mcpDiagnosisConstraints.get(field);
    const schemaConstraints = responseSchema.$defs?.[field];
    if (!mcpConstraints) {
      failures.push(`MCP response validator is missing optional ${field}.`);
      continue;
    }
    if (
      schemaConstraints?.type !== "string" ||
      schemaConstraints.minLength !== mcpConstraints.minLength ||
      schemaConstraints.maxLength !== mcpConstraints.maxLength
    ) {
      failures.push(`MCP and JSON Schema constraints differ for ${field}.`);
    }
  }
}

if (failures.length > 0) {
  for (const failure of failures) console.error(failure);
  process.exit(1);
}
console.log("Agent tool contract schemas and examples are valid.");
