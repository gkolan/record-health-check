import assert from "node:assert/strict";
import test from "node:test";
import {
  compareInlineSuppressionInventory,
  inspectInlineSuppressions
} from "./code-analyzer-inline-suppressions.mjs";

test("accepts a rule-specific suppression with a review reason", () => {
  const result = inspectInlineSuppressions(
    "Example.cls",
    "// code-analyzer-suppress-next-line ApexCRUDViolation: Custom Metadata configuration is reviewed setup data."
  );
  assert.equal(result.entries.length, 1);
  assert.deepEqual(result.errors, []);
});

test("rejects broad, unexplained, and legacy inline suppressions", () => {
  const result = inspectInlineSuppressions(
    "Example.cls",
    [
      "// code-analyzer-suppress-next-line Security: too broad",
      "// NOPMD",
      "@SuppressWarnings('PMD')"
    ].join("\n")
  );
  assert.equal(result.errors.length, 4);
  assert.match(result.errors.join("\n"), /broad inline suppression/);
  assert.match(result.errors.join("\n"), /legacy NOPMD/);
  assert.match(result.errors.join("\n"), /brace-style Apex warning/);
});

test("inventory comparison fails closed for marker drift", () => {
  const expected = [{ file: "A.cls", marker: "// approved" }];
  assert.deepEqual(compareInlineSuppressionInventory(expected, expected), []);
  assert.equal(
    compareInlineSuppressionInventory(
      [{ file: "A.cls", marker: "// changed" }],
      expected
    ).length,
    1
  );
});
