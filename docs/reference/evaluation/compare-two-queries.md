# Reference: Compare two queries

> [!NOTE]
> On this page, learn how the Framework compares two independent SOQL results, counts, single values, or lists, and choose the operator, empty-result behavior, and limits that fit the Rule.
>
> **Reference**
>
> - This page defines both query shapes, compatible modes, security, limits, and outcomes.
> - For every field's size, default, help text, and examples, use the [Rule field reference](../../metadata/fields-check-rule.md).

## Required Compare two queries settings

| Setup field | API name | Requirement |
| --- | --- | --- |
| **Evaluation Type** | [`EvaluationType__c`](../../metadata/fields-check-rule.md#evaluation-type-evaluationtype__c) | **Compare two queries**: `COMPARE_TWO_QUERIES` |
| **Source Query** | [`SourceQuery__c`](../../metadata/fields-check-rule.md#source-query-sourcequery__c) | Required left-side SOQL template |
| **Source Query Field** | [`SourceQueryField__c`](../../metadata/fields-check-rule.md#source-query-field-sourcequeryfield__c) | Selected field or aggregate alias; blank for bare `COUNT()` |
| **Comparison Query** | [`ComparisonQuery__c`](../../metadata/fields-check-rule.md#comparison-query-comparisonquery__c) | Required right-side SOQL template |
| **Comparison Query Field** | [`ComparisonQueryField__c`](../../metadata/fields-check-rule.md#comparison-query-field-comparisonqueryfield__c) | Selected field or aggregate alias; blank for bare `COUNT()` |
| **How To Read Query Results** | [`QueryResultHandling__c`](../../metadata/fields-check-rule.md#how-to-read-query-results-queryresulthandling__c) | **One row or aggregate** or **Compare as lists** |
| **Comparison Operator** | [`ComparisonOperator__c`](../../metadata/fields-check-rule.md#comparison-operator-comparisonoperator__c) | Operator compatible with the selected mode |

Expected Value Comes From is not used: Comparison Query is always the right side.

## Single-value mode

Choose **One row or aggregate**: `ONE_RESULT` to compare numeric, text, date, Date/Time, or Boolean
values. Common shapes include two bare `COUNT()` queries or two aliased aggregates.

- Leave both query-field settings blank for bare `COUNT()`.
- For an aliased aggregate, enter each alias in its corresponding Query Field.
- For a selected field, each query must produce the single value expected by the comparison.
- Use equality, ordering, contains, or empty-value operators supported by Comparison Operator.

## List mode

Choose **Compare as lists**: `COMPARE_AS_LISTS` and one of these operators:

| Setup label | API value | Pass condition |
| --- | --- | --- |
| **Lists overlap** | `LISTS_OVERLAP` | At least one normalized value occurs in both lists |
| **Lists contain all** | `LISTS_CONTAIN_ALL` | The source list contains every comparison-list value |
| **Lists match exactly** | `LISTS_MATCH_EXACTLY` | Both normalized lists contain the same values |

List matching is case-insensitive. Single-value **Contains** remains case-sensitive. Select the list
column with each Query Field and configure explicit no-row behavior.

## No rows, empty values, and row caps

| Setup field | API name | Behavior |
| --- | --- | --- |
| **If Query Finds No Records** | [`NoRowsResult__c`](../../metadata/fields-check-rule.md#if-query-finds-no-records-norowsresult__c) | Determines the outcome when a required list/query side has no records |
| **If Field Value Is Empty** | [`EmptyValueHandling__c`](../../metadata/fields-check-rule.md#if-field-value-is-empty-emptyvaluehandling__c) | Ignores, preserves as blank, or forces no match for empty selected values |
| **Max Query Rows (1-2000)** | [`MaxQueryRows__c`](../../metadata/fields-check-rule.md#max-query-rows-1-2000-maxqueryrows__c) | Applies to returned rows; defaults to `200`, maximum `2000` |

Both queries execute in the same evaluation transaction. Keep their selected fields and row counts
as small as the comparison requires.

## SOQL templates and security

- Both templates support current-record merge tokens such as `{!record.Id}` and parent paths. Add a quoted `fallback` attribute when an optional lookup can be blank (for example `{!record.ParentId fallback="001000000000000AAA"}`).
- Use API names in SOQL and aliases in the matching Query Field setting.
- Queries run using the current user's effective record, object, and field access.
- Access, invalid-query, alias, conversion, and incompatible-shape problems return
  `UNABLE_TO_EVALUATE` when the framework can report a result.
- Unexpected platform or evaluator failures return `ERROR`; governor limits can still throw like
  any synchronous Apex transaction.

## Outcomes and testing

Test unequal/equal values, each ordering boundary, one empty side, both empty sides, blank selected
values, duplicate list values, case differences, the configured row limit, and access denied to each
query source. Also test every applicability and prerequisite path.

Use stable `status` and `reasonCode` values for automation. Found represents the resolved Source
Query value; Expected represents the resolved Comparison Query value.

## Compatibility and deprecation

Compare-two-queries Rules return synchronous contract `1.0`; lifecycle events use an independent
`1.0` contract. Additive result fields are compatible. Removing or renaming a field, status,
operator, or reason requires a new contract version. No Compare-two-queries field is deprecated.

## Related

- [Opportunity Contact Role coverage](../../examples/compare-two-queries/01-opportunity-contact-role-coverage.md)
- [Rule fields](../../metadata/fields-check-rule.md)
- [Reason Codes](../contracts/reason-codes.md)
- [Configure Check Sets and Rules](../../guides/configure-check-sets-and-rules.md)
