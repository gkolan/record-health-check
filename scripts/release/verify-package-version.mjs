#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import fs from "node:fs";
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
import { packageVersionString } from "../lib/package-version.mjs";
import { run, runJson } from "../lib/run.mjs";
import { assertScratchCapacity } from "../lib/salesforce-limits.mjs";

const { values } = parseArgs({
  options: {
    alias: { type: "string", default: "rhc-verify" },
    "dev-hub": { type: "string", default: process.env.DEV_HUB_ALIAS ?? "" },
    package: { type: "string" },
    "upgrade-from": { type: "string", default: "" },
    "skip-upgrade": { type: "boolean", default: false },
    "upgrade-only": { type: "boolean", default: false },
    "security-mode": { type: "string", default: "LWS" },
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

function assertPackageVersion(
  packageVersionId,
  devHub,
  expectedVersion,
  label
) {
  const report =
    runJson("sf", [
      "package",
      "version",
      "report",
      "--package",
      packageVersionId,
      "--target-dev-hub",
      devHub
    ]).result ?? {};
  const actualVersion = packageVersionString(report);
  if (actualVersion !== expectedVersion) {
    console.error(
      `${label} must be version ${expectedVersion}; ${packageVersionId} reports ${actualVersion || "an unknown version"}.`
    );
    process.exit(1);
  }
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

function deployUpgradePreservationFixture(alias) {
  run("sf", [
    "project",
    "deploy",
    "start",
    "--source-dir",
    `${paths.subscriberApp}/main/default/customMetadata`,
    "--source-dir",
    `${paths.subscriberApp}/main/default/classes/RHCSubscriberPlugin.cls`,
    "--source-dir",
    `${paths.subscriberApp}/main/default/classes/RHCSubscriberPlugin.cls-meta.xml`,
    "--target-org",
    alias,
    "--wait",
    "30"
  ]);
}

function runUpgradeBaseVerification(alias) {
  run("sf", [
    "apex",
    "run",
    "--target-org",
    alias,
    "--file",
    `${paths.subscriberData}/verifyUpgradeBase.apex`
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

function runInstalledSurfaceGates(alias, securityMode) {
  run(
    "npm",
    [
      "run",
      "contract:org",
      "--prefix",
      "packages/record-health-check-mcp",
      "--",
      "--target-org",
      alias,
      "--namespace",
      "rhc"
    ],
    { cwd: paths.repoRoot }
  );
  run(
    "npm",
    [
      "run",
      "test:browser:salesforce",
      "--",
      "--target-org",
      alias,
      "--security-mode",
      securityMode
    ],
    { cwd: paths.repoRoot }
  );
}

function subscriberConfiguration(alias) {
  const queries = {
    checkSets:
      "SELECT FIELDS(ALL) FROM rhc__Record_Health_Check_Set__mdt WHERE DeveloperName LIKE 'Subscriber_%' LIMIT 200",
    checks:
      "SELECT FIELDS(ALL) FROM rhc__Record_Health_Check__mdt WHERE DeveloperName LIKE 'Subscriber_%' LIMIT 200"
  };
  const snapshot = {};
  for (const [kind, query] of Object.entries(queries)) {
    const records =
      runJson("sf", ["data", "query", "--target-org", alias, "--query", query])
        .result?.records ?? [];
    snapshot[kind] = records
      .map(({ attributes: _attributes, ...record }) => record)
      .sort((left, right) =>
        String(left.DeveloperName).localeCompare(String(right.DeveloperName))
      );
  }
  if (snapshot.checkSets.length !== 2 || snapshot.checks.length !== 5) {
    console.error(
      `Subscriber preservation fixture is incomplete: expected 2 Check Sets and 5 Checks; found ${snapshot.checkSets.length} and ${snapshot.checks.length}.`
    );
    process.exit(1);
  }
  return snapshot;
}

function assertSubscriberConfigurationPreserved(before, after) {
  for (const kind of ["checkSets", "checks"]) {
    const afterByName = new Map(
      after[kind].map((record) => [record.DeveloperName, record])
    );
    for (const original of before[kind]) {
      const upgraded = afterByName.get(original.DeveloperName);
      if (!upgraded) {
        console.error(
          `Upgrade removed subscriber-owned ${kind} record ${original.DeveloperName}.`
        );
        process.exit(1);
      }
      for (const [field, value] of Object.entries(original)) {
        if (
          ["CreatedDate", "LastModifiedDate", "SystemModstamp"].includes(field)
        )
          continue;
        if (JSON.stringify(upgraded[field]) !== JSON.stringify(value)) {
          console.error(
            `Upgrade changed subscriber-owned ${kind} record ${original.DeveloperName}.${field}.`
          );
          process.exit(1);
        }
      }
    }
  }
  console.log(
    "Subscriber-owned Custom Metadata values are identical before and after upgrade."
  );
}

function writeUpgradeEvidence(
  candidateId,
  upgradeFromId,
  securityMode,
  before,
  after
) {
  const evidenceDirectory = new URL(
    "../../packages/record-health-check/.package-evidence/",
    import.meta.url
  );
  fs.mkdirSync(evidenceDirectory, { recursive: true });
  const evidencePath = new URL(
    `${candidateId}-${securityMode.toLowerCase()}-upgrade-preservation.json`,
    evidenceDirectory
  );
  fs.writeFileSync(
    evidencePath,
    `${JSON.stringify(
      {
        capturedAt: new Date().toISOString(),
        candidateId,
        upgradeFromId,
        securityMode,
        before,
        after,
        preservationVerified: true
      },
      null,
      2
    )}\n`
  );
  console.log(`Upgrade preservation evidence: ${evidencePath.pathname}`);
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
  const runtimeMatrix = JSON.parse(
    fs.readFileSync(
      new URL("../../config/release-runtime-matrix.json", import.meta.url),
      "utf8"
    )
  );
  const securityMode = values["security-mode"];
  if (!runtimeMatrix.lightningSecurityModes.includes(securityMode)) {
    console.error(
      `--security-mode must be one of ${runtimeMatrix.lightningSecurityModes.join(
        ", "
      )}.`
    );
    process.exit(1);
  }
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
  assertPackageVersion(
    candidateId,
    devHub,
    runtimeMatrix.candidateVersion,
    "Release candidate"
  );
  const alias = values.alias;
  const stableId = releases.stable?.subscriberPackageVersionId ?? "";
  const previousId = releases.previous?.subscriberPackageVersionId ?? "";
  const upgradeFromId =
    values["upgrade-from"] ||
    (stableId === candidateId ? previousId : stableId);
  if (
    releases.stable?.version !== runtimeMatrix.upgradeFromVersion ||
    upgradeFromId !== stableId
  ) {
    console.error(
      `The release upgrade gate must start from tracked stable ${runtimeMatrix.upgradeFromVersion} (${stableId}).`
    );
    process.exit(1);
  }
  assertPackageVersion(
    upgradeFromId,
    devHub,
    runtimeMatrix.upgradeFromVersion,
    "Upgrade base"
  );
  const needsUpgradeOrg =
    !values["skip-upgrade"] &&
    upgradeFromId.startsWith("04t") &&
    upgradeFromId !== candidateId;

  if (values["upgrade-only"]) {
    runUpgradeGate(
      candidateId,
      upgradeFromId,
      alias,
      devHub,
      releases,
      securityMode,
      true
    );
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
    securityMode === "Locker"
      ? paths.lockerScratchDef
      : paths.subscriberScratchDef,
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
  runInstalledSurfaceGates(alias, securityMode);
  console.log("Clean subscriber install gate passed.");

  if (values["skip-upgrade"]) {
    return;
  }

  runUpgradeGate(
    candidateId,
    upgradeFromId,
    alias,
    devHub,
    releases,
    securityMode
  );
}

function runUpgradeGate(
  candidateId,
  upgradeFromId,
  alias,
  devHub,
  releases,
  securityMode,
  required = false
) {
  if (!upgradeFromId.startsWith("04t") || upgradeFromId === candidateId) {
    if (required) {
      console.error(
        "Upgrade-only verification requires a distinct promoted --upgrade-from 04t."
      );
      process.exit(1);
    }
    console.log("Skipping upgrade gate: no distinct stable 04t configured.");
    return;
  }

  if (!isPromoted(upgradeFromId, devHub)) {
    if (required) {
      console.error(
        `Upgrade-only verification requires promoted base version ${upgradeFromId}.`
      );
      process.exit(1);
    }
    console.warn(
      `Skipping upgrade gate: base ${upgradeFromId} is not promoted on Dev Hub.`
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
    securityMode === "Locker"
      ? paths.lockerScratchDef
      : paths.subscriberScratchDef,
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
    `Installing promoted base version ${upgradeFromId} for upgrade rehearsal...`
  );
  installPackage(upgradeFromId, alias);
  assignAdmin(alias, releases);
  deployUpgradePreservationFixture(alias);

  const baseInstalled = installedPackageRecords(
    runJson("sf", ["package", "installed", "list", "--target-org", alias])
  );
  if (!hasInstalledPackageVersion(baseInstalled, upgradeFromId)) {
    console.error(
      `Upgrade rehearsal did not install the exact base version ${upgradeFromId}.`
    );
    process.exit(1);
  }

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

  const configurationBeforeUpgrade = subscriberConfiguration(alias);
  runUpgradeBaseVerification(alias);
  console.log(
    "Pre-upgrade 2.0.6.2 global API and subscriber-preservation baseline passed."
  );

  console.log(`Upgrading ${alias} to candidate ${candidateId}...`);
  installPackage(candidateId, alias);
  assignAdmin(alias, releases);
  const configurationAfterUpgrade = subscriberConfiguration(alias);
  assertSubscriberConfigurationPreserved(
    configurationBeforeUpgrade,
    configurationAfterUpgrade
  );
  writeUpgradeEvidence(
    candidateId,
    upgradeFromId,
    securityMode,
    configurationBeforeUpgrade,
    configurationAfterUpgrade
  );
  deploySubscriberHarness(alias);
  runSubscriberSmoke(alias);
  runInstalledSurfaceGates(alias, securityMode);
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
