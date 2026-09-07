import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { demoOutcomeCoverageGaps } from "./demo-outcome-coverage.mjs";

function writeCheck(directory, name, fields) {
  const values = Object.entries(fields)
    .map(
      ([field, value]) =>
        `<values><field>${field}</field><value>${value}</value></values>`
    )
    .join("");
  fs.writeFileSync(
    path.join(directory, `Record_Health_Check.${name}.md-meta.xml`),
    `<CustomMetadata>${values}</CustomMetadata>`
  );
}

test("requires opposite and applicable non-result outcomes", () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "rhc-outcomes-"));
  writeCheck(directory, "Example_One", {
    Record_Health_Check_Set__c: "Example_Set",
    IsActive__c: "true",
    ApplicabilityMode__c: "WHEN_FORMULA_TRUE",
    NoRowsResult__c: "UNABLE_TO_EVALUATE"
  });
  const gaps = demoOutcomeCoverageGaps(directory, {
    Account: {
      checkSet: "Example_Set",
      records: {
        Ready: { Example_One: "PASS" },
        Review: { Example_One: "FAIL" }
      }
    }
  });
  assert.deepEqual(gaps, [
    "Example_One has no expected SKIPPED or UNABLE_TO_EVALUATE outcome."
  ]);
});

test("requires healthy and needs-review Check Set records", () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "rhc-outcomes-"));
  writeCheck(directory, "Example_One", {
    Record_Health_Check_Set__c: "Example_Set",
    IsActive__c: "true",
    ApplicabilityMode__c: "ALL_RECORDS",
    NoRowsResult__c: "FAIL"
  });
  assert.deepEqual(
    demoOutcomeCoverageGaps(directory, {
      Account: {
        checkSet: "Example_Set",
        records: {
          Review: { Example_One: "FAIL" },
          AlsoReview: { Example_One: "FAIL" }
        }
      }
    }),
    [
      "Account has no record with zero failed Checks.",
      "Example_One has no expected PASS outcome."
    ]
  );
});

test("accepts a complete executable outcome contract", () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "rhc-outcomes-"));
  writeCheck(directory, "Example_One", {
    Record_Health_Check_Set__c: "Example_Set",
    IsActive__c: "true",
    ApplicabilityMode__c: "ALL_RECORDS",
    NoRowsResult__c: "FAIL"
  });
  assert.deepEqual(
    demoOutcomeCoverageGaps(directory, {
      Account: {
        checkSet: "Example_Set",
        records: {
          Ready: { Example_One: "PASS" },
          Review: { Example_One: "FAIL" }
        }
      }
    }),
    []
  );
});

test("rejects a misspelled expected status", () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "rhc-outcomes-"));
  writeCheck(directory, "Example_One", {
    Record_Health_Check_Set__c: "Example_Set",
    IsActive__c: "true",
    ApplicabilityMode__c: "ALL_RECORDS",
    NoRowsResult__c: "FAIL"
  });
  assert.deepEqual(
    demoOutcomeCoverageGaps(directory, {
      Account: {
        checkSet: "Example_Set",
        records: {
          Ready: { Example_One: "PASS" },
          Review: { Example_One: "FAILED" },
          Failing: { Example_One: "FAIL" }
        }
      }
    }),
    ["Account / Review / Example_One has unknown status FAILED."]
  );
});
