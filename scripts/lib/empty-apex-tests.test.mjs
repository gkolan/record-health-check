import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";
import {
  discoverApexTestClasses,
  isEmptyApexTestClass
} from "./apex-test-inventory.mjs";

test("recognizes empty test shells without treating helpers or executable tests as empty", () => {
  for (const source of [
    "@IsTest private class Empty {}",
    "/* explanation */ @IsTest(SeeAllData=false) private with sharing class Empty { // TODO\n }"
  ]) {
    assert.equal(isEmptyApexTestClass(source), true);
  }
  for (const source of [
    "public class Marker {}",
    "@IsTest private class Real { @IsTest static void runs() {} }",
    "@IsTest public class Factory { public static String value() { return '/* not a comment */'; } }",
    "@IsTest private class Outer { private class Inner {} }"
  ]) {
    assert.equal(isEmptyApexTestClass(source), false);
  }
});

test("package test shells require an explicit executable integration overlay", () => {
  const base = "packages/record-health-check";
  const packaged = path.join(base, "force-app/main/default/classes");
  const integration = path.join(base, "integration-tests/main/default/classes");
  const overlays = new Set(
    JSON.parse(fs.readFileSync("config/apex-test-overlays.json", "utf8"))
      .classes
  );
  const executableIntegrationClasses = new Set(
    discoverApexTestClasses(process.cwd(), [integration]).map(
      (entry) => entry.className
    )
  );
  const unsupported = fs.readdirSync(packaged).filter((name) => {
    if (!name.endsWith(".cls")) {
      return false;
    }
    if (
      !isEmptyApexTestClass(fs.readFileSync(path.join(packaged, name), "utf8"))
    ) {
      return false;
    }
    const counterpart = path.join(integration, name);
    return (
      !overlays.has(path.basename(name, ".cls")) ||
      !fs.existsSync(counterpart) ||
      !executableIntegrationClasses.has(path.basename(name, ".cls"))
    );
  });
  assert.deepEqual(
    unsupported,
    [],
    "Empty test shells must not inflate the package inventory."
  );
});
