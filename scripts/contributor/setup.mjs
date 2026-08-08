#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import path from "node:path";
import { paths } from "../lib/paths.mjs";
import { run } from "../lib/run.mjs";
import { assertScratchCapacity } from "../lib/salesforce-limits.mjs";

function parseArgs(argv) {
  const options = {
    alias: process.env.RHC_DEV_ALIAS ?? "rhc-dev",
    devHub: process.env.DEV_HUB_ALIAS ?? "",
    durationDays: "30"
  };

  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (token === "--alias") {
      options.alias = argv[index + 1];
      index += 1;
    } else if (token === "--dev-hub") {
      options.devHub = argv[index + 1];
      index += 1;
    }
  }

  return options;
}

function ensureAliasAvailable(alias) {
  const result = spawnSync(
    "sf",
    ["org", "display", "--target-org", alias, "--json"],
    { encoding: "utf8", shell: process.platform === "win32" }
  );
  if (result.status === 0) {
    console.error(
      `An org already uses alias '${alias}'. Choose a new alias for contributor setup.`
    );
    process.exit(1);
  }
}

function main() {
  const options = parseArgs(process.argv.slice(2));
  if (!options.devHub) {
    console.error(
      "Pass --dev-hub (or set DEV_HUB_ALIAS). Example: npm run dev:setup -- --dev-hub my-dev-hub"
    );
    process.exit(1);
  }

  ensureAliasAvailable(options.alias);
  assertScratchCapacity(options.devHub);

  console.log(
    "Contributor mode: deploying unpackaged package source for development."
  );
  console.log(
    "Do not use this workflow to install or upgrade Record Health Check in a subscriber org."
  );

  run(
    "sf",
    [
      "org",
      "create",
      "scratch",
      "--definition-file",
      paths.packageScratchDef,
      "--alias",
      options.alias,
      "--target-dev-hub",
      options.devHub,
      "--duration-days",
      options.durationDays,
      "--wait",
      "30"
    ],
    { cwd: paths.packageRoot }
  );

  run(
    "sf",
    [
      "project",
      "deploy",
      "start",
      "--source-dir",
      "force-app",
      "--target-org",
      options.alias,
      "--test-level",
      "RunLocalTests",
      "--wait",
      "30"
    ],
    { cwd: paths.packageRoot }
  );

  run(
    "sf",
    [
      "project",
      "deploy",
      "start",
      "--source-dir",
      "integration-tests",
      "--target-org",
      options.alias,
      "--wait",
      "30"
    ],
    { cwd: paths.packageRoot }
  );

  console.log("");
  console.log(`Contributor development org '${options.alias}' is ready.`);
  console.log(`Package project: ${paths.packageRoot}`);
}

main();
