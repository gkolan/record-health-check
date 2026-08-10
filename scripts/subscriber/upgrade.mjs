#!/usr/bin/env node

import { parseArgs } from "node:util";
import {
  namespacedPermissionSet,
  readPackageReleases,
  stablePackageVersionId
} from "../lib/package-releases.mjs";
import { run, tryRun } from "../lib/run.mjs";

const { values } = parseArgs({
  options: {
    alias: { type: "string", default: process.env.RHC_ORG_ALIAS ?? "rhc-demo" },
    package: { type: "string" }
  }
});

const releases = readPackageReleases();
const packageVersionId = values.package ?? stablePackageVersionId(releases);
const adminPermset = namespacedPermissionSet(
  releases.permissionSets.admin,
  releases
);

run("sf", [
  "package",
  "install",
  "--package",
  packageVersionId,
  "--target-org",
  values.alias,
  "--upgrade-type",
  "DeprecateOnly",
  "--publish-wait",
  "10",
  "--wait",
  "30",
  "--no-prompt"
]);

// An upgrade almost always targets an org where the permission set is already
// assigned from the original install. `sf org assign permset` treats that as an
// error, so tolerate the duplicate and fail on anything else.
const assignment = tryRun("sf", [
  "org",
  "assign",
  "permset",
  "--name",
  adminPermset,
  "--target-org",
  values.alias
]);
if (assignment.status !== 0) {
  const output = `${assignment.stdout ?? ""}${assignment.stderr ?? ""}`;
  if (!output.includes("Duplicate PermissionSetAssignment")) {
    process.stderr.write(output);
    process.exit(assignment.status ?? 1);
  }
  console.log(`${adminPermset} is already assigned; continuing.`);
}

run("sf", [
  "apex",
  "run",
  "test",
  "--class-names",
  "RHCSubscriberSmokeTest",
  "--target-org",
  values.alias,
  "--result-format",
  "human",
  "--wait",
  "30"
]);

console.log(
  `Upgraded ${values.alias} to ${packageVersionId} with DeprecateOnly and reran subscriber smoke tests.`
);
