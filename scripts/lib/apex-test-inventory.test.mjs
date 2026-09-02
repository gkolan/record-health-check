import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import {
  discoverApexTestClasses,
  verifyApexTestResult
} from "./apex-test-inventory.mjs";

test("discovers class-level IsTest annotations and ignores comments", () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "rhc-apex-inventory-"));
  const classes = path.join(root, "classes");
  fs.mkdirSync(classes);
  fs.writeFileSync(
    path.join(classes, "RealTest.cls"),
    "@IsTest private class RealTest { @IsTest static void runs() {} }"
  );
  fs.writeFileSync(
    path.join(classes, "CommentOnly.cls"),
    "// @IsTest\npublic class CommentOnly { String value = '@IsTest'; }"
  );
  fs.writeFileSync(
    path.join(classes, "MethodOnly.cls"),
    "public class MethodOnly { @IsTest static void notAClassAnnotation() {} }"
  );

  assert.deepEqual(discoverApexTestClasses(root, ["classes"]), [
    {
      className: "RealTest",
      file: "classes/RealTest.cls",
      files: ["classes/RealTest.cls"],
      testSetupMethodCount: 0
    }
  ]);
});

test("excludes IsTest helpers without executable test methods", () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "rhc-apex-helpers-"));
  const classes = path.join(root, "classes");
  fs.mkdirSync(classes);
  fs.writeFileSync(
    path.join(classes, "TestDataFactory.cls"),
    "@IsTest public class TestDataFactory { public static Account account() { return new Account(); } }"
  );
  fs.writeFileSync(
    path.join(classes, "LegacyTest.cls"),
    "@IsTest private class LegacyTest { static testMethod void runs() {} }"
  );

  assert.deepEqual(
    discoverApexTestClasses(root, ["classes"]).map((entry) => entry.className),
    ["LegacyTest"]
  );
});

test("allows only declared last-deployed test overlays", () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "rhc-apex-overlay-"));
  for (const directory of ["package", "integration"]) {
    fs.mkdirSync(path.join(root, directory));
    fs.writeFileSync(
      path.join(root, directory, "OverlayTest.cls"),
      `@IsTest private class OverlayTest { @IsTest static void ${directory}() {} }`
    );
  }

  assert.throws(
    () => discoverApexTestClasses(root, ["package", "integration"]),
    /Unexpected duplicate Apex test class OverlayTest/
  );
  const [entry] = discoverApexTestClasses(root, ["package", "integration"], {
    overlayClassNames: ["OverlayTest"]
  });
  assert.equal(entry.file, "integration/OverlayTest.cls");
  assert.deepEqual(entry.files, [
    "package/OverlayTest.cls",
    "integration/OverlayTest.cls"
  ]);
});

test("allows an approved empty placeholder before an executable overlay", () => {
  const root = fs.mkdtempSync(
    path.join(os.tmpdir(), "rhc-apex-placeholder-overlay-")
  );
  fs.mkdirSync(path.join(root, "package"));
  fs.mkdirSync(path.join(root, "integration"));
  fs.writeFileSync(
    path.join(root, "package", "OverlayTest.cls"),
    "@IsTest private class OverlayTest {}"
  );
  fs.writeFileSync(
    path.join(root, "integration", "OverlayTest.cls"),
    "@IsTest private class OverlayTest { @IsTest static void runs() {} }"
  );

  const [entry] = discoverApexTestClasses(root, ["package", "integration"], {
    overlayClassNames: ["OverlayTest"]
  });

  assert.equal(entry.file, "integration/OverlayTest.cls");
  assert.deepEqual(entry.files, [
    "package/OverlayTest.cls",
    "integration/OverlayTest.cls"
  ]);
});

test("accepts an exact, passing Salesforce result", () => {
  const verdict = verifyApexTestResult(
    [{ className: "OneTest", file: "OneTest.cls" }],
    {
      summary: {
        outcome: "Passed",
        failing: 0,
        testsRan: 2,
        testRunId: "707000000000001",
        orgWideCoverage: "99%",
        testRunCoverage: "100%"
      },
      tests: [
        { Outcome: "Pass", ApexClass: { Name: "OneTest" } },
        { Outcome: "Pass", ApexClass: { Name: "OneTest" } }
      ]
    }
  );

  assert.equal(verdict.requestedClassCount, 1);
  assert.equal(verdict.executedMethodCount, 2);
});

test("reconciles TestSetup methods counted only in Salesforce summary", () => {
  const verdict = verifyApexTestResult(
    [
      {
        className: "OneTest",
        file: "OneTest.cls",
        testSetupMethodCount: 1
      }
    ],
    {
      summary: {
        outcome: "Passed",
        failing: 0,
        testsRan: 3,
        testRunId: "707000000000001"
      },
      tests: [
        { Outcome: "Pass", ApexClass: { Name: "OneTest" } },
        { Outcome: "Pass", ApexClass: { Name: "OneTest" } }
      ]
    }
  );

  assert.equal(verdict.executedMethodCount, 2);
  assert.equal(verdict.testSetupMethodCount, 1);
  assert.equal(verdict.salesforceMethodCount, 3);
});

test("fails when Salesforce omits an inventoried class", () => {
  assert.throws(
    () =>
      verifyApexTestResult(
        [
          { className: "OneTest", file: "OneTest.cls" },
          { className: "MissingTest", file: "MissingTest.cls" }
        ],
        {
          summary: { outcome: "Passed", failing: 0, testsRan: 1 },
          tests: [{ Outcome: "Pass", ApexClass: { Name: "OneTest" } }]
        }
      ),
    /Missing test classes: MissingTest/
  );
});

test("fails on non-passing methods or a mismatched method count", () => {
  const inventory = [{ className: "OneTest", file: "OneTest.cls" }];
  assert.throws(
    () =>
      verifyApexTestResult(inventory, {
        summary: { outcome: "Failed", failing: 1, testsRan: 1 },
        tests: [{ Outcome: "Fail", ApexClass: { Name: "OneTest" } }]
      }),
    /did not pass/
  );
  assert.throws(
    () =>
      verifyApexTestResult(inventory, {
        summary: { outcome: "Passed", failing: 0, testsRan: 2 },
        tests: [{ Outcome: "Pass", ApexClass: { Name: "OneTest" } }]
      }),
    /reports 2 methods but contains 1/
  );
});
