#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import { parseArgs } from "node:util";
import { paths } from "../lib/paths.mjs";
import { readPackageReleases } from "../lib/package-releases.mjs";
import { run, runJson } from "../lib/run.mjs";
import { assertPackageVersionCapacity } from "../lib/salesforce-limits.mjs";

const { values } = parseArgs({
  options: {
    "dev-hub": { type: "string", default: process.env.DEV_HUB_ALIAS ?? "" },
    "version-number": { type: "string" },
    "release-ready": { type: "boolean", default: false },
    wait: { type: "string", default: "120" }
  }
});

if (!values["dev-hub"]) {
  console.error(
    "Pass --dev-hub (or set DEV_HUB_ALIAS). Example: npm run package:create -- --dev-hub my-dev-hub"
  );
  process.exit(1);
}

if (!values["release-ready"]) {
  console.error(
    "Package creation is the final release-candidate step. Re-run with --release-ready only after the branch is committed and every preflight gate passes."
  );
  process.exit(1);
}

const branch = execFileSync("git", ["branch", "--show-current"], {
  cwd: paths.repoRoot,
  encoding: "utf8"
}).trim();
if (!branch || branch === "main") {
  console.error(
    "Create the package candidate from a committed release branch, not main or a detached HEAD."
  );
  process.exit(1);
}
const worktree = execFileSync("git", ["status", "--porcelain"], {
  cwd: paths.repoRoot,
  encoding: "utf8"
}).trim();
if (worktree) {
  console.error(
    "Package creation requires a clean worktree so the immutable candidate maps to an exact commit. Commit the release branch first."
  );
  process.exit(1);
}

run("npm", ["run", "release:preflight"], { cwd: paths.repoRoot });

const releases = readPackageReleases();
// Only pass --version-number when the caller asks for a specific line. A
// hardcoded default silently overrides packageDirectories[].versionNumber in
// sfdx-project.json, so a stale constant here builds the wrong version line
// (2.0.0.NEXT long after the project moved to 2.0.1).
const versionNumber = values["version-number"];
assertPackageVersionCapacity(values["dev-hub"]);

console.log(
  `Creating package version for ${releases.packageName} (${releases.package2Id}) from force-app` +
    `${versionNumber ? ` at ${versionNumber}` : " (version from sfdx-project.json)"}...`
);

const createArguments = [
  "package",
  "version",
  "create",
  "--package",
  releases.package2Id,
  "--path",
  "force-app",
  "--definition-file",
  "config/project-scratch-def.json",
  "--code-coverage",
  "--installation-key-bypass",
  "--wait",
  values.wait,
  "--target-dev-hub",
  values["dev-hub"]
];
if (versionNumber) {
  createArguments.push("--version-number", versionNumber);
}

run("sf", createArguments, { cwd: paths.packageRoot });

const versions = runJson(
  "sf",
  [
    "package",
    "version",
    "list",
    "--packages",
    releases.package2Id,
    "--target-dev-hub",
    values["dev-hub"],
    "--created-last-days",
    "1",
    "--order-by",
    "CreatedDate",
    "--concise"
  ],
  { cwd: paths.packageRoot }
);

const records = versions.result ?? [];
const latest = records[records.length - 1];
if (!latest?.SubscriberPackageVersionId) {
  console.error("Package version create finished but no new 04t was found.");
  process.exit(1);
}

console.log("");
console.log("Candidate package version created.");
console.log(`Version: ${latest.Version ?? latest.version ?? "unknown"}`);
console.log(`04t: ${latest.SubscriberPackageVersionId}`);
console.log("");
console.log(
  "Next: npm run package:verify -- --package " +
    latest.SubscriberPackageVersionId
);
console.log(
  "Do not update config/package-releases.json until clean install, upgrade, and promote gates pass."
);
