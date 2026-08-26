# Formula Checks

> [!NOTE]
> On this page, configure a Formula Check for a question Salesforce can answer from the current
> record and its parent records, such as “Does this Account have an Industry and an Annual Revenue?”
>
> **Reference**
>
> - This page explains every Formula setting, result, access rule, transaction limit, and failure
>   path.
> - For every field's size, default, help text, and example, use the [Check field reference](../custom-metadata/check-fields.md).

For a common owner check, use `Owner.IsActive` on Account. On Lead, where Owner is polymorphic, use
`Owner:User.IsActive` when the rule applies to user-owned Leads and handle queue ownership through
applicability or a Query Check.

## Required Formula settings

| Setup field | API name | Requirement |
| --- | --- | --- |
| **Evaluation Type** | [`EvaluationType__c`](../custom-metadata/check-fields.md#evaluation-type-evaluationtype__c) | **Verify with a formula**: `FORMULA` |
| **Pass Condition** | [`PassConditionFormula__c`](../custom-metadata/check-fields.md#pass-condition-passconditionformula__c) | Required Boolean formula; `true` returns `PASS`, `false` returns `FAIL` |
| **Display: Found Formula** | [`DisplayFoundFormula__c`](../custom-metadata/check-fields.md#display-found-formula-displayfoundformula__c) | Optional display-only Found value |
| **Display: Expected Formula** | [`DisplayExpectedFormula__c`](../custom-metadata/check-fields.md#display-expected-formula-displayexpectedformula__c) | Optional display-only Expected value |
| **Formula Result Type** | [`FormulaResultType__c`](../custom-metadata/check-fields.md#formula-result-type-formularesulttype__c) | Optional type hint; defaults to **Auto**: `AUTO` |

Query and custom Apex fields are not used by a Formula Check. Applicability runs before the Pass
Condition and can return `SKIPPED` without running that formula.

For dependency-depth, numeric-null, timezone, currency, global-variable, and polymorphic boundaries,
see [Platform limitations and safe patterns](../platform/limitations.md#formula-planning-and-evaluation).

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
- Polymorphic relationships (`Owner`, `CreatedBy`, `LastModifiedBy`, `What`, `Who`) can be
  disambiguated with Salesforce's colon syntax, `Relationship:SObjectType.Field`, for example
  `Owner:User.IsActive`. Record Health Check recognizes this syntax when preparing the record
  query and validates the type segment against the object's schema, so a mistyped type (or one
  that isn't a real candidate for that relationship) is treated the same as any other unresolvable
  path rather than guessing.
- Flat SOQL can hydrate only fields exposed by Salesforce's polymorphic `Name` pseudo-entity. For
  example, `What:Account.Name` is supported, while an Account-only field such as
  `What:Account.Industry` requires a Query or Apex Check; it is omitted from Formula record loading
  so one unsupported field cannot invalidate the shared scope query.
- Whether a polymorphic relationship needs the colon segment is decided by the relationship's
  schema. For User-only fields on `Owner`, including Account ownership checks, use the explicit
  `Owner:User.Field` form. Bare paths such as `Owner.IsActive`, `Owner.FirstName`, and
  `Owner.LastName` are not portable and can return `FIELD_NOT_RESOLVED`.
- `$User`, `$Profile`, `$Setup`, `$Permission`, and other global merge references are never treated
  as record fields; a formula that reads `$User.Id` never adds a bogus `User.Id` path to the record
  query.

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

## Ownership checks: Active User, Queue/Group, and QUERY vs Formula

"Owner is active" is a common Check, and it has two supported patterns with different behavior for
non-User owners:

| Pattern | Example | Queue/Group owner | Missing/inaccessible User |
| --- | --- | --- | --- |
| Formula `Owner:User.IsActive` | Custom Formula Check | `UNABLE_TO_EVALUATE`. FormulaEval cannot resolve a User-only path against a non-User owner, and a null formula result never becomes `FAIL` | `UNABLE_TO_EVALUATE`, for the same reason |
| QUERY `SELECT COUNT() FROM User WHERE Id = {!record.OwnerId} AND IsActive = true` | `Account_EU_OwnerIsActive` | `FAIL`. A Queue/Group Id never matches a `User` row, so the count is `0` | `FAIL`. A missing, inaccessible, or genuinely inactive User row all produce the same `0` |

Both patterns are fail-closed in the sense that neither produces a false `PASS` for a non-User or
inactive owner. They differ in **how** they fail: the Formula path reports "I could not determine
this" (`UNABLE_TO_EVALUATE`), while the QUERY `COUNT()` pattern reports "this predicate was not
satisfied" (`FAIL`) without distinguishing *why* the count was zero. Choose QUERY when you want a
uniform fail-closed outcome across Queue, inactive User, and missing User; choose Formula (once
hydrated per the polymorphic guidance above) when you want a Queue/Group owner treated as
"can't tell," not as "fails the check."

Label Check titles, failure messages, and action copy **"active User"**, not "active owner," unless
the Check is also designed to model Queue/Group ownership explicitly (for example with a dedicated
Queue-ratio Query Check). A `COUNT() = 0` result alone does not distinguish an inactive User, a
Queue/Group owner, a User the running user cannot see, or a stale/missing User row. Do not word a
failure message as if it has proven one specific cause (for example "assigned to an inactive
user") when the evaluator has only proven "no active, queryable User matched."

`IsActive = true` is necessary but not sufficient for "healthy owner" in many orgs: Experience
Cloud/partner users, integration/automated-process users, and bot or test accounts left active in
production can all satisfy a naive active-User check while not being a real internal owner able to
do follow-up work. If that distinction matters, filter further on `UserType`, `Profile`, or a
dedicated approved-user or excluded-user criteria in the QUERY or an Apex Check.

When an optional relationship is used in message text, provide a fallback, for example
`{!record.Parent.Name fallback="no parent account"}`.

## Outcomes and Reason Codes

| Outcome | When it occurs | What to investigate |
| --- | --- | --- |
| `PASS` | Pass Condition resolves to `true` | No action required |
| `FAIL` | Pass Condition resolves to `false` | Review Found, Expected, and the configured failure guidance |
| `SKIPPED` | Applicability or a prerequisite prevents evaluation | Review Applies To and Prerequisite Check |
| `UNABLE_TO_EVALUATE` | Formula configuration, access, missing relationship data, or a null/invalid result prevents a conclusion | Review the stable [Reason Code](../results/reason-codes.md) and authorized diagnostics |
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
- Saved-field and completed-text limits are documented in [Field limits](../configuration/field-limits.md).

## Additional Check configuration

The same Check can configure titles, category, severity, messages, applicability, prerequisites,
action links, display behavior, and Platform Event publication. Those fields apply consistently
across Evaluation Types; use the [Check field reference](../custom-metadata/check-fields.md) rather than
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
- [Check fields](../custom-metadata/check-fields.md)
- [Reason Codes](../results/reason-codes.md)
- [Configure Check Sets and Checks](../../build-checks/configure-check-sets-and-checks.md)
