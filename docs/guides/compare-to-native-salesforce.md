# Compare Record Health Check to native Salesforce tools

> [!NOTE]
> On this page, explain how Record Health Check compares to Validation Rules, Duplicate Rules, and
> Flow error messages or before-save automation, then choose the right tool for a given business
> requirement.

Record Health Check does not replace these Salesforce tools. It answers a different need: show
people whether an existing record is ready and explain what to correct without preventing them from
saving the record.

## The one check that decides most of it

> [!IMPORTANT]
> Record Health Check never blocks a save. It evaluates a record after it already exists, and a
> `FAIL` result does not undo or prevent a record change. If a business requirement is "Salesforce must refuse to
> save this record," Record Health Check is the wrong tool. Use a Validation Rule, a before-save
> Flow, or an Apex trigger instead.

Ask this question first: must Salesforce prevent the save, or should it let the save finish and then
show someone what needs attention? Use save-time automation for prevention. Use Record Health Check
for guidance, especially when the answer depends on related records or should also apply to records
that already exist.

## Side-by-side comparison

| Property | Validation Rule | Duplicate Rule | Flow error message / before-save Flow | Record Health Check |
| --- | --- | --- | --- | --- |
| When it runs | When Salesforce saves the record | When Salesforce checks the saved values against a Matching Rule | When the configured Flow runs, such as before or after a record is saved | When the Lightning card loads or a user selects Run; it can also run from Flow, Apex, Batch Apex, or a schedule |
| Can it block the save? | Yes | Yes, or it can show a warning, depending on the Duplicate Rule | A record-triggered Flow can show a custom error and prevent the save | No. Running a Check does not update the record being checked |
| Scope of data it can see | The record being saved, and formula-reachable related fields | Configured matching fields across a defined Duplicate Rule scope | The record being saved, and whatever the Flow queries | The current record, related records, aggregates, two independent SOQL queries, or custom Apex, including records unrelated by lookup |
| Can it evaluate records that existed before the rule or automation? | Not until someone saves each record again | Not until Salesforce checks the record during a later save | Yes, if you build a scheduled or manually started Flow to find those records | Yes. Users can check an existing record from its page, and automation can check many existing records |
| Where the result appears | An error banner blocking save | A duplicate warning or block on save | An error banner (before-save) or the record after a triggered Flow runs | A Lightning record-page card, or a typed Apex/Flow response |
| Where an administrator configures it | Validation Rule in Setup | Matching Rule and Duplicate Rule in Setup | Flow Builder | Record Health Check Set and Record Health Check Custom Metadata in Setup |
| Failure severity | Binary: blocks or does not | Binary or warn, per Duplicate Rule | Binary: blocks or does not (before-save); Flow can vary downstream handling | Three severities on `FAIL` (Failed, Warning, Info), plus distinct Skipped, Unable to Check, and System Error outcomes |
| Result values that automation can use | The save succeeds or shows the configured error | The save continues, shows a warning, or is blocked | Whatever outcomes the Flow was designed to provide | PASS, FAIL, SKIPPED, UNABLE_TO_EVALUATE, or ERROR, with a Reason Code. See [Reason Codes](../reference/contracts/reason-codes.md) |

## When to use which

| Business requirement | Use this |
| --- | --- |
| "Salesforce must never save an Opportunity without an Amount." | Validation Rule |
| "Warn the rep about a likely duplicate Lead before they save it." | Duplicate Rule |
| "Stop this Case from saving unless a required Flow-derived value is set." | Before-save Flow, or a Validation Rule if the check is a plain formula |
| "Tell the account team whether this Account has had a Task or Event in the last 90 days." | Record Health Check because it reviews existing related activities without blocking a save |
| "Show whether an existing Opportunity is missing an Executive Sponsor Contact Role." | Record Health Check because it reviews an existing Opportunity and its Contact Roles |
| "Compare pipeline coverage against a target calculated by two separate queries." | Record Health Check using **Compare two queries** |
| "Run a custom readiness algorithm that a formula or single query cannot express." | Record Health Check (Apex Evaluation Type) |
| "Let a user see a Fix it link and instructions, but still let them save regardless." | Record Health Check |

Other native tools can complement either choice:

| Tool | Use it for | Setup starting point |
| --- | --- | --- |
| Required Field | A value that every save through the supported UI/API must provide | **Setup → Object Manager → [Object] → Fields & Relationships → [Field]** |
| Path and Guidance for Success | Stage-specific coaching without evaluating a set of health requirements | **Setup → Path Settings** |
| Dynamic Forms | Showing or hiding fields and sections based on page rules | **Setup → Lightning App Builder** |
| List views and reports | Finding and monitoring groups of records | The object's **List Views** or the **Reports** tab |
| Record Health Check | Explaining whether one open record meets related, aggregate, formula, or custom readiness requirements | **Setup → Custom Metadata Types** and Lightning App Builder |

For save-time controls, start at **Setup → Object Manager → [Object] → Validation Rules**,
**Setup → Duplicate Rules** with a Matching Rule, or **Setup → Flows**. A Duplicate Rule's action
on create or edit determines whether Salesforce allows the save, allows it with an alert, or blocks
it.

For example, a user can save an Opportunity with a blank Amount when no save-time rule prevents it.
A Record Health Check can then show a failed readiness row and guidance. If the Amount must never
be blank, make it required or use a Validation Rule instead.

## Why the boundary matters

A Validation Rule, a blocking Duplicate Rule, and a Flow custom error can stop every matching save.
A Record Health Check never blocks the save. If a Check cannot run because its setup is incomplete
or the user lacks access, the card shows `UNABLE_TO_EVALUATE` or `ERROR` with a **Reason Code**, a
stable machine-readable value that identifies the cause. Users can
still save the record while an administrator corrects the Check. See
[Architecture: Position in the platform](../reference/framework/architecture.md#1-position-in-the-platform)
for the full comparison.

## They are not mutually exclusive

Combine them. A common pattern:

1. A Validation Rule or before-save Flow enforces the non-negotiable minimum at save time (for
   example, an Account must have an Industry).
2. A Record Health Check reviews the fuller readiness picture on read (for example, whether the
   Account has adequate Contact coverage, recent activity, and no open high-priority Cases), and
   guides the user toward the fix without blocking anything.

Record Health Checks can even read the same fields a Validation Rule checks; there is no
conflict, because a Check result never changes what Salesforce allows to be saved.

## Related

- [Architecture: Position in the platform](../reference/framework/architecture.md#1-position-in-the-platform)
- [How Record Health Check works](../installation/how-it-works.md)
- [Reason Codes](../reference/contracts/reason-codes.md)
- [FAQ](faq.md)
- [Configure Check Sets and Checks](configure-check-sets-and-checks.md)
- [Create your first Check](../installation/create-your-first-check.md)
