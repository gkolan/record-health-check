# Apex classes that run each Evaluation Type (L3)

> [!NOTE]
> Use this page to understand what the package does when a Check uses Formula, Query, Compare two
> queries, or Apex. These are internal package classes, not the Apex API used to start a health
> check.

This page is part of the [Apex class reference](README.md). For the plugin author contract, see
[Apex Check contract](../evaluation/apex-check-contract.md).

## Evaluators (L3)

Each class runs one Evaluation Type and returns the same result format. A condition that prevents a
safe answer becomes `UNABLE_TO_EVALUATE`; an unexpected package or Apex plugin failure becomes
`ERROR`. Every result identifies the Evaluation Type and how long the evaluation took.

### `RecordHealthCheckFormulaEvaluator`

**Role:** Run a Formula Check (`FORMULA`).

**Type:** Evaluator · `public with sharing`

Evaluates `PassConditionFormula__c` against the Salesforce record. The package also uses this class
for applicability formulas, Expected Value formulas, and `FindInListFormula__c`.

**Key members:**

| Member | Purpose |
| --- | --- |
| `evaluate(check, recordId, record)` | Main entry point for a Formula Check |
| `resolveFormulaSingleValue(...)` | Shared formula resolution used by other paths |
| Formula limit protection | Stops before Salesforce's 100 Formula Evaluation calls per transaction and remembers a formula's result type for the remaining records |

**Notable behavior:**

- **Null result:** a formula that returns `null`, such as when a related record is missing, returns
  `UNABLE_TO_EVALUATE`/`INVALID_FORMULA`. It does not return `FAIL`, because `null` is not the same as
  `false`.
- **Result type:** the class first tries the Formula Result Type selected on the Check. If needed, it
  tries the other supported types. It remembers the successful type so it does not repeat that work
  for every record.
- **Transaction limit:** Salesforce allows 100 Formula Evaluation calls in one transaction. The
  package stops at 95 so later Checks still have room to evaluate applicability formulas. Use a
  smaller Batch size when a Check Set contains several Formula Checks.

**See also:** [Reference: Formula](../evaluation/formula.md)

### `RecordHealthCheckSoqlEvaluator`

**Role:** Run a Query Check (`QUERY`).

**Type:** Evaluator · `public with sharing`

Replaces merge tokens in `SourceQuery__c`, runs the SOQL query, reads the Found Value, determines the
Expected Value configured on the Check, and compares them. It supports a single result, multiple
rows, list membership, and operators such as **Is Empty** that do not need an Expected Value.

**Notable behavior:**

- **No rows and an empty field are different:** when the query returns no records,
  `NoRowsResult__c` decides the result. When the query returns a record but the selected field is
  empty, `EmptyValueHandling__c` applies and an undecidable comparison returns `SKIPPED`.
- **Merge tokens:** `{!record.FieldApiName}` can include a fallback, such as
  `{!record.Name fallback="(no name)"}`. A multi-select picklist token is formatted differently when
  it appears inside quotes and when it is used unquoted in an `INCLUDES` condition.

**See also:** [Reference: Query](../evaluation/query.md)

### `RecordHealthCheckCompareQueriesEvaluator`

**Role:** Run a Compare two queries Check (`COMPARE_TWO_QUERIES`).

**Type:** Evaluator · `public with sharing`

Runs `SourceQuery__c` and `ComparisonQuery__c`, then compares either one value per side
(`ONE_RESULT`) or two lists (`COMPARE_AS_LISTS`) with list set operators. Empty-query handling
follows `NoRowsResult__c`, consistent with the single-query evaluator.

**Key members:**

| Member | Purpose |
| --- | --- |
| `LISTS_OVERLAP`, `LISTS_CONTAIN_ALL`, `LISTS_MATCH_EXACTLY` | Supported list operators (the last compares how often each cleaned-up value appears, so duplicate counts must match, not just shared values) |

**Notable behavior:**

- **Empty list values:** with `AS_NO_MATCH`, an empty value does not match another empty value. The
  class assigns each empty item a unique internal value, so it cannot accidentally count two blank
  items as a match.

**See also:** [Reference: Compare two queries](../evaluation/compare-two-queries.md)

### `RecordHealthCheckApexEvaluator`

**Role:** Run a custom Apex Check (`APEX`).

**Type:** Evaluator · `public with sharing`

Creates the class named in `ApexClass__c`, confirms that it implements `RecordHealthCheckPlugin`,
converts `ApexParametersJson__c` to the parameters supplied to the plugin, and calls the plugin once
for all records in the request. The package then confirms that the plugin returned one valid result
for every requested record and did not perform a prohibited database write.

**Key members:**

| Member | Purpose |
| --- | --- |
| `APEX_CLASS_NOT_FOUND`, `INVALID_APEX_PARAMETERS`, `APEX_EVALUATOR_ERROR` | Typical failure reason codes |

**Notable behavior:**

- **Important:** the plugin must return exactly one outcome for every requested record ID and none
  for records that were not requested. Missing or extra record IDs, prohibited database writes, and
  invalid results become `ERROR`. A configuration or data condition that prevents a safe answer
  becomes `UNABLE_TO_EVALUATE`.

**See also:** [Reference: Apex](../evaluation/apex-check-contract.md)

### `RecordHealthCheckQueryEvaluatorSupport`

**Role:** Apply the same SOQL row limit and empty-result behavior to both Query Evaluation Types.

**Type:** Shared helper · `public with sharing`

`runQuery` safely adds a row limit, runs the query, and returns `GOVERNOR_LIMIT_RISK` when the query
finds more records than the Check permits. The other methods create consistent results when a query
returns no records or an empty field value.

**Key members:**

| Member | Purpose |
| --- | --- |
| `runQuery(...)` | Shared, limited query execution for both SOQL evaluators |
| `buildEmptyResult(...)` | Shared zero-row result shape, based on `NoRowsResult__c` |
| `buildNullIndeterminateResult(...)` | Shared null-value result shape |

**Notable behavior:**

- **How it detects too many rows:** if the Check allows 200 rows, the class asks for 201. Receiving
  201 proves that the query exceeded the setting; receiving 200 does not. This avoids running a
  separate count query.
- **No Rows Result:** both Query Evaluation Types use the same `NoRowsResult__c` setting. It can make
  a zero-row query return `PASS`, `FAIL`, `UNABLE_TO_EVALUATE`, or the default
  `SKIPPED`/`APPLICABILITY_NOT_MET`.

---

## Related

- [Apex class reference](README.md)
- [Architecture](../framework/architecture.md)
