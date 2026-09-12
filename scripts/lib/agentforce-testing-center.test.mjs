import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

import {
  AGENTFORCE_TEST_RUNNER,
  validateLegacyAgentTestSpec
} from "./agentforce-testing-center.mjs";

const templatePath =
  "packages/record-health-check/integration-tests/agentforce/Record_Health_Assistant-testing-center.yaml.template";

test("declares and validates the supported Agentforce test runner", async () => {
  assert.equal(AGENTFORCE_TEST_RUNNER, "testing-center");
  const source = await readFile(templatePath, "utf8");
  const result = validateLegacyAgentTestSpec(source);
  assert.equal(result.caseCount, 47);
});

test("rejects a legacy test case without explicit no-action and topic expectations", () => {
  assert.throws(
    () =>
      validateLegacyAgentTestSpec(`name: Missing expectations
subjectType: AGENT
subjectName: Record_Health_Assistant
testCases:
  - utterance: "Do nothing."
    expectedOutcome: "No action is called."
`),
    /case 1.*expectedTopic.*expectedActions/s
  );
});
