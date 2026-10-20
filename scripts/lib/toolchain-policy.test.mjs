import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";
import { toolchainWorkflowErrors } from "./toolchain-policy.mjs";

const policy = JSON.parse(fs.readFileSync("config/toolchain.json", "utf8"));
const workflowPaths = [
  ".github/workflows/ci.yml",
  ".github/workflows/salesforce-validate.yml",
  ".github/workflows/subscriber-validate.yml"
];
const workflows = () =>
  Object.fromEntries(
    workflowPaths.map((file) => [file, fs.readFileSync(file, "utf8")])
  );

test("tracked workflows match the toolchain policy", () => {
  assert.deepEqual(toolchainWorkflowErrors(policy, workflows()), []);
});

test("a drifted or removed analyzer pin in any scanning workflow is rejected", () => {
  for (const workflow of [
    ".github/workflows/ci.yml",
    ".github/workflows/salesforce-validate.yml"
  ]) {
    const drifted = workflows();
    drifted[workflow] = drifted[workflow].replaceAll(
      `code-analyzer@${policy.codeAnalyzerPlugin}`,
      "code-analyzer@5.0.0"
    );
    assert.deepEqual(
      toolchainWorkflowErrors(policy, drifted),
      [
        `${workflow} must install only code-analyzer@${policy.codeAnalyzerPlugin}; found 5.0.0.`
      ],
      workflow
    );
    const removed = workflows();
    removed[workflow] = removed[workflow].replaceAll(
      `code-analyzer@${policy.codeAnalyzerPlugin}`,
      "code-analyzer"
    );
    assert.deepEqual(
      toolchainWorkflowErrors(policy, removed),
      [`${workflow} must install code-analyzer@${policy.codeAnalyzerPlugin}.`],
      workflow
    );
  }
});

test("one stale Salesforce CLI pin beside a current one is rejected", () => {
  const drifted = workflows();
  const workflow = ".github/workflows/salesforce-validate.yml";
  drifted[workflow] = drifted[workflow].replace(
    `@salesforce/cli@${policy.salesforceCli}`,
    "@salesforce/cli@2.150.6"
  );
  assert.deepEqual(toolchainWorkflowErrors(policy, drifted), [
    `${workflow} must install only @salesforce/cli@${policy.salesforceCli}; found 2.150.6.`
  ]);
});

test("one job on another Node.js major is rejected", () => {
  const drifted = workflows();
  const workflow = ".github/workflows/ci.yml";
  drifted[workflow] = drifted[workflow].replace(
    `node-version: ${policy.nodeMajor}`,
    "node-version: 20"
  );
  assert.deepEqual(toolchainWorkflowErrors(policy, drifted), [
    `${workflow} must use only Node.js ${policy.nodeMajor}; found 20.`
  ]);
});
