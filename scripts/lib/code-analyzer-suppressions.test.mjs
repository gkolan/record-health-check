import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";
import {
  codeAnalyzerSuppressionErrors,
  EXPECTED_CODE_ANALYZER_SUPPRESSIONS
} from "./code-analyzer-suppressions.mjs";

const trackedConfig = fs.readFileSync("code-analyzer.yml", "utf8");

test("accepts the exact tracked security suppression allowlist", () => {
  assert.deepEqual(codeAnalyzerSuppressionErrors(trackedConfig), []);
  assert.equal(EXPECTED_CODE_ANALYZER_SUPPRESSIONS.size, 4);
});

test("rejects an additional suppression path", () => {
  const widened = trackedConfig.replace(
    "\nengines:",
    '\n  "packages/example.cls":\n    - rule_selector: "pmd:ApexSOQLInjection"\n      max_suppressed_violations: 1\n      reason: "Synthetic unauthorized suppression used only by this test."\n\nengines:'
  );
  assert.match(
    codeAnalyzerSuppressionErrors(widened).join("\n"),
    /unapproved suppression path/
  );
});

test("rejects a widened limit or globally disabled security rule", () => {
  const widened = trackedConfig
    .replace("max_suppressed_violations: 1", "max_suppressed_violations: 2")
    .replace(
      "rules:\n  pmd:",
      "rules:\n  pmd:\n    ProtectSensitiveData:\n      disabled: true"
    );
  const errors = codeAnalyzerSuppressionErrors(widened).join("\n");
  assert.match(errors, /cap suppressed violations at exactly 1/);
  assert.match(errors, /must not be disabled globally/);
});
