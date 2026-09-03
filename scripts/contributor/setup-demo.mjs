#!/usr/bin/env node

import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { parseArgs } from "node:util";
import { paths } from "../lib/paths.mjs";
import { run, runJson } from "../lib/run.mjs";
import { seedDemoData } from "../lib/demo-data.mjs";
import { verifyReadinessData } from "../lib/demo-verification.mjs";

const { values } = parseArgs({
  options: {
    alias: { type: "string", default: process.env.RHC_DEV_ALIAS ?? "rhc-dev" },
    "verify-only": { type: "boolean", default: false }
  }
});

const alias = values.alias?.trim();
if (!alias) {
  console.error("Pass a non-blank scratch-org alias with --alias.");
  process.exit(1);
}

const apexClasses = runJson("sf", [
  "data",
  "query",
  "--use-tooling-api",
  "--target-org",
  alias,
  "--query",
  "SELECT NamespacePrefix FROM ApexClass WHERE Name = 'RecordHealthCheck' LIMIT 1"
]);
const records = apexClasses.result?.records ?? [];
if (records.length !== 1) {
  console.error(
    `RecordHealthCheck source is not deployed in scratch org '${alias}'.`
  );
  process.exit(1);
}

const namespace = records[0].NamespacePrefix ?? "";
const apexPrefix = namespace ? `${namespace}.` : "";
const metadataPrefix = namespace ? `${namespace}__` : "";
const verifierTemplate = fs.readFileSync(
  path.join(paths.repoRoot, "scripts/contributor/verifyDemoSource.apex"),
  "utf8"
);
const verifier = verifierTemplate
  .replaceAll(
    "Record_Health_Check_Set__mdt",
    `${metadataPrefix}Record_Health_Check_Set__mdt`
  )
  .replaceAll(
    "Record_Health_Check__mdt",
    `${metadataPrefix}Record_Health_Check__mdt`
  )
  .replaceAll(
    "RecordHealthCheckResponse",
    `${apexPrefix}RecordHealthCheckResponse`
  )
  .replaceAll(
    "RecordHealthCheckRequest",
    `${apexPrefix}RecordHealthCheckRequest`
  )
  .replaceAll(
    "RecordHealthCheckResultItem",
    `${apexPrefix}RecordHealthCheckResultItem`
  )
  .replaceAll(
    "RecordHealthCheckResultMode",
    `${apexPrefix}RecordHealthCheckResultMode`
  )
  .replaceAll(
    "RecordHealthCheck.evaluate",
    `${apexPrefix}RecordHealthCheck.evaluate`
  );

const temporaryDirectory = fs.mkdtempSync(
  path.join(os.tmpdir(), "rhc-source-demo-")
);
const verifierPath = path.join(temporaryDirectory, "verifyDemoSource.apex");

try {
  if (!values["verify-only"]) {
    console.log(`Seeding deterministic demo data in '${alias}'...`);
    seedDemoData(alias);
  }

  fs.writeFileSync(verifierPath, verifier);
  console.log(
    `Verifying current source outcomes${namespace ? ` in namespace '${namespace}'` : " without a namespace"}...`
  );
  run("sf", ["apex", "run", "--target-org", alias, "--file", verifierPath]);
  verifyReadinessData(alias, namespace);
} finally {
  fs.rmSync(temporaryDirectory, { recursive: true, force: true });
}

console.log(
  `All four current-source demo Check Sets are verified; Acme Builder Guide in '${alias}': 7 passed, 17 failed, 0 skipped, 1 unable.`
);
