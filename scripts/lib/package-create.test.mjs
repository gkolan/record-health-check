import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

const root = new URL("../../", import.meta.url);
const requestId = "08c000000000001AAA";
const candidateId = "04t000000000001AAA";
const commit = "a".repeat(40);

// Exercise the real entry point with disposable CLI fixtures. These are release
// tooling scenarios, so Check/Check Set Custom Metadata cannot represent them.
function fixture(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "rhc-create-"));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  for (const file of [
    "scripts/release/create-package-version.mjs",
    ...[
      "paths",
      "run",
      "package-version",
      "package-releases",
      "salesforce-limits"
    ].map((name) => `scripts/lib/${name}.mjs`),
    "config/package-releases.json"
  ]) {
    fs.mkdirSync(path.dirname(path.join(dir, file)), { recursive: true });
    fs.copyFileSync(new URL(file, root), path.join(dir, file));
  }
  fs.writeFileSync(
    path.join(dir, "config/release-runtime-matrix.json"),
    JSON.stringify({ candidateVersion: "2.0.11.2" })
  );
  const packageDir = path.join(dir, "packages/record-health-check");
  fs.mkdirSync(packageDir, { recursive: true });
  const bin = path.join(dir, "bin");
  fs.mkdirSync(bin);
  const log = path.join(dir, "calls.jsonl");
  const cli = `
import fs from "node:fs";
import path from "node:path";
const name = path.basename(process.argv[1]).replace(/\\.mjs$/, "");
const args = process.argv.slice(2);
fs.appendFileSync(process.env.FIXTURE_LOG, JSON.stringify({ name, args, autoUpdateDisabled: process.env.SF_PROJECT_AUTOUPDATE_DISABLE_FOR_PACKAGE_VERSION_CREATE }) + "\\n");
const mode = process.env.FIXTURE_MODE;
const result = { Id: "${requestId}", Package2Id: "0Hoak0000004kKPCAY", Package2VersionId: "05i000000000001AAA", SubscriberPackageVersionId: "${candidateId}", VersionNumber: "2.0.11.2", Branch: "2.0.11", Tag: "${commit}:2.0.11.2", Status: "Success", HasPassedCodeCoverageCheck: true };
if (name === "git") {
  if (args[0] === "branch") console.log("2.0.11");
  // "later-head" models a resume after a tooling-only commit; "later-source" changes package inputs.
  const head = /^later-/.test(mode) && fs.existsSync(process.env.FIXTURE_LOG + ".submitted") ? "${"b".repeat(40)}" : "${commit}";
  if (args[0] === "rev-parse") console.log(head);
  if (args[0] === "merge-base") process.exit(args[2] === "${commit}" ? 0 : 1);
  if (args[0] === "diff") process.exit(mode === "later-source" ? 1 : 0);
  if (args[0] === "status" && mode === "dirty-after-preflight" && fs.existsSync(process.env.FIXTURE_LOG + ".preflight")) console.log(" M file");
} else if (name === "npm") {
  fs.writeFileSync(process.env.FIXTURE_LOG + ".preflight", "done");
} else if (name === "sf") {
  let response;
  if (args[0] === "limits") response = [{ name: "Package2VersionCreates", max: 6, remaining: 6 }];
  else if (args[2] === "list") response = mode === "existing" ? [{ ...result, Version: "2.0.11.2", CreatedDate: "2026-09-01" }] : [];
  else if (args[2] === "create") {
    if (mode === "queued") { result.Status = "Queued"; result.SubscriberPackageVersionId = null; }
    if (mode === "wrong-package") result.Package2Id = "0Ho000000000002AAA";
    if (mode === "wrong-tag") result.Tag = "other-commit";
    if (mode === "wrong-request" && args[3] === "report") result.Id = "08c000000000002AAA";
    if (mode === "no-coverage") result.HasPassedCodeCoverageCheck = false;
    if (mode === "wrong-version") result.VersionNumber = "2.0.11.1";
    if (mode === "failed") result.Status = "Error";
    if (mode === "finalizing") result.Status = "FinalizingPackageVersion";
    // The real CLI returns create reports as a one-element list (observed 2026-10-06).
    response = args[3] === "report" ? [result] : result;
    if (args[3] !== "report") fs.writeFileSync(process.env.FIXTURE_LOG + ".submitted", "yes");
    if (/^later-/.test(mode) && args[3] !== "report") { result.Status = "Queued"; result.SubscriberPackageVersionId = null; }
    if (mode === "lost-response" && args[3] !== "report") { console.log("connection lost"); process.exit(1); }
  } else throw new Error("Unexpected command " + args.join(" "));
  console.log(JSON.stringify({ status: 0, result: response }));
}
`;
  for (const name of ["git", "npm", "sf"]) {
    const script = path.join(bin, `${name}.mjs`);
    fs.writeFileSync(script, cli);
    if (process.platform === "win32") {
      fs.writeFileSync(
        path.join(bin, `${name}.cmd`),
        `@"${process.execPath}" "${script}" %*\r\n`
      );
    } else {
      fs.writeFileSync(path.join(bin, name), `#!${process.execPath}\n${cli}`, {
        mode: 0o755
      });
    }
  }
  return {
    packageDir,
    calls: () =>
      fs.readFileSync(log, "utf8").trim().split("\n").map(JSON.parse),
    run: (mode = "success", extra = []) =>
      spawnSync(
        process.execPath,
        [
          path.join(dir, "scripts/release/create-package-version.mjs"),
          "--dev-hub",
          "fixture",
          "--release-ready",
          "--wait",
          "0",
          ...extra
        ],
        {
          cwd: dir,
          encoding: "utf8",
          env: {
            ...process.env,
            PATH: `${bin}${path.delimiter}${process.env.PATH}`,
            FIXTURE_LOG: log,
            FIXTURE_MODE: mode
          }
        }
      )
  };
}

function creates(f) {
  return f
    .calls()
    .filter(
      ({ name, args }) =>
        name === "sf" && args[2] === "create" && args[3] !== "report"
    );
}

test("creation binds evidence to the returned request and preserves the committed project", (t) => {
  const f = fixture(t);
  const result = f.run();
  assert.equal(result.status, 0, result.stderr);
  const evidence = JSON.parse(
    fs.readFileSync(
      path.join(f.packageDir, `.package-evidence/${candidateId}-create.json`),
      "utf8"
    )
  );
  assert.equal(evidence.version, "2.0.11.2");
  assert.equal(evidence.createRequestId, requestId);
  assert.equal(evidence.gitCommit, commit);
  assert.equal(creates(f).length, 1);
  assert.equal(creates(f)[0].autoUpdateDisabled, "true");
  assert.ok(creates(f)[0].args.includes("--json"));
});

for (const mode of ["existing", "dirty-after-preflight"]) {
  test(`${mode} refuses to consume a package creation`, (t) => {
    const f = fixture(t);
    assert.notEqual(f.run(mode).status, 0);
    assert.equal(creates(f).length, 0);
  });
}

for (const mode of ["queued", "lost-response", "finalizing"]) {
  test(`${mode} is resumable without resubmitting a package`, (t) => {
    const f = fixture(t);
    assert.notEqual(f.run(mode).status, 0);
    assert.equal(creates(f).length, 1);
    assert.notEqual(f.run().status, 0, "a plain retry must not submit again");
    assert.equal(creates(f).length, 1);
    const resumed = f.run("success", ["--resume", requestId]);
    assert.equal(resumed.status, 0, resumed.stderr);
    assert.equal(creates(f).length, 1);
  });
}

for (const [mode, expected] of [
  ["wrong-package", /does not match the saved request/],
  ["wrong-tag", /does not match the saved request/],
  ["no-coverage", /passing package code coverage/],
  ["wrong-version", /exact candidate version/],
  ["failed", /Package creation failed/]
]) {
  test(`${mode} never creates promotion evidence`, (t) => {
    const f = fixture(t);
    const result = f.run(mode);
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, expected);
    assert.equal(
      fs.existsSync(
        path.join(f.packageDir, `.package-evidence/${candidateId}-create.json`)
      ),
      false
    );
  });
}

test("resume rejects a different request returned by Salesforce", (t) => {
  const f = fixture(t);
  f.run("queued");
  assert.notEqual(f.run("wrong-request", ["--resume", requestId]).status, 0);
  assert.equal(creates(f).length, 1);
});

test("resume may run from a later commit only when package inputs are unchanged", (t) => {
  const f = fixture(t);
  assert.notEqual(f.run("later-head").status, 0, "submission stays queued");
  const resumed = f.run("later-head", ["--resume", requestId]);
  assert.equal(resumed.status, 0, resumed.stderr);
  assert.equal(creates(f).length, 1);
  const evidence = JSON.parse(
    fs.readFileSync(
      path.join(f.packageDir, `.package-evidence/${candidateId}-create.json`),
      "utf8"
    )
  );
  assert.equal(evidence.gitCommit, commit, "evidence names the built commit");
});

test("resume refuses a later commit that changed package inputs", (t) => {
  const f = fixture(t);
  f.run("later-source");
  const resumed = f.run("later-source", ["--resume", requestId]);
  assert.notEqual(resumed.status, 0);
  assert.match(resumed.stderr, /package inputs changed/);
  assert.equal(creates(f).length, 1);
});
