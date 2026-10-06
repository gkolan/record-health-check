#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { parseArgs } from "node:util";
import { paths } from "../lib/paths.mjs";
import { seedDemoData } from "../lib/demo-data.mjs";
import { verifyReadinessData } from "../lib/demo-verification.mjs";
import {
  namespacedPermissionSet,
  readPackageReleases
} from "../lib/package-releases.mjs";
import {
  hasInstalledPackageVersion,
  installedPackageRecords
} from "../lib/installed-packages.mjs";
import { packageVersionString } from "../lib/package-version.mjs";
import { run, runJson, tryRun } from "../lib/run.mjs";
import { assertScratchCapacity } from "../lib/salesforce-limits.mjs";
import { selectUpgradeBase } from "../lib/release-upgrades.mjs";
import {
  planReleasePairReset,
  writeReleasePairResetDeploy
} from "../lib/release-pair-reset.mjs";

import {
  assertReuseOptions,
  assertRetainedReleaseOrg,
  securityRetrieveDirectory
} from "../lib/release-org-reuse.mjs";

const { values } = parseArgs({
  options: {
    alias: { type: "string", default: "rhc-verify" },
    "dev-hub": { type: "string", default: process.env.DEV_HUB_ALIAS ?? "" },
    package: { type: "string" },
    "upgrade-from": { type: "string", default: "" },
    "skip-upgrade": { type: "boolean", default: false },
    "upgrade-only": { type: "boolean", default: false },
    "release-pair": { type: "boolean", default: false },
    "reuse-existing-org": { type: "boolean", default: false },
    "reset-installed-package": { type: "string", default: "" },
    "security-mode": { type: "string", default: "LWS" },
    "keep-org": { type: "boolean", default: false }
  }
});

const createdAliases = new Set();
const reusedPairAliases = new Set();

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

function releaseVersion(runtimeMatrix) {
  return runtimeMatrix.candidateVersion.split(".").slice(0, 3).join(".");
}

function assertReleasePairSlotAvailable(devHub, runtimeMatrix, securityMode) {
  const version = releaseVersion(runtimeMatrix);
  const description = `Record Health Check ${version} ${securityMode} release pair`;
  const records =
    runJson("sf", [
      "data",
      "query",
      "--target-org",
      devHub,
      "--query",
      "SELECT Id, Description, Status FROM ScratchOrgInfo WHERE Status = 'Active'"
    ]).result?.records ?? [];
  if (records.some((record) => record.Description === description)) {
    console.error(
      `The ${version} ${securityMode} release-pair slot already has an active scratch org. Reuse or explicitly retire it; do not create a duplicate.`
    );
    process.exit(1);
  }
  const retainedVersions = new Set(
    records
      .map((record) =>
        String(record.Description ?? "").match(
          /^Record Health Check (\d+\.\d+\.\d+) (?:LWS|Locker) release pair$/
        )
      )
      .filter(Boolean)
      .map((match) => match[1])
  );
  if (!retainedVersions.has(version) && retainedVersions.size >= 2) {
    console.error(
      `Two release pairs are already retained (${[...retainedVersions].join(", ")}). Delete the pair two releases behind before creating ${version}.`
    );
    process.exit(1);
  }
  return description;
}

function assertExistingReleasePair(alias, devHub, runtimeMatrix, securityMode) {
  const organization = runJson("sf", [
    "data",
    "query",
    "--target-org",
    alias,
    "--query",
    "SELECT Id, NamespacePrefix FROM Organization"
  ]).result?.records?.[0];
  const records =
    runJson("sf", [
      "data",
      "query",
      "--target-org",
      devHub,
      "--query",
      "SELECT ScratchOrg, Description, Status FROM ScratchOrgInfo WHERE Status = 'Active'"
    ]).result?.records ?? [];
  assertRetainedReleaseOrg({
    orgId: organization?.Id,
    namespace: organization?.NamespacePrefix,
    securityMode,
    version: releaseVersion(runtimeMatrix),
    records
  });
  const directory = securityRetrieveDirectory(paths.repoRoot);
  try {
    run("sf", [
      "project",
      "retrieve",
      "start",
      "--metadata",
      "Settings:Security",
      "--target-org",
      alias,
      "--output-dir",
      directory,
      "--wait",
      "10"
    ]);
    const findSettings = (folder) => {
      for (const entry of fs.readdirSync(folder, { withFileTypes: true })) {
        const file = path.join(folder, entry.name);
        if (entry.isDirectory()) {
          const found = findSettings(file);
          if (found) return found;
        } else if (entry.name === "Security.settings-meta.xml") return file;
      }
      return null;
    };
    const file = findSettings(directory);
    const value = file
      ? fs
          .readFileSync(file, "utf8")
          .match(/<lockerServiceNext>(true|false)<\/lockerServiceNext>/)?.[1]
      : null;
    if (value !== (securityMode === "LWS" ? "true" : "false"))
      throw new Error(
        "Retained org Lightning security setting does not match the requested mode."
      );
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
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

function resetReleasePairForUpgrade(alias, candidateId) {
  const deployDirectory = fs.mkdtempSync(
    path.join(os.tmpdir(), "rhc-subscriber-reset-")
  );
  try {
    // One transaction: delete Checks, reset record-page overrides and
    // deactivate Flows, then delete the remaining harness components.
    const plan = planReleasePairReset(paths.subscriberApp);
    writeReleasePairResetDeploy(plan, deployDirectory);
    run("sf", [
      "project",
      "deploy",
      "start",
      "--metadata-dir",
      deployDirectory,
      "--target-org",
      alias,
      "--test-level",
      "NoTestRun",
      "--wait",
      "30"
    ]);
    // A metadata delete of a deactivated Flow is rejected; delete its versions.
    const emptyBody = path.join(deployDirectory, "empty.json");
    fs.writeFileSync(emptyBody, "{}");
    for (const flow of plan.flows) {
      const versions =
        runJson("sf", [
          "data",
          "query",
          "--use-tooling-api",
          "--target-org",
          alias,
          "--query",
          `SELECT Id FROM Flow WHERE Definition.DeveloperName = '${flow}'`
        ]).result?.records ?? [];
      for (const { Id } of versions) {
        run("sf", [
          "api",
          "request",
          "rest",
          `/services/data/v66.0/tooling/sobjects/Flow/${Id}`,
          "--method",
          "DELETE",
          "--body",
          emptyBody,
          "--target-org",
          alias
        ]);
      }
    }
    // Uninstall is rejected while any package Permission Set is assigned.
    const unassign = path.join(deployDirectory, "unassign.apex");
    fs.writeFileSync(
      unassign,
      "delete [SELECT Id FROM PermissionSetAssignment WHERE PermissionSet.NamespacePrefix = 'rhc'];\n"
    );
    run("sf", ["apex", "run", "--target-org", alias, "--file", unassign]);
    run("sf", [
      "package",
      "uninstall",
      "--package",
      candidateId,
      "--target-org",
      alias,
      "--wait",
      "30"
    ]);
  } finally {
    fs.rmSync(deployDirectory, { recursive: true, force: true });
  }
}

function assignAdmin(alias, releases) {
  const permissionSet = namespacedPermissionSet(
    releases.permissionSets.admin,
    releases
  );
  const assignment = tryRun("sf", [
    "org",
    "assign",
    "permset",
    "--name",
    permissionSet,
    "--target-org",
    alias
  ]);
  if (assignment.status === 0) return;
  const output = `${assignment.stdout ?? ""}${assignment.stderr ?? ""}`;
  if (output.includes("Duplicate PermissionSetAssignment")) {
    console.log(`${permissionSet} is already assigned; continuing.`);
    return;
  }
  process.stderr.write(output);
  process.exit(assignment.status ?? 1);
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
    "--source-dir",
    `${paths.subscriberApp}/main/default/classes/RHCSubscriberFormatPlugin.cls`,
    "--source-dir",
    `${paths.subscriberApp}/main/default/classes/RHCSubscriberFormatPlugin.cls-meta.xml`,
    "--source-dir",
    paths.subscriberUpgradePreflight,
    "--target-org",
    alias,
    "--wait",
    "30"
  ]);
}

function runUpgradeCompatibilityAudit(alias, expectedCount) {
  run(
    "node",
    [
      "scripts/release/audit-2.0.11-upgrade.mjs",
      "--target-org",
      alias,
      "--expect-count",
      String(expectedCount)
    ],
    { cwd: paths.repoRoot }
  );
}

function runUpgradeCompatibilityVerification(alias) {
  run("sf", [
    "apex",
    "run",
    "--target-org",
    alias,
    "--file",
    `${paths.subscriberData}/verify2_0_11UpgradeCompatibility.apex`
  ]);
}

function recoverUpgradeCompatibilityFixture(alias) {
  run("sf", [
    "project",
    "deploy",
    "start",
    "--source-dir",
    paths.subscriberUpgradeCorrected,
    "--target-org",
    alias,
    "--wait",
    "30"
  ]);
  runUpgradeCompatibilityAudit(alias, 0);
  run("sf", [
    "apex",
    "run",
    "--target-org",
    alias,
    "--file",
    `${paths.subscriberData}/verify2_0_11UpgradeRecovery.apex`
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

function runSubscriberSmoke(alias, phase) {
  // Discover and reconcile every subscriber test, including the real Flow
  // interview. A class existing on disk is not evidence that it executed.
  run(
    "node",
    [
      "scripts/release/run_exact_apex_test_inventory.mjs",
      "--target-org",
      alias,
      "--scope",
      "subscriber",
      "--topology",
      `${alias}-${phase}`,
      "--wait",
      "60"
    ],
    { cwd: paths.repoRoot }
  );
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
  verifyReadinessData(alias);
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
      "--installed-package",
      values.package,
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
  if (snapshot.checkSets.length !== 4 || snapshot.checks.length !== 12) {
    console.error(
      `Subscriber preservation fixture is incomplete: expected 4 Check Sets and 12 Checks; found ${snapshot.checkSets.length} and ${snapshot.checks.length}.`
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
    `${candidateId}-${upgradeFromId}-${securityMode.toLowerCase()}-upgrade-preservation.json`,
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
  if (
    values["release-pair"] &&
    (values["skip-upgrade"] || values["upgrade-only"] || !values["keep-org"])
  ) {
    console.error(
      "--release-pair requires --keep-org and performs both clean-install and upgrade validation in the same org."
    );
    process.exit(1);
  }
  assertReuseOptions({
    reuseExistingOrg: values["reuse-existing-org"],
    upgradeOnly: values["upgrade-only"],
    releasePair: values["release-pair"],
    keepOrg: values["keep-org"]
  });
  if (
    values["reset-installed-package"] &&
    !(values["reuse-existing-org"] && values["release-pair"])
  ) {
    throw new Error(
      "--reset-installed-package requires reuse of a retained release pair."
    );
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
  const upgradeBase = selectUpgradeBase(runtimeMatrix, releases, upgradeFromId);
  assertPackageVersion(
    upgradeFromId,
    devHub,
    upgradeBase.version,
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
      true,
      false,
      values["reuse-existing-org"]
    );
    return;
  }

  if (values["reuse-existing-org"]) {
    assertExistingReleasePair(alias, devHub, runtimeMatrix, securityMode);
    const installed = installedPackageRecords(
      runJson("sf", ["package", "installed", "list", "--target-org", alias])
    );
    if (installed.length) {
      const resetId = values["reset-installed-package"];
      if (
        !resetId ||
        installed.length !== 1 ||
        !hasInstalledPackageVersion(installed, resetId)
      ) {
        throw new Error(
          "Clean install requires an empty org or --reset-installed-package naming its one exact installed version."
        );
      }
      // The owner explicitly selects the package to uninstall; never infer it.
      resetReleasePairForUpgrade(alias, resetId);
      const remaining = installedPackageRecords(
        runJson("sf", ["package", "installed", "list", "--target-org", alias])
      );
      if (remaining.length)
        throw new Error(
          "Release-pair reset did not leave a clean package inventory."
        );
    } else if (values["reset-installed-package"]) {
      throw new Error(
        "The selected reset package is not installed; no reset was performed."
      );
    }
    reusedPairAliases.add(alias);
  } else {
    if (!aliasAvailable(alias)) {
      console.error(
        `Alias '${alias}' is already in use. Pass --alias with a free name.`
      );
      process.exit(1);
    }

    console.log(`Creating no-namespace verification org '${alias}'...`);
    const releaseDescription = values["release-pair"]
      ? assertReleasePairSlotAvailable(devHub, runtimeMatrix, securityMode)
      : "";
    assertScratchCapacity(
      devHub,
      values["release-pair"] ? 1 : needsUpgradeOrg ? 2 : 1
    );
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
      values["release-pair"] ? "30" : "1",
      ...(values["release-pair"] ? ["--description", releaseDescription] : []),
      "--no-namespace",
      "--wait",
      "30"
    ]);
    createdAliases.add(alias);
  }

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
  runSubscriberSmoke(alias, "clean-install");
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
    securityMode,
    false,
    values["release-pair"]
  );
}

function runUpgradeGate(
  candidateId,
  upgradeFromId,
  alias,
  devHub,
  releases,
  securityMode,
  required = false,
  reuseReleaseOrg = false,
  reuseExistingOrg = false
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

  if (reuseExistingOrg) {
    if (aliasAvailable(alias)) {
      console.error(
        `--reuse-existing-org requires an existing authorized org alias; '${alias}' was not found.`
      );
      process.exit(1);
    }
  } else if (reuseReleaseOrg) {
    if (
      (!createdAliases.has(alias) && !reusedPairAliases.has(alias)) ||
      aliasAvailable(alias)
    ) {
      console.error(
        `Release-pair upgrade expected the clean-install org '${alias}' created or verified for this process.`
      );
      process.exit(1);
    }
    console.log(
      `Resetting ${alias} after clean-install evidence so the same release org can rehearse the upgrade...`
    );
    resetReleasePairForUpgrade(alias, candidateId);
  } else if (!aliasAvailable(alias)) {
    deleteOwnedScratchOrg(alias);
    if (!aliasAvailable(alias)) {
      console.error(
        `Alias '${alias}' belongs to an org this process did not create. Pass a free alias; it will not be deleted.`
      );
      process.exit(1);
    }
  }

  if (!reuseReleaseOrg && !reuseExistingOrg) {
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
      "1",
      "--no-namespace",
      "--wait",
      "30"
    ]);
    createdAliases.add(alias);
  }

  const initiallyInstalled = installedPackageRecords(
    runJson("sf", ["package", "installed", "list", "--target-org", alias])
  );
  if (reuseExistingOrg) {
    if (!hasInstalledPackageVersion(initiallyInstalled, upgradeFromId)) {
      console.error(
        `Existing org '${alias}' must already contain the exact base ${upgradeFromId}.`
      );
      process.exit(1);
    }
    if (hasInstalledPackageVersion(initiallyInstalled, candidateId)) {
      console.error(
        `Existing org '${alias}' already contains candidate ${candidateId}; the pre-upgrade state cannot be proven.`
      );
      process.exit(1);
    }
    console.log(
      `Reusing authorized org '${alias}' with promoted base ${upgradeFromId}.`
    );
  } else {
    console.log(
      `Installing promoted base version ${upgradeFromId} for upgrade rehearsal...`
    );
    installPackage(upgradeFromId, alias);
  }
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
    seedDemoData(alias);
  }

  const configurationBeforeUpgrade = subscriberConfiguration(alias);
  runUpgradeCompatibilityAudit(alias, 1);
  runUpgradeBaseVerification(alias);
  console.log(
    "Pre-upgrade global API, compatibility audit, and subscriber-preservation baseline passed."
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
  runUpgradeCompatibilityVerification(alias);
  recoverUpgradeCompatibilityFixture(alias);
  deploySubscriberHarness(alias);
  runSubscriberSmoke(alias, "upgrade");
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
