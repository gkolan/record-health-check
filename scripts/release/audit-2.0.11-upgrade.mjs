#!/usr/bin/env node

import fs from "node:fs";
import { parseArgs } from "node:util";
import {
  incompatibleHiddenManualCheckSets,
  upgradeCompatibilityQuery
} from "../lib/upgrade-2.0.11-compatibility.mjs";
import { runJson } from "../lib/run.mjs";

const { values } = parseArgs({
  options: {
    "target-org": { type: "string" },
    namespace: { type: "string", default: "rhc" },
    "expect-count": { type: "string" },
    output: { type: "string" }
  }
});

if (!values["target-org"]) {
  console.error(
    "Pass --target-org with the org alias to audit before upgrading."
  );
  process.exit(1);
}

const namespace = values.namespace === "none" ? "" : values.namespace;
const response = runJson(
  "sf",
  [
    "data",
    "query",
    "--target-org",
    values["target-org"],
    "--query",
    upgradeCompatibilityQuery(namespace)
  ],
  { env: { ...process.env, SF_DISABLE_LOG_FILE: "true" } }
);
const findings = incompatibleHiddenManualCheckSets(
  response.result?.records ?? [],
  namespace
);
const report = {
  schemaVersion: 1,
  release: "2.0.11",
  targetOrg: values["target-org"],
  namespace: namespace || null,
  findingCount: findings.length,
  findings,
  remedies: [
    "Set Card Heading Display to SHOW so the manual Run action remains reachable.",
    "Or set Card Run Mode to RUN_ON_LOAD so the card does not depend on a manual action."
  ]
};

if (values.output) {
  fs.writeFileSync(values.output, `${JSON.stringify(report, null, 2)}\n`);
}
console.log(JSON.stringify(report, null, 2));

const expected = values["expect-count"];
if (expected !== undefined) {
  const expectedCount = Number(expected);
  if (!Number.isInteger(expectedCount) || expectedCount < 0) {
    console.error("--expect-count must be a non-negative integer.");
    process.exit(1);
  }
  if (findings.length !== expectedCount) {
    console.error(
      `Expected ${expectedCount} finding(s), but found ${findings.length}.`
    );
    process.exit(1);
  }
} else if (findings.length > 0) {
  console.error(
    "Resolve every hidden manual-run Check Set before upgrading to 2.0.11."
  );
  process.exit(2);
}
