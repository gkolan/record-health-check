# Compare Record Health Check to native Salesforce tools

> [!NOTE]
> On this page, explain how Record Health Check compares to Validation Rules, Duplicate Rules, and
> Flow error messages or before-save automation, then choose the right tool for a given business
> requirement.

Record Health Check does not replace these native Salesforce tools. It fills a different gap:
advisory guidance at read time, for questions that a save-time or duplicate-time mechanism cannot
answer.

## The one rule that decides most of it

> [!IMPORTANT]
> Record Health Check never blocks a save. It evaluates a record after it already exists, and a
> `FAIL` result has no transactional effect. If a business requirement is "Salesforce must refuse to
> save this record," Record Health Check is the wrong tool. Use a Validation Rule, a before-save
> Flow, or an Apex trigger instead.

Ask this question first: does bad data need to be physically prevented, or does someone need to be
told about it? Prevention belongs to save-time automation. Advisory guidance, especially guidance
that depends on data outside the record being saved, belongs to Record Health Check.

## Side-by-side comparison

| Property | Validation Rule | Duplicate Rule | Flow error message / before-save Flow | Record Health Check |
| --- | --- | --- | --- | --- |
| When it runs | At save, in the save transaction | At save, when a matching rule fires | At save (before-save) or after save (Flow error message on a screen/record-triggered Flow) | On read: page load or user request; also callable from Apex, Flow, or a schedule |
| Can it block the save? | Yes | Yes (block or warn, configurable) | Before-save Flow can block; a Flow error message on save can block | No. It is read-only and has no DML on the evaluated record |
| Scope of data it can see | The record being saved, and formula-reachable related fields | Configured matching fields across a defined duplicate rule scope | The record being saved, and whatever the Flow queries | The current record, related records, aggregates, two independent SOQL queries, or custom Apex, including records unrelated by lookup |
| Can it evaluate records that existed before the rule did? | No. It only fires on a DML event | No. It only fires on a DML event | Only if built as a scheduled or on-demand Flow, not natively retroactive | Yes. Evaluation is not bound to a DML event, so it can review every existing record on read or on demand |
| Where the result appears | An error banner blocking save | A duplicate warning or block on save | An error banner (before-save) or the record after a triggered Flow runs | A Lightning record-page card, or a typed Apex/Flow response |
| Configuration model | Formula in Setup | Matching Rule + Duplicate Rule in Setup | Flow Builder | Custom Metadata (Check Set + Rule), deployable and version-controlled |
| Failure severity | Binary: blocks or does not | Binary or warn, per Duplicate Rule | Binary: blocks or does not (before-save); Flow can vary downstream handling | Three severities on `FAIL` (Failed, Warning, Info), plus distinct Skipped, Unable to Check, and System Error outcomes |
| Stable status and Reason Code for automation | No, only pass/block | No, only match/no-match | Depends on Flow design | Yes: status and Reason Code, versioned independently of display text. See [Reason Codes](../reference/contracts/01-reason-codes.md) |

## When to use which

| Business requirement | Use this |
| --- | --- |
| "Salesforce must never save an Opportunity without an Amount." | Validation Rule |
| "Warn the rep about a likely duplicate Lead before they save it." | Duplicate Rule |
| "Stop this Case from saving unless a required Flow-derived value is set." | Before-save Flow, or a Validation Rule if the check is a plain formula |
| "Tell the account team whether this Account has had a Task or Event in the last 90 days." | Record Health Check (retroactive, needs related records, advisory) |
| "Show whether an existing Opportunity is missing an Executive Sponsor Contact Role." | Record Health Check (existing records, related-record query, advisory) |
| "Compare pipeline coverage against a target computed from two independent queries." | Record Health Check (Compare Two Queries; no single-record trigger point exists) |
| "Run a custom readiness algorithm that a formula or single query cannot express." | Record Health Check (Apex Evaluation Type) |
| "Let a user see a Fix It link and instructions, but still let them save regardless." | Record Health Check |

## Why the boundary matters

A Validation Rule, a blocking Duplicate Rule, and a before-save Flow all share one property: a
malformed condition blocks every save that matches it, org-wide, immediately. Record Health Check's
advisory boundary is what makes richer administrator-authored logic (arbitrary SOQL, cross-object
aggregates, custom Apex) tolerable: a misconfigured Rule becomes a documented status on one card
(`UNABLE_TO_EVALUATE` or `ERROR` with a Reason Code), not a block on every save in the org. See
[Architecture: Position in the platform](../reference/framework/01-architecture.md#1-position-in-the-platform)
for the full comparison.

## They are not mutually exclusive

Combine them. A common pattern:

1. A Validation Rule or before-save Flow enforces the non-negotiable minimum at save time (for
   example, an Account must have an Industry).
2. A Record Health Check Rule reviews the fuller readiness picture on read (for example, whether the
   Account has adequate Contact coverage, recent activity, and no open high-priority Cases), and
   guides the user toward the fix without blocking anything.

Record Health Check Rules can even read the same fields a Validation Rule checks; there is no
conflict, because a Rule result never changes what Salesforce allows to be saved.

## Related

- [Architecture: Position in the platform](../reference/framework/01-architecture.md#1-position-in-the-platform)
- [How Record Health Check works](../installation/01-how-it-works.md)
- [Reason Codes](../reference/contracts/01-reason-codes.md)
- [FAQ](02-faq.md)
- [Configure Check Sets and Rules](03-configure-check-sets-and-rules.md)
