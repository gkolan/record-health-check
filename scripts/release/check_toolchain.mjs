#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { toolchainWorkflowErrors } from "../lib/toolchain-policy.mjs";

const root = resolve(import.meta.dirname, "../..");
const policy = JSON.parse(
  readFileSync(resolve(root, "config/toolchain.json"), "utf8")
);
const policyOnly = process.argv.includes("--policy-only");
const checkLatest = process.argv.includes("--latest");

function fail(message) {
  console.error(message);
  process.exitCode = 1;
}

const workflowPaths = [
  ".github/workflows/ci.yml",
  ".github/workflows/salesforce-validate.yml",
  ".github/workflows/subscriber-validate.yml"
];
const workflows = Object.fromEntries(
  workflowPaths.map((workflow) => [
    workflow,
    readFileSync(resolve(root, workflow), "utf8")
  ])
);
for (const error of toolchainWorkflowErrors(policy, workflows)) {
  fail(error);
}

const subscriberWorkflow =
  workflows[".github/workflows/subscriber-validate.yml"];
if (
  !subscriberWorkflow.includes("required: true") ||
  !subscriberWorkflow.includes("config/release-runtime-matrix.json")
) {
  fail(
    ".github/workflows/subscriber-validate.yml must require an explicit candidate and resolve the tracked stable upgrade base."
  );
}
for (const expectedCommand of [
  'npm run package:verify -- --package "${{ steps.rhc-package.outputs.id }}" --upgrade-from "${{ steps.rhc-package.outputs.upgrade_from }}" --alias "rhc-${{ steps.rhc-package.outputs.release_alias }}-${{ matrix.artifact_suffix }}" --security-mode "${{ matrix.security_mode }}" --release-pair --keep-org'
]) {
  if (!subscriberWorkflow.includes(expectedCommand)) {
    fail(
      `.github/workflows/subscriber-validate.yml is missing the explicit package verification contract: ${expectedCommand}`
    );
  }
}

if (!policyOnly) {
  try {
    const output = execFileSync("sf", ["--version"], {
      encoding: "utf8",
      env: { ...process.env, SF_DISABLE_LOG_FILE: "true" }
    });
    const match = output.match(/@salesforce\/cli\/(\d+\.\d+\.\d+)/);
    if (!match || match[1] !== policy.salesforceCli) {
      fail(
        `Salesforce CLI ${policy.salesforceCli} is required; found ${match?.[1] ?? "unknown"}. Run npm install --global @salesforce/cli@${policy.salesforceCli}.`
      );
    }
  } catch (error) {
    fail(`Unable to run sf --version: ${error.message}`);
  }
}

if (checkLatest) {
  try {
    const latest = JSON.parse(
      execFileSync("npm", ["view", "@salesforce/cli", "version", "--json"], {
        encoding: "utf8",
        shell: process.platform === "win32"
      })
    );
    if (latest !== policy.salesforceCli) {
      fail(
        `Salesforce CLI policy is stale: pinned ${policy.salesforceCli}, official latest ${latest}. Review and update the toolchain baseline.`
      );
    }
  } catch (error) {
    fail(
      `Unable to verify the official Salesforce CLI latest release: ${error.message}`
    );
  }
}

if (!process.exitCode) {
  console.log(
    `Toolchain policy matches Salesforce CLI ${policy.salesforceCli}` +
      `${policyOnly ? "." : " locally and in CI."}` +
      `${checkLatest ? " The npm latest release also matches." : ""}`
  );
}
