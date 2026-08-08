#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { parseArgs } from "node:util";
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
import { run, runJson } from "../lib/run.mjs";

const { values } = parseArgs({
  options: {
    alias: { type: "string", default: "rhc-verify" },
    "dev-hub": { type: "string", default: process.env.DEV_HUB_ALIAS ?? "" },
    package: { type: "string" },
    "skip-upgrade": { type: "boolean", default: false },
    "upgrade-only": { type: "boolean", default: false }
  }
});

function aliasAvailable(alias) {
  const result = spawnSync(
    "sf",
    ["org", "display", "--target-org", alias, "--json"],
    { encoding: "utf8", shell: process.platform === "win32" }
  );
  return result.status !== 0;
}

function isPromoted(packageVersionId, devHub) {
  const report = runJson("sf", [
    "package",
    "version",
    "report",
    "--package",
    packageVersionId,
    "--target-dev-hub",
    devHub
  ]);
  const details = report.result ?? {};
  return (
    details.IsReleased === true ||
    details.isReleased === true ||
    details.Released === true
  );
}

function installPackage(packageVersionId, alias) {
  run("sf", [
    "package",
    "install",
    "--package",
    packageVersionId,
    "--target-org",
    alias,
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
}

function assignAdmin(alias, releases) {
  run("sf", [
    "org",
    "assign",
    "permset",
    "--name",
    namespacedPermissionSet(releases.permissionSets.admin, releases),
    "--target-org",
    alias
  ]);
}

function deploySubscriberHarness(alias) {
  run("sf", [
    "project",
    "deploy",
    "start",
    "--source-dir",
    paths.subscriberApp,
    "--target-org",
    alias,
    "--wait",
    "30"
  ]);
}

function runSubscriberSmoke(alias) {
  run("sf", [
    "apex",
    "run",
    "test",
    "--class-names",
    "RHCSubscriberSmokeTest",
    "--target-org",
    alias,
    "--result-format",
    "human",
    "--wait",
    "30"
  ]);
}

function assertNoInternalFactory(alias) {
  const query = runJson("sf", [
    "data",
    "query",
    "--target-org",
    alias,
    "--query",
    "SELECT Name FROM ApexClass WHERE Name = 'RecordHealthCheckTestDataFactory' AND NamespacePrefix = null",
    "--json"
  ]);
  const records = query.result?.records ?? [];
  if (records.length > 0) {
    console.error(
      "RecordHealthCheckTestDataFactory must not be deployed as subscriber-owned source."
    );
    process.exit(1);
  }
}

function main() {
  const devHub = values["dev-hub"];
  if (!devHub) {
    console.error("Set DEV_HUB_ALIAS or pass --dev-hub.");
    process.exit(1);
  }

  const releases = readPackageReleases();
  const candidateId = values.package ?? stablePackageVersionId(releases);
  const alias = values.alias;

  if (values["upgrade-only"]) {
    runUpgradeGate(candidateId, alias, devHub, releases);
    return;
  }

  if (!aliasAvailable(alias)) {
    console.error(
      `Alias '${alias}' is already in use. Pass --alias with a free name.`
    );
    process.exit(1);
  }

  console.log(`Creating no-namespace verification org '${alias}'...`);
  run("sf", [
    "org",
    "create",
    "scratch",
    "--definition-file",
    paths.subscriberScratchDef,
    "--alias",
    alias,
    "--target-dev-hub",
    devHub,
    "--duration-days",
    "1",
    "--no-namespace",
    "--wait",
    "30"
  ]);

  console.log(`Clean install of candidate ${candidateId}...`);
  installPackage(candidateId, alias);
  assignAdmin(alias, releases);
  deploySubscriberHarness(alias);

  const installed = installedPackageRecords(
    runJson("sf", ["package", "installed", "list", "--target-org", alias])
  );
  if (!hasInstalledPackageVersion(installed, candidateId)) {
    console.error(
      "Clean install verification failed: candidate 04t not installed."
    );
    process.exit(1);
  }

  assertNoInternalFactory(alias);
  runSubscriberSmoke(alias);
  console.log("Clean subscriber install gate passed.");

  if (values["skip-upgrade"]) {
    return;
  }

  runUpgradeGate(candidateId, alias, devHub, releases);
}

function runUpgradeGate(candidateId, alias, devHub, releases) {
  const previousId = releases.previous?.subscriberPackageVersionId ?? "";
  if (!previousId.startsWith("04t") || previousId === candidateId) {
    console.log("Skipping upgrade gate: no distinct previous 04t configured.");
    return;
  }

  if (!isPromoted(previousId, devHub)) {
    console.warn(
      `Skipping upgrade gate: previous ${previousId} is not promoted on Dev Hub. Promote it to enable N-1 upgrade CI.`
    );
    return;
  }

  if (!aliasAvailable(alias)) {
    run("sf", [
      "org",
      "delete",
      "scratch",
      "--target-org",
      alias,
      "--no-prompt"
    ]);
  }

  console.log(`Creating no-namespace upgrade org '${alias}'...`);
  run("sf", [
    "org",
    "create",
    "scratch",
    "--definition-file",
    paths.subscriberScratchDef,
    "--alias",
    alias,
    "--target-dev-hub",
    devHub,
    "--duration-days",
    "1",
    "--no-namespace",
    "--wait",
    "30"
  ]);

  console.log(
    `Installing previous promoted version ${previousId} for upgrade rehearsal...`
  );
  installPackage(previousId, alias);
  assignAdmin(alias, releases);
  deploySubscriberHarness(alias);

  if (process.env.RHC_SKIP_DEMO_DATA !== "1") {
    run("sf", [
      "apex",
      "run",
      "--target-org",
      alias,
      "--file",
      `${paths.subscriberData}/setupDemoData.apex`
    ]);
  }

  console.log(`Upgrading ${alias} to candidate ${candidateId}...`);
  installPackage(candidateId, alias);
  runSubscriberSmoke(alias);

  const upgraded = installedPackageRecords(
    runJson("sf", ["package", "installed", "list", "--target-org", alias])
  );
  if (!hasInstalledPackageVersion(upgraded, candidateId)) {
    console.error(
      "Upgrade gate failed: candidate 04t not installed after upgrade."
    );
    process.exit(1);
  }

  console.log("Subscriber upgrade gate passed.");
}

main();
