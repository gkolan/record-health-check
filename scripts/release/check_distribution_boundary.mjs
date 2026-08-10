#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { paths } from "../lib/paths.mjs";
import { readPackageReleases } from "../lib/package-releases.mjs";

const failures = [];

function read(filePath) {
  return fs.readFileSync(filePath, "utf8");
}

function fail(message) {
  failures.push(message);
}

function includes(relativePath, pattern, message) {
  const filePath = path.join(paths.repoRoot, relativePath);
  if (!fs.existsSync(filePath)) {
    fail(`${relativePath}: missing file (${message})`);
    return;
  }
  const contents = read(filePath);
  if (
    pattern instanceof RegExp
      ? pattern.test(contents)
      : contents.includes(pattern)
  ) {
    fail(`${relativePath}: ${message}`);
  }
}

const rootProject = JSON.parse(read("sfdx-project.json"));
if (rootProject.namespace) {
  fail("sfdx-project.json: root namespace must be empty for subscriber mode");
}
for (const directory of rootProject.packageDirectories ?? []) {
  if (
    directory.path === "force-app" ||
    directory.path?.includes("integration-tests")
  ) {
    fail(
      `sfdx-project.json: root packageDirectories must not include ${directory.path}`
    );
  }
}

includes(
  "README.md",
  /githubsfdeploy/i,
  "README must not link to GitHubSFDeploy"
);
includes(
  "docs/installation/install-and-verify.md",
  /sf project deploy start/i,
  "installation guide must not document source deploy"
);
includes(
  "docs/installation/install-and-verify.md",
  /Option B/i,
  "installation guide must not expose Option B source deploy"
);
includes(
  "docs/installation/upgrading.md",
  /Option B/i,
  "upgrade guide must not expose Option B source deploy"
);
includes(
  "docs/installation/upgrading.md",
  /sf project deploy start/i,
  "upgrade guide must not document source deploy"
);
includes(
  "docs/installation/README.md",
  /source-deploy|Option B/i,
  "installation index must not document source deploy"
);

const setupScript = read("scripts/subscriber/setup.mjs");
for (const forbidden of [
  "force-app",
  "packages/record-health-check/force-app",
  "manifest/package.xml",
  "githubsfdeploy",
  "RunAllTestsInOrg",
  "RecordHealthCheckTestDataFactory"
]) {
  if (setupScript.includes(forbidden)) {
    fail(`scripts/subscriber/setup.mjs: must not reference ${forbidden}`);
  }
}

const packageJson = JSON.parse(read("package.json"));
// `setup` must invoke the subscriber script directly rather than delegating via
// `npm run subscriber:setup`: npm consumes flags across a nested `npm run`, so
// `npm run setup -- --dev-hub my-hub` would reach the script as just `my-hub`.
const subscriberSetupCommand = "node scripts/subscriber/setup.mjs";
if (packageJson.scripts?.setup !== subscriberSetupCommand) {
  fail(`package.json: scripts.setup must be '${subscriberSetupCommand}'`);
}
if (packageJson.scripts?.["subscriber:setup"] !== subscriberSetupCommand) {
  fail(
    `package.json: scripts.subscriber:setup must be '${subscriberSetupCommand}'`
  );
}

const releases = readPackageReleases();
const stableVersionId = releases.stable.subscriberPackageVersionId;
if (!stableVersionId.startsWith("04t")) {
  fail(
    "config/package-releases.json: stable subscriberPackageVersionId must start with 04t"
  );
}

// The one-click install buttons hard-code the promoted 04t. Keep every published
// install link pinned to the current stable release so a promote cannot leave the
// README pointing subscribers at a superseded package version.
for (const relativePath of [
  "README.md",
  "docs/installation/install-and-verify.md"
]) {
  const contents = read(path.join(paths.repoRoot, relativePath));
  const linked = new Set(contents.match(/04t[A-Za-z0-9]{12,15}/g) ?? []);
  if (!linked.size) {
    fail(
      `${relativePath}: must publish an install link for ${stableVersionId}`
    );
    continue;
  }
  for (const id of linked) {
    if (id !== stableVersionId) {
      fail(
        `${relativePath}: install link points at ${id}; stable release is ${stableVersionId}`
      );
    }
  }
  for (const host of ["login.salesforce.com", "test.salesforce.com"]) {
    if (
      !contents.includes(
        `https://${host}/packaging/installPackage.apexp?p0=${stableVersionId}`
      )
    ) {
      fail(
        `${relativePath}: missing ${host} install link for ${stableVersionId}`
      );
    }
  }
}

const subscriberClassesDir = path.join(
  paths.subscriberApp,
  "main/default/classes"
);
if (fs.existsSync(subscriberClassesDir)) {
  for (const fileName of fs.readdirSync(subscriberClassesDir)) {
    if (!fileName.endsWith(".cls")) continue;
    const source = read(path.join(subscriberClassesDir, fileName));
    if (source.includes("RecordHealthCheckTestDataFactory")) {
      fail(
        `${fileName}: subscriber harness must not reference internal test factory`
      );
    }
  }
}

if (read("scripts/setup-demo.sh").includes("--source-dir force-app")) {
  fail(
    "scripts/setup-demo.sh: legacy demo script still deploys force-app; use npm run setup"
  );
}

if (failures.length) {
  console.error(failures.join("\n"));
  process.exit(1);
}

console.log(
  "Distribution boundary checks passed: subscriber mode is the default workflow."
);
