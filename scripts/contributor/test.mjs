#!/usr/bin/env node

import { parseArgs } from "node:util";
import { paths } from "../lib/paths.mjs";
import { run } from "../lib/run.mjs";

const { values } = parseArgs({
  options: {
    alias: { type: "string", default: process.env.RHC_DEV_ALIAS ?? "rhc-dev" }
  }
});

run(
  "sf",
  [
    "apex",
    "run",
    "test",
    "--target-org",
    values.alias,
    "--test-level",
    "RunLocalTests",
    "--code-coverage",
    "--result-format",
    "human",
    "--wait",
    "30"
  ],
  { cwd: paths.packageRoot }
);

console.log(`Package RunLocalTests completed in ${values.alias}.`);
