import assert from "node:assert/strict";
import test from "node:test";
import {
  incompatibleHiddenManualCheckSets,
  upgradeCompatibilityQuery
} from "./upgrade-2.0.11-compatibility.mjs";

test("finds only hidden manual-run Check Sets", () => {
  const records = [
    {
      DeveloperName: "Hidden_Manual",
      MasterLabel: "Hidden manual",
      rhc__CardHeadingDisplay__c: "HIDE",
      rhc__CardRunMode__c: "RUN_ON_REQUEST",
      rhc__RunButtonDisplay__c: "SHOW"
    },
    {
      DeveloperName: "Hidden_On_Load",
      rhc__CardHeadingDisplay__c: "HIDE",
      rhc__CardRunMode__c: "RUN_ON_LOAD"
    },
    {
      DeveloperName: "Shown_Manual",
      rhc__CardHeadingDisplay__c: "SHOW",
      rhc__CardRunMode__c: "RUN_ON_REQUEST"
    }
  ];

  assert.deepEqual(incompatibleHiddenManualCheckSets(records, "rhc"), [
    {
      developerName: "Hidden_Manual",
      label: "Hidden manual",
      headingDisplay: "HIDE",
      runMode: "RUN_ON_REQUEST",
      runButtonDisplay: "SHOW"
    }
  ]);
});

test("supports unpackaged field names for source-org diagnosis", () => {
  const records = [
    {
      DeveloperName: "Source_Hidden_Manual",
      CardHeadingDisplay__c: "HIDE",
      CardRunMode__c: "RUN_ON_REQUEST",
      RunButtonDisplay__c: "HIDE"
    }
  ];

  assert.equal(incompatibleHiddenManualCheckSets(records, "").length, 1);
  assert.match(upgradeCompatibilityQuery(""), /CardHeadingDisplay__c/);
  assert.doesNotMatch(upgradeCompatibilityQuery(""), /rhc__/);
});

test("builds an exact namespaced compatibility query", () => {
  const query = upgradeCompatibilityQuery("rhc");
  assert.match(query, /FROM rhc__Record_Health_Check_Set__mdt/);
  assert.match(query, /rhc__CardHeadingDisplay__c = 'HIDE'/);
  assert.match(query, /rhc__CardRunMode__c = 'RUN_ON_REQUEST'/);
  assert.match(query, /ORDER BY DeveloperName/);
});

test("rejects malformed records instead of silently clearing the audit", () => {
  assert.throws(
    () =>
      incompatibleHiddenManualCheckSets([{ DeveloperName: "Broken" }], "rhc"),
    /missing CardHeadingDisplay__c/
  );
});
