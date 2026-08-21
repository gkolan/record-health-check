# Compare two SOQL queries

> [!NOTE]
> On this page, configure a Check that compares the result of one SOQL query with the result of a
> second SOQL query. Use it for two counts, two single values, or two lists.
>
> **Reference**
>
> - This page defines the required SOQL, compatible result settings and operators, access behavior,
>   limits, and outcomes.
> - For every field's size, default, help text, and examples, use the [Check field reference](../../metadata/fields-check.md).

This evaluation type requires working knowledge of SOQL. Both queries are stored on the same Check
record in Setup: **Source Query** is the left side and **Comparison Query** is the right side. If you
cannot safely write and test both queries, use a Formula Check or ask a Salesforce developer.

## Required Compare two queries settings

| Setup field | API name | Requirement |
| --- | --- | --- |
| **Evaluation Type** | [`EvaluationType__c`](../../metadata/fields-check.md#evaluation-type-evaluationtype__c) | **Compare two queries**: `COMPARE_TWO_QUERIES` |
| **Source Query** | [`SourceQuery__c`](../../metadata/fields-check.md#source-query-sourcequery__c) | Required left-side SOQL template |
| **Source Query Field** | [`SourceQueryField__c`](../../metadata/fields-check.md#source-query-field-sourcequeryfield__c) | Selected field or aggregate alias; blank for bare `COUNT()` |
| **Comparison Query** | [`ComparisonQuery__c`](../../metadata/fields-check.md#comparison-query-comparisonquery__c) | Required right-side SOQL template |
| **Comparison Query Field** | [`ComparisonQueryField__c`](../../metadata/fields-check.md#comparison-query-field-comparisonqueryfield__c) | Selected field or aggregate alias; blank for bare `COUNT()` |
| **How To Read Query Results** | [`QueryResultHandling__c`](../../metadata/fields-check.md#how-to-read-query-results-queryresulthandling__c) | **One row or aggregate** or **Compare as lists** |
| **Comparison Operator** | [`ComparisonOperator__c`](../../metadata/fields-check.md#comparison-operator-comparisonoperator__c) | Operator compatible with the selected mode |

**Expected Value Comes From** is not used. The Comparison Query always supplies the Expected value.

## Single-value mode

Choose **One row or aggregate** (`ONE_RESULT`) to compare Number, Text, Date, Date/Time, or Checkbox
values. Common examples are two bare `COUNT()` queries or two aggregate queries with aliases.

- Leave both query-field settings blank for bare `COUNT()`.
- For an aliased aggregate, enter each alias in its corresponding Query Field.
- For a selected field, each query must produce the single value expected by the comparison.
- Use equality, ordering, contains, or empty-value operators supported by Comparison Operator.

For example, compare the total number of Opportunity Contact Roles with the number marked Primary:

```sql
SELECT COUNT()
FROM OpportunityContactRole
WHERE OpportunityId = {!record.Id}
```

```sql
SELECT COUNT()
FROM OpportunityContactRole
WHERE OpportunityId = {!record.Id} AND IsPrimary = TRUE
```

## List mode

Choose **Compare as lists**: `COMPARE_AS_LISTS` and one of these operators:

| Setup label | API value | Pass condition |
| --- | --- | --- |
| **Lists overlap** | `LISTS_OVERLAP` | At least one normalized value occurs in both lists |
| **Lists contain all** | `LISTS_CONTAIN_ALL` | The Comparison/Expected list contains every value in the Source/Found list; it may contain additional values |
| **Lists match exactly** | `LISTS_MATCH_EXACTLY` | Both lists contain the same values the same number of times |

List matching ignores letter case. For example, `Chicago` and `CHICAGO` match. Single-value
**Contains** remains case-sensitive. Select the list column with each Query Field and configure the
result to use when either query finds no records.

## No rows, empty values, and row caps

| Setup field | API name | Behavior |
| --- | --- | --- |
| **If Query Finds No Records** | [`NoRowsResult__c`](../../metadata/fields-check.md#if-query-finds-no-records-norowsresult__c) | Determines the outcome when a required list/query side has no records |
| **If Field Value Is Empty** | [`EmptyValueHandling__c`](../../metadata/fields-check.md#if-field-value-is-empty-emptyvaluehandling__c) | Ignores, preserves as blank, or forces no match for empty selected values |
| **Max Query Rows (1-2000)** | [`MaxQueryRows__c`](../../metadata/fields-check.md#max-query-rows-1-2000-maxqueryrows__c) | Applies to returned rows; defaults to `200`, maximum `2000` |

Both queries execute in the same evaluation transaction. Keep their selected fields and row counts
as small as the comparison requires.

Each side is capped independently. Record Health Check probes one row beyond **Max Query Rows** for
the Source Query and again for the Comparison Query; either side exceeding the cap returns
`UNABLE_TO_EVALUATE` / `ROW_LIMIT_EXCEEDED` before comparison. The detail names the configured cap,
not the true row count.

A bare `COUNT()` query always returns one aggregate row, even when the count is zero. **If Query
Finds No Records** therefore applies to a query that returns zero rows, not to a `COUNT()` value of
zero.

## SOQL templates and security

- Both templates support current-record merge tokens such as `{!record.Id}` and parent paths. Add a quoted `fallback` attribute when an optional lookup can be blank (for example `{!record.ParentId fallback="001000000000000AAA"}`).
- Use API names in SOQL and aliases in the matching Query Field setting.
- Queries run using the current user's effective record, object, and field access.
- Access, invalid-query, alias, value-conversion, and incompatible result problems return
  `UNABLE_TO_EVALUATE` when Record Health Check can safely return a result.
- Unexpected Apex failures return `ERROR`; Salesforce governor limits can still stop the current
  Apex transaction.

## Outcomes and testing

Test unequal/equal values, each ordering boundary, one empty side, both empty sides, blank selected
values, duplicate list values, case differences, the configured row limit, and access denied to each
query source. Also test every applicability and prerequisite path.

Use stable `status` and `reasonCode` values for automation. Found represents the resolved Source
Query value; Expected represents the resolved Comparison Query value.

## Compatibility and deprecation

The Apex response does not contain a separate Compare-two-queries version number. Its global Apex
types are the compile-time contract supplied by the installed package. Flow responses currently
report contract `2.0`, and Platform Events report their separate contract `1.0`. A future field can
be added without changing existing fields; removing or renaming a field, Status, operator, or Reason
Code requires a new contract version. No Compare-two-queries field is currently deprecated.

## Related

- [Opportunity Contact Role coverage](../../examples/compare-two-queries/opportunity-contact-role-coverage.md)
- [Check fields](../../metadata/fields-check.md)
- [Reason Codes](../contracts/reason-codes.md)
- [Configure Check Sets and Checks](../../guides/configure-check-sets-and-checks.md)
