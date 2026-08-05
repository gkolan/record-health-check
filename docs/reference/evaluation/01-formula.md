# Reference: Formula

> [!NOTE]
> On this page, learn how Formula Rules evaluate fields on the current or parent record, control applicability and display values, and turn Salesforce formula outcomes into Framework results.
>
> **Reference**
>
> - This page explains every Formula setting, result, security behavior, and failure path.
> - For every field's size, default, help text, and example, use the [Rule field reference](../../metadata/02-fields-check-rule.md).

## Required Formula settings

| Setup field | API name | Requirement |
| --- | --- | --- |
| **Evaluation Type** | [`EvaluationType__c`](../../metadata/02-fields-check-rule.md#evaluation-type-evaluationtype__c) | **Verify with a formula**: `FORMULA` |
| **Pass Condition** | [`PassConditionFormula__c`](../../metadata/02-fields-check-rule.md#pass-condition-passconditionformula__c) | Required Boolean formula; `true` returns `PASS`, `false` returns `FAIL` |
| **Display: Found Formula** | [`DisplayFoundFormula__c`](../../metadata/02-fields-check-rule.md#display-found-formula-displayfoundformula__c) | Optional display-only Found value |
| **Display: Expected Formula** | [`DisplayExpectedFormula__c`](../../metadata/02-fields-check-rule.md#display-expected-formula-displayexpectedformula__c) | Optional display-only Expected value |
| **Formula Result Type** | [`FormulaResultType__c`](../../metadata/02-fields-check-rule.md#formula-result-type-formularesulttype__c) | Optional type hint; defaults to **Auto**: `AUTO` |

Query and Apex evaluator fields are ignored by a Formula Rule. Applicability fields run before the
pass condition and can return `SKIPPED` without evaluating it.

## Formula context and syntax

- Write Salesforce formula syntax without a leading `=`.
- Reference current-record fields by API name, such as `AnnualRevenue` or `Custom_Score__c`.
- Traverse supported parent relationships, such as `Parent.Parent.AnnualRevenue`.
- Formula fields and roll-up summary fields can be operands; Record Health Check evaluates their
  current values.
- When a referenced formula field depends on other fields, the Framework expands that dependency
  chain while planning the record query (up to 10 levels). This lets FormulaEval regenerate
  calculated values without requiring administrators to list each underlying field manually.
- A record formula cannot aggregate child collections. Use a Query Rule or Apex when child records
  must be counted, summed, or grouped.

The pass condition must resolve to Boolean. Display formulas can resolve to Checkbox, Number, Date,
Date/Time, or Text. **Auto** detects the return type; an explicit Formula Result Type can reduce
formula-evaluation work when every configured formula on the Rule returns that type.

## Found and Expected values

Display formulas never change `PASS` or `FAIL`.

- **Found** should show the value the Rule observed.
- **Expected** should show the target used by the pass condition.
- Keep both formulas aligned with the corresponding operands in Pass Condition.
- If Display: Expected Formula is blank, the card can show the default Passes when explanation.
- If Display: Found Formula is blank, no custom Found value is produced.

## Outcomes and Reason Codes

| Outcome | When it occurs | What to investigate |
| --- | --- | --- |
| `PASS` | Pass Condition resolves to `true` | No action required |
| `FAIL` | Pass Condition resolves to `false` | Review Found, Expected, and the configured failure guidance |
| `SKIPPED` | Applicability or a prerequisite prevents evaluation | Review Applies To and Prerequisite Rule |
| `UNABLE_TO_EVALUATE` | Formula configuration, access, missing relationship data, or a null/invalid result prevents a conclusion | Review the stable [Reason Code](../contracts/01-reason-codes.md) and authorized diagnostics |
| `ERROR` | An unexpected evaluator or platform problem occurs | Review authorized diagnostics and Apex debug logs |

A null or non-Boolean pass-condition result does not become `FAIL`; the engine returns
`UNABLE_TO_EVALUATE` because it cannot make the configured decision reliably.

## Security and limits

- Evaluation uses the running user's object, record, and field access.
- Use display formulas only for values the viewer is allowed to see.
- Parent traversal depends on the relationship and referenced fields being available to the user.
- Formula evaluation consumes Salesforce transaction resources; avoid repeating expensive logic
  across pass, Found, Expected, and applicability formulas.
- Framework-wide caps are documented in [Field limits](../contracts/04-field-limits.md).

## Additional Rule configuration

The same Rule can configure titles, category, severity, messages, applicability, prerequisites,
action links, display behavior, and lifecycle-event publication. Those fields apply consistently
across Evaluation Types; use the [Rule field reference](../../metadata/02-fields-check-rule.md) rather than
copying their definitions into each check-type reference.

## Test coverage

Test at least:

1. A record that returns `PASS`.
2. A record that returns `FAIL`.
3. Blank values used by the formula.
4. A missing parent relationship used by the formula.
5. The intended user without access to one referenced field.
6. Each applicability or prerequisite path configured on the Rule.

## Compatibility and deprecation

Formula Rules return the stable synchronous response contract `1.0`. Adding result fields is
compatible within that contract; removing or renaming a public field, status, or reason requires a
new contract version. Lifecycle events use a separate `1.0` contract. No Formula field is
currently deprecated.

## Related

- [Seller research readiness](../../examples/formula/01-account-research-ready.md)
- [Rule fields](../../metadata/02-fields-check-rule.md)
- [Reason Codes](../contracts/01-reason-codes.md)
- [Configure Check Sets and Rules](../../guides/03-configure-check-sets-and-rules.md)
