#!/usr/bin/env node

import { paths } from "../lib/paths.mjs";
import {
  namespacedPermissionSet,
  readPackageReleases,
  stablePackageVersionId
} from "../lib/package-releases.mjs";
import {
  hasInstalledPackageVersion,
  installedPackageRecords
} from "../lib/installed-packages.mjs";
import { run, runJson, tryRun } from "../lib/run.mjs";
import { assertScratchCapacity } from "../lib/salesforce-limits.mjs";

function parseArgs(argv) {
  const options = {
    alias: process.env.RHC_ORG_ALIAS ?? "rhc-demo",
    devHub: process.env.DEV_HUB_ALIAS ?? "",
    durationDays: process.env.RHC_SCRATCH_DAYS ?? "30"
  };

  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (token === "--alias") {
      options.alias = argv[index + 1];
      index += 1;
    } else if (token === "--dev-hub") {
      options.devHub = argv[index + 1];
      index += 1;
    } else if (token === "--duration-days") {
      options.durationDays = argv[index + 1];
      index += 1;
    }
  }

  return options;
}

function ensureSfInstalled() {
  run("sf", ["--version"]);
}

function ensureAliasAvailable(alias) {
  const result = tryRun("sf", [
    "org",
    "display",
    "--target-org",
    alias,
    "--json"
  ]);
  if (result.status === 0) {
    console.error(
      `An org already uses alias '${alias}'. Choose a new alias; subscriber setup never overwrites an existing org.`
    );
    process.exit(1);
  }
}

function main() {
  const options = parseArgs(process.argv.slice(2));
  if (!options.devHub) {
    console.error(
      "Pass --dev-hub (or set DEV_HUB_ALIAS). Example: npm run setup -- --dev-hub my-dev-hub"
    );
    process.exit(1);
  }

  const releases = readPackageReleases();
  const packageVersionId = stablePackageVersionId(releases);
  const adminPermset = namespacedPermissionSet(
    releases.permissionSets.admin,
    releases
  );

  ensureSfInstalled();
  ensureAliasAvailable(options.alias);
  const durationDays = Number.parseInt(options.durationDays, 10);
  if (
    !Number.isInteger(durationDays) ||
    durationDays < 1 ||
    durationDays > 30
  ) {
    console.error("Scratch-org duration must be between 1 and 30 days.");
    process.exit(1);
  }
  assertScratchCapacity(options.devHub);

  console.log(
    `Creating no-namespace subscriber scratch org '${options.alias}'...`
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

  console.log(`Installing stable package ${packageVersionId}...`);
  run("sf", [
    "package",
    "install",
    "--package",
    packageVersionId,
    "--target-org",
    options.alias,
    "--security-type",
    "AdminsOnly",
    "--upgrade-type",
    "DeprecateOnly",
    "--publish-wait",
    "10",
    "--wait",
    "30",
    "--no-prompt"
  ]);

  const installed = installedPackageRecords(
    runJson("sf", [
      "package",
      "installed",
      "list",
      "--target-org",
      options.alias
    ])
  );
  if (!hasInstalledPackageVersion(installed, packageVersionId)) {
    console.error(
      `Package install verification failed: ${packageVersionId} is not installed.`
    );
    process.exit(1);
  }

  console.log(`Assigning ${adminPermset}...`);
  run("sf", [
    "org",
    "assign",
    "permset",
    "--name",
    adminPermset,
    "--target-org",
    options.alias
  ]);

  console.log("Deploying subscriber-owned metadata...");
  run("sf", [
    "project",
    "deploy",
    "start",
    "--source-dir",
    paths.subscriberApp,
    "--target-org",
    options.alias,
    "--wait",
    "30"
  ]);

  if (process.env.RHC_SKIP_DEMO_DATA !== "1") {
    const demoDataScript = `${paths.subscriberData}/setupDemoData.apex`;
    console.log("Creating demo Account data...");
    run("sf", [
      "apex",
      "run",
      "--target-org",
      options.alias,
      "--file",
      demoDataScript
    ]);
  }

  console.log("Running subscriber smoke tests...");
  run("sf", [
    "apex",
    "run",
    "test",
    "--class-names",
    "RHCSubscriberSmokeTest",
    "--target-org",
    options.alias,
    "--result-format",
    "human",
    "--wait",
    "30"
  ]);

  console.log("");
  console.log("Subscriber demo org is ready.");
  console.log(`Alias: ${options.alias}`);
  console.log(
    `Open: sf org open --target-org ${options.alias} --path 'lightning/o/Account/list?filterName=RHC_Demo_Accounts'`
  );
  console.log("");
  console.log(
    "This org installed the promoted package. It did not deploy unpackaged Framework source."
  );
}

main();
