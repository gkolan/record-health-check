import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";

test("MCP vulnerability failures stay blocking and retain their findings", () => {
  const workflow = fs.readFileSync(
    new URL("../../.github/workflows/mcp-artifact.yml", import.meta.url),
    "utf8"
  );
  const scan = workflow.match(
    / {6}- name: Scan container[^\n]*\n[\s\S]*?(?= {6}- name:)/
  )?.[0];
  assert.ok(scan, "The container security scan is required.");
  assert.match(scan, /fail-build: true/);
  assert.match(scan, /severity-cutoff: high/);
  assert.doesNotMatch(scan, /continue-on-error|only-fixed: true/);
  assert.match(scan, /output-format: json/);
  assert.match(scan, /output-file: mcp-container-scan\.json/);
  const upload = workflow.match(
    / {6}- name: Upload container scan findings\n[\s\S]*?(?= {6}- name:)/
  )?.[0];
  assert.ok(upload, "Findings must survive a failed scan.");
  assert.match(upload, /if:.*always\(\)/);
  assert.match(upload, /steps\.container-scan\.outcome == 'failure'/);
  assert.match(upload, /uses: actions\/upload-artifact@/);
  assert.match(upload, /path: mcp-container-scan\.json/);
  assert.match(upload, /if-no-files-found: error/);
});
