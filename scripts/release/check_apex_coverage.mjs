#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import { readdirSync, readFileSync } from "node:fs";
import { basename, resolve } from "node:path";

const argumentsList = process.argv.slice(2);
const listCoverage = argumentsList.includes("--list");
const helpRequested = argumentsList.includes("--help");
const optionValue = (name, fallback) => {
  const index = argumentsList.indexOf(name);
  return index >= 0 ? argumentsList[index + 1] : fallback;
};
const optionsWithValues = new Set(["--source-dir", "--threshold"]);
const positionalArguments = argumentsList.filter((argument, index) => {
  if (argument.startsWith("--")) {
    return false;
  }
  return index === 0 || !optionsWithValues.has(argumentsList[index - 1]);
});
const targetOrg = positionalArguments[0] || process.env.SF_TARGET_ORG;
const threshold = Number(optionValue("--threshold", "98"));
const sourceDirectory = optionValue(
  "--source-dir",
  "packages/record-health-check/force-app/main/default/classes"
);
if (helpRequested) {
  console.log(
    "Usage: node scripts/release/check_apex_coverage.mjs <target-org> [--source-dir <classes-dir>] [--threshold <percent>] [--list]"
  );
  console.log(
    "Checks every executable production Apex class and optionally prints the complete class-by-class result."
  );
  process.exit(0);
}
if (!targetOrg) {
  console.error(
    "Usage: node scripts/release/check_apex_coverage.mjs <target-org> [--source-dir <classes-dir>] [--threshold <percent>] [--list]"
  );
  process.exit(2);
}
if (!Number.isFinite(threshold) || threshold < 0 || threshold > 100) {
  console.error("--threshold must be a number from 0 through 100.");
  process.exit(2);
}

const classesDirectory = resolve(sourceDirectory);
const productionClasses = readdirSync(classesDirectory)
  .filter((name) => name.endsWith(".cls"))
  .filter((name) => {
    const body = readFileSync(resolve(classesDirectory, name), "utf8");
    return !/@isTest\b|\btestMethod\b/i.test(body);
  })
  .map((name) => basename(name, ".cls"))
  .sort();
const interfaces = new Set(
  productionClasses.filter((className) => {
    const body = readFileSync(
      resolve(classesDirectory, `${className}.cls`),
      "utf8"
    );
    return new RegExp(`\\binterface\\s+${className}\\b`).test(body);
  })
);

const query =
  "SELECT ApexClassOrTrigger.Name, NumLinesCovered, NumLinesUncovered " +
  "FROM ApexCodeCoverageAggregate ORDER BY ApexClassOrTrigger.Name";
const raw = execFileSync(
  "sf",
  [
    "data",
    "query",
    "--target-org",
    targetOrg,
    "--use-tooling-api",
    "--query",
    query,
    "--json"
  ],
  { encoding: "utf8", env: process.env }
);
const payload = JSON.parse(raw);
if (payload.status !== 0) {
  console.error(payload.message || "Salesforce coverage query failed.");
  process.exit(2);
}

const coverageByName = new Map(
  payload.result.records.map((record) => [
    record.ApexClassOrTrigger.Name,
    record
  ])
);
const failures = [];
const notApplicable = [];
const coverageRows = [];
let aggregateCovered = 0;
let aggregateExecutable = 0;
for (const className of productionClasses) {
  const coverage = coverageByName.get(className);
  if (!coverage) {
    if (interfaces.has(className)) {
      notApplicable.push(className);
      coverageRows.push(`${className}\tN/A\t0/0`);
      continue;
    }
    failures.push(`${className}: missing coverage result`);
    continue;
  }
  const covered = coverage.NumLinesCovered;
  const uncovered = coverage.NumLinesUncovered;
  const total = covered + uncovered;
  if (total === 0) {
    notApplicable.push(className);
    coverageRows.push(`${className}\tN/A\t0/0`);
    continue;
  }
  const percent = (covered * 100) / total;
  aggregateCovered += covered;
  aggregateExecutable += total;
  coverageRows.push(
    `${className}\t${percent.toFixed(2)}%\t${covered}/${total}`
  );
  if (percent <= threshold) {
    failures.push(
      `${className}: ${percent.toFixed(2)}% (${covered}/${total}, ${uncovered} uncovered)`
    );
  }
}

console.log(
  `Checked ${productionClasses.length} production Apex classes; ${notApplicable.length} N/A (0 executable lines).`
);
const aggregatePercent =
  aggregateExecutable === 0
    ? 100
    : (aggregateCovered * 100) / aggregateExecutable;
console.log(
  `Framework Apex coverage: ${aggregatePercent.toFixed(2)}% (${aggregateCovered}/${aggregateExecutable} executable lines).`
);
if (notApplicable.length > 0) {
  console.log(`N/A: ${notApplicable.join(", ")}`);
}
if (listCoverage) {
  console.log("Class\tCoverage\tCovered/Executable");
  console.log(coverageRows.join("\n"));
}
if (failures.length > 0) {
  console.error(
    `Apex classes must be above ${threshold}%:\n${failures.join("\n")}`
  );
  process.exit(1);
}
console.log(`Every executable production Apex class is above ${threshold}%.`);
