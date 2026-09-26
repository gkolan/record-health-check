import assert from "node:assert/strict";
import test from "node:test";
import { selectCardUserPermissionSet } from "./browser-permission-set.mjs";

const unpackaged = {
  Id: "0PS-unpackaged",
  Name: "Record_Health_Check_Card_User",
  NamespacePrefix: null
};
const packaged = {
  Id: "0PS-packaged",
  Name: "Record_Health_Check_Card_User",
  NamespacePrefix: "rhc"
};

test("selects the managed package permission set when subscriber harness metadata has the same name", () => {
  assert.equal(
    selectCardUserPermissionSet([unpackaged, packaged], {
      installedPackage: "04t-candidate"
    }),
    packaged
  );
});

test("preserves the single-source permission set contract without an installed package", () => {
  assert.equal(
    selectCardUserPermissionSet([unpackaged], { installedPackage: null }),
    unpackaged
  );
});

test("fails closed when the installed package permission set is absent", () => {
  assert.throws(
    () =>
      selectCardUserPermissionSet([unpackaged], {
        installedPackage: "04t-candidate"
      }),
    /Expected one namespaced package Card User permission set; found 0/
  );
});
