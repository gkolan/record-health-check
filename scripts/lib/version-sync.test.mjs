import assert from "node:assert/strict";
import test from "node:test";
import { versionSyncErrors } from "./version-sync.mjs";

const synced = () => ({
  productVersion: "2.0.12",
  packageLock: { version: "2.0.12", packages: { "": { version: "2.0.12" } } },
  releaseRegistry: {
    stable: { version: "2.0.11.4" },
    previous: { version: "2.0.10.1" },
    candidate: { version: "2.0.11.4", status: "released" }
  },
  packageDirectory: {
    versionNumber: "2.0.12.NEXT",
    versionName: "Version 2.0.12"
  },
  frameworkVersion: "2.0.12"
});

test("accepts a bumped version and a same-version hotfix build", () => {
  assert.deepEqual(versionSyncErrors(synced()), []);
  const hotfix = synced();
  hotfix.releaseRegistry.stable.version = "2.0.12.1";
  assert.deepEqual(versionSyncErrors(hotfix), []);
});

test("an unreleased candidate does not raise the released floor", () => {
  const input = synced();
  input.releaseRegistry.candidate = { version: "2.0.13.1", status: "beta" };
  assert.deepEqual(versionSyncErrors(input), []);
});

test("a development version below a released version is rejected", () => {
  const input = synced();
  input.releaseRegistry.candidate = { version: "2.0.13.1", status: "released" };
  assert.deepEqual(versionSyncErrors(input), [
    "development version 2.0.12 must not be older than released version 2.0.13. A matching semantic version is permitted for a higher 2GP hotfix build."
  ]);
});

test("each unsynchronized version source is rejected on its own", () => {
  const cases = [
    [
      (input) => (input.packageLock.version = "2.0.11"),
      'package-lock.json version must be "2.0.12"; found "2.0.11".'
    ],
    [
      (input) => (input.packageLock.packages[""].version = "2.0.11"),
      'package-lock.json root package version must be "2.0.12"; found "2.0.11".'
    ],
    [
      (input) => (input.packageDirectory.versionNumber = "2.0.11.NEXT"),
      'versionNumber must be "2.0.12.NEXT"; found "2.0.11.NEXT".'
    ],
    [
      (input) => (input.packageDirectory.versionName = "Version 2.0.11"),
      'versionName must be "Version 2.0.12"; found "Version 2.0.11".'
    ],
    [
      (input) => (input.frameworkVersion = undefined),
      'RecordHealthCheckLifecyclePublisher.FRAMEWORK_VERSION must be "2.0.12"; found "missing".'
    ]
  ];
  for (const [mutate, expected] of cases) {
    const input = synced();
    mutate(input);
    assert.deepEqual(versionSyncErrors(input), [expected]);
  }
});
