#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
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
    "allow-additional-candidate": { type: "boolean", default: false },
    "override-reason": { type: "string", default: "" },
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
const gitCommit = execFileSync("git", ["rev-parse", "HEAD"], {
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
const packageCapacity = assertPackageVersionCapacity(values["dev-hub"]);
const createsUsedToday = packageCapacity.max - packageCapacity.remaining;
if (createsUsedToday > 0 && !values["allow-additional-candidate"]) {
  console.error(
    `The Dev Hub has already consumed ${createsUsedToday} of ${packageCapacity.max} ` +
      "package-version creates in the current limit window. This repository permits one " +
      "candidate attempt per day by default. Wait for the limit to reset."
  );
  process.exit(1);
}
if (values["allow-additional-candidate"]) {
  if (values["override-reason"].trim().length < 20) {
    console.error(
      "An additional candidate requires --override-reason with at least 20 characters " +
        "describing the reviewed evidence and why waiting is unacceptable."
    );
    process.exit(1);
  }
  console.warn(
    "EXCEPTION: allowing an additional package candidate in the current limit window."
  );
  console.warn(`Reviewed reason: ${values["override-reason"].trim()}`);
}

console.log(
  `Creating package version for ${releases.packageName} (${releases.package2Id}) from force-app` +
    `${versionNumber ? ` at ${versionNumber}` : " (version from sfdx-project.json)"}...`
);

const versionListArguments = [
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
];
const versionsBefore = runJson("sf", versionListArguments, {
  cwd: paths.packageRoot
});
const idsBefore = new Set(
  (versionsBefore.result ?? [])
    .map((record) => record.SubscriberPackageVersionId)
    .filter(Boolean)
);
const candidateBranch = `${branch}@${gitCommit.slice(0, 12)}`;

const createArguments = [
  "package",
  "version",
  "create",
  "--package",
  releases.package2Id,
  "--definition-file",
  "config/project-scratch-def.json",
  "--code-coverage",
  "--generate-pkg-zip",
  "--installation-key-bypass",
  "--branch",
  candidateBranch,
  "--wait",
  values.wait,
  "--target-dev-hub",
  values["dev-hub"]
];
if (versionNumber) {
  createArguments.push("--version-number", versionNumber);
}

run("sf", createArguments, { cwd: paths.packageRoot });

const versions = runJson("sf", versionListArguments, {
  cwd: paths.packageRoot
});

const records = versions.result ?? [];
const createdRecords = records.filter(
  (record) =>
    record.SubscriberPackageVersionId &&
    !idsBefore.has(record.SubscriberPackageVersionId) &&
    (record.Branch ?? record.branch) === candidateBranch
);
if (createdRecords.length !== 1) {
  console.error(
    `Package version create must produce exactly one candidate bound to ${candidateBranch}; found ${createdRecords.length}.`
  );
  process.exit(1);
}
const latest = createdRecords[0];

const evidenceDirectory = path.join(paths.packageRoot, ".package-evidence");
fs.mkdirSync(evidenceDirectory, { recursive: true });
const evidencePath = path.join(
  evidenceDirectory,
  `${latest.SubscriberPackageVersionId}-create.json`
);
fs.writeFileSync(
  evidencePath,
  `${JSON.stringify(
    {
      capturedAt: new Date().toISOString(),
      gitCommit,
      packageBranch: candidateBranch,
      package2Id: releases.package2Id,
      subscriberPackageVersionId: latest.SubscriberPackageVersionId,
      packageVersionId: latest.Id ?? null,
      version: latest.Version ?? latest.version ?? null,
      devHubAlias: values["dev-hub"],
      generatedPackageZipRequested: true,
      capacityAtPreflight: {
        remaining: packageCapacity.remaining,
        maximum: packageCapacity.max,
        consumed: createsUsedToday
      },
      additionalCandidateException: values["allow-additional-candidate"],
      overrideReason: values["allow-additional-candidate"]
        ? values["override-reason"].trim()
        : null
    },
    null,
    2
  )}\n`
);

console.log("");
console.log("Candidate package version created.");
console.log(`Version: ${latest.Version ?? latest.version ?? "unknown"}`);
console.log(`04t: ${latest.SubscriberPackageVersionId}`);
console.log(`Redacted creation evidence: ${evidencePath}`);
console.log("");
console.log(
  "Next: npm run package:verify -- --package " +
    latest.SubscriberPackageVersionId
);
console.log(
  "Do not update config/package-releases.json until clean install, upgrade, and promote gates pass."
);
