#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { parseArgs } from "node:util";
import {
  discoverApexTestClasses,
  verifyApexTestResult
} from "../lib/apex-test-inventory.mjs";

const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../.."
);
const { values } = parseArgs({
  options: {
    "target-org": { type: "string" },
    topology: { type: "string" },
    scope: { type: "string", default: "full" },
    wait: { type: "string", default: "60" }
  }
});

if (!values["target-org"] || !values.topology) {
  console.error("Pass --target-org and --topology.");
  process.exit(1);
}
if (!["package", "full"].includes(values.scope)) {
  console.error("--scope must be package or full.");
  process.exit(1);
}
if (!/^[a-z0-9-]+$/i.test(values.topology)) {
  console.error("--topology must contain only letters, numbers, and hyphens.");
  process.exit(1);
}
if (!/^\d+$/.test(values.wait) || Number(values.wait) < 1) {
  console.error("--wait must be a positive number of minutes.");
  process.exit(1);
}

const sourceDirectories = [
  "packages/record-health-check/force-app/main/default/classes"
];
if (values.scope === "full") {
  sourceDirectories.push(
    "packages/record-health-check/integration-tests/main/default/classes"
  );
}
const overlayPolicy = JSON.parse(
  fs.readFileSync(path.join(root, "config/apex-test-overlays.json"), "utf8")
);
const inventory = discoverApexTestClasses(root, sourceDirectories, {
  overlayClassNames: values.scope === "full" ? overlayPolicy.classes : []
});
if (inventory.length === 0) {
  console.error("No Apex test classes were discovered; refusing to pass.");
  process.exit(1);
}

const temporaryOutput = fs.mkdtempSync(
  path.join(os.tmpdir(), `rhc-apex-${values.topology}-`)
);
const evidenceDirectory = path.join(
  root,
  "test-results",
  "apex",
  values.topology
);
fs.mkdirSync(evidenceDirectory, { recursive: true });

const args = [
  "apex",
  "run",
  "test",
  "--target-org",
  values["target-org"],
  "--code-coverage",
  "--wait",
  values.wait,
  "--result-format",
  "json",
  "--output-dir",
  temporaryOutput
];
for (const entry of inventory) {
  args.push("--class-names", entry.className);
}

console.log(
  `Running exact Apex inventory: ${inventory.length} classes in ${values.topology}.`
);
const execution = spawnSync("sf", args, {
  cwd: root,
  encoding: "utf8",
  env: { ...process.env, SF_DISABLE_LOG_FILE: "true" },
  maxBuffer: 64 * 1024 * 1024
});
if (execution.stdout) {
  process.stdout.write(execution.stdout);
}
if (execution.stderr) {
  process.stderr.write(execution.stderr);
}

const resultFiles = fs
  .readdirSync(temporaryOutput)
  .filter(
    (file) =>
      /^test-result-[A-Za-z0-9]+\.json$/.test(file) &&
      !file.endsWith("-codecoverage.json")
  );
if (resultFiles.length !== 1) {
  console.error(
    `Expected one Apex result JSON file, found ${resultFiles.length}: ${resultFiles.join(", ")}`
  );
  process.exit(1);
}

const resultPath = path.join(temporaryOutput, resultFiles[0]);
const result = JSON.parse(fs.readFileSync(resultPath, "utf8"));
fs.copyFileSync(
  resultPath,
  path.join(evidenceDirectory, "salesforce-result.json")
);

if (execution.error || execution.status !== 0) {
  console.error(
    `Salesforce Apex test command failed with status ${execution.status ?? "unknown"}.`
  );
  process.exit(execution.status ?? 1);
}

try {
  const verdict = verifyApexTestResult(inventory, result);
  const evidence = {
    topology: values.topology,
    scope: values.scope,
    targetOrg: values["target-org"],
    inventory,
    verdict
  };
  fs.writeFileSync(
    path.join(evidenceDirectory, "inventory-verdict.json"),
    `${JSON.stringify(evidence, null, 2)}\n`
  );
  console.log(
    `Exact Apex inventory passed: ${verdict.executedClassCount}/${verdict.requestedClassCount} classes, ${verdict.executedMethodCount} methods.`
  );
} catch (error) {
  console.error(error.message);
  process.exit(1);
}
