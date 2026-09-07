#!/usr/bin/env node

/**
 * Lints the Python gate scripts with a pinned Ruff.
 *
 * prettier does not cover .py, so without this gate the four scripts under
 * scripts/release/ that enforce release gates are themselves unchecked.
 *
 * Ruff resolution prefers an installed `ruff`, then a pinned one-shot run
 * through `uvx` or `pipx`. See external-linter.mjs for what happens when none
 * of those exist.
 */

import {
  resolveTool,
  exitForMissingTool,
  listSourceFiles,
  runTool
} from "../lib/external-linter.mjs";

const RUFF_VERSION = "0.14.2";

const ruff = resolveTool([
  { command: "ruff" },
  { command: "uvx", prefix: [`ruff@${RUFF_VERSION}`] },
  { command: "pipx", prefix: ["run", `ruff==${RUFF_VERSION}`] }
]);

if (!ruff) {
  exitForMissingTool(`Ruff ${RUFF_VERSION}`, [
    `pipx install ruff==${RUFF_VERSION}`,
    `uv tool install ruff@${RUFF_VERSION}`,
    "brew install ruff"
  ]);
}

const pythonFiles = listSourceFiles(["scripts/**/*.py"]);
runTool(ruff, ["check", ...pythonFiles, ...process.argv.slice(2)]);
