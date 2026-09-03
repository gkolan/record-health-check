#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { parseArgs } from "node:util";
import { paths } from "../lib/paths.mjs";
import { packageVersionString } from "../lib/package-version.mjs";
import { readPackageReleases } from "../lib/package-releases.mjs";
import { run, runJson } from "../lib/run.mjs";
import { assertReleaseAcceptance } from "../lib/release-acceptance.mjs";

const { values, positionals } = parseArgs({
  allowPositionals: true,
  options: {
    "dev-hub": { type: "string", default: process.env.DEV_HUB_ALIAS ?? "" },
    package: { type: "string" }
  }
});

const devHub = values["dev-hub"];
if (!devHub) {
  console.error("Set DEV_HUB_ALIAS or pass --dev-hub.");
  process.exit(1);
}

const releases = readPackageReleases();
const runtimeMatrix = JSON.parse(
  fs.readFileSync(
    path.join(paths.repoRoot, "config/release-runtime-matrix.json"),
    "utf8"
  )
);
const packageVersionId = values.package ?? positionals[0] ?? "";

if (!/^04t[0-9A-Za-z]{12}(?:[0-9A-Za-z]{3})?$/.test(packageVersionId)) {
  console.error(
    "Pass a candidate 04t via --package or as the first positional argument."
  );
  process.exit(1);
}

const evidencePath = path.join(
  paths.packageRoot,
  ".package-evidence",
  `${packageVersionId}-create.json`
);
if (!fs.existsSync(evidencePath)) {
  console.error(
    `Missing immutable creation evidence for ${packageVersionId}: ${evidencePath}`
  );
  process.exit(1);
}
const evidence = JSON.parse(fs.readFileSync(evidencePath, "utf8"));
const gitCommit = execFileSync("git", ["rev-parse", "HEAD"], {
  cwd: paths.repoRoot,
  encoding: "utf8"
}).trim();
const worktree = execFileSync("git", ["status", "--porcelain"], {
  cwd: paths.repoRoot,
  encoding: "utf8"
}).trim();
if (worktree) {
  console.error(
    "Package promotion requires a clean worktree so the validation evidence and promotion logic match the exact hosted commit."
  );
  process.exit(1);
}
if (
  evidence.subscriberPackageVersionId !== packageVersionId ||
  evidence.package2Id !== releases.package2Id ||
  evidence.gitCommit !== gitCommit ||
  String(evidence.version) !== runtimeMatrix.candidateVersion
) {
  console.error(
    "Candidate evidence does not bind this 04t to the configured package and current commit."
  );
  process.exit(1);
}

const acceptancePath = path.join(
  paths.packageRoot,
  ".package-evidence",
  `${packageVersionId}-acceptance.json`
);
if (!fs.existsSync(acceptancePath)) {
  throw new Error(
    `Missing representative-sandbox acceptance: ${acceptancePath}. Complete the release-owner checklist; do not fabricate pass evidence.`
  );
}
assertReleaseAcceptance(
  JSON.parse(fs.readFileSync(acceptancePath, "utf8")),
  packageVersionId,
  gitCommit
);

run("node", [
  "scripts/release/check_hosted_validation.mjs",
  "--workflow",
  "salesforce-validate.yml",
  "--commit",
  gitCommit
]);
run("node", [
  "scripts/release/check_hosted_validation.mjs",
  "--workflow",
  "subscriber-validate.yml",
  "--commit",
  gitCommit,
  "--candidate",
  packageVersionId
]);

const report = runJson("sf", [
  "package",
  "version",
  "report",
  "--package",
  packageVersionId,
  "--target-dev-hub",
  devHub
]).result;
const reportedPackage2Id = report?.Package2Id ?? report?.package2Id;
const reportedSubscriberId =
  report?.SubscriberPackageVersionId ?? report?.subscriberPackageVersionId;
const reportedVersion = packageVersionString(report);
if (
  reportedPackage2Id !== releases.package2Id ||
  (reportedSubscriberId && reportedSubscriberId !== packageVersionId) ||
  reportedVersion !== runtimeMatrix.candidateVersion
) {
  console.error(
    "Dev Hub package report does not match the configured package or candidate 04t."
  );
  process.exit(1);
}

run("sf", [
  "package",
  "version",
  "promote",
  "--package",
  packageVersionId,
  "--target-dev-hub",
  devHub,
  "--no-prompt"
]);

console.log("");
console.log(`Promoted ${packageVersionId}.`);
console.log("");
console.log("Installation URLs:");
console.log(
  `  Production: https://login.salesforce.com/packaging/installPackage.apexp?p0=${packageVersionId}`
);
console.log(
  `  Sandbox: https://test.salesforce.com/packaging/installPackage.apexp?p0=${packageVersionId}`
);
console.log(
  "  Tracked Production: https://recordhealthcheck.com/install/production"
);
console.log("  Tracked Sandbox: https://recordhealthcheck.com/install/sandbox");
console.log("");
console.log("Update config/package-releases.json:");
console.log("  1. Move the current stable 04t into previous.");
console.log("  2. Set stable.subscriberPackageVersionId to the promoted 04t.");
console.log("  3. Refresh installUrl production and sandbox p0 values.");
console.log(
  "Subscriber scripts and docs read from that file; do not duplicate 04t IDs elsewhere."
);
