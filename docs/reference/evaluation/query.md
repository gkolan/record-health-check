# Verify records with a SOQL Query

> [!NOTE]
> On this page, configure one Query Check that turns SOQL results into a count, a single value, a
> decision across several rows, or a list-membership check.
>
> **Reference**
>
> - This page defines the required fields, query-result choices, Expected Value choices, access
>   behavior, limits, and outcomes.
> - For every field's size, default, help text, and examples, use the [Check field reference](../../metadata/fields-check.md).

## Required Query settings

| Setup field | API name | Requirement |
| --- | --- | --- |
| **Evaluation Type** | [`EvaluationType__c`](../../metadata/fields-check.md#evaluation-type-evaluationtype__c) | **Verify with a query**: `QUERY` |
| **Source Query** | [`SourceQuery__c`](../../metadata/fields-check.md#source-query-sourcequery__c) | Primary SOQL template; required except list-membership mode |
| **Source Query Field** | [`SourceQueryField__c`](../../metadata/fields-check.md#source-query-field-sourcequeryfield__c) | Selected field or aggregate alias; blank for bare `COUNT()` |
| **How To Read Query Results** | [`QueryResultHandling__c`](../../metadata/fields-check.md#how-to-read-query-results-queryresulthandling__c) | Converts returned rows into the value or row decision |
| **Comparison Operator** | [`ComparisonOperator__c`](../../metadata/fields-check.md#comparison-operator-comparisonoperator__c) | Required operator compatible with the selected mode |
| **Expected Value Comes From** | [`ExpectedValueSource__c`](../../metadata/fields-check.md#expected-value-comes-from-expectedvaluesource__c) | Required when the operator needs a right-side value |
| **Expected Currency ISO Code** | [`ExpectedCurrencyIsoCode__c`](../../metadata/fields-check.md#expected-currency-iso-code-expectedcurrencyisocode__c) | Required when a Currency field is compared with a fixed value |

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

### Example: Compare one count

To return PASS when an Account has at least one Contact:

```sql
SELECT COUNT()
FROM Contact
WHERE AccountId = {!record.Id}
```

Use **One row or aggregate**, **Greater than or equal**, **Fixed value**, and an Expected Value of
`1`. Leave **Source Query Field** blank because bare `COUNT()` does not use an alias.

### Example: Check several returned records

To confirm that every open Opportunity has a Next Step:

```sql
SELECT NextStep
FROM Opportunity
WHERE AccountId = {!record.Id} AND IsClosed = FALSE
```

Set **Source Query Field** to `NextStep`, choose **Every record passes**, and use **Is not empty**.
Then decide explicitly what should happen when the Account has no open Opportunities by setting
**If Query Finds No Records**.

## Expected-value sources

| Setup label | API value | Additional field |
| --- | --- | --- |
| **Fixed value** | `FIXED_VALUE` | [Expected Value (Fixed)](../../metadata/fields-check.md#expected-value-fixed-expectedfixedvalue__c) |
| **Record formula** | `RECORD_FORMULA` | [Expected Value (Formula)](../../metadata/fields-check.md#expected-value-formula-expectedrecordformula__c) |
| **Comparison query** | `COMPARISON_QUERY` | [Comparison Query](../../metadata/fields-check.md#comparison-query-comparisonquery__c) and, when needed, Comparison Query Field |

Leave Expected Value Comes From blank for **Is empty** and **Is not empty**. Compare-two-queries
Checks also leave it blank because the second query is inherently the right side.

## Operators

Single-value and row modes support equality, ordering, contains, and empty-value operators as
documented under [Comparison Operator](../../metadata/fields-check.md#comparison-operator-comparisonoperator__c).

Query list-membership uses:

- **List contains any**: `LIST_CONTAINS_ANY`
- **List contains none**: `LIST_CONTAINS_NONE`

For those operators, set How To Read Query Results to **Compare as lists**, put the current-record
value in [Value to find in the list (formula)](../../metadata/fields-check.md#value-to-find-in-the-list-formula-findinlistformula__c),
and return the candidate list from Comparison Query. Source Query is blank in this mode.

## No rows, empty values, and row caps

| Setup field | API name | Behavior |
| --- | --- | --- |
| **If Query Finds No Records** | [`NoRowsResult__c`](../../metadata/fields-check.md#if-query-finds-no-records-norowsresult__c) | Returns Pass, Fail, Skip, or Unable to evaluate when a query returns zero rows |
| **If Field Value Is Empty** | [`EmptyValueHandling__c`](../../metadata/fields-check.md#if-field-value-is-empty-emptyvaluehandling__c) | Ignore the row, compare blank, or force no match |
| **Max Query Rows (1-2000)** | [`MaxQueryRows__c`](../../metadata/fields-check.md#max-query-rows-1-2000-maxqueryrows__c) | Defaults to `200`; maximum `2000` |

No-row behavior is a business decision. Configure it explicitly where required; zero rows can mean
pass, fail, skip, or unable depending on the Check.

Record Health Check probes one row beyond **Max Query Rows** so it never turns a truncated
collection into a collection-wide verdict. When the probe returns that extra row, the Check returns
`UNABLE_TO_EVALUATE` / `ROW_LIMIT_EXCEEDED`. The administrator detail names the configured cap but
does not disclose the true row count. Narrow the query or raise the configured cap.

A bare `COUNT()` query always returns one aggregate row, even when the count is zero. **If Query
Finds No Records** therefore does not replace a `COUNT()` value of zero. Compare that zero with the
Expected Value normally.

**If Field Value Is Empty** applies when a row exists but the selected field is `null`. That is
different from the query returning no rows:

- **Ignore the record** removes that row from a multi-row decision.
- **Treat as blank** compares the value as empty text.
- **Treat as not matching** makes that value fail to match another value, including another empty
  value.

## Currency-unit safety

Record Health Check compares values; it does not convert currencies. In a multi-currency org,
non-aggregate Query and Compare two queries checks retain each returned row's `CurrencyIsoCode`.
When the reachable codes across both sides differ, evaluation returns `UNABLE_TO_EVALUATE` with
`MIXED_CURRENCY`. A fixed value compared with a Currency field must declare its unit in **Expected
Currency ISO Code**, and that declaration participates in the same guard.

`SUM`, `AVG`, `MIN`, and `MAX` collapse the source rows before Apex receives the result, so a
corporate-currency display label is not evidence that the inputs shared a unit. Metadata validation
therefore rejects an aggregate over a Currency field unless the query groups by `CurrencyIsoCode`;
an alternative is a custom Apex Check that explicitly owns and carries unit semantics. Formula
Checks cannot reliably inspect `CurrencyIsoCode` and are not covered by this guard. Single-currency
orgs have no row ISO field and are unaffected.

## SOQL templates and security

- Use `{!record.Id}` and supported `{!record.FieldName}` tokens for current-record values. Add a
  fallback that matches the Salesforce field's data type when an empty value needs a substitute,
  such as `{!record.AnnualRevenue fallback="0"}`.
- Use field API names, not labels, in SOQL.
- Queries run in user mode and enforce the running user's record, object, and field access.
- A missing object, field, record, or relationship permission can return `UNABLE_TO_EVALUATE`.
- Store reviewed SOQL in Check Custom Metadata. Do not build Check SOQL from text entered by an end
  user.
- Keep the selected columns and row limit as small as the decision requires.
- Base64/Blob selected fields are refused before execution with `FIELD_TYPE_NOT_SUPPORTED`. When a
  business decision genuinely depends on binary content, use reviewed user-mode Apex and return
  only the redacted business outcome, never the binary value.

## Outcomes and testing

`PASS` and `FAIL` are completed business decisions. `SKIPPED` means the Check did not apply or a
dependency prevented it. Configuration, access, unsupported SOQL, or value-conversion problems
return `UNABLE_TO_EVALUATE` with a stable Reason Code; unexpected Apex failures return `ERROR`.

Test the pass, fail, no-row, empty-field, row-cap, access-denied, and every configured applicability
or prerequisite path. For aggregate queries, also test null aggregate values and the exact alias.

## Compatibility and deprecation

The Apex response does not contain a Query-specific version number. Its global Apex types are the
compile-time contract supplied by the installed package. Flow responses currently report contract
`2.0`, and Platform Events report their separate contract `1.0`. Removing or renaming a public
field, Status, operator, or Reason Code requires a new contract version. No Query field is currently
deprecated.

## Related

- [Customer handoff](../../examples/query/customer-contact.md)
- [Check fields](../../metadata/fields-check.md)
- [Reason Codes](../contracts/reason-codes.md)
- [Configure Check Sets and Checks](../../guides/configure-check-sets-and-checks.md)
