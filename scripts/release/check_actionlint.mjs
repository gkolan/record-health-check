#!/usr/bin/env node

/**
 * Validates the GitHub Actions workflows with a pinned actionlint.
 *
 * The workflows are the only place several release steps are declared, and a
 * typo in an expression or a step key is otherwise found by dispatching the
 * workflow - which for salesforce-validate.yml costs scratch-org quota.
 *
 * actionlint resolution prefers an installed binary, then pinned one-shot
 * Python and container distributions.
 * See external-linter.mjs for what happens when neither exists.
 */

import {
  resolveTool,
  exitForMissingTool,
  runTool
} from "../lib/external-linter.mjs";

const ACTIONLINT_VERSION = "1.7.7";
const ACTIONLINT_PY_VERSION = "1.7.7.24";

const actionlint = resolveTool([
  { command: "actionlint" },
  {
    command: "uvx",
    prefix: ["--from", `actionlint-py==${ACTIONLINT_PY_VERSION}`, "actionlint"]
  },
  {
    command: "docker",
    prefix: [
      "run",
      "--rm",
      "--volume",
      `${process.cwd()}:/repo`,
      "--workdir",
      "/repo",
      `rhysd/actionlint:${ACTIONLINT_VERSION}`
    ],
    probe: ["-version"]
  }
]);

if (!actionlint) {
  exitForMissingTool(`actionlint ${ACTIONLINT_VERSION}`, [
    "brew install actionlint",
    `go install github.com/rhysd/actionlint/cmd/actionlint@v${ACTIONLINT_VERSION}`,
    `uv tool install actionlint-py==${ACTIONLINT_PY_VERSION}`,
    "docker pull rhysd/actionlint:" + ACTIONLINT_VERSION
  ]);
}

runTool(actionlint, [...process.argv.slice(2)]);
