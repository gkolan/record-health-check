#!/usr/bin/env node

import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "../..");
const packageJson = JSON.parse(
  readFileSync(resolve(root, "package.json"), "utf8")
);
const packageLock = JSON.parse(
  readFileSync(resolve(root, "package-lock.json"), "utf8")
);
const releaseRegistry = JSON.parse(
  readFileSync(resolve(root, "config/package-releases.json"), "utf8")
);
const packagingProject = JSON.parse(
  readFileSync(
    resolve(root, "packages/record-health-check/sfdx-project.json"),
    "utf8"
  )
);
const packageDirectory = packagingProject.packageDirectories.find(
  (entry) => entry.default === true
);
const lifecyclePublisher = readFileSync(
  resolve(
    root,
    "packages/record-health-check/force-app/main/default/classes/RecordHealthCheckLifecyclePublisher.cls"
  ),
  "utf8"
);

if (!packageDirectory) {
  console.error(
    "packages/record-health-check/sfdx-project.json must have one default package directory."
  );
  process.exit(1);
}

const productVersion = packageJson.version;
const expectedVersionNumber = `${productVersion}.NEXT`;
const expectedVersionName = `Version ${productVersion}`;
const failures = [];
const compareVersions = (left, right) => {
  const leftParts = left.split(".").map(Number);
  const rightParts = right.split(".").map(Number);
  for (let index = 0; index < 3; index += 1) {
    if (leftParts[index] !== rightParts[index]) {
      return leftParts[index] - rightParts[index];
    }
  }
  return 0;
};

if (!/^\d+\.\d+\.\d+$/.test(productVersion)) {
  failures.push(
    `package.json version must use major.minor.patch format; found "${productVersion}".`
  );
}
if (packageLock.version !== productVersion) {
  failures.push(
    `package-lock.json version must be "${productVersion}"; found "${packageLock.version}".`
  );
}
if (packageLock.packages?.[""]?.version !== productVersion) {
  failures.push(
    `package-lock.json root package version must be "${productVersion}"; found "${packageLock.packages?.[""]?.version}".`
  );
}
const releasedVersions = [
  releaseRegistry.stable?.version,
  releaseRegistry.previous?.version,
  releaseRegistry.candidate?.status === "released"
    ? releaseRegistry.candidate.version
    : null,
]
  .filter(Boolean)
  .map((version) => version.split(".").slice(0, 3).join("."));
const latestReleasedVersion = releasedVersions.sort(compareVersions).at(-1);
if (
  latestReleasedVersion &&
  /^\d+\.\d+\.\d+$/.test(productVersion) &&
  compareVersions(productVersion, latestReleasedVersion) <= 0
) {
  failures.push(
    `development version ${productVersion} must be newer than released version ${latestReleasedVersion}.`
  );
}
if (packageDirectory.versionNumber !== expectedVersionNumber) {
  failures.push(
    `versionNumber must be "${expectedVersionNumber}"; found "${packageDirectory.versionNumber}".`
  );
}
if (packageDirectory.versionName !== expectedVersionName) {
  failures.push(
    `versionName must be "${expectedVersionName}"; found "${packageDirectory.versionName}".`
  );
}
const frameworkVersionMatch = lifecyclePublisher.match(
  /FRAMEWORK_VERSION\s*=\s*'([^']+)'/
);
if (frameworkVersionMatch?.[1] !== productVersion) {
  failures.push(
    `RecordHealthCheckLifecyclePublisher.FRAMEWORK_VERSION must be "${productVersion}"; found "${frameworkVersionMatch?.[1] ?? "missing"}".`
  );
}

if (failures.length > 0) {
  console.error(
    "Package version metadata is out of sync. Update package.json and the default package directory together:"
  );
  console.error(failures.map((failure) => `- ${failure}`).join("\n"));
  process.exit(1);
}

console.log(
  `Package version metadata is synchronized at ${productVersion} (${expectedVersionName}).`
);
