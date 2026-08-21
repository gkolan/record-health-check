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
const validators = {
  request: ajv.compile(readJson("request.schema.json")),
  response: ajv.compile(readJson("response.schema.json"))
};
const failures = [];

for (const example of readJson("examples/valid.json")) {
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
if (failures.length > 0) {
  for (const failure of failures) console.error(failure);
  process.exit(1);
}
console.log("Agent tool contract schemas and examples are valid.");
