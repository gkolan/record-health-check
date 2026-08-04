# How Record Health Check works

> [!NOTE]
> On this page, learn how Check Sets and Rules turn Salesforce record data into advisory readiness guidance, and when that experience serves users better than blocking a save with a Validation Rule.

Record Health Check provides advisory guidance as a read-only card on a Lightning record page. An
administrator groups related questions in a **Check Set**, configures each question as a **Rule**,
and chooses when the card runs. It does not block unrelated record edits.

Use this page before installation when you want the mental model, or after
[Install and verify](02-install-and-verify.md) when you want to understand a result on the card.

## What you will learn

| Question | What this page explains |
| --- | --- |
| What appears on the Lightning record page? | One Check Set card containing ordered Rule rows |
| What does each result mean? | The difference between Pass, Fail (shown as Failed, Warning, or Info), Skipped, Unable to Check, and System Error |
| Where can a Rule get its answer? | Current-record fields, related records, two query results, or Apex |
| When should I use a Validation Rule instead? | When Salesforce must prevent a record from being saved |

## The plain-English model

Record Health Check is a read-only checklist on a record page. It looks at the record, runs the checks you configured, and shows what looks healthy or needs attention.

It does not stop users from saving. Use validation rules when a user must be blocked from saving bad data.

### What the user sees

When someone opens the Account, the card shows the Check Set title and one result for each Rule.
A result can confirm readiness, identify something that needs attention, explain that a Rule did
not apply, or state that access or configuration prevented a reliable answer.

The person reading the card does not need to understand the Formula, SOQL, or Apex behind the Rule.
Those Framework options make the business question reliable and the result actionable.

## The words you need

- **Check Set:** the whole card. It decides which object the card is for, when it runs, and which Rules belong together.
- **Rule:** one row on the card. A Rule asks one question, such as "Has there been recent activity?"
- **Pass:** the record meets the Rule. The card label is **Pass**; the API status is `PASS`.
- **Fail:** the Rule found something that needs attention. The card shows **Failed**, **Warning**, or **Info** based on Failure Severity; the API status is `FAIL`.
- **Skipped:** the Rule did not apply to this record right now, or it was waiting for another Rule to pass first. The card label is **Skipped**; the API status is `SKIPPED`.
- **Unable to Check:** the card label when setup, access, or available data prevented a reliable conclusion. Setup fields and API status use **Unable to Evaluate** / `UNABLE_TO_EVALUATE`.
- **System Error:** the card label for an unexpected evaluator or platform problem. The API status is `ERROR`.
- **Applicability:** a condition that decides whether a Rule runs. Example: only check Partner requirements on Partner Accounts.
- **Formula-based check:** a check that looks at fields on the current record, or parent fields Salesforce formula syntax can reach.
- **Query-based check:** a check that looks for related records with SOQL, such as Contacts, Opportunities, Cases, Tasks, or Events.
- **Regular user:** a user who sees clean pass/fail/skipped results. Assign the Permission Set named `Record_Health_Check_User`.
- **Troubleshooting user:** a user who can see extra technical detail when the Check Set enables **Show Diagnostics**. Assign the Permission Set named `Record_Health_Check_Admin` for troubleshooting sessions.

## Example: Account has recent activity

Business question:

```text
Has anyone completed a Task or logged an Event on this Account in the last 90 days?
```

Why this is a health check:

- It is useful when someone opens the Account.
- It coaches users at read time instead of blocking saves.
- It reads Tasks and Events, not only Account fields.

How it appears to users:

- **Pass:** the Account has recent activity.
- **Fail:** the Account has no completed Task or logged Event inside the configured look-back window. The card shows **Failed**, **Warning**, or **Info** based on Failure Severity.
- **Skipped:** the Rule did not apply because of its setup conditions.
- **Unable to Check:** access, setup, or available data prevented a conclusion. Setup and API call this outcome Unable to Evaluate (`UNABLE_TO_EVALUATE`).
- **System Error:** an unexpected evaluator or platform problem occurred; review troubleshooting details. The API status is `ERROR`.

Record Health Check installs four Demo Check Sets (`Example_…`) whose card titles start with
`Demo:` so administrators can distinguish starter content from org policy. Review or deactivate
them before production use, and create the Check Sets your org will enforce. The
[examples library](../examples/README.md) teaches reusable patterns; additional teaching packs may
live in [RecordHealthCheck-Examples](https://github.com/gkolan/RecordHealthCheck-Examples).

## First troubleshooting checks

- **Component shows no checks:** confirm the component's **Check Set** selection is active and
  targets the record page object. Create a Check Set before configuring the component.
- **Check Set is not found:** confirm the Check Set metadata was deployed and is active.
- **Rule is skipped:** review **Applies To**, dependencies, and whether the record meets the applicability condition.
- **SOQL query returns no rows:** confirm related records exist and the query uses the current record token `{!record.Id}` when it filters records for the open record. For an optional parent lookup, use a typed fallback such as `{!record.ParentId fallback="001000000000000AAA"}`.
- **SOQL query returns more than one row:** use an aggregate such as `COUNT()` or choose **How To Read Query Results** = **Any record passes** (`ANY_ROW_PASSES`).
- **Formula errors:** confirm the formula returns true/false for pass/fail and uses valid field API names.
- **User does not see troubleshooting details:** confirm **Show Diagnostics** is checked on the Check Set and the user has the Permission Set named `Record_Health_Check_Admin`.

For deeper fixes, use [Configuration Guide: Troubleshooting](../guides/configure-check-sets-and-rules.md#13-troubleshooting).

## Next steps

- [Install and verify](02-install-and-verify.md): install the Framework and place the card
- [Create your first Rule](03-create-your-first-rule.md): create your first Rule
- [Configure Check Sets and Rules](../guides/configure-check-sets-and-rules.md): configure every Evaluation Type
- [Reason Codes](../reference/contracts/reason-codes.md): diagnose unable and system-error outcomes
