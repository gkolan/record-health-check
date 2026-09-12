import assert from "node:assert/strict";
import { mkdir, mkdtemp, readFile, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";

const root = path.resolve(".");

function distributableFiles() {
  const result = spawnSync(
    "git",
    ["ls-files", "--cached", "--others", "--exclude-standard"],
    { cwd: root, encoding: "utf8" }
  );
  assert.equal(result.status, 0, result.stderr);
  return result.stdout.split(/\r?\n/).filter(Boolean);
}

async function writeMetadata(directory, value) {
  await mkdir(directory, { recursive: true });
  await writeFile(
    path.join(directory, "Record_Health_Check.Source.md-meta.xml"),
    `<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata">
  <label>Source</label>
  <protected>false</protected>
  <values><field>ComparisonOperator__c</field><value>${value}</value></values>
</CustomMetadata>`
  );
}

async function cleanCliCopy() {
  const files = distributableFiles();
  const directory = await mkdtemp(path.join(os.tmpdir(), "rhc-source-"));
  for (const relative of [
    "scripts/validation/lint-rhc.mjs",
    "scripts/lib/rhc-lint.mjs"
  ]) {
    assert.ok(
      files.includes(relative),
      `missing distributable file ${relative}`
    );
    const destination = path.join(directory, relative);
    await mkdir(path.dirname(destination), { recursive: true });
    await writeFile(destination, await readFile(path.join(root, relative)));
  }
  return { directory, files };
}

function runCli(directory, args) {
  return spawnSync(
    process.execPath,
    [path.join(directory, "scripts/validation/lint-rhc.mjs"), ...args],
    { cwd: directory, encoding: "utf8" }
  );
}

test("S01 Clean source required executable", async () => {
  const { directory } = await cleanCliCopy();
  assert.equal(
    (
      await readFile(
        path.join(directory, "scripts/validation/lint-rhc.mjs"),
        "utf8"
      )
    ).includes("../lib/rhc-lint.mjs"),
    true
  );
});

test("S02 Invalid CLI configuration", async () => {
  const { directory } = await cleanCliCopy();
  const source = path.join(directory, "fixture");
  await writeMetadata(source, "EQUALS");
  const result = runCli(directory, [
    "--source",
    source,
    "--mode",
    "offline",
    "--format",
    "yaml",
    "--output",
    path.join(directory, "result.json")
  ]);
  assert.equal(result.status, 2);
  assert.match(result.stderr, /--format must be json or sarif/);
});

test("S03 Incomplete clean lint and missing org argument", async () => {
  const { directory } = await cleanCliCopy();
  const source = path.join(directory, "fixture");
  await writeMetadata(source, "EQUALS");
  const offline = runCli(directory, [
    "--source",
    source,
    "--mode",
    "offline",
    "--format",
    "sarif",
    "--output",
    path.join(directory, "result.sarif")
  ]);
  assert.equal(offline.status, 2, offline.stderr);
  assert.equal(
    JSON.parse(await readFile(path.join(directory, "result.sarif"), "utf8"))
      .version,
    "2.1.0"
  );
  const org = runCli(directory, [
    "--source",
    source,
    "--mode",
    "org",
    "--format",
    "json",
    "--output",
    path.join(directory, "org.json")
  ]);
  assert.equal(org.status, 2);
  assert.match(org.stderr, /requires --target-org/);
});

test("S04 Ignored evidence and secrets", () => {
  const files = distributableFiles();
  const forbidden = files.filter((file) =>
    /^(?:specs|internal|reports|evidence|releases|\.sf|\.sfdx)\//.test(file)
  );
  assert.deepEqual(forbidden, []);
});
