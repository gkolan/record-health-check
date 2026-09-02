#!/usr/bin/env node

import { run } from "../lib/run.mjs";

const gates = [
  "check:toolchain-latest",
  "prettier:verify",
  "lint",
  "lint:slds",
  "check:namespaced-tokens",
  "check:configuration-identity",
  "check:lightning-runtime-compatibility",
  "check:hosted-validation:self-test",
  "check:release-gate-parity",
  "check:release-runtime-matrix",
  "check:dependency-security",
  "check:agent-tool-contract",
  "check:mcp",
  "check:test-data-factory",
  "check:test-data-factory-inventory",
  "check:apex-architecture",
  "check:apex-surface",
  "check:code-analyzer-output-paths",
  "check:code-analyzer-suppressions",
  "check:code-analyzer-inline-suppressions",
  "check:plugin-sharing",
  "check:version-sync",
  "check:product-version-language",
  "check:docs",
  "check:field-limits",
  "check:manifest",
  "check:package-artifact",
  "check:package-boundary",
  "check:query-shapes",
  "check:distribution-boundary",
  "check:permission-sets",
  "check:xml",
  "test:scripts",
  "test:unit:coverage",
  "check:quality-metrics"
];

for (const gate of gates) {
  console.log(`\n=== Release preflight: ${gate} ===`);
  run("npm", ["run", gate]);
}

console.log(
  "\nRelease preflight passed. Package candidate creation is unlocked."
);
