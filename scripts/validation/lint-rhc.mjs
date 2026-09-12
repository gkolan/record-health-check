#!/usr/bin/env node
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { spawnSync } from "node:child_process";

import { lintRhcSource } from "../lib/rhc-lint.mjs";

function argumentsByName(argv) {
  const values = new Map();
  for (let index = 0; index < argv.length; index += 2) {
    const name = argv[index];
    const value = argv[index + 1];
    if (!name?.startsWith("--") || value == null) {
      throw new Error("Options must be supplied as --name value pairs.");
    }
    values.set(name.slice(2), value);
  }
  return values;
}

function sarif(report) {
  return {
    version: "2.1.0",
    $schema: "https://json.schemastore.org/sarif-2.1.0.json",
    runs: [
      {
        tool: { driver: { name: "lint-rhc", version: report.version } },
        results: report.findings.map((finding) => ({
          ruleId: finding.ruleId,
          level: finding.severity === "ERROR" ? "error" : "warning",
          message: { text: finding.message },
          locations: [
            {
              physicalLocation: {
                artifactLocation: { uri: finding.path },
                region: finding.region
              }
            }
          ],
          properties: {
            configurationField: finding.configurationField,
            tokenStart: finding.tokenStart,
            tokenEnd: finding.tokenEnd
          }
        }))
      }
    ]
  };
}

function verifyExpected(report, expected) {
  const expectedKeys = new Set();
  for (const wanted of expected.findings || []) {
    const key = `${wanted.path}\0${wanted.ruleId}\0${wanted.configurationField}`;
    expectedKeys.add(key);
    const count = report.findings.filter(
      (finding) =>
        finding.path === wanted.path &&
        finding.ruleId === wanted.ruleId &&
        finding.configurationField === wanted.configurationField
    ).length;
    if (count !== wanted.count) {
      throw new Error(
        `Expected ${wanted.count} finding(s) for ${wanted.path} ${wanted.ruleId} ${wanted.configurationField}; found ${count}.`
      );
    }
  }
  const unexpected = report.findings.filter(
    (finding) =>
      finding.severity === "ERROR" &&
      !expectedKeys.has(
        `${finding.path}\0${finding.ruleId}\0${finding.configurationField}`
      )
  );
  if (unexpected.length > 0) {
    throw new Error(
      `Found ${unexpected.length} unexpected ERROR finding(s): ${unexpected
        .map((finding) => `${finding.path} ${finding.ruleId}`)
        .join(", ")}.`
    );
  }
}

async function main() {
  const options = argumentsByName(process.argv.slice(2));
  const source = options.get("source");
  const mode = options.get("mode");
  const format = options.get("format");
  const output = options.get("output");
  if (!source || !mode || !format || !output) {
    throw new Error("--source, --mode, --format, and --output are required.");
  }
  if (!new Set(["json", "sarif"]).has(format)) {
    throw new Error("--format must be json or sarif.");
  }
  if (mode === "org" && !options.get("target-org")) {
    throw new Error(
      "org mode requires --target-org; this command never creates an org."
    );
  }
  if (mode === "org") {
    const display = spawnSync(
      "sf",
      ["org", "display", "--target-org", options.get("target-org"), "--json"],
      { encoding: "utf8" }
    );
    if (display.status !== 0) {
      throw new Error(
        "The requested target org is not authenticated; lint-rhc never creates an org."
      );
    }
  }
  const report = await lintRhcSource({ source, mode });
  let expectedErrors = false;
  if (options.get("expect")) {
    verifyExpected(
      report,
      JSON.parse(await readFile(options.get("expect"), "utf8"))
    );
    expectedErrors = true;
  }
  await mkdir(path.dirname(path.resolve(output)), { recursive: true });
  await writeFile(
    output,
    `${JSON.stringify(format === "sarif" ? sarif(report) : report, null, 2)}\n`
  );
  if (
    !expectedErrors &&
    report.findings.some(({ severity }) => severity === "ERROR")
  ) {
    process.exitCode = 1;
  } else if (
    Object.values(report.capabilities).some((value) => value === "incomplete")
  ) {
    process.exitCode = 2;
  }
}

main().catch((error) => {
  process.stderr.write(`${error.message}\n`);
  process.exitCode = 2;
});
