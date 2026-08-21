#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { paths } from "../lib/paths.mjs";
import { run } from "../lib/run.mjs";
import { assertScratchCapacity } from "../lib/salesforce-limits.mjs";

function parseArgs(argv) {
  const options = {
    alias: process.env.RHC_PORTABLE_ALIAS ?? "rhc-portable",
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
      `An org already uses alias '${alias}'. Choose a new alias for the portable workflow.`
    );
    process.exit(1);
  }
}

function main() {
  const options = parseArgs(process.argv.slice(2));
  if (!options.devHub) {
    console.error(
      "Pass --dev-hub (or set DEV_HUB_ALIAS). Example: npm run dev:test-no-namespace -- --dev-hub my-dev-hub"
    );
    process.exit(1);
  }

  ensureAliasAvailable(options.alias);
  assertScratchCapacity(options.devHub);

  console.log(
    "Portable contributor check: deploy unpackaged force-app into a no-namespace scratch org."
  );
  console.log(
    "This is not a subscriber installation workflow. Use npm run setup to install the promoted package."
  );

  run("sf", [
    "org",
    "create",
    "scratch",
    "--definition-file",
    paths.subscriberScratchDef,
    "--alias",
    options.alias,
    "--target-dev-hub",
    options.devHub,
    "--duration-days",
    options.durationDays,
    "--no-namespace",
    "--wait",
    "30"
  ]);

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
      "--wait",
      "30"
    ],
    { cwd: paths.packageRoot }
  );

  run("sf", [
    "org",
    "assign",
    "permset",
    "--name",
    "Record_Health_Check_Admin",
    "--target-org",
    options.alias
  ]);

  run(
    "sf",
    [
      "apex",
      "run",
      "test",
      "--target-org",
      options.alias,
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

  console.log("");
  console.log(
    `Portable no-namespace source deploy and RunLocalTests completed in '${options.alias}'.`
  );
}

main();
