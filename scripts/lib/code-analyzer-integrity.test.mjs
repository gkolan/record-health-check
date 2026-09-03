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
  assert.deepEqual(analyzerIntegrityErrors(logs, [output]), []);
});

test("rejects a scanner false-green engine processing error", () => {
  const { logs, output } = fixture();
  fs.writeFileSync(
    path.join(logs, "scan.log"),
    "Error pmd - PMD issued a processing error\nNullPointerException\n"
  );
  assert.equal(analyzerIntegrityErrors(logs, [output]).length, 1);
});

test("rejects missing or incomplete reports", () => {
  const { logs, output } = fixture();
  fs.writeFileSync(output, "{}");
  assert.equal(analyzerIntegrityErrors(logs, [output]).length, 1);
  assert.equal(
    analyzerIntegrityErrors(logs, [path.join(logs, "missing.json")]).length,
    1
  );
});
