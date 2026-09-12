import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";

const metadataRoot =
  "packages/record-health-check/force-app/main/default/objects";

const expectedPicklists = {
  Record_Health_Check__mdt: {
    ApplicabilityCountOperator__c: {
      defaultValue: null,
      labels: [
        "Equal to",
        "Not equal to",
        "Greater than",
        "At least",
        "Less than",
        "At most"
      ]
    },
    ApplicabilityMode__c: {
      defaultValue: "ALL_RECORDS",
      labels: [
        "All records",
        "When a formula is true",
        "When a count query matches"
      ]
    },
    Category__c: {
      defaultValue: null,
      labels: [
        "Completeness",
        "Consistency",
        "Timeliness",
        "Eligibility",
        "Readiness",
        "Risk",
        "Compliance",
        "Relationship coverage"
      ]
    },
    ComparisonDisplayMode__c: {
      defaultValue: "AUTOMATIC",
      labels: ["Automatic", "Show found only", "Show expected only", "Hide"]
    },
    ComparisonOperator__c: {
      defaultValue: null,
      labels: [
        "Equal to",
        "Not equal to",
        "Greater than",
        "At least",
        "Less than",
        "At most",
        "Contains text",
        "Does not contain text",
        "Is empty",
        "Is not empty",
        "List contains any",
        "List contains none",
        "Lists overlap",
        "Lists contain all",
        "Lists match exactly"
      ]
    },
    DisplayValueFormat__c: {
      defaultValue: "AUTO",
      labels: [
        "Automatic",
        "Number",
        "Currency",
        "Percent",
        "Ratio as percent",
        "Checkbox",
        "Date",
        "Date/Time",
        "Text",
        "Raw"
      ]
    },
    EmptyValueHandling__c: {
      defaultValue: "AS_NO_MATCH",
      labels: ["Ignore the record", "Treat as blank", "Treat as not matching"]
    },
    EvaluationType__c: {
      defaultValue: null,
      labels: [
        "Verify with a formula",
        "Verify with a query",
        "Compare two queries",
        "Verify with Apex"
      ]
    },
    ExpectedValueSource__c: {
      defaultValue: null,
      labels: ["Fixed value", "Record formula", "Comparison query"]
    },
    FailureSeverity__c: {
      defaultValue: "WARNING",
      labels: ["Critical", "Warning", "Info"]
    },
    FormulaResultType__c: {
      defaultValue: "AUTO",
      labels: ["Automatic", "Checkbox", "Number", "Date", "Date/Time", "Text"]
    },
    NoRowsResult__c: {
      defaultValue: null,
      labels: ["Pass", "Fail", "Skip", "Unable to evaluate"]
    },
    QueryResultHandling__c: {
      defaultValue: "ONE_RESULT",
      labels: [
        "One row or aggregate",
        "Any record passes",
        "Every record passes",
        "Compare as lists"
      ]
    }
  },
  Record_Health_Check_Set__mdt: {
    CardHeadingDisplay__c: {
      defaultValue: "TITLE_AND_SUBTITLE",
      labels: ["Show title and subtitle", "Show title only", "Hide"]
    },
    CardRevealMode__c: {
      defaultValue: "ONE_BY_ONE",
      labels: ["All at once", "One by one"]
    },
    CardRunMode__c: {
      defaultValue: "RUN_ON_REQUEST",
      labels: ["When the page opens", "When the user clicks Run"]
    },
    FoundExpectedDisplay__c: {
      defaultValue: "ON_DEMAND",
      labels: [
        "Show on demand",
        "Show for failed checks",
        "Show for every check"
      ]
    },
    PassedChecksDisplay__c: {
      defaultValue: "SHOW_EACH_CHECK",
      labels: ["Show each passed check", "Show passed count only"]
    },
    RunButtonDisplay__c: {
      defaultValue: "LABEL_AND_ICON",
      labels: [
        "Show label and icon",
        "Show label only",
        "Show icon only",
        "Hide"
      ]
    },
    SkippedChecksDisplay__c: {
      defaultValue: "SHOW_EACH_CHECK",
      labels: ["Show each skipped check", "Show skipped count only"]
    },
    SummaryDisplay__c: {
      defaultValue: "BOTTOM",
      labels: ["Show above checks", "Show below checks", "Hide"]
    }
  }
};

function normalizedXml(file) {
  return fs.readFileSync(file, "utf8").replace(/\s+/g, " ");
}

function valuesFrom(xml) {
  const definition = xml.match(
    /<valueSetDefinition>(.*?)<\/valueSetDefinition>/
  )?.[1];
  assert.ok(definition, "Picklist must define its values inline");
  return [...definition.matchAll(/<value\s*>(.*?)<\/value>/g)].map(
    ([, value]) => ({
      apiName: value.match(/<fullName\s*>([^<]+)<\/fullName>/)[1],
      label: value.match(/<label\s*>([^<]+)<\/label>/)[1],
      isDefault: value.match(/<default\s*>([^<]+)<\/default>/)[1] === "true"
    })
  );
}

test("every Check and Check Set picklist follows the complete label and default contract", () => {
  for (const [objectName, fields] of Object.entries(expectedPicklists)) {
    const directory = path.join(metadataRoot, objectName, "fields");
    const actualPicklists = fs
      .readdirSync(directory)
      .filter((name) =>
        normalizedXml(path.join(directory, name)).includes(
          "<type>Picklist</type>"
        )
      )
      .map((name) => name.replace(".field-meta.xml", ""))
      .sort();
    assert.deepEqual(
      actualPicklists,
      Object.keys(fields).sort(),
      `${objectName} picklist inventory`
    );

    for (const [fieldName, contract] of Object.entries(fields)) {
      const xml = normalizedXml(
        path.join(directory, `${fieldName}.field-meta.xml`)
      );
      const values = valuesFrom(xml);
      assert.deepEqual(
        values.map(({ label }) => label),
        contract.labels,
        `${objectName}.${fieldName} labels`
      );
      assert.deepEqual(
        values
          .filter(({ isDefault }) => isDefault)
          .map(({ apiName }) => apiName),
        contract.defaultValue ? [contract.defaultValue] : [],
        `${objectName}.${fieldName} default`
      );
    }
  }
});

test("every checkbox and safe numeric field has a source default", () => {
  const expectedScalarDefaults = {
    Record_Health_Check__mdt: {
      EvaluationOrder__c: "100",
      IsActive__c: "true",
      MaxQueryRows__c: "200",
      PublishUserResultEvent__c: "false"
    },
    Record_Health_Check_Set__mdt: {
      IsActive__c: "true",
      PublishErrorLogEvent__c: "false",
      PublishUserRunEvent__c: "false",
      ShowDiagnostics__c: "false",
      StopOnSystemError__c: "false"
    }
  };
  for (const [objectName, fields] of Object.entries(expectedScalarDefaults)) {
    for (const [fieldName, expected] of Object.entries(fields)) {
      const xml = normalizedXml(
        path.join(
          metadataRoot,
          objectName,
          "fields",
          `${fieldName}.field-meta.xml`
        )
      );
      assert.equal(
        xml.match(/<defaultValue\s*>([^<]+)<\/defaultValue>/)?.[1],
        expected,
        `${objectName}.${fieldName}`
      );
    }
  }
});

test("administrator validation uses the same visible comparison choices", () => {
  const source = fs.readFileSync(
    "packages/record-health-check/force-app/main/default/classes/RecordHealthCheckMetadataIssueMapper.cls",
    "utf8"
  );
  assert.ok(
    source.includes(
      "Show Found and Expected must be Automatic, Show found only, Show expected only, or Hide."
    )
  );
  assert.ok(source.includes("Show Found and Expected is set to Hide"));
});

test("every packaged and integration record persists each safe default as a value", () => {
  const metadataDirectories = [
    "packages/record-health-check/force-app/main/default/customMetadata",
    "packages/record-health-check/integration-tests/main/default/customMetadata",
    "packages/record-health-check/integration-tests/foreign-apex-namespace/main/default/customMetadata",
    "packages/record-health-check/integration-tests/foreign-namespace/main/default/customMetadata"
  ];
  const requiredFieldsByPrefix = {
    "Record_Health_Check.": [
      "ApplicabilityMode__c",
      "ComparisonDisplayMode__c",
      "DisplayValueFormat__c",
      "EmptyValueHandling__c",
      "EvaluationOrder__c",
      "FailureSeverity__c",
      "FormulaResultType__c",
      "IsActive__c",
      "MaxQueryRows__c",
      "PublishUserResultEvent__c",
      "QueryResultHandling__c"
    ],
    "Record_Health_Check_Set.": [
      "CardHeadingDisplay__c",
      "CardRevealMode__c",
      "CardRunMode__c",
      "FoundExpectedDisplay__c",
      "IsActive__c",
      "PassedChecksDisplay__c",
      "PublishErrorLogEvent__c",
      "PublishUserRunEvent__c",
      "RunButtonDisplay__c",
      "ShowDiagnostics__c",
      "SkippedChecksDisplay__c",
      "StopOnSystemError__c",
      "SummaryDisplay__c"
    ]
  };

  for (const metadataDirectory of metadataDirectories) {
    for (const [prefix, requiredFields] of Object.entries(
      requiredFieldsByPrefix
    )) {
      for (const fileName of fs
        .readdirSync(metadataDirectory)
        .filter((name) => name.startsWith(prefix))) {
        const xml = normalizedXml(path.join(metadataDirectory, fileName));
        for (const fieldName of requiredFields) {
          const valueBlock = [...xml.matchAll(/<values\s*>(.*?)<\/values>/g)]
            .map(([, block]) => block)
            .find((block) => block.includes(`<field>${fieldName}</field>`));
          assert.ok(
            valueBlock &&
              !/<value[^>]*xsi:nil=["']true["']/.test(valueBlock) &&
              /<value(?:\s[^>]*)?>([^<]+)<\/value>/.test(valueBlock),
            `${path.relative(".", path.join(metadataDirectory, fileName))} must persist a nonblank ${fieldName}`
          );
        }
      }
    }
  }
});
