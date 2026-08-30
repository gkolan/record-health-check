#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { parseArgs } from "node:util";
import { paths } from "../lib/paths.mjs";
import {
  namespacedPermissionSet,
  readPackageReleases
} from "../lib/package-releases.mjs";
import {
  hasInstalledPackageVersion,
  installedPackageRecords
} from "../lib/installed-packages.mjs";
import { run, runJson } from "../lib/run.mjs";
import { assertScratchCapacity } from "../lib/salesforce-limits.mjs";

const { values } = parseArgs({
  options: {
    alias: { type: "string", default: "rhc-verify" },
    "dev-hub": { type: "string", default: process.env.DEV_HUB_ALIAS ?? "" },
    package: { type: "string" },
    "skip-upgrade": { type: "boolean", default: false },
    "upgrade-only": { type: "boolean", default: false },
    "keep-org": { type: "boolean", default: false }
  }
});

const createdAliases = new Set();

function deleteOwnedScratchOrg(alias) {
  if (!createdAliases.has(alias)) return;
  const result = spawnSync(
    "sf",
    ["org", "delete", "scratch", "--target-org", alias, "--no-prompt"],
    { encoding: "utf8", shell: process.platform === "win32" }
  );
  if (result.status === 0) {
    createdAliases.delete(alias);
    console.log(`Deleted verification scratch org '${alias}'.`);
  } else {
    console.error(
      `Unable to delete verification scratch org '${alias}'. Delete it manually to release Dev Hub capacity.`
    );
    if (result.stderr) process.stderr.write(result.stderr);
  }
}

process.once("exit", () => {
  if (values["keep-org"]) return;
  for (const alias of [...createdAliases]) deleteOwnedScratchOrg(alias);
});

for (const [signal, exitCode] of [
  ["SIGINT", 130],
  ["SIGTERM", 143]
]) {
  process.once(signal, () => {
    if (!values["keep-org"]) {
      for (const alias of [...createdAliases]) deleteOwnedScratchOrg(alias);
    }
    process.exit(exitCode);
  });
}

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
    "Mixed",
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

function runDemoVerification(alias) {
  run("sf", [
    "apex",
    "run",
    "--target-org",
    alias,
    "--file",
    `${paths.subscriberData}/verifyDemo.apex`
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
  if (!values.package) {
    console.error(
      "Pass the explicit candidate 04t with --package. Verification must never infer a release candidate from stable configuration."
    );
    process.exit(1);
  }
  const candidateId = values.package;
  if (!/^04t[0-9A-Za-z]{12}(?:[0-9A-Za-z]{3})?$/.test(candidateId)) {
    console.error(
      "Pass a 15- or 18-character subscriber package version ID beginning with 04t."
    );
    process.exit(1);
  }
  const alias = values.alias;
  const stableId = releases.stable?.subscriberPackageVersionId ?? "";
  const needsUpgradeOrg =
    !values["skip-upgrade"] &&
    stableId.startsWith("04t") &&
    stableId !== candidateId;

  if (values["upgrade-only"]) {
    runUpgradeGate(candidateId, alias, devHub, releases, true);
    return;
  }

  if (!aliasAvailable(alias)) {
    console.error(
      `Alias '${alias}' is already in use. Pass --alias with a free name.`
    );
    process.exit(1);
  }

  console.log(`Creating no-namespace verification org '${alias}'...`);
  assertScratchCapacity(devHub, needsUpgradeOrg ? 2 : 1);
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
    "30",
    "--no-namespace",
    "--wait",
    "30"
  ]);
  createdAliases.add(alias);

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

function runUpgradeGate(
  candidateId,
  alias,
  devHub,
  releases,
  required = false
) {
  const stableId = releases.stable?.subscriberPackageVersionId ?? "";
  if (!stableId.startsWith("04t") || stableId === candidateId) {
    if (required) {
      console.error(
        "Upgrade-only verification requires a distinct stable 04t in package-releases.json."
      );
      process.exit(1);
    }
    console.log("Skipping upgrade gate: no distinct stable 04t configured.");
    return;
  }

  if (!isPromoted(stableId, devHub)) {
    if (required) {
      console.error(
        `Upgrade-only verification requires promoted stable version ${stableId}.`
      );
      process.exit(1);
    }
    console.warn(
      `Skipping upgrade gate: stable ${stableId} is not promoted on Dev Hub. Promote it to enable upgrade CI.`
    );
    return;
  }

  if (!aliasAvailable(alias)) {
    deleteOwnedScratchOrg(alias);
    if (!aliasAvailable(alias)) {
      console.error(
        `Alias '${alias}' belongs to an org this process did not create. Pass a free alias; it will not be deleted.`
      );
      process.exit(1);
    }
  }

  console.log(`Creating no-namespace upgrade org '${alias}'...`);
  assertScratchCapacity(devHub);
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
    "30",
    "--no-namespace",
    "--wait",
    "30"
  ]);
  createdAliases.add(alias);

  console.log(
    `Installing stable promoted version ${stableId} for upgrade rehearsal...`
  );
  installPackage(stableId, alias);
  assignAdmin(alias, releases);
  deploySubscriberHarness(alias);

  if (process.env.RHC_SKIP_DEMO_DATA !== "1") {
    for (const script of ["setupDemoData.apex"]) {
      run("sf", [
        "apex",
        "run",
        "--target-org",
        alias,
        "--file",
        `${paths.subscriberData}/${script}`
      ]);
    }
  }

  console.log(`Upgrading ${alias} to candidate ${candidateId}...`);
  installPackage(candidateId, alias);
  runSubscriberSmoke(alias);
  if (process.env.RHC_SKIP_DEMO_DATA !== "1") {
    runDemoVerification(alias);
  }

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
