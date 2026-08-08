#!/usr/bin/env node

import { run } from "../lib/run.mjs";

const gates = [
  "check:toolchain-latest",
  "prettier:verify",
  "lint",
  "lint:slds",
  "check:namespaced-tokens",
  "check:configuration-identity",
  "check:test-data-factory",
  "check:apex-architecture",
  "check:apex-surface",
  "check:plugin-sharing",
  "check:product-version-language",
  "check:docs",
  "check:field-limits",
  "check:manifest",
  "check:package-boundary",
  "check:query-shapes",
  "check:distribution-boundary",
  "check:permission-sets",
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
