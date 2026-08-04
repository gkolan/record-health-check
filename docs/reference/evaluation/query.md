# Reference: Query

> [!NOTE]
> On this page, learn how one Query Rule turns SOQL rows into a count, value, or list and compares that result with the source best suited to the Salesforce decision.
>
> **Reference**
>
> - This page defines Query Rule modes, conditional fields, security, limits, and outcomes.
> - For every field's size, default, help text, and examples, use the [Rule field reference](../../metadata/fields-check-rule.md).

## Required Query settings

| Setup field | API name | Requirement |
| --- | --- | --- |
| **Evaluation Type** | [`EvaluationType__c`](../../metadata/fields-check-rule.md#evaluation-type-evaluationtype__c) | **Verify with a query**: `QUERY` |
| **Source Query** | [`SourceQuery__c`](../../metadata/fields-check-rule.md#source-query-sourcequery__c) | Primary SOQL template; required except list-membership mode |
| **Source Query Field** | [`SourceQueryField__c`](../../metadata/fields-check-rule.md#source-query-field-sourcequeryfield__c) | Selected field or aggregate alias; blank for bare `COUNT()` |
| **How To Read Query Results** | [`QueryResultHandling__c`](../../metadata/fields-check-rule.md#how-to-read-query-results-queryresulthandling__c) | Converts returned rows into the value or row decision |
| **Comparison Operator** | [`ComparisonOperator__c`](../../metadata/fields-check-rule.md#comparison-operator-comparisonoperator__c) | Required operator compatible with the selected mode |
| **Expected Value Comes From** | [`ExpectedValueSource__c`](../../metadata/fields-check-rule.md#expected-value-comes-from-expectedvaluesource__c) | Required when the operator needs a right-side value |

## Result-handling modes

| Setup label | API value | Behavior |
| --- | --- | --- |
| **One row or aggregate** | `ONE_RESULT` | Compare one selected field, `COUNT()`, or aliased aggregate |
| **Any record passes** | `ANY_ROW_PASSES` | `PASS` when at least one returned row satisfies the comparison |
| **Every record passes** | `ALL_ROWS_PASS` | `PASS` only when every evaluated row satisfies the comparison |
| **Compare as lists** | `COMPARE_AS_LISTS` | Use a supported membership operator and explicit no-row behavior |

For row modes, Source Query Field identifies the compared column. For a bare `COUNT()`, leave the
field blank. For `SUM()`, `AVG()`, `MIN()`, or `MAX()`, give the aggregate an alias and enter that
alias as Source Query Field.

## Expected-value sources

| Setup label | API value | Additional field |
| --- | --- | --- |
| **Fixed value** | `FIXED_VALUE` | [Expected Value (Fixed)](../../metadata/fields-check-rule.md#expected-value-fixed-expectedfixedvalue__c) |
| **Record formula** | `RECORD_FORMULA` | [Expected Value (Formula)](../../metadata/fields-check-rule.md#expected-value-formula-expectedrecordformula__c) |
| **Comparison query** | `COMPARISON_QUERY` | [Comparison Query](../../metadata/fields-check-rule.md#comparison-query-comparisonquery__c) and, when needed, Comparison Query Field |

Leave Expected Value Comes From blank for **Is empty** and **Is not empty**. Compare-two-queries
Rules also leave it blank because the second query is inherently the right side.

## Operators

Single-value and row modes support equality, ordering, contains, and empty-value operators as
documented under [Comparison Operator](../../metadata/fields-check-rule.md#comparison-operator-comparisonoperator__c).

Query list-membership uses:

- **List contains any**: `LIST_CONTAINS_ANY`
- **List contains none**: `LIST_CONTAINS_NONE`

For those operators, set How To Read Query Results to **Compare as lists**, put the current-record
value in [Value to find in the list (formula)](../../metadata/fields-check-rule.md#value-to-find-in-the-list-formula-findinlistformula__c),
and return the candidate list from Comparison Query. Source Query is blank in this mode.

## No rows, empty values, and row caps

| Setup field | API name | Behavior |
| --- | --- | --- |
| **If Query Finds No Records** | [`NoRowsResult__c`](../../metadata/fields-check-rule.md#if-query-finds-no-records-norowsresult__c) | Explicitly returns Pass, Fail, Skip, or Unable to evaluate for multi-row/list modes |
| **If Field Value Is Empty** | [`EmptyValueHandling__c`](../../metadata/fields-check-rule.md#if-field-value-is-empty-emptyvaluehandling__c) | Ignore the row, compare blank, or force no match |
| **Max Query Rows (1-2000)** | [`MaxQueryRows__c`](../../metadata/fields-check-rule.md#max-query-rows-1-2000-maxqueryrows__c) | Defaults to `200`; maximum `2000` |

No-row behavior is a business decision. Configure it explicitly where required; zero rows can mean
pass, fail, skip, or unable depending on the Rule.

## SOQL templates and security

- Use `{!record.Id}` and supported `{!record.FieldName}` tokens for current-record values. Append a typed substitute when a blank bind needs one, such as `{!record.AnnualRevenue fallback="0"}`.
- Use field API names, not labels, in SOQL.
- Evaluation runs in the current user's access context and query execution uses the framework's
  user-mode security controls.
- A missing object, field, record, or relationship permission can return `UNABLE_TO_EVALUATE`.
- Query text comes from trusted Custom Metadata; keep it in administrator configuration rather than building it from untrusted user input.
- Keep the selected columns and row limit as small as the decision requires.

## Outcomes and testing

`PASS` and `FAIL` are completed business decisions. `SKIPPED` means the Rule did not apply or a
dependency prevented it. Configuration, access, query-shape, or data-conversion problems return
`UNABLE_TO_EVALUATE` with a stable Reason Code; unexpected evaluator failures return `ERROR`.

Test the pass, fail, no-row, empty-field, row-cap, access-denied, and every configured applicability
or prerequisite path. For aggregate queries, also test null aggregate values and the exact alias.

## Compatibility and deprecation

Query Rules return synchronous contract `1.0`; lifecycle events use an independent `1.0` contract.
Additive result fields are compatible. Removing or renaming a field, status, operator, or reason
requires a new contract version. No Query field is currently deprecated.

## Related

- [Customer handoff](../../examples/query/01-customer-contact.md)
- [Rule fields](../../metadata/fields-check-rule.md)
- [Reason Codes](../contracts/reason-codes.md)
- [Configure Check Sets and Rules](../../guides/configure-check-sets-and-rules.md)
