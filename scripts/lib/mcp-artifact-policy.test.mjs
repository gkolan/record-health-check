import assert from "node:assert/strict";
import fs from "node:fs";
import crypto from "node:crypto";
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

test("MCP reachability dispositions stay limited to the reviewed runtime", () => {
  const root = new URL(
    "../../packages/record-health-check-mcp/",
    import.meta.url
  );
  const config = fs.readFileSync(new URL("grype.yaml", root), "utf8");
  const entries = config.split("  - vulnerability: ").slice(1);
  const expected = [
    ["CVE-2026-5435", "libc6", "2.41-12+deb13u4", "wont-fix"],
    ["CVE-2026-85091", "zlib1g", "1:1.3.dfsg+really1.3.1-1+b1", "not-fixed"],
    ["CVE-2026-19499", "libc6", "2.41-12+deb13u4", "wont-fix"],
    ...["gcc-14-base", "libgcc-s1", "libgomp1", "libstdc++6"].flatMap(
      (name) => [
        [
          "CVE-2026-95619",
          name === "libstdc++6" ? "'libstdc\\+\\+6'" : name,
          "14.2.0-19",
          "not-fixed"
        ],
        [
          "CVE-2026-102010",
          name === "libstdc++6" ? "'libstdc\\+\\+6'" : name,
          "14.2.0-19",
          "wont-fix"
        ]
      ]
    )
  ];
  const actual = entries.map((entry) => {
    assert.match(entry, /namespace: debian:distro:debian:13/);
    assert.match(entry, /type: deb/);
    const lines = entry.trim().split("\n");
    return [
      lines[0],
      entry.match(/name: ([^\n]+)/)?.[1],
      entry.match(/version: "([^"\n]+)"/)?.[1],
      entry.match(/fix-state: ([^\n]+)/)?.[1]
    ];
  });
  assert.deepEqual(actual.sort(), expected.sort());
  assert.doesNotMatch(config, /severity:|fix-state: fixed|include-aliases:/);
  const dockerfile = fs.readFileSync(new URL("Dockerfile", root), "utf8");
  assert.match(
    dockerfile,
    /nonroot@sha256:ec2313763dd43931543bd03830466e0c409ce73a487e8d46f10db72d3b816c1c AS runtime/
  );
  assert.match(dockerfile, /ENV NODE_OPTIONS=--no-addons/);
  const lock = JSON.parse(fs.readFileSync(new URL("package-lock.json", root)));
  const production = Object.entries(lock.packages)
    .filter(([name, pkg]) => name && !pkg.dev)
    .map(([name, pkg]) => [name, pkg.version, pkg.integrity]);
  assert.equal(
    crypto
      .createHash("sha256")
      .update(JSON.stringify(production))
      .digest("hex"),
    "cc6bbe0246ceb553fa1865b00b9093692e9a6ba587e143890872cf08ddd26152",
    "Production dependency changes require renewed native reachability review."
  );
  const workflow = fs.readFileSync(
    new URL("../../.github/workflows/mcp-artifact.yml", import.meta.url),
    "utf8"
  );
  assert.match(
    workflow,
    /name: Verify native vulnerability reachability assumptions/
  );
  assert.match(workflow, /grep -q 'call\.\*posix_memalign'/);
  assert.match(workflow, /ERR_DLOPEN_DISABLED/);
  assert.match(workflow, /if grep[^\n]+strfmon[^\n]+then exit 1; fi/);
  assert.doesNotMatch(workflow, /\n {10}! grep/);
  assert.match(workflow, /__gnu_pbds/);
});
