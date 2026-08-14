#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { parseArgs } from "node:util";
import { paths } from "../lib/paths.mjs";
import { run, tryRun } from "../lib/run.mjs";

const { values } = parseArgs({
  options: {
    alias: { type: "string", default: process.env.RHC_DEV_ALIAS ?? "rhc-dev" },
    deploy: { type: "boolean", default: false },
    "combined-features": { type: "boolean", default: false },
    full: { type: "boolean", default: false }
  }
});

const sf = (...args) => run("sf", args, { cwd: paths.packageRoot });
const suiteXml = fs.readFileSync(
  path.join(
    paths.integrationTests,
    "main/default/testSuites/RHC_Negative_Conformance.testSuite-meta.xml"
  ),
  "utf8"
);
const negativeClasses = [...suiteXml.matchAll(/<testClassName>([^<]+)<\/testClassName>/g)].map(
  (match) => match[1]
);
const integrationMetadataDirectories = fs
  .readdirSync(path.join(paths.integrationTests, "main/default"), {
    withFileTypes: true
  })
  .filter((entry) => entry.isDirectory() && entry.name !== "testSuites")
  .map((entry) => `integration-tests/main/default/${entry.name}`);

console.log(`Record Health Check war room: ${values.alias}`);

if (values.deploy) {
  sf(
    "project",
    "deploy",
    "start",
    "--source-dir",
    "force-app",
    "--target-org",
    values.alias,
    "--wait",
    "30"
  );
  sf(
    "project",
    "deploy",
    "start",
    ...integrationMetadataDirectories.flatMap((directory) => [
      "--source-dir",
      directory
    ]),
    "--target-org",
    values.alias,
    "--wait",
    "30"
  );
}

const permissionAssignment = tryRun(
  "sf",
  [
    "org",
    "assign",
    "permset",
    "--name",
    "Record_Health_Check_Admin",
    "--target-org",
    values.alias
  ],
  { cwd: paths.packageRoot }
);
if (permissionAssignment.status !== 0) {
  const assignmentOutput = `${permissionAssignment.stdout ?? ""}${
    permissionAssignment.stderr ?? ""
  }`;
  if (!assignmentOutput.includes("Duplicate PermissionSetAssignment")) {
    process.stderr.write(assignmentOutput);
    process.exit(permissionAssignment.status ?? 1);
  }
  console.log("Record_Health_Check_Admin is already assigned; continuing.");
}

sf(
  "apex",
  "run",
  "--file",
  "integration-tests/scripts/setup-negative-scenarios.apex",
  "--target-org",
  values.alias
);
sf(
  "apex",
  "run",
  "test",
  ...negativeClasses.flatMap((className) => ["--class-names", className]),
  "--target-org",
  values.alias,
  "--wait",
  "30",
  "--result-format",
  "human"
);
sf(
  "apex",
  "run",
  "--file",
  "integration-tests/scripts/verify-negative-scenarios.apex",
  "--target-org",
  values.alias
);

if (values["combined-features"]) {
  sf(
    "apex",
    "run",
    "--file",
    "integration-tests/scripts/setup-pa-multicurrency-scenarios.apex",
    "--target-org",
    values.alias
  );
  sf(
    "apex",
    "run",
    "test",
    "--class-names",
    "RHCPersonAccountFactoryTest",
    "--class-names",
    "RHCMixedCurrencyRedTest",
    "--class-names",
    "RHCCurrencyAuthoringRedTest",
    "--target-org",
    values.alias,
    "--wait",
    "30",
    "--result-format",
    "human"
  );
}

if (values.full) {
  sf(
    "apex",
    "run",
    "test",
    "--test-level",
    "RunLocalTests",
    "--code-coverage",
    "--target-org",
    values.alias,
    "--wait",
    "30",
    "--result-format",
    "human"
  );
}

console.log(`War-room scenarios passed in ${values.alias}.`);
