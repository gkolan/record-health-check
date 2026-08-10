#!/usr/bin/env node

import { paths } from "./lib/paths.mjs";
import { tryRun } from "./lib/run.mjs";

const args = process.argv.slice(2);
const result = tryRun("npx", ["sfdx-lwc-jest", ...args], {
  cwd: paths.packageRoot,
  stdio: "inherit"
});

process.exit(result.status ?? 1);
