#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import { createRequire } from "node:module";
import { readFileSync, readdirSync } from "node:fs";
import { basename, resolve } from "node:path";

const require = createRequire(import.meta.url);
const { createCoverageMap } = require("istanbul-lib-coverage");
const root = resolve(import.meta.dirname, "../..");
const metrics = JSON.parse(
  readFileSync(resolve(root, "config/quality-metrics.json"), "utf8")
);
const releases = JSON.parse(
  readFileSync(resolve(root, "config/package-releases.json"), "utf8")
);
const packageJson = JSON.parse(
  readFileSync(resolve(root, "package.json"), "utf8")
);
const readme = readFileSync(resolve(root, "README.md"), "utf8");
const argumentsList = process.argv.slice(2);
const apexOrgIndex = argumentsList.indexOf("--apex-org");
const apexOrg = apexOrgIndex >= 0 ? argumentsList[apexOrgIndex + 1] : "";

function fail(message) {
  console.error(message);
  process.exitCode = 1;
}

function fixed(value) {
  return Number(value).toFixed(2);
}

const apexPercent = fixed(metrics.apex.sourceCoveragePercent);
const packagePercent = fixed(metrics.apex.packageCoveragePercent);
const lwcLines = fixed(metrics.lwc.linesPercent);
const sourceVersion = metrics.apex.packageVersion
  .split(".")
  .slice(0, 3)
  .join(".");
for (const text of [
  `Apex_coverage-${apexPercent}%25-brightgreen`,
  `LWC_lines-${lwcLines}%25-brightgreen`,
  `${apexPercent}% coverage from the complete namespaced ${sourceVersion} source test run`,
  `Salesforce-validated ${metrics.apex.packageVersion} package coverage: ${Number(packagePercent)}%`,
  `${lwcLines}% line coverage`
]) {
  if (!readme.includes(text)) {
    fail(`README quality metric is missing or stale: ${text}`);
  }
}

if (sourceVersion !== packageJson.version) {
  fail(
    `Apex statistics describe ${sourceVersion}; package.json is ${packageJson.version}.`
  );
}
if (metrics.apex.packageVersion !== releases.stable.version) {
  fail(
    `Apex package statistics name ${metrics.apex.packageVersion}; stable is ${releases.stable.version}.`
  );
}
if (
  metrics.apex.subscriberPackageVersionId !==
  releases.stable.subscriberPackageVersionId
) {
  fail(
    "Apex package statistics do not identify the current stable Salesforce package version."
  );
}
if (metrics.apex.evidenceOrgShape !== "namespaced") {
  fail("Published Apex coverage must come from the namespaced release source.");
}
if (
  metrics.apex.salesforceTestCount !==
  metrics.apex.testMethodCount + metrics.apex.testSetupMethodCount
) {
  fail(
    "Salesforce Apex test count must equal test methods plus test setup methods."
  );
}
const calculatedApexPercent =
  (metrics.apex.coveredLines * 100) / metrics.apex.executableLines;
if (fixed(calculatedApexPercent) !== apexPercent) {
  fail(
    `Recorded Apex coverage ${apexPercent}% does not match ${metrics.apex.coveredLines}/${metrics.apex.executableLines}.`
  );
}
if (!/^707[A-Za-z0-9]{12,15}$/.test(metrics.apex.testRunId)) {
  fail("Apex statistics must identify the exact Salesforce test run.");
}

const coverageFile = resolve(
  root,
  "packages/record-health-check/coverage/coverage-final.json"
);
try {
  const coverageMap = createCoverageMap(
    JSON.parse(readFileSync(coverageFile, "utf8"))
  );
  const summary = coverageMap.getCoverageSummary().toJSON();
  for (const [name, expected] of [
    ["lines", metrics.lwc.linesPercent],
    ["statements", metrics.lwc.statementsPercent],
    ["functions", metrics.lwc.functionsPercent],
    ["branches", metrics.lwc.branchesPercent]
  ]) {
    if (fixed(summary[name].pct) !== fixed(expected)) {
      fail(
        `LWC ${name} coverage changed: recorded ${fixed(expected)}%, current ${fixed(summary[name].pct)}%. Update config/quality-metrics.json and README.md.`
      );
    }
  }
} catch (error) {
  if (error?.code === "ENOENT") {
    fail("Run npm run test:unit:coverage before check:quality-metrics.");
  } else {
    throw error;
  }
}

if (apexOrg) {
  const classesDirectory = resolve(
    root,
    "packages/record-health-check/force-app/main/default/classes"
  );
  const productionClasses = new Set(
    readdirSync(classesDirectory)
      .filter((name) => name.endsWith(".cls"))
      .filter((name) => {
        const body = readFileSync(resolve(classesDirectory, name), "utf8");
        return !/@isTest\b|\btestMethod\b/i.test(body);
      })
      .map((name) => basename(name, ".cls"))
  );
  const payload = JSON.parse(
    execFileSync(
      "sf",
      [
        "data",
        "query",
        "--target-org",
        apexOrg,
        "--use-tooling-api",
        "--query",
        "SELECT ApexClassOrTrigger.Name, NumLinesCovered, NumLinesUncovered FROM ApexCodeCoverageAggregate",
        "--json"
      ],
      { encoding: "utf8", env: process.env }
    )
  );
  let covered = 0;
  let executable = 0;
  for (const record of payload.result?.records ?? []) {
    if (!productionClasses.has(record.ApexClassOrTrigger.Name)) continue;
    covered += record.NumLinesCovered;
    executable += record.NumLinesCovered + record.NumLinesUncovered;
  }
  const current = executable === 0 ? 0 : (covered * 100) / executable;
  if (
    Number(fixed(current)) !== Number(apexPercent) ||
    covered !== metrics.apex.coveredLines ||
    executable !== metrics.apex.executableLines
  ) {
    fail(
      `Apex coverage in ${apexOrg} is ${fixed(current)}% (${covered}/${executable}); recorded 2.0.8 evidence is ${apexPercent}% (${metrics.apex.coveredLines}/${metrics.apex.executableLines}). Rerun the complete inventory and publish one matching result.`
    );
  }
}

if (!process.exitCode) {
  console.log(
    `Quality metrics match 2.0.8 evidence: Apex ${apexPercent}% (${metrics.apex.coveredLines}/${metrics.apex.executableLines}), promoted package ${Number(packagePercent)}%, and LWC ${lwcLines}% lines, ${fixed(metrics.lwc.statementsPercent)}% statements, ${fixed(metrics.lwc.functionsPercent)}% functions, ${fixed(metrics.lwc.branchesPercent)}% branches.`
  );
}
