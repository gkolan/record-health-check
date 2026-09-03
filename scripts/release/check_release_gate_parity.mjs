#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const preflightFile = "scripts/release/run_release_preflight.mjs";
const ciFile = ".github/workflows/ci.yml";
const preflightSource = fs.readFileSync(path.join(root, preflightFile), "utf8");
const ciSource = fs.readFileSync(path.join(root, ciFile), "utf8");
const gateArray = preflightSource.match(/const gates = \[([\s\S]*?)\n\];/);

if (!gateArray) {
  throw new Error(`${preflightFile} must declare the release gates array.`);
}

const preflightGates = new Set(
  [...gateArray[1].matchAll(/"([a-z0-9:-]+)"/g)].map((match) => match[1])
);
const ciGates = new Set(
  [...ciSource.matchAll(/npm run ([a-z0-9:-]+)/g)].map((match) => match[1])
);

// Local release preflight verifies that the pinned Salesforce CLI is still
// the official latest release. Hosted CI verifies the pinned policy without a
// mutable registry lookup; all other named source gates must be identical.
preflightGates.delete("check:toolchain-latest");
ciGates.delete("check:toolchain-policy");

const missingFromCi = [...preflightGates].filter((gate) => !ciGates.has(gate));
const missingFromPreflight = [...ciGates].filter(
  (gate) => !preflightGates.has(gate)
);

if (missingFromCi.length || missingFromPreflight.length) {
  const details = [];
  if (missingFromCi.length) {
    details.push(`missing from CI: ${missingFromCi.sort().join(", ")}`);
  }
  if (missingFromPreflight.length) {
    details.push(
      `missing from release preflight: ${missingFromPreflight.sort().join(", ")}`
    );
  }
  throw new Error(`Release gate parity failed: ${details.join("; ")}.`);
}

process.stdout.write(
  `Release preflight and CI contain the same ${preflightGates.size} named source gates.\n`
);
