import assert from "node:assert/strict";
import test from "node:test";
import {
  assertPackageObjectBoundary,
  assertRunOnlyCustomPermission
} from "./package-object-boundary.mjs";

test("rejects the non-customizable CustomPermission object introduced by a Setup list view", () => {
  for (const [type, member] of [
    ["CustomObject", "CustomPermission"],
    ["ListView", "CustomPermission.Record_Health_Check"],
    ["CustomField", "CustomPermission.Invalid__c"]
  ]) {
    assert.throws(
      () =>
        assertPackageObjectBoundary(
          `<types><members>${member}</members><name>${type}</name></types>`
        ),
      /not a customizable object/
    );
  }
});

test("only Run is accepted in the converted CustomPermission inventory", () => {
  const manifest = (names) =>
    `<types>${names.map((name) => `<members>${name}</members>`).join("")}<name>CustomPermission</name></types>`;
  assert.doesNotThrow(() =>
    assertRunOnlyCustomPermission(manifest(["Record_Health_Check_Run"]))
  );
  for (const names of [
    [],
    ["*"],
    ["Record_Health_Check_View_Diagnostics"],
    ["Record_Health_Check_Run", "Record_Health_Check_View_Diagnostics"]
  ]) {
    assert.throws(
      () => assertRunOnlyCustomPermission(manifest(names)),
      /only custom permission/
    );
  }
});

test("retains real custom permissions and supported Custom Metadata list views", () => {
  assert.doesNotThrow(() =>
    assertPackageObjectBoundary(
      "<types><members>Record_Health_Check_Run</members><name>CustomPermission</name></types><types><members>Record_Health_Check__mdt.All</members><name>ListView</name></types>"
    )
  );
});
