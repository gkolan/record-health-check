# Reference: Apex evaluators (L3)

> [!NOTE]
> On this page, look up the L3 evaluator classes for Formula, Query, Compare two queries, and
> Apex Rule plugins.

This page is part of the [Apex class reference](README.md). For the plugin author contract, see
[Apex Rule contract](../evaluation/04-apex-rule-contract.md).

## Evaluators (L3)

Each evaluator implements the same shape: build an empty result, run Evaluation Type logic, catch
failures into `UNABLE_TO_EVALUATE` / `ERROR` with a reason code, and set `durationMs` /
`evaluatorType`.

### `RecordHealthCheckFormulaEvaluator`

**Role:** Formula Evaluation Type (`FORMULA`).
**Type:** Evaluator · `public with sharing`

Evaluates `PassConditionFormula__c` against the loaded record via Salesforce `FormulaEval`. Also
used by other paths for applicability formulas, expected-record formulas, and list-membership
primary values (`FindInListFormula__c`).

**Key members:**

| Member | Purpose |
| --- | --- |
| `evaluate(rule, recordId, record)` | Main entry point for a Formula Rule |
| `resolveFormulaSingleValue(...)` | Shared formula resolution used by other paths |
| Governor safety | Tracks FormulaEval calls for the whole transaction (platform limit 100) with a safety margin; caches resolved return types so bulk callers do not retry every record |

**Notable behavior:**
- **Important:** a formula that resolves to `null` (e.g. a null relationship traversal) is treated as
 `UNABLE_TO_EVALUATE`/`INVALID_FORMULA`, not `FAIL` - the class comments explain that letting null
 count as false would produce false failures. `evaluateFormulaAnyType` tries the admin-declared
 `FormulaResultType__c` or a cached previously-resolved return type first, and only falls back to
 trying all eight `formulaeval.FormulaReturnType` values (in a fixed cheapest-first order:
 `BOOLEAN`, `DECIMAL`, `DATE`, `DATETIME`, `STRING`, `DOUBLE`, `INTEGER`, `LONG`) when that preferred
 type fails, since every failed attempt still uses one of the 100 FormulaEval calls for the
 transaction. `FORMULA_EVAL_SAFETY_MARGIN` is `5`, so calls stop being attempted once
 `formulaEvalCallCount` reaches 95, leaving spare room for later checks' applicability checks in
 the same transaction.

**See also:** [Reference: Formula](../evaluation/01-formula.md)

### `RecordHealthCheckSoqlEvaluator`

**Role:** Query Evaluation Type (`QUERY`).
**Type:** Evaluator · `public with sharing`

Binds merge tokens in `SourceQuery__c`, runs the query through
`RecordHealthCheckQueryEvaluatorSupport` / `RecordHealthCheckSoqlTemplate`, extracts Found values,
resolves Expected from fixed value / record formula / comparison query, and applies operators via
`RecordHealthCheckComparisonEngine`. Supports one-result, multi-row, list-membership, and unary
operators according to Rule configuration.

**Notable behavior:**
- **Important:** an indeterminate operator result is split into two distinct causes that must not be
 handled the same way: a genuine zero-row query is governed by `NoRowsResult__c`, while a present
 row whose field value is null is governed by `EmptyValueHandling__c` and resolves to `SKIPPED` - 
 collapsing the two would let "null value + no rows" wrongly resolve to `FAIL`. `bindTokens` also
  resolves each `{!record.FieldApiName}` token (with an optional quoted `fallback` attribute) in both a quoted and unquoted form, since a multi-select
 picklist token expands differently depending on whether it appears inside quotes (raw `'A;B;C'`
 value) or unquoted (an `INCLUDES (...)` list).

**See also:** [Reference: Query](../evaluation/02-query.md)

### `RecordHealthCheckCompareQueriesEvaluator`

**Role:** Compare two queries Evaluation Type (`COMPARE_TWO_QUERIES`).
**Type:** Evaluator · `public with sharing`

Runs `SourceQuery__c` and `ComparisonQuery__c`, then compares either one value per side
(`ONE_RESULT`) or two lists (`COMPARE_AS_LISTS`) with list set operators. Empty-query handling
follows `NoRowsResult__c`, consistent with the single-query evaluator.

**Key members:**

| Member | Purpose |
| --- | --- |
| `LISTS_OVERLAP`, `LISTS_CONTAIN_ALL`, `LISTS_MATCH_EXACTLY` | Supported list operators (the last compares how often each cleaned-up value appears, so duplicate counts must match, not just shared values) |

**Notable behavior:**
- **Important:** under `AS_NO_MATCH` empty-value handling, a missing list value is not converted to an
 empty string (which would let two nulls wrongly "match" as blanks) - it is replaced with a unique
 placeholder, `' __rhc_missing__:' + side + ':' + index`, so a null on one side matches nothing, not
 even another null.

**See also:** [Reference: Compare two queries](../evaluation/03-compare-two-queries.md)

### `RecordHealthCheckApexEvaluator`

**Role:** Apex Evaluation Type (`APEX`).
**Type:** Evaluator · `public with sharing`

Resolves `ApexClass__c` with `Type.forName`, confirms the instance implements
`RecordHealthCheckRule`, parses `ApexParametersJson__c` into `scope.parameters`, and invokes the
plugin once with the complete record scope. `RecordHealthCheckPluginDispatch` validates exact record-key coverage,
supported statuses, and forbidden writes before the Framework derives display content.

**Key members:**

| Member | Purpose |
| --- | --- |
| `APEX_CLASS_NOT_FOUND`, `INVALID_APEX_PARAMETERS`, `APEX_EVALUATOR_ERROR` | Typical failure reason codes |

**Notable behavior:**
- **Important:** the plugin dispatch requires exactly one outcome for every requested record ID and
 no outcomes for unknown IDs. Missing or extra keys, forbidden writes, and malformed plugin
 responses become `ERROR` results with stable plugin-contract reason codes. Configuration or data
 conditions that prevent a safe verdict become `UNABLE_TO_EVALUATE` instead.

**See also:** [Reference: Apex](../evaluation/04-apex-rule-contract.md)

### `RecordHealthCheckQueryEvaluatorSupport`

**Role:** Shared query execution for both SOQL evaluators.
**Type:** Shared helper · `public with sharing`

`runQuery` prepares SOQL (row limit +1 so it can detect too many rows), executes `Database.query`,
maps template and query exceptions to evaluator exceptions, and rejects results over the row limit
with `GOVERNOR_LIMIT_RISK`. Also provides shared `buildEmptyResult` / `buildNullIndeterminateResult`
and the safe "cannot evaluate" message helper.

**Key members:**

| Member | Purpose |
| --- | --- |
| `runQuery(...)` | Shared, limited query execution for both SOQL evaluators |
| `buildEmptyResult(...)` | Shared zero-row result shape, based on `NoRowsResult__c` |
| `buildNullIndeterminateResult(...)` | Shared null-value result shape |

**Notable behavior:**
- **Important:** `runQuery` asks `RecordHealthCheckSoqlTemplate.prepareForExecution` for `maxRows + 1`
 rows rather than `maxRows` - fetching one extra row is how it distinguishes "exactly at the limit"
 from "over the limit" and raises `GOVERNOR_LIMIT_RISK` only in the latter case, without needing a
 separate `COUNT()` query. `buildEmptyResult`'s four-way branch on `NoRowsResult__c` (`PASS`, `FAIL`,
 `UNABLE_TO_EVALUATE`, or the default `SKIPPED`/`APPLICABILITY_NOT_MET`) is shared exactly by both
 SOQL evaluators so a zero-row query behaves identically regardless of Evaluation Type.

---

Documentation example of a merge token with a quoted fallback attribute: `{!record.Name fallback="(no name)"}`.

## Related

- [Apex class reference](README.md)
- [Architecture](../framework/01-architecture.md)
