import { spawnSync } from "node:child_process";

const isWindows = process.platform === "win32";

/**
 * `sf` and `npx` are `.cmd` shims on Windows, so they can only be spawned
 * through a shell. Node concatenates argv into that shell command without
 * escaping it (DEP0190), so any argument holding a space — a clone under
 * `C:\Users\First Last\` is the common case — is split into separate tokens by
 * cmd.exe. Quote the arguments ourselves before they reach the shell.
 */
function shellQuote(value) {
  const arg = String(value);
  if (!/[\s"&|<>^()]/.test(arg)) {
    return arg;
  }
  return `"${arg.replace(/"/g, '""')}"`;
}

function shellArgs(args) {
  return isWindows ? args.map(shellQuote) : args;
}

export function run(command, args = [], options = {}) {
  const result = spawnSync(command, shellArgs(args), {
    stdio: "inherit",
    shell: isWindows,
    ...options
  });
  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
  return result;
}

export function runCapture(command, args = [], options = {}) {
  const result = spawnSync(command, shellArgs(args), {
    encoding: "utf8",
    shell: isWindows,
    ...options
  });
  if (result.status !== 0) {
    if (result.stderr) {
      process.stderr.write(result.stderr);
    }
    process.exit(result.status ?? 1);
  }
  return result.stdout;
}

export function runJson(command, args = [], options = {}) {
  return JSON.parse(runCapture(command, [...args, "--json"], options));
}

/** Like `runCapture`, but a non-zero exit is an answer rather than a failure. */
export function tryRun(command, args = [], options = {}) {
  return spawnSync(command, shellArgs(args), {
    encoding: "utf8",
    shell: isWindows,
    ...options
  });
}
