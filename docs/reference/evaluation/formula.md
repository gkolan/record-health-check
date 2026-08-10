# Verify a record with a Formula

> [!NOTE]
> On this page, configure a Formula Check for a question Salesforce can answer from the current
> record and its parent records, such as “Does this Account have an Industry and an Annual Revenue?”
>
> **Reference**
>
> - This page explains every Formula setting, result, access rule, transaction limit, and failure
>   path.
> - For every field's size, default, help text, and example, use the [Check field reference](../../metadata/fields-check.md).

## Required Formula settings

| Setup field | API name | Requirement |
| --- | --- | --- |
| **Evaluation Type** | [`EvaluationType__c`](../../metadata/fields-check.md#evaluation-type-evaluationtype__c) | **Verify with a formula**: `FORMULA` |
| **Pass Condition** | [`PassConditionFormula__c`](../../metadata/fields-check.md#pass-condition-passconditionformula__c) | Required Boolean formula; `true` returns `PASS`, `false` returns `FAIL` |
| **Display: Found Formula** | [`DisplayFoundFormula__c`](../../metadata/fields-check.md#display-found-formula-displayfoundformula__c) | Optional display-only Found value |
| **Display: Expected Formula** | [`DisplayExpectedFormula__c`](../../metadata/fields-check.md#display-expected-formula-displayexpectedformula__c) | Optional display-only Expected value |
| **Formula Result Type** | [`FormulaResultType__c`](../../metadata/fields-check.md#formula-result-type-formularesulttype__c) | Optional type hint; defaults to **Auto**: `AUTO` |

Query and custom Apex fields are not used by a Formula Check. Applicability runs before the Pass
Condition and can return `SKIPPED` without running that formula.

For example:

```text
AND(NOT(ISBLANK(Industry)), AnnualRevenue > 0)
```

This formula returns PASS only when the Account has an Industry and Annual Revenue is greater than
zero.

## Formula context and syntax

- Write Salesforce formula syntax without a leading `=`.
- Reference current-record fields by API name, such as `AnnualRevenue` or `Custom_Score__c`.
- Traverse supported parent relationships, such as `Parent.Parent.AnnualRevenue`.
- Formula fields and roll-up summary fields can be used in the formula; Record Health Check evaluates their
  current values.
- When a referenced formula field depends on other fields, Record Health Check follows those field
  dependencies up to 10 levels while preparing the record query. Administrators do not have to list
  every field used inside the referenced formula field.
- A record formula cannot aggregate child collections. Use a Query Check or Apex when child records
  must be counted, summed, or grouped.

The Pass Condition must return a Checkbox value (`true` or `false`). Display formulas can return
Checkbox, Number, Date, Date/Time, or Text. **Auto** tries supported result types until one works.
Selecting the exact **Formula Result Type** can reduce those attempts, but that one setting must be
correct for every formula on the Check that uses it.

## Found and Expected values

Display formulas never change `PASS` or `FAIL`.

- **Found** should show the value the Check observed.
- **Expected** should show the target used by the pass condition.
- Keep both formulas aligned with the values compared in Pass Condition.
- If Display: Expected Formula is blank, the card can show the default Passes when explanation.
- If Display: Found Formula is blank, no custom Found value is produced.

## Outcomes and Reason Codes

| Outcome | When it occurs | What to investigate |
| --- | --- | --- |
| `PASS` | Pass Condition resolves to `true` | No action required |
| `FAIL` | Pass Condition resolves to `false` | Review Found, Expected, and the configured failure guidance |
| `SKIPPED` | Applicability or a prerequisite prevents evaluation | Review Applies To and Prerequisite Check |
| `UNABLE_TO_EVALUATE` | Formula configuration, access, missing relationship data, or a null/invalid result prevents a conclusion | Review the stable [Reason Code](../contracts/reason-codes.md) and authorized diagnostics |
| `ERROR` | An unexpected Apex or Salesforce problem occurs | Review authorized diagnostics and Apex debug logs |

A null or non-Boolean Pass Condition result does not become `FAIL`; Record Health Check returns
`UNABLE_TO_EVALUATE` because it cannot make the configured decision reliably.

## Access and transaction limits

- Evaluation uses the running user's object, record, and field access.
- Use display formulas only for values the viewer is allowed to see.
- Parent traversal depends on the relationship and referenced fields being available to the user.
- Salesforce allows 100 Formula Evaluation calls in one Apex transaction. Record Health Check stops
  at 95 so it can return a controlled result before reaching that hard limit.
- Each applicable formula is evaluated for each record. For example, a Pass Condition plus Found,
  Expected, and applicability formulas can require four calls per record. At 25 records, that would
  require 100 calls, so the request is rejected before evaluation. Use a smaller Batch size or fewer
  formulas in one Check Set.
- A formula can require extra attempts when **Formula Result Type** is **Auto** and the first result
  type tried is not correct.
- Saved-field and completed-text limits are documented in [Field limits](../contracts/field-limits.md).

## Additional Check configuration

The same Check can configure titles, category, severity, messages, applicability, prerequisites,
action links, display behavior, and Platform Event publication. Those fields apply consistently
across Evaluation Types; use the [Check field reference](../../metadata/fields-check.md) rather than
copying their definitions into each check-type reference.

## Test coverage

Test at least:

1. A record that returns `PASS`.
2. A record that returns `FAIL`.
3. Blank values used by the formula.
4. A missing parent relationship used by the formula.
5. The intended user without access to one referenced field.
6. Each applicability or prerequisite path configured on the Check.

## Compatibility and deprecation

The Apex response does not contain a Formula-specific version number. Its global Apex types are the
compile-time contract supplied by the installed package. Flow responses currently report contract
`2.0`, and Platform Events report their separate contract `1.0`. Removing or renaming a public
field, Status, or Reason Code requires a new contract version. No Formula field is currently
deprecated.

## Related

- [Seller research readiness](../../examples/formula/account-research-ready.md)
- [Check fields](../../metadata/fields-check.md)
- [Reason Codes](../contracts/reason-codes.md)
- [Configure Check Sets and Checks](../../guides/configure-check-sets-and-checks.md)
