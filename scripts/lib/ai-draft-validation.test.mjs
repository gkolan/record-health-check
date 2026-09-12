import assert from "node:assert/strict";
import test from "node:test";
import {
  MUST_FILL,
  inventedNameProblems,
  coverageGaps,
  draftFields,
  draftNarrativeProblems,
  draftProblems,
  typeExpectations
} from "./ai-draft-validation.mjs";

const schema = {
  declared: new Set([
    "EvaluationType__c",
    "FormulaResultType__c",
    "CheckTitle__c",
    "PassConditionFormula__c",
    "SourceQuery__c",
    "ComparisonQuery__c",
    "ComparisonOperator__c",
    "QueryResultHandling__c",
    "ExpectedValueSource__c",
    "NoRowsResult__c",
    "MaxQueryRows__c",
    "ActionUrl__c",
    "ApexClass__c",
    "ActionLabel__c",
    "DisplayExpectedText__c",
    "RunButtonDisplay__c",
    "RunButtonLabel__c",
    "RerunButtonLabel__c",
    "RunButtonIcon__c"
  ]),
  picklists: new Map([
    ["EvaluationType__c", ["FORMULA", "QUERY", "COMPARE_TWO_QUERIES", "APEX"]],
    ["FormulaResultType__c", ["AUTO", "BOOLEAN", "TEXT"]],
    ["NoRowsResult__c", ["PASS", "FAIL", "SKIP", "UNABLE_TO_EVALUATE"]],
    [
      "QueryResultHandling__c",
      ["ONE_RESULT", "ANY_ROW_PASSES", "ALL_ROWS_PASS", "COMPARE_AS_LISTS"]
    ],
    [
      "ComparisonOperator__c",
      ["EQUALS", "IS_BLANK", "IS_NOT_BLANK", "LISTS_OVERLAP"]
    ],
    ["RunButtonDisplay__c", ["LABEL_AND_ICON", "HIDE"]],
    ["ExpectedValueSource__c", ["FIXED_VALUE"]]
  ]),
  lengths: new Map([["ActionLabel__c", 80]])
};

const formula = () =>
  new Map([
    ["EvaluationType__c", "FORMULA"],
    ["CheckTitle__c", "Billing address is complete"],
    ["PassConditionFormula__c", "NOT(ISBLANK(BillingCity))"]
  ]);

test("N/A is retained so a non-deployable metadata value is rejected", () => {
  const fields = draftFields(
    [
      "| Setup label | API field name | Proposed value | Why |",
      "| --- | --- | --- | --- |",
      "| Evaluation Type | `EvaluationType__c` | FORMULA | fields on the record |",
      "| Source Query | `SourceQuery__c` | N/A | not used by a Formula Check |",
      "| Pass Condition | PassConditionFormula__c | NOT(ISBLANK(BillingCity)) | rule |"
    ].join("\n")
  );
  assert.equal(fields.get("EvaluationType__c"), "FORMULA");
  assert.equal(
    fields.get("PassConditionFormula__c"),
    "NOT(ISBLANK(BillingCity))"
  );
  assert.equal(fields.get("SourceQuery__c"), "N/A");
  assert.ok(
    draftProblems(fields, schema).some((problem) =>
      /FORMULA must not set SourceQuery__c/.test(problem)
    )
  );
});

test("FormulaResultType is a cross-cutting safe default for every type", () => {
  assert.ok(MUST_FILL.includes("FormulaResultType__c"));
  for (const type of ["FORMULA", "QUERY", "COMPARE_TWO_QUERIES", "APEX"]) {
    const { forbidden } = typeExpectations(
      new Map([["EvaluationType__c", type]])
    );
    assert.ok(!forbidden.includes("FormulaResultType__c"));
  }
});

test("Prettier-escaped Custom Metadata API names remain readable", () => {
  const fields = draftFields(
    [
      "| Setup label | API field name | Proposed value | Why |",
      "| --- | --- | --- | --- |",
      "| Evaluation Type | EvaluationType\\_\\_c | FORMULA | fields on the record |",
      "| Check title | CheckTitle\\_\\_c | Billing address is complete | claim |"
    ].join("\n")
  );
  assert.equal(fields.get("EvaluationType__c"), "FORMULA");
  assert.equal(fields.get("CheckTitle__c"), "Billing address is complete");
});

test("a table with no proposed-value column contributes no values", () => {
  const fields = draftFields(
    [
      "| Setup label | API field name | Proposed value | Why |",
      "| --- | --- | --- | --- |",
      "| Evaluation Type | EvaluationType__c | FORMULA | fields on the record |",
      "",
      "| Setup label | API field name | Why it is unused |",
      "| --- | --- | --- |",
      "| Source Query | SourceQuery__c | An Apex class runs the logic |"
    ].join("\n")
  );
  assert.equal(fields.get("EvaluationType__c"), "FORMULA");
  assert.ok(!fields.has("SourceQuery__c"));
});

test("a sound Formula draft has no problems", () => {
  assert.deepEqual(draftProblems(formula(), schema), []);
});

test("a Formula draft that also proposes a query is reported", () => {
  const fields = formula();
  fields.set("SourceQuery__c", "SELECT COUNT() FROM Contact");
  assert.ok(
    draftProblems(fields, schema).some((problem) =>
      /must not set SourceQuery__c/.test(problem)
    )
  );
});

test("an invented field and a Setup label stored as a value are reported", () => {
  const fields = formula();
  fields.set("FailMessage__c", "Missing");
  fields.set("EvaluationType__c", "Verify with a formula");
  const problems = draftProblems(fields, schema);
  assert.ok(
    problems.some((problem) => /FailMessage__c is not a Check/.test(problem))
  );
  assert.ok(problems.some((problem) => /is not a stored value/.test(problem)));
});

test("a row-handling Query Check without a no-rows decision is reported", () => {
  const fields = new Map([
    ["EvaluationType__c", "QUERY"],
    ["CheckTitle__c", "Open Opportunities have a Next Step"],
    [
      "SourceQuery__c",
      "SELECT NextStep FROM Opportunity WHERE AccountId = {!record.Id}"
    ],
    ["QueryResultHandling__c", "ALL_ROWS_PASS"],
    ["ComparisonOperator__c", "IS_BLANK"]
  ]);
  assert.ok(
    draftProblems(fields, schema).some((problem) =>
      /needs NoRowsResult__c/.test(problem)
    )
  );
});

test("a list search must leave the Source Query blank", () => {
  const listSearch = new Map([
    ["EvaluationType__c", "QUERY"],
    ["ComparisonOperator__c", "LIST_CONTAINS_ANY"]
  ]);
  const { required, forbidden } = typeExpectations(listSearch);
  assert.ok(required.includes("FindInListFormula__c"));
  assert.ok(forbidden.includes("SourceQuery__c"));
});

test("a list operator without list handling is reported", () => {
  const fields = new Map([
    ["EvaluationType__c", "COMPARE_TWO_QUERIES"],
    ["CheckTitle__c", "Lists match"],
    [
      "SourceQuery__c",
      "SELECT Name FROM Opportunity WHERE AccountId = {!record.Id}"
    ],
    ["ComparisonQuery__c", "SELECT Opportunity.Name FROM OpportunityLineItem"],
    ["ComparisonOperator__c", "LISTS_OVERLAP"],
    ["QueryResultHandling__c", "ONE_RESULT"]
  ]);
  assert.ok(
    draftProblems(fields, schema).some((problem) =>
      /requires QueryResultHandling__c = COMPARE_AS_LISTS/.test(problem)
    )
  );
});

test("merge tokens on the wrong surface are reported", () => {
  const fields = new Map([
    ["EvaluationType__c", "QUERY"],
    ["CheckTitle__c", "Contacts exist"],
    ["QueryResultHandling__c", "ONE_RESULT"],
    ["ComparisonOperator__c", "IS_BLANK"],
    [
      "SourceQuery__c",
      "SELECT COUNT() FROM Contact WHERE AccountId = '{!record.Id}'"
    ],
    ["ActionUrl__c", "/lightning/r/Account/{!rhcResult.foundValue}/view"]
  ]);
  const problems = draftProblems(fields, schema);
  assert.ok(problems.some((problem) => /quotes a merge token/.test(problem)));
  assert.ok(
    problems.some((problem) => /ActionUrl__c cannot contain/.test(problem))
  );
});

test("a no-rows decision on a bare COUNT() is reported", () => {
  const fields = new Map([
    ["EvaluationType__c", "QUERY"],
    ["CheckTitle__c", "Open Opportunities have a Next Step"],
    [
      "SourceQuery__c",
      "SELECT COUNT() FROM Opportunity WHERE AccountId = {!record.Id}"
    ],
    ["QueryResultHandling__c", "ONE_RESULT"],
    ["ComparisonOperator__c", "EQUALS"],
    ["ExpectedValueSource__c", "FIXED_VALUE"],
    ["NoRowsResult__c", "SKIP"]
  ]);
  assert.ok(
    draftProblems(fields, schema).some((problem) =>
      /never applies; use ApplicabilityMode__c/.test(problem)
    )
  );
});

test("an AS alias and an object-less action URL are reported", () => {
  const fields = new Map([
    ["EvaluationType__c", "COMPARE_TWO_QUERIES"],
    ["CheckTitle__c", "Products cover open Opportunities"],
    [
      "SourceQuery__c",
      "SELECT COUNT() FROM Opportunity WHERE AccountId = {!record.Id}"
    ],
    [
      "ComparisonQuery__c",
      "SELECT COUNT_DISTINCT(OpportunityId) AS covered FROM OpportunityLineItem"
    ],
    ["QueryResultHandling__c", "ONE_RESULT"],
    ["ComparisonOperator__c", "EQUALS"],
    ["ActionUrl__c", "/lightning/r/{!record.Id}/related/Opportunities/view"]
  ]);
  const problems = draftProblems(fields, schema);
  assert.ok(
    problems.some((problem) => /aliases have no AS keyword/.test(problem))
  );
  assert.ok(
    problems.some((problem) => /omits the object API name/.test(problem))
  );
});

test("a formula field holding a merge token is reported", () => {
  const fields = formula();
  fields.set("PassConditionFormula__c", "NOT(ISBLANK({!record.BillingCity}))");
  assert.ok(
    draftProblems(fields, schema).some((problem) =>
      /cannot contain a merge token/.test(problem)
    )
  );
});

test("a value past its field length is reported", () => {
  const fields = formula();
  fields.set("ActionLabel__c", "x".repeat(81));
  assert.ok(
    draftProblems(fields, schema).some((problem) =>
      /over its 80 limit/.test(problem)
    )
  );
});

test("an Apex draft needs its class and no query settings", () => {
  const fields = new Map([
    ["EvaluationType__c", "APEX"],
    ["CheckTitle__c", "Recent activity"],
    ["SourceQuery__c", "SELECT COUNT() FROM Task"]
  ]);
  const problems = draftProblems(fields, schema);
  assert.ok(problems.some((problem) => /needs ApexClass__c/.test(problem)));
  assert.ok(
    problems.some((problem) => /must not set SourceQuery__c/.test(problem))
  );
});

test("a hidden Run button must not save ignored labels or an icon", () => {
  const fields = formula();
  fields.set("RunButtonDisplay__c", "HIDE");
  fields.set("RunButtonLabel__c", "Run");
  fields.set("RerunButtonLabel__c", "Rerun");
  fields.set("RunButtonIcon__c", "utility:refresh");
  const problems = draftProblems(fields, schema);
  assert.ok(
    problems.some((problem) => /RunButtonLabel__c is ignored/.test(problem))
  );
  assert.ok(
    problems.some((problem) => /RerunButtonLabel__c is ignored/.test(problem))
  );
  assert.ok(
    problems.some((problem) => /RunButtonIcon__c is ignored/.test(problem))
  );
});

test("a unary comparison must not display an absent expected value", () => {
  const fields = new Map([
    ["EvaluationType__c", "QUERY"],
    ["CheckTitle__c", "Open Opportunities have a Next Step"],
    ["SourceQuery__c", "SELECT NextStep FROM Opportunity"],
    ["QueryResultHandling__c", "ALL_ROWS_PASS"],
    ["ComparisonOperator__c", "IS_NOT_BLANK"],
    ["NoRowsResult__c", "SKIP"],
    ["DisplayExpectedText__c", "Expected {!rhcResult.expectedValue}"]
  ]);
  assert.ok(
    draftProblems(fields, schema).some((problem) =>
      /has no expected operand/.test(problem)
    )
  );
});

test("the installed activity example must use its real parameter contract", () => {
  const fields = new Map([
    ["EvaluationType__c", "APEX"],
    ["ApexClass__c", "AccountHasRecentActivityCheck"]
  ]);
  const wrong = draftNarrativeProblems(
    "daysBack accepts 1-365 and invalid values return INVALID_CONFIG.",
    fields
  );
  assert.ok(wrong.some((problem) => /3,650/.test(problem)));
  assert.ok(wrong.some((problem) => /INVALID_APEX_PARAMETERS/.test(problem)));
  assert.ok(
    wrong.some((problem) =>
      /RecordHealthCheckPluginDefinitionSource/.test(problem)
    )
  );
  assert.ok(wrong.some((problem) => /RecordHealthCheckEvidence/.test(problem)));
  assert.ok(
    wrong.some((problem) => /RecordHealthCheckRecordEvaluator/.test(problem))
  );
  assert.ok(
    wrong.some((problem) => /RecordHealthCheckDisplayPlugin/.test(problem))
  );

  assert.deepEqual(
    draftNarrativeProblems(
      "## Execution and result-delivery plan\n\nUse the Lightning card.\n\n" +
        "daysBack accepts 1 through 3,650; invalid declared values return " +
        "INVALID_APEX_PARAMETERS. The class filters WhatId and ActivityDate. " +
        "It implements RecordHealthCheckPluginDefinitionSource, attaches " +
        "RecordHealthCheckEvidence, uses RecordHealthCheckRecordEvaluator with " +
        "RecordHealthCheckOutcome.tryEvaluate, and implements " +
        "RecordHealthCheckDisplayPlugin.",
      fields
    ),
    []
  );
});

test("provider-neutral drafts stay inactive until human sandbox review", () => {
  const fields = new Map([
    ["EvaluationType__c", "FORMULA"],
    ["IsActive__c", "true"]
  ]);
  assert.ok(
    draftNarrativeProblems("Human-reviewed draft.", fields).some((problem) =>
      /IsActive__c = false/.test(problem)
    )
  );
});

test("provider-neutral drafts identify their execution and result delivery", () => {
  const fields = new Map([["EvaluationType__c", "FORMULA"]]);
  assert.ok(
    draftNarrativeProblems("## Check configuration", fields).some((problem) =>
      /Execution and result-delivery plan/.test(problem)
    )
  );
  assert.ok(
    !draftNarrativeProblems(
      "## Execution and result-delivery plan\n\nUse the Lightning card.",
      fields
    ).some((problem) => /Execution and result-delivery plan/.test(problem))
  );
});

test("provider-neutral drafts use current formula defaults and ordering", () => {
  const fields = new Map([["EvaluationType__c", "FORMULA"]]);
  const problems = draftNarrativeProblems(
    "| Formula Result Type | FormulaResultType\\_\\_c | BOOLEAN | The default |\n" +
      "| Evaluation Order | EvaluationOrder\\_\\_c | 100 | Checks run in order |",
    fields
  );
  assert.ok(problems.some((problem) => /field default is AUTO/.test(problem)));
  assert.ok(problems.some((problem) => /presentation order/.test(problem)));
});

/**
 * A draft that fills every cross-cutting field, so each coverage test can
 * remove exactly the one thing it is about.
 */
function filled(type) {
  const fields = new Map(MUST_FILL.map((field) => [field, "something"]));
  for (const field of [
    "FormulaResultType__c",
    "DisplayFoundFormula__c",
    "DisplayExpectedFormula__c",
    "SourceQueryField__c",
    "ComparisonQueryField__c",
    "EmptyValueHandling__c",
    "MaxQueryRows__c",
    "ApexParametersJson__c"
  ]) {
    fields.set(field, "something");
  }
  fields.set("EvaluationType__c", type);
  fields.set("ApplicabilityMode__c", "ALL_RECORDS");
  return fields;
}

test("a draft that fills every field it reads has no coverage gap", () => {
  assert.deepEqual(coverageGaps(filled("FORMULA")), []);
});

test("a field left blank is a coverage gap", () => {
  const fields = filled("FORMULA");
  fields.delete("FixMessage__c");
  assert.deepEqual(coverageGaps(fields), ["FixMessage__c"]);
});

test("a field left as a Setup placeholder is a coverage gap", () => {
  const fields = filled("FORMULA");
  fields.set("CardTitle__c", "Confirm in Salesforce Setup");
  assert.deepEqual(coverageGaps(fields), ["CardTitle__c"]);
});

test("PrerequisiteCheck__c is never demanded, because it names a sibling Check", () => {
  const fields = filled("FORMULA");
  fields.delete("PrerequisiteCheck__c");
  assert.deepEqual(coverageGaps(fields), []);
});

test("an Apex Check is not asked for display text it ignores", () => {
  const fields = filled("APEX");
  fields.set("ApexClass__c", "AccountRecentActivityCheck");
  fields.delete("DisplayFoundText__c");
  fields.delete("DisplayExpectedText__c");
  assert.deepEqual(coverageGaps(fields), []);
});

test("an always-applicable Check is not asked for a not-applicable message", () => {
  const fields = filled("FORMULA");
  fields.delete("ApplicabilityNotMetMessage__c");
  assert.deepEqual(coverageGaps(fields), []);
});

test("a Check that can be skipped is asked for its not-applicable message", () => {
  const fields = filled("FORMULA");
  fields.set("ApplicabilityMode__c", "WHEN_FORMULA_TRUE");
  fields.delete("ApplicabilityNotMetMessage__c");
  assert.deepEqual(coverageGaps(fields), ["ApplicabilityNotMetMessage__c"]);
});

test("each Evaluation Type is asked for the optional fields it reads", () => {
  const query = filled("QUERY");
  for (const field of [
    "SourceQueryField__c",
    "EmptyValueHandling__c",
    "MaxQueryRows__c"
  ]) {
    query.delete(field);
  }
  assert.deepEqual(coverageGaps(query), [
    "SourceQueryField__c",
    "EmptyValueHandling__c",
    "MaxQueryRows__c"
  ]);

  const formula = filled("FORMULA");
  for (const field of [
    "FormulaResultType__c",
    "DisplayFoundFormula__c",
    "DisplayExpectedFormula__c"
  ]) {
    formula.delete(field);
  }
  // Both display formulas are excused while the fixture still carries the text
  // spellings, which is how the shipped Formula examples are written.
  assert.deepEqual(coverageGaps(formula), ["FormulaResultType__c"]);
});

test("format on a result token is reported, but not on a record token", () => {
  const fields = formula();
  fields.set(
    "FailureMessage__c",
    'Found {!rhcResult.foundValue format="CURRENCY"} of ' +
      '{!record.AnnualRevenue format="CURRENCY"}.'
  );
  const problems = draftProblems(fields, schema);
  assert.equal(
    problems.filter((problem) => /format="\.\.\." works only on/.test(problem))
      .length,
    1
  );
  assert.ok(
    problems.some((problem) => /formats a rhcResult token/.test(problem))
  );
});

test("a hand-rolled plural beside a count token is reported", () => {
  const fields = formula();
  fields.set(
    "FailureMessage__c",
    "{!rhcResult.failedRecordCount} open Opportunity(ies) have no Next Step."
  );
  assert.ok(
    draftProblems(fields, schema).some((problem) =>
      /foundValuePluralSuffix/.test(problem)
    )
  );
});

test("a count token with the suffix token is not reported", () => {
  const fields = formula();
  fields.set(
    "FailureMessage__c",
    "{!rhcResult.failedRecordCount} open " +
      "Opportunit{!rhcResult.foundValuePluralSuffix} have no Next Step."
  );
  assert.equal(
    draftProblems(fields, schema).filter((problem) =>
      /foundValuePluralSuffix/.test(problem)
    ).length,
    0
  );
});

test("a plural spelled out without a count token is left alone", () => {
  const fields = formula();
  fields.set("FailureMessage__c", "Some Opportunity(s) are stale.");
  assert.equal(
    draftProblems(fields, schema).filter((problem) =>
      /foundValuePluralSuffix/.test(problem)
    ).length,
    0
  );
});

test("a Formula Check may show its expected side as text instead of a formula", () => {
  const fields = filled("FORMULA");
  fields.delete("DisplayExpectedFormula__c");
  assert.deepEqual(coverageGaps(fields), []);

  fields.delete("DisplayExpectedText__c");
  assert.deepEqual(coverageGaps(fields), [
    "DisplayExpectedText__c",
    "DisplayExpectedFormula__c"
  ]);
});

test("the found side is required whichever expected spelling is used", () => {
  const fields = filled("FORMULA");
  fields.delete("DisplayFoundFormula__c");
  fields.delete("DisplayFoundText__c");
  assert.deepEqual(coverageGaps(fields), [
    "DisplayFoundText__c",
    "DisplayFoundFormula__c"
  ]);
});

test("an API name from neither the metadata nor the requirement is reported", () => {
  const problems = inventedNameProblems(
    "For example: NOT(ISBLANK(ServiceTeam__c))",
    "Base object: Account",
    new Set(["CheckTitle__c"])
  );
  assert.equal(problems.length, 1);
  assert.match(problems[0], /ServiceTeam__c is an API name nobody supplied/);
});

test("a name the requirement supplied, or the product declares, is fine", () => {
  assert.deepEqual(
    inventedNameProblems(
      "Set CheckTitle__c and read Customer_Tier__c.",
      "Verified field API names: Customer_Tier__c",
      new Set(["CheckTitle__c"])
    ),
    []
  );
});

test("an obviously fake placeholder is allowed through", () => {
  assert.deepEqual(
    inventedNameProblems(
      "For example: NOT(ISBLANK(Your_Readiness_Field__c))",
      "Base object: Account",
      new Set()
    ),
    []
  );
});

test("a Formula Check is not excused from display text, unlike an Apex one", () => {
  const formula = filled("FORMULA");
  formula.delete("DisplayFoundFormula__c");
  formula.delete("DisplayFoundText__c");
  assert.deepEqual(coverageGaps(formula), [
    "DisplayFoundText__c",
    "DisplayFoundFormula__c"
  ]);

  // Either spelling answers for that side of the card.
  formula.set("DisplayFoundText__c", "City, State, and Country populated");
  assert.deepEqual(coverageGaps(formula), []);
});

test("a single-row query still owes its empty-value handling", () => {
  const query = filled("QUERY");
  query.set("QueryResultHandling__c", "ONE_RESULT");
  query.delete("EmptyValueHandling__c");
  assert.deepEqual(coverageGaps(query), ["EmptyValueHandling__c"]);
});
