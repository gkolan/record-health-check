import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import assert from "node:assert/strict";
import test from "node:test";
import {
  assertReuseOptions,
  assertRetainedReleaseOrg,
  securityRetrieveDirectory
} from "./release-org-reuse.mjs";

test("a retained pair can perform clean installation and upgrade without creating or deleting an org", () => {
  assert.doesNotThrow(() =>
    assertReuseOptions({
      reuseExistingOrg: true,
      releasePair: true,
      keepOrg: true,
      upgradeOnly: false
    })
  );
});
test("ordinary reuse still requires upgrade-only or a retained release pair", () => {
  assert.throws(
    () => assertReuseOptions({ reuseExistingOrg: true, upgradeOnly: false }),
    /reuse/
  );
});
test("a reused pair must be retained", () => {
  assert.throws(
    () =>
      assertReuseOptions({
        reuseExistingOrg: true,
        releasePair: true,
        keepOrg: false
      }),
    /reuse/
  );
});
test("existing upgrade-only behavior remains supported", () => {
  assert.doesNotThrow(() =>
    assertReuseOptions({ reuseExistingOrg: true, upgradeOnly: true })
  );
});

const receipt = {
  ScratchOrg: "00DcU00000HkG0k",
  Description: "Record Health Check 2.0.11 LWS release pair",
  Status: "Active"
};
const existing = {
  orgId: "00DcU00000HkG0kUAF",
  namespace: null,
  securityMode: "LWS",
  version: "2.0.11",
  records: [receipt]
};
test("exact active release receipt permits subscriber reuse", () =>
  assert.doesNotThrow(() => assertRetainedReleaseOrg(existing)));
for (const [name, change] of [
  ["wrong org", { orgId: "00DRu00000ZC781MAD" }],
  ["wrong mode", { securityMode: "Locker" }],
  ["wrong release", { version: "2.0.12" }],
  ["namespaced source", { namespace: "rhc" }],
  ["expired receipt", { records: [{ ...receipt, Status: "Expired" }] }],
  ["missing receipt", { records: [] }],
  ["duplicate receipt", { records: [receipt, receipt] }]
]) {
  test(`rejects ${name} before any reset or installation`, () =>
    assert.throws(() => assertRetainedReleaseOrg({ ...existing, ...change })));
}

test("Security settings retrieve stays inside the Salesforce project", () => {
  const project = fs.mkdtempSync(path.join(os.tmpdir(), "rhc-project-"));
  const directory = securityRetrieveDirectory(project);
  try {
    assert.equal(path.dirname(directory), project);
    assert.equal(
      path.basename(directory).startsWith("."),
      false,
      "CLI skips hidden retrieve directories"
    );
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
    fs.rmSync(project, { recursive: true, force: true });
  }
});
