import assert from "node:assert/strict";
import test from "node:test";
import { unexcusedAdvisories } from "./dependency-audit-exceptions.mjs";

const exceptions = [
  { id: "GHSA-vfj7-8cjw-p6xm", package: "braces", expires: "2026-11-06" }
];

function report(...advisories) {
  const vulnerabilities = {};
  for (const [name, id] of advisories) {
    vulnerabilities[name] = {
      via: [{ name, url: `https://github.com/advisories/${id}`, title: "x" }]
    };
  }
  // A dependent package lists the advisory only by name; it adds nothing new.
  vulnerabilities.micromatch = { via: ["braces"] };
  return JSON.stringify({ vulnerabilities });
}

test("excuses only the listed advisory on the listed package before expiry", () => {
  assert.deepEqual(
    unexcusedAdvisories(
      report(["braces", "GHSA-vfj7-8cjw-p6xm"]),
      "2026-10-06",
      exceptions
    ),
    []
  );
});

test("fails once the exception expires", () => {
  assert.deepEqual(
    unexcusedAdvisories(
      report(["braces", "GHSA-vfj7-8cjw-p6xm"]),
      "2026-11-07",
      exceptions
    ),
    ["braces GHSA-vfj7-8cjw-p6xm"]
  );
});

test("fails for any other advisory, or the same ID on another package", () => {
  assert.deepEqual(
    unexcusedAdvisories(
      report(
        ["braces", "GHSA-vfj7-8cjw-p6xm"],
        ["axios", "GHSA-aaaa-bbbb-cccc"],
        ["other", "GHSA-vfj7-8cjw-p6xm"]
      ),
      "2026-10-06",
      exceptions
    ),
    ["axios GHSA-aaaa-bbbb-cccc", "other GHSA-vfj7-8cjw-p6xm"]
  );
});

test("an unreadable or empty report never passes", () => {
  assert.throws(() => unexcusedAdvisories("", "2026-10-06", exceptions));
  assert.throws(() => unexcusedAdvisories("{}", "2026-10-06", exceptions));
});
