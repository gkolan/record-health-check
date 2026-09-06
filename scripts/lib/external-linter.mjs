import { spawnSync } from "node:child_process";

/**
 * Shared policy for linters that are not npm dependencies.
 *
 * Ruff and actionlint cannot be installed by `npm ci`, so a gate that runs them
 * has to decide what "the tool is missing" means. The decision must be the same
 * for both, and it is not symmetric:
 *
 * - In CI, missing means fail. A release gate that silently checks nothing is
 *   worse than no gate, because the green tick claims coverage it does not have.
 * - Locally, missing means skip with a warning, so `npm run ci:gates` stays
 *   runnable by a contributor who has not installed a Go or Python tool. CI is
 *   still the authority.
 */

const isWindows = process.platform === "win32";

/** True when `command` exists and exits zero. A missing command is an answer, not a crash. */
export function canRun(command, args = []) {
  const probe = spawnSync(command, args, {
    encoding: "utf8",
    shell: isWindows
  });
  return !probe.error && probe.status === 0;
}

/**
 * Returns the first runnable candidate, or null when none are available.
 *
 * @param {{command: string, prefix?: string[], probe?: string[]}[]} candidates
 *   In preference order. `probe` defaults to `--version`.
 */
export function resolveTool(candidates) {
  for (const candidate of candidates) {
    const prefix = candidate.prefix ?? [];
    const probe = candidate.probe ?? ["--version"];
    if (canRun(candidate.command, [...prefix, ...probe])) {
      return { command: candidate.command, prefix };
    }
  }
  return null;
}

/** Lists tracked and unignored source files without admitting ignored local evidence. */
export function listSourceFiles(
  patterns,
  { cwd = process.cwd(), spawn = spawnSync } = {}
) {
  const result = spawn(
    "git",
    [
      "ls-files",
      "--cached",
      "--others",
      "--exclude-standard",
      "--",
      ...patterns
    ],
    { cwd, encoding: "utf8", shell: isWindows }
  );
  if (result.error || result.signal || result.status !== 0) {
    const detail =
      result.error?.message ?? result.stderr?.trim() ?? "git failed";
    throw new Error(`Unable to inventory source files: ${detail}`);
  }
  const files = result.stdout.split(/\r?\n/).filter(Boolean);
  if (files.length === 0) {
    throw new Error(`No source files matched: ${patterns.join(", ")}`);
  }
  return files;
}

/**
 * Applies the missing-tool policy and never returns: exits 1 under CI, 0 otherwise.
 *
 * @param {string} tool Human-readable tool name and version.
 * @param {string[]} installCommands Exact commands a reader can copy.
 * @param {boolean} isCi Whether this is a CI run.
 */
export function exitForMissingTool(
  tool,
  installCommands,
  isCi = Boolean(process.env.CI)
) {
  const header = `${tool} is not available. Install it with one of:\n`;
  const body = installCommands.map((line) => `  ${line}\n`).join("");
  if (isCi) {
    process.stderr.write(`${header}${body}CI must not skip this gate.\n`);
    process.exit(1);
  }
  process.stderr.write(
    `${header}${body}Skipping locally; CI runs this gate and will fail if it does not pass.\n`
  );
  process.exit(0);
}

/** Runs the resolved tool, forwarding stdio, and exits with its status. */
export function runTool(tool, args) {
  const result = spawnSync(tool.command, [...tool.prefix, ...args], {
    stdio: "inherit",
    shell: isWindows
  });
  if (result.error) {
    process.stderr.write(
      `Unable to run ${tool.command}: ${result.error.message}\n`
    );
    process.exit(1);
  }
  process.exit(result.status ?? 1);
}
