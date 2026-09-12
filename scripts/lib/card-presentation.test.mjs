import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";
const base = "packages/record-health-check/force-app/main/default";
const read = (path) => fs.readFileSync(`${base}/${path}`, "utf8");

function layoutSections(layout) {
  return [
    ...layout.matchAll(/<layoutSections>([\s\S]*?)<\/layoutSections>/g)
  ].map(([, section]) => ({
    label: section.match(/<label\s*>([^<]+)<\/label>/)?.[1],
    style: section.match(/<style\s*>([^<]+)<\/style>/)?.[1],
    columns: [
      ...section.matchAll(/<layoutColumns\s*>([\s\S]*?)<\/layoutColumns>/g)
    ].map(([, column]) =>
      [...column.matchAll(/<field\s*>([^<]+)<\/field>/g)].map(([, field]) =>
        field.trim()
      )
    )
  }));
}

const expectedLayoutJourney = {
  "Record_Health_Check__mdt-Record Health Check Layout.layout-meta.xml": [
    [
      "1. Check basics",
      "TwoColumnsLeftToRight",
      [
        [
          "MasterLabel",
          "Record_Health_Check_Set__c",
          "EvaluationType__c",
          "Category__c",
          "FailureSeverity__c",
          "IsActive__c"
        ],
        [
          "DeveloperName",
          "EvaluationOrder__c",
          "IsProtected",
          "NamespacePrefix"
        ]
      ]
    ],
    [
      "2. Result messages",
      "OneColumn",
      [
        [
          "CheckTitle__c",
          "CheckDescription__c",
          "FailureMessage__c",
          "FixMessage__c",
          "UnableToEvaluateMessage__c"
        ]
      ]
    ],
    [
      "3. Optional action",
      "TwoColumnsLeftToRight",
      [["ActionLabel__c"], ["ActionUrl__c"]]
    ],
    [
      "4A. Formula evaluation (Formula only)",
      "OneColumn",
      [["FormulaResultType__c", "PassConditionFormula__c"]]
    ],
    [
      "4B. Query result (Query only)",
      "OneColumn",
      [
        [
          "SourceQuery__c",
          "SourceQueryField__c",
          "QueryResultHandling__c",
          "FindInListFormula__c"
        ]
      ]
    ],
    [
      "4C. Expected value (Query only)",
      "OneColumn",
      [
        [
          "ExpectedValueSource__c",
          "ExpectedFixedValue__c",
          "ExpectedCurrencyIsoCode__c",
          "ExpectedRecordFormula__c",
          "ComparisonQuery__c",
          "ComparisonQueryField__c"
        ]
      ]
    ],
    [
      "4D. Pass and empty rules (Query only)",
      "OneColumn",
      [
        [
          "ComparisonOperator__c",
          "NoRowsResult__c",
          "EmptyValueHandling__c",
          "MaxQueryRows__c"
        ]
      ]
    ],
    [
      "4E. Apex evaluation (Apex only)",
      "OneColumn",
      [["ApexClass__c", "ApexParametersJson__c"]]
    ],
    [
      "5. Applicability and prerequisite",
      "OneColumn",
      [
        [
          "ApplicabilityMode__c",
          "PrerequisiteCheck__c",
          "ApplicabilityFormula__c",
          "ApplicabilityCountQuery__c",
          "ApplicabilityCountOperator__c",
          "ApplicabilityCountThreshold__c",
          "ApplicabilityNotMetMessage__c"
        ]
      ]
    ],
    [
      "6. Values shown on the card",
      "OneColumn",
      [
        [
          "ComparisonDisplayMode__c",
          "DisplayValueFormat__c",
          "DisplayFoundText__c",
          "DisplayFoundFormula__c",
          "DisplayExpectedText__c",
          "DisplayExpectedFormula__c"
        ]
      ]
    ],
    ["7. Platform events", "OneColumn", [["PublishUserResultEvent__c"]]]
  ],
  "Record_Health_Check_Set__mdt-Record Health Check Set Layout.layout-meta.xml":
    [
      [
        "1. Check Set basics",
        "TwoColumnsLeftToRight",
        [
          ["MasterLabel", "ObjectApiName__c", "IsActive__c", "IsProtected"],
          ["DeveloperName", "NamespacePrefix"]
        ]
      ],
      [
        "2. Card heading",
        "OneColumn",
        [["CardHeadingDisplay__c", "CardTitle__c", "CardSubtitle__c"]]
      ],
      [
        "3. Run experience",
        "OneColumn",
        [["CardRunMode__c", "CardRevealMode__c"]]
      ],
      [
        "4. Run button",
        "TwoColumnsLeftToRight",
        [
          ["RunButtonDisplay__c", "RunButtonLabel__c"],
          ["RunButtonIcon__c", "RerunButtonLabel__c"]
        ]
      ],
      [
        "5. Check results",
        "TwoColumnsLeftToRight",
        [
          ["SummaryDisplay__c", "PassedChecksDisplay__c"],
          ["FoundExpectedDisplay__c", "SkippedChecksDisplay__c"]
        ]
      ],
      [
        "6. Errors and diagnostics",
        "TwoColumnsLeftToRight",
        [["StopOnSystemError__c"], ["ShowDiagnostics__c"]]
      ],
      [
        "7. Platform events",
        "TwoColumnsLeftToRight",
        [["PublishUserRunEvent__c"], ["PublishErrorLogEvent__c"]]
      ]
    ]
};

test("Check and Check Set layouts guide administrators through the build journey", () => {
  for (const [file, expected] of Object.entries(expectedLayoutJourney)) {
    const actual = layoutSections(read(`layouts/${file}`)).map(
      ({ label, style, columns }) => [label, style, columns]
    );
    assert.deepEqual(actual, expected, file);
  }
});

test("every Check and Check Set field is present exactly once on its layout", () => {
  for (const object of [
    "Record_Health_Check__mdt",
    "Record_Health_Check_Set__mdt"
  ]) {
    const file = fs
      .readdirSync(`${base}/layouts`)
      .find((name) => name.startsWith(object + "-"));
    const layout = read(`layouts/${file}`);
    const placed = [...layout.matchAll(/<field\s*>([^<]+)<\/field>/g)].map(
      (m) => m[1]
    );
    for (const field of fs.readdirSync(`${base}/objects/${object}/fields`)) {
      const name = field.replace(".field-meta.xml", "");
      assert.equal(
        placed.filter((value) => value === name).length,
        1,
        `${object}.${name}`
      );
    }
  }
});
test("summary supports Hide while keeping Show below checks as the default", () => {
  const xml = read(
    "objects/Record_Health_Check_Set__mdt/fields/SummaryDisplay__c.field-meta.xml"
  );
  assert.match(xml, /<fullName>HIDE<\/fullName>/);
  assert.match(xml, /<fullName>BOTTOM<\/fullName>\s*<default>true<\/default>/);
});
test("bare card leaves radius clearance above and below accents and only separates adjacent rows", () => {
  const css = read("lwc/recordHealthCheck/recordHealthCheck.css");
  assert.match(
    css,
    /\.rhc-body--bare-top\s*\{[^}]*padding-top:\s*var\(--rhc-theme-card-radius\)/
  );
  assert.match(
    css,
    /\.rhc-list:not\(:empty\):last-child\s*\{[^}]*padding-bottom:\s*var\(--rhc-theme-card-radius\)/
  );
  assert.match(css, /\.rhc-row \+ \.rhc-row\s*\{[^}]*border-top:/);
});

test("a top summary does not draw a divider against a hidden heading and action", () => {
  const css = read("lwc/recordHealthCheck/recordHealthCheck.css");
  assert.match(
    css,
    /\.rhc-body--bare-top \.rhc-stats-bar\[data-summary-position="top"\]\s*\{[^}]*border-top:\s*0\s*;/
  );
});

test("bare-card fixtures provide one and two record-dependent PASS/FAIL Checks", () => {
  const metadata =
    "packages/record-health-check/integration-tests/main/default/customMetadata";
  for (const [name, count] of [
    ["RHC_Bare_One", 1],
    ["RHC_Bare_Two", 2]
  ]) {
    const set = fs.readFileSync(
      `${metadata}/Record_Health_Check_Set.${name}.md-meta.xml`,
      "utf8"
    );
    for (const field of [
      "CardHeadingDisplay__c",
      "RunButtonDisplay__c",
      "SummaryDisplay__c"
    ]) {
      assert.match(
        set,
        new RegExp(`<field>${field}</field>\\s*<value[^>]*>HIDE</value>`)
      );
    }
    for (let i = 1; i <= count; i++) {
      const check = fs.readFileSync(
        `${metadata}/Record_Health_Check.${name}_Employees${i}.md-meta.xml`,
        "utf8"
      );
      assert.ok(check.includes(`>${name}</value>`));
      assert.ok(check.includes("BLANKVALUE(NumberOfEmployees, 0) &gt; 0"));
    }
    assert.ok(
      fs
        .readFileSync(
          "packages/record-health-check/integration-tests/card-bare-display.md",
          "utf8"
        )
        .includes(name)
    );
  }
});
