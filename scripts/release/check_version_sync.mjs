#!/usr/bin/env node

import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "../..");
const packageJson = JSON.parse(
  readFileSync(resolve(root, "package.json"), "utf8")
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

if (!/^\d+\.\d+\.\d+$/.test(productVersion)) {
  failures.push(
    `package.json version must use major.minor.patch format; found "${productVersion}".`
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
