import assert from "node:assert/strict";
import test from "node:test";
import {
  capabilityGaps,
  currentContractProblems,
  fieldNameProblems,
  mergeSyntaxProblems,
  picklistValueProblems,
  sharedBlockDrift
} from "./ai-prompt-accuracy.mjs";

const page = (text) => [{ file: "prompt.md", text }];
const declared = new Set([
  "NoRowsResult__c",
  "ApplicabilityMode__c",
  "SourceQuery__c",
  "CheckTitle__c"
]);
const picklists = new Map([
  ["NoRowsResult__c", ["PASS", "FAIL", "SKIP", "UNABLE_TO_EVALUATE"]],
  [
    "ApplicabilityMode__c",
    ["ALL_RECORDS", "WHEN_FORMULA_TRUE", "WHEN_COUNT_QUERY_MATCHES"]
  ]
]);

test("a field the objects do not declare is reported", () => {
  const problems = fieldNameProblems(
    page("- Set HowToRead__c to one row."),
    declared
  );
  assert.equal(problems.length, 1);
  assert.match(problems[0], /HowToRead__c/);
});

test("a field named only to forbid it is not reported", () => {
  assert.deepEqual(
    fieldNameProblems(
      page("- Never invent HowToRead__c or Object__c."),
      declared
    ),
    []
  );
});

test("warning against a field that is real is reported", () => {
  const problems = fieldNameProblems(
    page("- Never invent CheckTitle__c. Use SourceQuery__c for the query."),
    declared
  );
  assert.equal(problems.length, 1);
  assert.match(problems[0], /warns against inventing CheckTitle__c/);
});

test("a field an example borrows from the reader's org is allowed", () => {
  assert.deepEqual(
    fieldNameProblems(
      page("- Example: Customer_Tier__c"),
      declared,
      new Set(["Customer_Tier__c"])
    ),
    []
  );
});

test("a Setup label mapped to the wrong stored value is reported", () => {
  // The product stores SKIP. SKIPPED is the card status, so a rule that only
  // knew the product's vocabulary would let this through.
  const problems = picklistValueProblems(
    page("- NoRowsResult__c: Pass -> PASS; Skip -> SKIPPED."),
    picklists
  );
  assert.equal(problems.length, 1);
  assert.match(problems[0], /stores SKIPPED/);
});

test("a value assigned to a field that does not declare it is reported", () => {
  const problems = picklistValueProblems(
    page("- Set ApplicabilityMode__c to COUNT_MATCHES with a count query."),
    picklists
  );
  assert.ok(problems.some((problem) => /COUNT_MATCHES/.test(problem)));
});

test("values of every picklist the bullet names are accepted", () => {
  assert.deepEqual(
    picklistValueProblems(
      page(
        "- NoRowsResult__c is required: PASS, FAIL, SKIP, or UNABLE_TO_EVALUATE.\n" +
          "- ApplicabilityMode__c: ALL_RECORDS, WHEN_FORMULA_TRUE, or WHEN_COUNT_QUERY_MATCHES."
      ),
      picklists
    ),
    []
  );
});

test("a documented reason code is not read as a stored value", () => {
  assert.deepEqual(
    picklistValueProblems(
      page("- Invalid JSON reports INVALID_APEX_PARAMETERS."),
      picklists,
      new Set(["INVALID_APEX_PARAMETERS"])
    ),
    []
  );
});

test("a configurable field no page mentions is reported", () => {
  const problems = capabilityGaps(
    page("- SourceQuery__c holds the query."),
    ["SourceQuery__c", "PrerequisiteCheck__c"],
    new Map()
  );
  assert.equal(problems.length, 1);
  assert.match(problems[0], /PrerequisiteCheck__c/);
});

test("a withheld entry for a field that no longer exists is reported", () => {
  const problems = capabilityGaps(
    page("- SourceQuery__c holds the query."),
    ["SourceQuery__c"],
    new Map([["Removed__c", "gone"]])
  );
  assert.equal(problems.length, 1);
  assert.match(problems[0], /stale entry/);
});

test("a prompt that stopped repeating the shared rules is reported", () => {
  const shared = "Rule one.\nRule two.";
  assert.deepEqual(
    sharedBlockDrift(shared, [
      { file: "prompt-query.md", text: `Header\n\n${shared}\n\nQuery rules.` }
    ]),
    []
  );
  const drifted = sharedBlockDrift(shared, [
    { file: "prompt-query.md", text: "Header\n\nRule one.\n\nQuery rules." }
  ]);
  assert.equal(drifted.length, 1);
  assert.match(drifted[0], /shared rules/);
});

test("zero-based rhcQuery row examples are accepted", () => {
  assert.deepEqual(
    mergeSyntaxProblems(
      page(
        "Use {!rhcQuery.sourceRows[0].Email} and " +
          "{!rhcQuery.comparisonRows[1].Id}. Row indexes start at 0."
      )
    ),
    []
  );
});

test("stale one-based rhcQuery guidance is reported", () => {
  const problems = mergeSyntaxProblems(
    page("Row numbers start at 1. These are one-based row positions.")
  );
  assert.equal(problems.length, 2);
  assert.match(problems[0], /indexes start at 0/);
  assert.match(problems[1], /indexes start at 0/);
});

test("stale prerequisite-order guidance is reported", () => {
  const problems = currentContractProblems(
    page(
      "PrerequisiteCheck__c must name a Check with a lower EvaluationOrder__c."
    )
  );
  assert.ok(problems.some((problem) => /dependency order/.test(problem)));
});

test("the shared prompt must teach the 2.0.10 inline-link syntax", () => {
  const problems = currentContractProblems([
    {
      file: "docs/build-checks/draft-with-ai/shared-rules.md",
      text: "Use ordinary merge tokens in messages."
    },
    {
      file: "docs/build-checks/draft-with-ai/prompt-apex.md",
      text:
        "RecordHealthCheckPluginDefinitionSource RecordHealthCheckEvidence " +
        "RecordHealthCheckRecordEvaluator RecordHealthCheckOutcome.tryEvaluate " +
        "RecordHealthCheckDisplayPlugin"
    }
  ]);
  assert.ok(problems.some((problem) => /inline-link syntax/.test(problem)));
});

test("the Apex prompt must teach each optional 2.0.10 extension", () => {
  const problems = currentContractProblems([
    {
      file: "docs/build-checks/draft-with-ai/shared-rules.md",
      text: '{!link label="Open record" href="/lightning/r/Account/{!record.Id}/view"}'
    },
    {
      file: "docs/build-checks/draft-with-ai/prompt-apex.md",
      text: "Implement RecordHealthCheckPlugin."
    }
  ]);
  for (const concept of [
    "RecordHealthCheckPluginDefinitionSource",
    "RecordHealthCheckEvidence",
    "RecordHealthCheckRecordEvaluator",
    "RecordHealthCheckOutcome.tryEvaluate",
    "RecordHealthCheckDisplayPlugin"
  ]) {
    assert.ok(problems.some((problem) => problem.includes(concept)));
  }
});

test("the shared prompt must cover non-agent entry and exit points", () => {
  const problems = currentContractProblems([
    {
      file: "docs/build-checks/draft-with-ai/shared-rules.md",
      text: '{!link label="Open record" href="/lightning/r/Account/{!record.Id}/view"}'
    },
    {
      file: "docs/build-checks/draft-with-ai/prompt-apex.md",
      text:
        "RecordHealthCheckPluginDefinitionSource RecordHealthCheckEvidence " +
        "RecordHealthCheckRecordEvaluator RecordHealthCheckOutcome.tryEvaluate " +
        "RecordHealthCheckDisplayPlugin"
    }
  ]);
  for (const concept of [
    "Lightning record card",
    "Flow actions",
    "public Apex API",
    "RecordHealthCheckQueueable",
    "RecordHealthCheckBatch",
    "RecordHealthCheckScheduled",
    "direct response",
    "Platform Events",
    "does not save normal run results"
  ]) {
    assert.ok(problems.some((problem) => problem.includes(concept)));
  }
});

test("the execution generator is a guarded part of the AI series", () => {
  const problems = currentContractProblems([
    {
      file: "docs/build-checks/draft-with-ai/shared-rules.md",
      text:
        "Lightning record card Flow actions public Apex API RecordHealthCheckQueueable " +
        "RecordHealthCheckBatch RecordHealthCheckScheduled direct response Platform Events " +
        'does not save normal run results {!link label="Open" href="/lightning"}'
    },
    {
      file: "docs/build-checks/draft-with-ai/prompt-apex.md",
      text:
        "RecordHealthCheckPluginDefinitionSource RecordHealthCheckEvidence " +
        "RecordHealthCheckRecordEvaluator RecordHealthCheckOutcome.tryEvaluate " +
        "RecordHealthCheckDisplayPlugin"
    }
  ]);
  assert.ok(
    problems.some((problem) =>
      problem.includes("execution-workflow-generator.md is missing")
    )
  );
});

test("current prompt checks reject formula defaults and execution-order claims", () => {
  const problems = currentContractProblems([
    {
      file: "tests/ai-drafts/reference-formula.md",
      text:
        "| Formula Result Type | FormulaResultType\\_\\_c | BOOLEAN | The default |\n" +
        "| Evaluation Order | EvaluationOrder\\_\\_c | 100 | Checks run in order |"
    }
  ]);
  assert.ok(problems.some((problem) => /field default is AUTO/.test(problem)));
  assert.ok(problems.some((problem) => /presentation order/.test(problem)));
});

test("current prompt checks require child-query opacity and formula planning", () => {
  const problems = currentContractProblems([
    {
      file: "docs/build-checks/draft-with-ai/shared-rules.md",
      text:
        "Lightning record card Flow actions public Apex API RecordHealthCheckQueueable " +
        "RecordHealthCheckBatch RecordHealthCheckScheduled direct response Platform Events " +
        'does not save normal run results {!link label="Open" href="/lightning"}'
    },
    {
      file: "docs/build-checks/draft-with-ai/prompt-formula.md",
      text: "Use Salesforce formulas."
    }
  ]);
  assert.ok(problems.some((problem) => /child-subquery fields/.test(problem)));
  assert.ok(
    problems.some((problem) =>
      /used only when a QUERY Check evaluates/.test(problem)
    )
  );
  assert.ok(
    problems.some((problem) => /deterministic token offsets/.test(problem))
  );
  assert.ok(problems.some((problem) => /FIELD_NOT_ACCESSIBLE/.test(problem)));
});
