import assert from "node:assert/strict";
import test from "node:test";
import { packageVersionString } from "./package-version.mjs";

test("reads direct package-list version fields", () => {
  assert.equal(packageVersionString({ Version: "2.0.7.1" }), "2.0.7.1");
  assert.equal(packageVersionString({ version: "2.0.7.1" }), "2.0.7.1");
});

test("assembles a package-report four-part version", () => {
  assert.equal(
    packageVersionString({
      MajorVersion: 2,
      MinorVersion: 0,
      PatchVersion: 7,
      BuildNumber: 1
    }),
    "2.0.7.1"
  );
});

test("fails closed for partial or malformed report data", () => {
  assert.equal(
    packageVersionString({
      MajorVersion: 2,
      MinorVersion: 0,
      PatchVersion: 6
    }),
    ""
  );
  assert.equal(packageVersionString({ Version: "" }), "");
});
