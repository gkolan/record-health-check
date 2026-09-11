import assert from "node:assert/strict";
import { mkdtemp, mkdir, readFile, symlink, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";

import { lintRhcSource } from "./rhc-lint.mjs";

const metadata = (field, value) => `<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata">
  <label>Draft</label>
  <protected>false</protected>
  <values>
    <field>${field}</field>
    <value>${value}</value>
  </values>
</CustomMetadata>`;

async function fixture(name, field, value) {
  const root = await mkdtemp(path.join(os.tmpdir(), "rhc-lint-"));
  const source = path.join(root, "source");
  await mkdir(source);
  await writeFile(path.join(source, name), metadata(field, value));
  return source;
}

test("reports a formula literal at its original XML location", async () => {
  const source = await fixture(
    "literal.md-meta.xml",
    "ApplicabilityFormula__c",
    "ISPICKVAL(Industry, &apos;Banking&apos;)"
  );
  const report = await lintRhcSource({ source, mode: "offline" });
  const finding = report.findings.find(({ ruleId }) => ruleId === "RHC001");
  assert.equal(finding.configurationField, "ApplicabilityFormula__c");
  assert.deepEqual(finding.region, {
    startLine: 7,
    startColumn: 12,
    endLine: 7,
    endColumn: 52
  });
});

test("reports every deterministic offline rule in stable order", async () => {
  const root = await mkdtemp(path.join(os.tmpdir(), "rhc-lint-"));
  const source = path.join(root, "source");
  await mkdir(source);
  const cases = [
    ["blank.md-meta.xml", "DisplayFoundFormula__c", "&quot;&quot;", "RHC012"],
    ["class.md-meta.xml", "ApexClass__c", "NoSuchPlugin", "RHC006"],
    [
      "comparison.md-meta.xml",
      "ComparisonOperator__c",
      "NOT_AN_OPERATOR",
      "RHC011"
    ],
    [
      "function.md-meta.xml",
      "PassConditionFormula__c",
      "ISCHANGED(Website)",
      "RHC002"
    ],
    ["merge.md-meta.xml", "FailureMessage__c", "Review {!record.Id", "RHC005"],
    [
      "parameters.md-meta.xml",
      "ApexParametersJson__c",
      "{&quot;maxPreviewRecords&quot;:&quot;5&quot;}",
      "RHC008"
    ],
    [
      "unresolved.md-meta.xml",
      "ApplicabilityFormula__c",
      "NoSuchField__c = 1",
      "RHC003"
    ],
    [
      "inaccessible.md-meta.xml",
      "ApplicabilityFormula__c",
      "AnnualRevenue >= 0",
      "RHC004"
    ],
    ["interface.md-meta.xml", "ApexClass__c", "WrongInterfacePlugin", "RHC007"]
  ];
  for (const [name, field, value] of cases) {
    const contents =
      name === "parameters.md-meta.xml"
        ? metadata("ApexClass__c", "ParameterPlugin").replace(
            "</CustomMetadata>",
            `${metadata(field, value).match(/<values>[\s\S]*<\/values>/)[0]}\n</CustomMetadata>`
          )
        : metadata(field, value);
    await writeFile(path.join(source, name), contents);
  }
  const report = await lintRhcSource({
    source,
    mode: "offline",
    capabilities: {
      apexClasses: new Map([
        ["NoSuchPlugin", "missing"],
        ["WrongInterfacePlugin", "incompatible"]
      ]),
      fields: new Map([["AnnualRevenue", "inaccessible"]]),
      parameterSchemas: new Map([
        ["ParameterPlugin", { maxPreviewRecords: "NUMBER" }]
      ])
    }
  });
  assert.deepEqual(
    report.findings.map(({ ruleId }) => ruleId).sort(),
    cases.map((entry) => entry[3]).sort()
  );
  assert.equal(report.mode, "offline");
  assert.equal(report.version, "1.0");
});

test("reports inactive prerequisites and every participant in a cycle", async () => {
  const root = await mkdtemp(path.join(os.tmpdir(), "rhc-lint-"));
  const source = path.join(root, "source");
  await mkdir(source);
  await writeFile(
    path.join(source, "Record_Health_Check.Inactive.md-meta.xml"),
    metadata("IsActive__c", "false")
  );
  await writeFile(
    path.join(source, "Record_Health_Check.UsesInactive.md-meta.xml"),
    metadata("PrerequisiteCheck__c", "Inactive")
  );
  await writeFile(
    path.join(source, "Record_Health_Check.Cycle_A.md-meta.xml"),
    metadata("PrerequisiteCheck__c", "Cycle_B")
  );
  await writeFile(
    path.join(source, "Record_Health_Check.Cycle_B.md-meta.xml"),
    metadata("PrerequisiteCheck__c", "Cycle_A")
  );

  const report = await lintRhcSource({ source, mode: "offline" });
  assert.deepEqual(
    report.findings.map(({ ruleId }) => ruleId),
    ["RHC010", "RHC010", "RHC009"]
  );
});

test("the checked-in corpus covers all twelve rules with exact expected counts", async () => {
  const source = path.resolve("tests/fixtures/rhc-lint");
  const expected = JSON.parse(
    await readFile(path.join(source, "expected-findings.json"), "utf8")
  );
  const report = await lintRhcSource({
    source,
    mode: "offline",
    capabilities: {
      apexClasses: new Map([
        ["NoSuchPlugin", "missing"],
        ["WrongInterfacePlugin", "incompatible"]
      ]),
      fields: new Map([["AnnualRevenue", "inaccessible"]]),
      parameterSchemas: new Map([
        ["ParameterPlugin", { maxPreviewRecords: "NUMBER" }]
      ])
    }
  });
  for (const wanted of expected.findings) {
    assert.equal(
      report.findings.filter(
        (finding) =>
          finding.path === wanted.path &&
          finding.ruleId === wanted.ruleId &&
          finding.configurationField === wanted.configurationField
      ).length,
      wanted.count,
      `${wanted.path} must retain its expected ${wanted.ruleId} finding`
    );
  }
  assert.deepEqual(
    [...new Set(report.findings.map(({ ruleId }) => ruleId))].sort(),
    Array.from(
      { length: 12 },
      (_, index) => `RHC${String(index + 1).padStart(3, "0")}`
    )
  );
  const cdata = report.findings.find(
    (finding) => finding.path === "literal-cdata.md-meta.xml"
  );
  assert.deepEqual(cdata.region, {
    startLine: 7,
    startColumn: 21,
    endLine: 10,
    endColumn: 6
  });
});

test("rejects a source path that escapes through a symlink", async () => {
  const root = await mkdtemp(path.join(os.tmpdir(), "rhc-lint-"));
  const source = path.join(root, "source");
  const outside = path.join(root, "outside");
  await mkdir(source);
  await mkdir(outside);
  await writeFile(
    path.join(outside, "escape.md-meta.xml"),
    metadata("FailureMessage__c", "safe")
  );
  await symlink(outside, path.join(source, "escaped"));
  await assert.rejects(
    lintRhcSource({ source, mode: "offline" }),
    /escapes source directory/
  );
});

test("CLI writes JSON and distinguishes findings from incomplete clean analysis", async () => {
  const root = await mkdtemp(path.join(os.tmpdir(), "rhc-lint-cli-"));
  const invalid = path.join(root, "invalid");
  const clean = path.join(root, "clean");
  await mkdir(invalid);
  await mkdir(clean);
  await writeFile(
    path.join(invalid, "invalid.md-meta.xml"),
    metadata("ComparisonOperator__c", "NOT_AN_OPERATOR")
  );
  await writeFile(
    path.join(clean, "clean.md-meta.xml"),
    metadata("ComparisonOperator__c", "EQUALS")
  );
  const command = path.resolve("scripts/validation/lint-rhc.mjs");
  const invalidOutput = path.join(root, "invalid.json");
  const invalidRun = spawnSync(
    process.execPath,
    [
      command,
      "--source",
      invalid,
      "--mode",
      "offline",
      "--format",
      "json",
      "--output",
      invalidOutput
    ],
    { encoding: "utf8" }
  );
  assert.equal(invalidRun.status, 1);
  assert.equal(
    JSON.parse(await readFile(invalidOutput, "utf8")).findings[0].ruleId,
    "RHC011"
  );

  const cleanOutput = path.join(root, "clean.sarif");
  const cleanRun = spawnSync(
    process.execPath,
    [
      command,
      "--source",
      clean,
      "--mode",
      "offline",
      "--format",
      "sarif",
      "--output",
      cleanOutput
    ],
    { encoding: "utf8" }
  );
  assert.equal(cleanRun.status, 2);
  assert.equal(
    JSON.parse(await readFile(cleanOutput, "utf8")).version,
    "2.1.0"
  );
});

test("CLI refuses org mode without an explicit existing target", () => {
  const run = spawnSync(
    process.execPath,
    [
      path.resolve("scripts/validation/lint-rhc.mjs"),
      "--source",
      path.resolve("tests/fixtures/rhc-lint"),
      "--mode",
      "org",
      "--format",
      "json",
      "--output",
      path.join(os.tmpdir(), "rhc-lint-org.json")
    ],
    { encoding: "utf8" }
  );
  assert.equal(run.status, 2);
  assert.match(run.stderr, /requires --target-org/);
});
