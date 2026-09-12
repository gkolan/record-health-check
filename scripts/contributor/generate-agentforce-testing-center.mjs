import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

import {
  AGENTFORCE_TEST_RUNNER,
  validateLegacyAgentTestSpec
} from "../lib/agentforce-testing-center.mjs";

const SYNTHETIC_PRIMARY = "001000000000001AAA";
const SYNTHETIC_SECONDARY = "001000000000002AAA";
const SOURCE = resolve(
  "packages/record-health-check/integration-tests/agentforce/Record_Health_Assistant-testing-center.yaml.template"
);

function argument(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : undefined;
}

function requireRealAccountId(value, option) {
  if (!/^001(?:[A-Za-z0-9]{12}|[A-Za-z0-9]{15})$/.test(value ?? "")) {
    throw new Error(`${option} must be a real 15- or 18-character Account ID.`);
  }
  if (value === SYNTHETIC_PRIMARY || value === SYNTHETIC_SECONDARY) {
    throw new Error(
      `${option} cannot use the repository's synthetic placeholder ID.`
    );
  }
}

const recordId = argument("--record-id");
const secondRecordId = argument("--second-record-id");
const output = argument("--output");

requireRealAccountId(recordId, "--record-id");
requireRealAccountId(secondRecordId, "--second-record-id");
if (!output) {
  throw new Error(
    "--output is required; write the generated suite outside the tracked template."
  );
}

const source = await readFile(SOURCE, "utf8");
validateLegacyAgentTestSpec(source);
if (
  !source.includes(SYNTHETIC_PRIMARY) ||
  !source.includes(SYNTHETIC_SECONDARY)
) {
  throw new Error(
    "Testing Center template placeholders changed; update this generator deliberately."
  );
}

const generated = source
  .replaceAll(SYNTHETIC_PRIMARY, recordId)
  .replaceAll(SYNTHETIC_SECONDARY, secondRecordId);
if (/00100000000000[12]AAA/.test(generated)) {
  throw new Error("Generated suite still contains synthetic record IDs.");
}

await writeFile(resolve(output), generated, { flag: "wx" });
console.log(
  `Generated validated ${AGENTFORCE_TEST_RUNNER} suite at ${resolve(output)}\n` +
    `Preview it against an authorized existing org with: sf agent test create --json --test-runner ${AGENTFORCE_TEST_RUNNER} --spec ${resolve(output)} --api-name <UNIQUE_API_NAME> --preview --target-org <ALIAS>`
);
