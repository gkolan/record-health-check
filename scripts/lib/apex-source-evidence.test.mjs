import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import {
  apexSourceSnapshot,
  apexEvidenceStatus
} from "./apex-source-evidence.mjs";

test("Apex snapshot changes for source edits, added fixtures, and deleted files", () => {
  const root = mkdtempSync(join(tmpdir(), "rhc-source-evidence-"));
  const classes = join(
    root,
    "packages/record-health-check/force-app/main/default/classes"
  );
  mkdirSync(classes, { recursive: true });
  const source = join(classes, "Example.cls");
  writeFileSync(source, "public class Example {}\n");
  try {
    const original = apexSourceSnapshot(root);
    assert.match(original, /^[a-f0-9]{64}$/);
    assert.equal(apexSourceSnapshot(root), original);
    writeFileSync(source, "public class Example { public Integer value; }\n");
    assert.notEqual(apexSourceSnapshot(root), original);
    writeFileSync(source, "public class Example {}\n");
    assert.equal(apexSourceSnapshot(root), original);
    const fixture = join(
      root,
      "packages/record-health-check/integration-tests/main/default/customMetadata"
    );
    mkdirSync(fixture, { recursive: true });
    writeFileSync(join(fixture, "Sample.md-meta.xml"), "<CustomMetadata/>\n");
    assert.notEqual(apexSourceSnapshot(root), original);
    rmSync(join(root, "packages/record-health-check/integration-tests"), {
      recursive: true
    });
    rmSync(source);
    assert.notEqual(apexSourceSnapshot(root), original);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("Apex evidence never treats a release version or missing snapshot as current", () => {
  const current = "a".repeat(64);
  assert.equal(
    apexEvidenceStatus({ sourceSnapshotSha256: null }, current),
    "historical-unbound"
  );
  assert.equal(
    apexEvidenceStatus({ sourceSnapshotSha256: "b".repeat(64) }, current),
    "historical-source-mismatch"
  );
  assert.equal(
    apexEvidenceStatus({ sourceSnapshotSha256: current }, current),
    "source-matched"
  );
  assert.throws(() => apexEvidenceStatus({}, current), /sourceSnapshotSha256/);
  assert.throws(
    () => apexEvidenceStatus({ sourceSnapshotSha256: "not-a-hash" }, current),
    /sourceSnapshotSha256/
  );
});
