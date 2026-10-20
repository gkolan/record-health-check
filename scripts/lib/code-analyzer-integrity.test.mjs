import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { analyzerIntegrityErrors } from "./code-analyzer-integrity.mjs";

function fixture() {
  const root = fs.mkdtempSync(
    path.join(os.tmpdir(), "rhc-analyzer-integrity-")
  );
  const logs = path.join(root, "logs");
  const output = path.join(root, "results.json");
  fs.mkdirSync(logs);
  fs.writeFileSync(path.join(logs, "scan.log"), "scan complete\n");
  fs.writeFileSync(
    output,
    JSON.stringify({ versions: {}, violationCounts: {}, violations: [] })
  );
  return { logs, output };
}

test("accepts complete reports with clean engine logs", () => {
  const { logs, output } = fixture();
  fs.writeFileSync(
    path.join(logs, "scan.log"),
    "[INFO] Engine pmd finished with 0 violations and 0 errors\n"
  );
  assert.deepEqual(analyzerIntegrityErrors(logs, [output]), []);
});

test("rejects each scanner false-green engine signature on its own", () => {
  for (const line of [
    "[2026-10-19T12:00:00Z] Error pmd - could not parse Foo.cls",
    "PMD issued a processing error for Foo.cls",
    "java.lang.NullPointerException at net.sourceforge.pmd",
    "Engine sfge emitted an error while building the graph"
  ]) {
    const { logs, output } = fixture();
    fs.writeFileSync(path.join(logs, "scan.log"), `${line}\n`);
    assert.deepEqual(
      analyzerIntegrityErrors(logs, [output]),
      [
        `${path.join(logs, "scan.log")} contains an analyzer engine processing error.`
      ],
      line
    );
  }
});

test("rejects missing or incomplete reports", () => {
  const { logs, output } = fixture();
  fs.writeFileSync(output, "{}");
  assert.deepEqual(analyzerIntegrityErrors(logs, [output]), [
    `${output} is not a complete Code Analyzer report.`
  ]);
  const missing = path.join(logs, "missing.json");
  assert.deepEqual(analyzerIntegrityErrors(logs, [missing]), [
    `Analyzer JSON output does not exist: ${missing}`
  ]);
  fs.writeFileSync(output, "{not json");
  assert.match(
    analyzerIntegrityErrors(logs, [output]).join("\n"),
    /is not valid JSON/
  );
});

test("rejects a scan whose engine log directory is absent", () => {
  const { logs, output } = fixture();
  const absent = path.join(logs, "never-written");
  assert.deepEqual(analyzerIntegrityErrors(absent, [output]), [
    `Analyzer log directory does not exist: ${absent}`
  ]);
});

test("each blocking scan step checks integrity of every JSON report it writes", () => {
  for (const workflow of [
    ".github/workflows/ci.yml",
    ".github/workflows/salesforce-validate.yml"
  ]) {
    const steps = fs
      .readFileSync(workflow, "utf8")
      .split(/\n {6}- /)
      .filter((step) => step.includes("check_code_analyzer_integrity.mjs"));
    assert.equal(steps.length, 1, `${workflow} must run one integrity check`);
    const written = [...steps[0].matchAll(/--output-file (\S+\.json)/g)].map(
      (match) => match[1]
    );
    const checked = [...steps[0].matchAll(/--output (\S+\.json)/g)].map(
      (match) => match[1]
    );
    assert.ok(written.length > 0, `${workflow} scan writes no JSON report`);
    assert.deepEqual(checked.sort(), written.sort(), workflow);
  }
});
