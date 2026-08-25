#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { parseArgs } from "node:util";
import { paths } from "../lib/paths.mjs";
import { readPackageReleases } from "../lib/package-releases.mjs";
import { run, runJson } from "../lib/run.mjs";

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
if (
  evidence.subscriberPackageVersionId !== packageVersionId ||
  evidence.package2Id !== releases.package2Id ||
  evidence.gitCommit !== gitCommit
) {
  console.error(
    "Candidate evidence does not bind this 04t to the configured package and current commit."
  );
  process.exit(1);
}

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
if (
  reportedPackage2Id !== releases.package2Id ||
  (reportedSubscriberId && reportedSubscriberId !== packageVersionId)
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
