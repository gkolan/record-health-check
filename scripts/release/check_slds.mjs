#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { resolve } from "node:path";

const result = spawnSync(
  resolve("node_modules/.bin/slds-linter"),
  [
    "lint",
    "packages/record-health-check/force-app/main/default/lwc",
    "--config-eslint",
    "slds-eslint.config.mjs"
  ],
  {
    encoding: "utf8"
  }
);

process.stdout.write(result.stdout ?? "");
process.stderr.write(result.stderr ?? "");

const output = `${result.stdout ?? ""}\n${result.stderr ?? ""}`.replace(
  // eslint-disable-next-line no-control-regex
  /\u001b\[[0-9;]*m/g,
  ""
);
if (result.status !== 0 || /\d+ SLDS Violations?/.test(output)) {
  process.exitCode = 1;
}
