#!/usr/bin/env node

import { parseArgs } from "node:util";
import { run } from "../lib/run.mjs";
import {
  gateEnvironment,
  gatesFor,
  selectGates
} from "../lib/release-gates.mjs";

const { values } = parseArgs({
  options: {
    ci: { type: "boolean", default: false },
    only: { type: "string" },
    list: { type: "boolean", default: false }
  }
});

const environment = values.ci ? "ci" : "local";
const allGates = gatesFor(environment);

if (values.list) {
  for (const gate of allGates) {
    console.log(gate);
  }
  process.exit(0);
}

let gates;
try {
  gates = values.only
    ? selectGates(allGates, values.only.split(","))
    : allGates;
} catch (error) {
  process.stderr.write(`${error.message}\n`);
  process.exit(1);
}

for (const gate of gates) {
  console.log(`\n=== ${environment} gates: ${gate} ===`);
  run("npm", ["run", gate], {
    env: gateEnvironment(environment)
  });
}

if (values.only) {
  console.log(
    `\n${gates.length} of ${allGates.length} ${environment} gates passed. ` +
      `This is a subset - run the full preflight before handing off.`
  );
} else {
  console.log(
    environment === "ci"
      ? `\nAll ${gates.length} source gates passed.`
      : "\nLocal release preflight passed. Package creation is ready when the release owner approves it."
  );
}
