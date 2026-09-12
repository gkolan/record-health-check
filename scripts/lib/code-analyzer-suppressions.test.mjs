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
  assert.equal(EXPECTED_CODE_ANALYZER_SUPPRESSIONS.size, 7);
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

test("rejects a widened Flow false-positive allowance", () => {
  const widened = trackedConfig.replace(
    "max_suppressed_violations: 24",
    "max_suppressed_violations: 25"
  );
  assert.match(
    codeAnalyzerSuppressionErrors(widened).join("\n"),
    /must cap suppressed violations at exactly 24/
  );
});

test("readiness pass-count exception remains a single numeric-field false positive", () => {
  const field =
    "packages/record-health-check/force-app/main/default/objects/Record_Health_Check_Readiness__c/fields/PassCount__c.field-meta.xml";
  assert.deepEqual(EXPECTED_CODE_ANALYZER_SUPPRESSIONS.get(field), {
    rule: "pmd:ProtectSensitiveData",
    maximum: 1
  });
  assert.match(fs.readFileSync(field, "utf8"), /<type>Number<\/type>/);
  const widened = trackedConfig.replace(
    `"${field}":\n    - rule_selector: "pmd:ProtectSensitiveData"\n      max_suppressed_violations: 1`,
    `"${field}":\n    - rule_selector: "pmd:ProtectSensitiveData"\n      max_suppressed_violations: 2`
  );
  assert.match(
    codeAnalyzerSuppressionErrors(widened).join("\n"),
    /PassCount__c.*exactly 1/
  );
});
