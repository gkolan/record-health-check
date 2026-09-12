import assert from "node:assert/strict";
import test from "node:test";
import { missingDefaults } from "./metadata-defaults.mjs";
test("backfill only declared defaults on blank fields and preserve false, zero and choices", () => {
  const fields = [
    { name: "rhc__Mode__c", defaultValue: "AUTO" },
    { name: "rhc__Enabled__c", defaultValue: true },
    { name: "rhc__Limit__c", defaultValue: 10 },
    { name: "rhc__Rule__c", defaultValue: null }
  ];
  assert.deepEqual(
    missingDefaults(
      { rhc__Mode__c: null, rhc__Enabled__c: false, rhc__Limit__c: 0 },
      fields
    ),
    { rhc__Mode__c: "AUTO" }
  );
  assert.deepEqual(
    missingDefaults({ rhc__Mode__c: "HIDE" }, fields.slice(0, 1)),
    {}
  );
});
test("standard fields and defaults without a value are never synthesized", () => {
  assert.deepEqual(
    missingDefaults({}, [
      { name: "Language", defaultValue: "en_US" },
      { name: "rhc__Rule__c", defaultValue: null }
    ]),
    {}
  );
});
