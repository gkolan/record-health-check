#!/usr/bin/env node

import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { versionSyncErrors } from "../lib/version-sync.mjs";

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
const expectedVersionName = `Version ${productVersion}`;
const failures = versionSyncErrors({
  productVersion,
  packageLock,
  releaseRegistry,
  packageDirectory,
  frameworkVersion: lifecyclePublisher.match(
    /FRAMEWORK_VERSION\s*=\s*'([^']+)'/
  )?.[1]
});

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
