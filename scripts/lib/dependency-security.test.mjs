import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";

async function auditFixture(failMcp) {
  const temporary = await mkdtemp(path.join(os.tmpdir(), "rhc-audit-"));
  const log = path.join(temporary, "calls.jsonl");
  try {
    await writeFile(
      path.join(temporary, "npm"),
      `#!${process.execPath}
const fs = require("node:fs");
const args = process.argv.slice(2);
fs.appendFileSync(process.env.AUDIT_TEST_LOG, JSON.stringify({cwd:process.cwd(),args})+"\\n");
process.exit(process.env.AUDIT_TEST_FAIL_MCP === "true" && process.cwd().endsWith("record-health-check-mcp") ? 1 : 0);
`,
      { mode: 0o755 }
    );
    const manifest = JSON.parse(await readFile("package.json", "utf8"));
    const result = spawnSync(
      "sh",
      ["-c", manifest.scripts["check:dependency-security"]],
      {
        cwd: process.cwd(),
        encoding: "utf8",
        env: {
          ...process.env,
          PATH: `${temporary}${path.delimiter}${process.env.PATH}`,
          AUDIT_TEST_LOG: log,
          AUDIT_TEST_FAIL_MCP: String(failMcp)
        }
      }
    );
    const calls = (await readFile(log, "utf8"))
      .trim()
      .split("\n")
      .map((line) => JSON.parse(line));
    return { result, calls };
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
}

test("security gate audits both independent lockfiles for production and development dependencies", async () => {
  const { result, calls } = await auditFixture(false);
  assert.equal(result.status, 0, result.stderr);
  for (const directory of [
    process.cwd(),
    path.resolve("packages/record-health-check-mcp")
  ]) {
    assert.ok(
      calls.some(
        (call) =>
          call.cwd === directory &&
          call.args.includes("--omit=dev") &&
          call.args.includes("--audit-level=low")
      ),
      `Production audit missing for ${directory}`
    );
    assert.ok(
      calls.some(
        (call) =>
          call.cwd === directory &&
          !call.args.includes("--omit=dev") &&
          call.args.includes("--audit-level=moderate")
      ),
      `Development audit missing for ${directory}`
    );
  }
});

test("an MCP vulnerability fails the release security gate", async () => {
  const { result } = await auditFixture(true);
  assert.notEqual(
    result.status,
    0,
    "A clean root audit must not hide an MCP audit failure."
  );
});
