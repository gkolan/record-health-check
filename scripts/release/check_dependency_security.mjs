#!/usr/bin/env node

import { fileURLToPath } from "node:url";
import { run } from "../lib/run.mjs";

// The MCP service has its own lockfile and is not an npm workspace of the root.
for (const directory of ["../../", "../../packages/record-health-check-mcp/"]) {
  const cwd = fileURLToPath(new URL(directory, import.meta.url));
  run("npm", ["audit", "--omit=dev", "--audit-level=low"], { cwd });
  run("npm", ["audit", "--audit-level=moderate"], { cwd });
}
