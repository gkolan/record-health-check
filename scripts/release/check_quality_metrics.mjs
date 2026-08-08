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

const apexPercent = fixed(metrics.apex.coveragePercent);
const lwcLines = fixed(metrics.lwc.linesPercent);
for (const text of [
  `Apex_coverage-${apexPercent}%25-brightgreen`,
  `LWC_lines-${lwcLines}%25-brightgreen`,
  `${apexPercent}% test coverage for packaged Apex`,
  `${lwcLines}% line coverage`
]) {
  if (!readme.includes(text)) {
    fail(`README quality metric is missing or stale: ${text}`);
  }
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
  if (fixed(current) !== apexPercent) {
    fail(
      `Apex coverage changed in ${apexOrg}: recorded ${apexPercent}%, current ${fixed(current)}% (${covered}/${executable}). Update config/quality-metrics.json and README.md.`
    );
  }
}

if (!process.exitCode) {
  console.log(
    `Quality metrics match: Apex ${apexPercent}%; LWC ${lwcLines}% lines, ${fixed(metrics.lwc.statementsPercent)}% statements, ${fixed(metrics.lwc.functionsPercent)}% functions, ${fixed(metrics.lwc.branchesPercent)}% branches.`
  );
}
