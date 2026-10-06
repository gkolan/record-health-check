#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { parseArgs } from "node:util";
import { setTimeout } from "node:timers/promises";
import { paths } from "../lib/paths.mjs";
import { packageVersionString } from "../lib/package-version.mjs";
import { readPackageReleases } from "../lib/package-releases.mjs";
import { run, runJson, tryRun } from "../lib/run.mjs";
import { assertPackageVersionCapacity } from "../lib/salesforce-limits.mjs";

const { values } = parseArgs({
  options: {
    "dev-hub": { type: "string", default: process.env.DEV_HUB_ALIAS ?? "" },
    "version-number": { type: "string" },
    "release-ready": { type: "boolean", default: false },
    "allow-additional-candidate": { type: "boolean", default: false },
    "override-reason": { type: "string", default: "" },
    wait: { type: "string", default: "120" },
    resume: { type: "string" }
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

if (!/^\d+$/.test(values.wait) || !Number.isSafeInteger(Number(values.wait))) {
  throw new Error("--wait must be a non-negative integer number of minutes.");
}
if (
  values.resume &&
  !/^08c[0-9A-Za-z]{12}(?:[0-9A-Za-z]{3})?$/.test(values.resume)
) {
  throw new Error("--resume requires a package creation request ID (08c).");
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
const runtimeMatrix = JSON.parse(
  fs.readFileSync(
    path.join(paths.repoRoot, "config/release-runtime-matrix.json"),
    "utf8"
  )
);
// The release contract names one exact four-part 2GP version. Passing it
// explicitly prevents NEXT from advancing to an unexpected build number.
const versionNumber =
  values["version-number"] ?? runtimeMatrix.candidateVersion;
if (versionNumber !== runtimeMatrix.candidateVersion) {
  console.error(
    `This release gate may create only ${runtimeMatrix.candidateVersion}; received ${versionNumber}.`
  );
  process.exit(1);
}
const evidenceDirectory = path.join(paths.packageRoot, ".package-evidence");
fs.mkdirSync(evidenceDirectory, { recursive: true });
const attemptPath = path.join(
  evidenceDirectory,
  `${releases.package2Id}-${versionNumber}-attempt.json`
);
const tag = `${gitCommit}:${versionNumber}`;

function assertSourceUnchanged() {
  const git = (...args) =>
    execFileSync("git", args, { cwd: paths.repoRoot, encoding: "utf8" }).trim();
  if (
    git("rev-parse", "HEAD") !== gitCommit ||
    git("branch", "--show-current") !== branch ||
    git("status", "--porcelain")
  ) {
    throw new Error(
      "Release source changed during preparation. No candidate may be bound to this commit."
    );
  }
}

let attempt;
let response;
if (values.resume) {
  attempt = JSON.parse(fs.readFileSync(attemptPath, "utf8"));
  if (
    attempt.gitCommit !== gitCommit ||
    attempt.packageBranch !== branch ||
    attempt.package2Id !== releases.package2Id ||
    attempt.version !== versionNumber ||
    attempt.devHubAlias !== values["dev-hub"] ||
    (attempt.createRequestId && attempt.createRequestId !== values.resume)
  ) {
    throw new Error(
      "Resume request does not match the saved candidate attempt and current commit."
    );
  }
  response = runJson(
    "sf",
    [
      "package",
      "version",
      "create",
      "report",
      "--package-create-request-id",
      values.resume,
      "--target-dev-hub",
      values["dev-hub"]
    ],
    { cwd: paths.packageRoot }
  ).result;
} else {
  if (fs.existsSync(attemptPath)) {
    throw new Error(
      `A candidate attempt already exists: ${attemptPath}. Inspect its request and use --resume; do not create again.`
    );
  }
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

  const versionListArguments = [
    "package",
    "version",
    "list",
    "--packages",
    releases.package2Id,
    "--target-dev-hub",
    values["dev-hub"],
    "--order-by",
    "CreatedDate",
    "--concise"
  ];
  const versionsBefore = runJson("sf", versionListArguments, {
    cwd: paths.packageRoot
  });
  if (!Array.isArray(versionsBefore.result)) {
    throw new Error("Dev Hub returned an invalid package version inventory.");
  }
  if (
    versionsBefore.result.some(
      (record) => packageVersionString(record) === versionNumber
    )
  ) {
    throw new Error(
      `Candidate ${versionNumber} already exists. Select a reviewed new build number; do not recreate it.`
    );
  }
  assertSourceUnchanged();
  attempt = {
    capturedAt: new Date().toISOString(),
    gitCommit,
    packageBranch: branch,
    package2Id: releases.package2Id,
    version: versionNumber,
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
      : null,
    createRequestId: null,
    status: "SubmissionPending"
  };
  // Exclusive creation prevents a second local invocation from consuming quota.
  // Retain this journal even if the CLI loses its response after submission.
  fs.writeFileSync(attemptPath, `${JSON.stringify(attempt, null, 2)}\n`, {
    flag: "wx"
  });

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
    branch,
    "--tag",
    tag,
    "--wait",
    "0",
    "--target-dev-hub",
    values["dev-hub"]
  ];
  createArguments.push("--version-number", versionNumber);

  const submission = tryRun("sf", [...createArguments, "--json"], {
    cwd: paths.packageRoot,
    env: {
      ...process.env,
      SF_PROJECT_AUTOUPDATE_DISABLE_FOR_PACKAGE_VERSION_CREATE: "true"
    }
  });
  // Keep raw CLI output locally for diagnosis, including failures and lost responses.
  fs.writeFileSync(`${attemptPath}.stdout`, submission.stdout ?? "");
  fs.writeFileSync(`${attemptPath}.stderr`, submission.stderr ?? "");
  if (submission.status !== 0) {
    throw new Error(
      `Submission outcome is uncertain. Inspect ${attemptPath} and the Dev Hub creation requests; recover with --resume, never a blind retry.`
    );
  }
  const envelope = JSON.parse(submission.stdout);
  if (envelope.status !== 0)
    throw new Error(
      "Package submission returned an unsuccessful JSON status; inspect the saved attempt."
    );
  response = envelope.result;
}

const deadline = Date.now() + Number(values.wait) * 60_000;
while (true) {
  if (
    !response ||
    !/^08c[0-9A-Za-z]{12}(?:[0-9A-Za-z]{3})?$/.test(response.Id) ||
    response.Package2Id !== releases.package2Id ||
    response.Branch !== branch ||
    response.Tag !== tag ||
    (values.resume && response.Id !== values.resume) ||
    (attempt.createRequestId && response.Id !== attempt.createRequestId)
  ) {
    throw new Error(
      "Salesforce creation response does not match the saved request, package, branch, and commit tag."
    );
  }
  attempt.createRequestId = response.Id;
  attempt.status = response.Status;
  fs.writeFileSync(attemptPath, `${JSON.stringify(attempt, null, 2)}\n`);
  fs.writeFileSync(
    `${attemptPath}.report.json`,
    `${JSON.stringify(response, null, 2)}\n`
  );
  if (response.Status === "Success") break;
  if (response.Status === "Error")
    throw new Error(
      `Package creation failed. Inspect ${attemptPath}.report.json; a new attempt needs a reviewed build number.`
    );
  if (
    ![
      "Queued",
      "InProgress",
      "Initializing",
      "VerifyingFeaturesAndSettings",
      "VerifyingDependencies",
      "VerifyingMetadata",
      "FinalizingPackageVersion",
      "PerformingValidations"
    ].includes(response.Status)
  ) {
    throw new Error(
      `Unknown package creation status: ${response.Status}. Inspect the saved request.`
    );
  }
  if (Date.now() >= deadline) {
    throw new Error(
      `Candidate still ${response.Status}. Resume without consuming quota: npm run package:create -- --dev-hub ${values["dev-hub"]} --release-ready --resume ${response.Id}`
    );
  }
  console.log(`Package request ${response.Id}: ${response.Status}`);
  await setTimeout(Math.min(30_000, deadline - Date.now()));
  response = runJson(
    "sf",
    [
      "package",
      "version",
      "create",
      "report",
      "--package-create-request-id",
      attempt.createRequestId,
      "--target-dev-hub",
      values["dev-hub"]
    ],
    { cwd: paths.packageRoot }
  ).result;
}

const createdVersion = packageVersionString(response);
if (
  createdVersion !== versionNumber ||
  !/^04t[0-9A-Za-z]{12}(?:[0-9A-Za-z]{3})?$/.test(
    response.SubscriberPackageVersionId
  ) ||
  response.HasPassedCodeCoverageCheck !== true
) {
  throw new Error(
    "Completed request does not have the exact candidate version, a valid 04t, and passing package code coverage."
  );
}
assertSourceUnchanged();
const evidencePath = path.join(
  evidenceDirectory,
  `${response.SubscriberPackageVersionId}-create.json`
);
const evidence = {
  ...attempt,
  subscriberPackageVersionId: response.SubscriberPackageVersionId,
  packageVersionId: response.Package2VersionId,
  version: createdVersion
};
const serialized = `${JSON.stringify(evidence, null, 2)}\n`;
if (fs.existsSync(evidencePath)) {
  if (fs.readFileSync(evidencePath, "utf8") !== serialized)
    throw new Error(
      "Existing creation evidence differs; preserve and review it."
    );
} else {
  fs.writeFileSync(evidencePath, serialized, { flag: "wx" });
}
console.log(
  `Candidate ${createdVersion} created: ${response.SubscriberPackageVersionId}`
);
console.log(`Creation evidence: ${evidencePath}`);
console.log(
  "Subscriber install and upgrade validation is recommended optional evidence; its scratch orgs require explicit owner authorization."
);
console.log(
  "Update config/package-releases.json only after owner-authorized promotion."
);
