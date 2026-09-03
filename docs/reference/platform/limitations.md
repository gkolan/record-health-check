# Platform limitations and safe patterns

Audience: Check authors and developers diagnosing a platform edge case. For ordinary configuration,
start with the [Formula](../evaluation/formula.md) or [Query](../evaluation/query.md) reference.

Record Health Check runs inside Salesforce security, query, and FormulaEval contracts. Use this
page to identify boundaries where a syntactically valid Check can otherwise look more capable than
it is and choose a safe alternative.

## Formula planning and evaluation

Record Health Check regenerates formula results against the queried in-memory record; it does not
trust a formula field's stored/UI value. The planner loads transitive operands. If a calculated-field
chain exceeds ten expansions, the Check returns `UNABLE_TO_EVALUATE` with
`FORMULA_DEPENDENCY_DEPTH_EXCEEDED` instead of evaluating partially hydrated data. Merge-token paths
have a separate depth contract; see [merge tokens](../merge-syntax/README.md).

Roll-up summary fields are different: their queried value is supplied to FormulaEval. Record Health
Check does not reproduce the roll-up query. Boolean `false` is `FAIL`; a null or unbuildable result is
`UNABLE_TO_EVALUATE`.

| Depth boundary | Ceiling | When exceeded |
| --- | --- | --- |
| `{!record.Parent...}` merge path | 5 relationship hops | Token validation/resolution fails; fallback is only for an optional value, not an invalid path |
| Calculated-formula dependency expansion | 10 expansions | `UNABLE_TO_EVALUATE` / `FORMULA_DEPENDENCY_DEPTH_EXCEEDED` |
| Salesforce cross-object formula spanning | Salesforce compiler limit (commonly 5 levels) | Salesforce rejects the formula at save/compile time |

The dependency ceiling is larger because one operand can expand through several stored formula
fields. Keep author-written formula and merge paths within five relationship hops. For an optional
parent value within that ceiling, use a literal fallback such as
`{!record.Parent.Name fallback="no parent"}`.

`treatNumericNullAsZero(true)` is enabled. A blank Number field therefore satisfies
`NumberOfEmployees = 0`. This differs from a Query Check's **If Field Value Is Empty** policy.

An API 66 spike for `formulaeval.FormulaInstance.getReferencedFields()` found that the API exists,
returns paths such as `AnnualRevenue` and `Parent.Name`, preserves `Owner:User.IsActive`, and builds
without evaluation, SOQL, or DML. FormulaEval rejects `$User.Id` in record-context formulas before
references are returned. The runtime planner therefore retains its describe-only scanner: it works
before compilation, supports offline fixtures, masks `$User`, `$Profile`, `$Setup`, `$Permission`,
and `$CustomMetadata` as non-record globals, and avoids a second compiler pass for every Check. Do
not use those globals in a Pass Condition; use an applicability field, Query, or Apex Check with a
tested user-context contract.

## Polymorphic relationships

Use colon syntax to state the type: `Owner:User.IsActive`, `Who:Contact.Email`, or
`Who:Lead.Email`. The planner fails closed when a multi-type relationship is ambiguous. Only fields
exposed by Salesforce's flat polymorphic Name entity can be hydrated without `TYPEOF`; a type-only
path such as `What:Account.Industry` requires a Query or Apex Check.

Flat `Owner.IsActive` hydration has been measured across transactions for active and inactive User
owners, so the package does not add a `TYPEOF` planner. Queue/Group owners remain an explicit
`UNABLE_TO_EVALUATE` case for a User-only formula. Status text and actions must describe the same
policy; never build `/lightning/r/User/{id}/view` from generic OwnerId unless its type is known.

## Activities: What, Who, and shared relations

The packaged `AccountHasRecentActivityCheck` counts only completed Tasks and Events whose `WhatId`
is the Account. Its bulk contract does not silently broaden to related people or child records.

| Activity shape | Packaged example | Safe pattern when it must count |
| --- | --- | --- |
| `WhatId = Account.Id` | Counted | Use the packaged Apex Check |
| Contact `WhoId`, null `WhatId` | Not counted | Resolve Contacts for scoped Accounts, then query activity by WhoId in Apex |
| Lead `WhoId` | Not Account activity | Evaluate the Lead directly |
| `TaskRelation` / `EventRelation` | Not counted | Use an org-specific, feature-aware Apex plugin |
| Opportunity/Case `WhatId` | Not counted | Deliberately roll child activity up in custom Apex |

A safe bulk Who recipe queries `Contact(Id, AccountId)` once for all Account IDs, queries recent
Task/Event rows by those WhoIds, maps each WhoId back to AccountId, seeds every requested Account
with zero, and ignores keys outside the requested scope. Shared Activities require a separate
feature-aware implementation.

`LastActivityDate` is Salesforce's stored activity summary, not completed Task/Event counting. A
Formula Check using it can change for activity the WhatId-only Apex example does not count. When a
New Task action starts from Contact or Person Account context, set the intended `WhoId`; setting only
`WhatId` expresses a different relationship.

## Person Accounts

Packaged examples do not require Person Account-only fields. Salesforce gives a Person Account one
underlying `PersonContact` child whose `AccountId` is the Person Account. Consequently,
`COUNT(Contact) WHERE AccountId = current Account` returns one for that system-created identity, and
a generic “at least one Contact” Check can vacuously `PASS` without proving that the account has a
separate business contact. Use explicit Person Account applicability instead of interpreting that
count as relationship coverage.

| Business Account concept | Person Account counterpart | Guidance |
| --- | --- | --- |
| `BillingStreet/City/...` | `PersonMailingStreet/City/...` | Use explicit applicability |
| Contact `Email` | Account `PersonEmail` | Do not infer PA completeness from Contact count |
| `Website`, `Industry` | Often not meaningful | Gate B2B checks with `NOT(IsPersonAccount)` |
| `ParentId` hierarchy | Usually business-only | Mark hierarchy checks business-only |
| Contact identity | `PersonContactId` | Use only in PA-enabled org-specific metadata/code |

Business-only recipe: `NOT(IsPersonAccount)`. A PA recipe can use
`IsPersonAccount && NOT(ISBLANK(PersonEmail))` in a PA-enabled org, but metadata containing Person*
fields is not portable to an org without the feature. Action links should target Account unless the
implementation deliberately resolves and authorizes `PersonContactId`.

## Currency, dates, and display

Multi-currency support preserves and displays a loaded row's `CurrencyIsoCode`; it does not perform
corporate, dated, or Advanced Currency Management conversion. `CURRENCYRATE()` is not a supported
FormulaEval workaround. Normalize in Query/Apex when cross-currency comparison is required. Display
formatting adds a code/symbol but does not change comparison units.

Currency authoring guards resolve both direct fields and relationship paths through describe
metadata. They apply only in
multi-currency orgs; an aggregate may retain one unit either by grouping on `CurrencyIsoCode` or by
filtering it to one literal ISO code in a conjunctive outer predicate. Predicates containing `OR`
or `NOT` at outer depth do not prove that every contributing row has that unit and are refused;
operators and equalities inside semi-joins do not alter the outer proof.

`TODAY()`, `NOW()`, `DATEVALUE()`, and datetime comparisons follow FormulaEval and the running-user
context. A formatted chip follows display locale/timezone rules and does not prove that the Pass
Condition used the same boundary. Prefer Date fields for date-only SLAs; for datetime cutoffs,
document the timezone and test users on both sides of the boundary.

## Derived values, snapshots, and freshness

> [!IMPORTANT]
> To check whether data is current, use an available timestamp or processing status in a Formula,
> Query, or custom Apex Check. Choose the acceptable age for your business process.

Core does not infer when a stored or derived field was computed. Make freshness an explicit part of
the Check when the data model exposes evidence for it:

- compare a snapshot timestamp with a source-change timestamp using Formula or Compare Two Queries;
- compare a watermark with `NOW()` or `TODAY()` when policy is based on maximum age;
- use applicability or a prerequisite Check to handle a missing or unreadable watermark; and
- use reviewed subscriber Apex when freshness depends on job history or another source that the
  checked record does not expose.

Snapshot-versus-current value comparison is an authoring decision: Compare Two Queries can report
whether the values differ, but it cannot establish which value should govern the decision. A null
watermark cannot prove freshness. These cases are expressible without a core freshness field, and
core does not inspect product jobs, trigger recalculation, or attach hidden semantics to copied
values.

Use the smallest existing mechanism that can prove the policy:

| Available evidence | Recommended Check design | Safe stale or unknown outcome |
| --- | --- | --- |
| Stored calculation timestamp and source `LastModifiedDate` | Formula or Compare Two Queries compares the two timestamps | `FAIL` when the source is newer; never infer freshness from the derived value alone |
| Stored watermark and maximum permitted age | Formula compares the watermark with `NOW()` or `TODAY()` using the intended timezone/date boundary | `FAIL` outside the threshold; missing watermark follows an explicit applicability or prerequisite policy |
| Child or aggregate source changes | Query or Compare Two Queries obtains a source maximum/change signal and compares it with the watermark | A cap, inaccessible source, or unprovable unit returns unable rather than a partial `PASS` |
| Processing job history or external provenance | Reviewed subscriber Apex reads the authorized evidence and returns one bounded outcome per root | Missing, failed, inaccessible, or never-run evidence cannot default to `PASS` |

The same derived field can legitimately have different freshness policies in different
organizations. Keeping those thresholds and evidence paths in Check configuration makes the policy
reviewable without adding product assumptions to the core metadata contract.

## Query and data-model boundaries

Record Health Check deterministically pre-validates the root object and comma-separated plain field
or relationship paths in a flat `SELECT`. Missing roots return `OBJECT_NOT_RESOLVED`; missing fields
and relationships return `FIELD_NOT_RESOLVED` or `RELATIONSHIP_NOT_RESOLVED`; user-mode access
remains distinct. Compare Two Queries also validates its configured extraction fields against each
query root before display or comparison. Subqueries, `TYPEOF`, aggregate expressions and aliases, SOQL functions, date
literals, and bind/syntax errors are outside this schema subset. If those shapes fail at execution,
they return `INVALID_SOQL_TEMPLATE`; the framework does not build a second SOQL parser or infer a
more specific result from localized platform text.

A resolved Base64/Blob selected field is a deliberately unsupported value boundary and returns
`FIELD_TYPE_NOT_SUPPORTED` before query execution, comparison, serialization, or display. If binary
inspection is essential, use reviewed user-mode Apex that returns only a redacted business outcome
and never the binary content.

- `ALL ROWS` is rejected, so recycle-bin rows are invisible. Restore a row or use purpose-built
  administrative Apex when deleted records matter.
- `WITH DATA CATEGORY` is rejected because it cannot be safely combined with framework-managed
  `WITH USER_MODE`. Use an Apex plugin designed for Knowledge categories.
- File-link queries require org validation because `ContentDocumentLink` applies additional
  implementation restrictions under user-mode SOQL. Use a custom Apex Check unless the exact Query
  template has passed in a representative org. A Knowledge action URL navigates only; it does not
  change evaluation semantics.
- For indirect Contacts, query `AccountContactRelation` by `AccountId`. A role-presence recipe is
  `SELECT COUNT() FROM AccountContactRelation WHERE AccountId = {!record.Id} AND IsActive = true AND Roles INCLUDES ('Decision Maker')`.
  Direct Contact (`Contact.AccountId`), ACR, and OpportunityContactRole are separate relationships;
  Formula cannot aggregate these child collections.
- After duplicate merge, the losing ID no longer identifies the survivor. Rerun against the
  surviving record; activity WhatIds are evaluated exactly as loaded for that run.

These constraints favor explicit `UNABLE_TO_EVALUATE` outcomes and narrow recipes over believable
but incorrect PASS/FAIL results.

## Related

- [Formula reference](../evaluation/formula.md)
- [Query reference](../evaluation/query.md)
- [Compatibility](./compatibility.md)
- [Configure action links](../../build-checks/add-fix-link.md)
