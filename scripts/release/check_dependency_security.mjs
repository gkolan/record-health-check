#!/usr/bin/env node

import { fileURLToPath } from "node:url";
import { unexcusedAdvisories } from "../lib/dependency-audit-exceptions.mjs";
import { run, tryRun } from "../lib/run.mjs";

// The MCP service has its own lockfile and is not an npm workspace of the root.
for (const directory of ["../../", "../../packages/record-health-check-mcp/"]) {
  const cwd = fileURLToPath(new URL(directory, import.meta.url));
  run("npm", ["audit", "--omit=dev", "--audit-level=low"], { cwd });
  const isRoot = directory === "../../";
  if (!isRoot) {
    run("npm", ["audit", "--audit-level=moderate"], { cwd });
    continue;
  }
  // Root development tooling may carry only documented, expiring exceptions.
  const audit = tryRun("npm", ["audit", "--audit-level=moderate", "--json"], {
    cwd,
    maxBuffer: 64 * 1024 * 1024
  });
  if (audit.status === 0) continue;
  let unexcused;
  try {
    unexcused = unexcusedAdvisories(
      audit.stdout,
      new Date().toISOString().slice(0, 10)
    );
  } catch (error) {
    console.error(`Development dependency audit failed: ${error.message}`);
    process.exit(1);
  }
  if (unexcused.length) {
    console.error(
      `Development dependency advisories without an exception:\n  ${unexcused.join("\n  ")}`
    );
    process.exit(1);
  }
  console.log(
    "Development audit: only documented, unexpired exceptions remain (scripts/lib/dependency-audit-exceptions.mjs)."
  );
}
