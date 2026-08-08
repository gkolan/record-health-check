# How Record Health Check works

> [!NOTE]
> On this page, learn how Check Sets and Rules turn Salesforce record data into advisory readiness guidance, and when that experience serves users better than blocking a save with a Validation Rule.

Record Health Check provides advisory guidance as a read-only card on a Lightning record page. An
administrator groups related questions in a **Check Set**, configures each question as a **Rule**,
and chooses when the card runs. It looks at the record, runs the checks you configured, and shows
what looks healthy or needs attention. It does not stop users from saving. Use validation rules when
a user must be blocked from saving bad data.

Use this page before installation when you want the mental model, or after
[Install and verify](02-install-and-verify.md) when you want to understand a result on the card.

### What the user sees

When someone opens the Account, the card shows the Check Set title and one result for each Rule. A
result can confirm readiness, identify something that needs attention, explain that a Rule did not
apply, or state that access or configuration prevented a reliable answer.

The person reading the card does not need to understand the Formula, SOQL, or Apex behind the Rule.
Those Framework options make the business question reliable and the result actionable.

## What you will learn

| Question | What this page explains |
| --- | --- |
| What appears on the Lightning record page? | One Check Set card containing ordered Rule rows |
| What does each result mean? | The difference between Pass, Fail (shown as Failed, Warning, or Info), Skipped, Unable to Check, and System Error |
| Where can a Rule get its answer? | Current-record fields, related records, two query results, or Apex |
| When should I use a Validation Rule instead? | When Salesforce must prevent a record from being saved |

## Terms to know

| Term | Meaning |
| --- | --- |
| **Check Set** | The whole card. It decides which object the card is for, when it runs, and which Rules belong together. |
| **Rule** | One row on the card. A Rule asks one question, such as "Has there been recent activity?" |
| **Pass** (`PASS`) | The record meets the Rule. The card label is **Pass**. |
| **Fail** (`FAIL`) | The Rule found something that needs attention. The card shows **Failed**, **Warning**, or **Info** based on **Failure Severity** (`FailureSeverity__c`). |
| **Skipped** (`SKIPPED`) | The Rule did not apply to this record right now, or it was waiting for another Rule to pass first. |
| **Unable to Check** (`UNABLE_TO_EVALUATE`) | Setup, access, or available data prevented a reliable conclusion. Setup fields say **Unable to Evaluate**; the API status is `UNABLE_TO_EVALUATE`. |
| **System Error** (`ERROR`) | An unexpected evaluator or platform problem. The card label is **System Error**. |
| **Applicability** | A condition that decides whether a Rule runs. Example: only check Partner requirements on Partner Accounts. |
| **Verify with a formula** (`FORMULA`) | A check that looks at fields on the current record, or parent fields Salesforce formula syntax can reach. |
| **Verify with a query** (`QUERY`) | A check that looks for related records with SOQL, such as Contacts, Opportunities, Cases, Tasks, or Events. |
| **Compare two queries** (`COMPARE_TWO_QUERIES`) | A check that compares two independent SOQL results, as a value or as a list. |
| **Verify with Apex** (`APEX`) | A check that needs custom Apex, such as multi-object date math or a weighted score. |
| **Regular user** | A user who sees clean Pass, Fail, and Skipped results. Assign the **Record Health Check User** (`Record_Health_Check_User`) Permission Set. |
| **Troubleshooting user** | A user who can see extra technical detail when the Check Set enables **Show Diagnostics** (`ShowDiagnostics__c`). Assign the **Record Health Check Admin** (`Record_Health_Check_Admin`) Permission Set for troubleshooting sessions. |

## Example: Account has recent activity

**Business question:**

```text
Has anyone completed a Task or logged an Event on this Account in the last 90 days?
```

Why this is a health check:

- It is useful when someone opens the Account.
- It coaches users at read time instead of blocking saves.
- It reads Tasks and Events, not only Account fields.

### How it appears to users

| Card label | API status | What the user sees on this Account |
| --- | --- | --- |
| **Pass** | `PASS` | The Account has recent activity |
| **Fail** | `FAIL` | The Account has no completed Task or logged Event inside the configured look-back window. The card shows **Failed**, **Warning**, or **Info** based on **Failure Severity** (`FailureSeverity__c`) |
| **Skipped** | `SKIPPED` | The Rule did not apply because of its setup conditions |
| **Unable to Check** | `UNABLE_TO_EVALUATE` | Access, setup, or available data prevented a conclusion. Setup calls this **Unable to Evaluate** |
| **System Error** | `ERROR` | An unexpected evaluator or platform problem occurred; review troubleshooting details |

Record Health Check installs four Demo Check Sets (`Example_…`) whose card titles start with
`Demo:` so administrators can distinguish starter content from org policy. Review or deactivate
them before production use, and create the Check Sets your org will enforce. The
[examples library](../examples/README.md) teaches reusable patterns.

## First troubleshooting checks

| Issue | What to check |
| --- | --- |
| Component shows no checks | Confirm the component's **Check Set** selection is active and targets the record page object. Create a Check Set before configuring the component. |
| Check Set is not found | Confirm the Check Set metadata was deployed and is active. |
| Rule is skipped | Review **Applies To** (`ApplicabilityMode__c`), dependencies, and whether the record meets the applicability condition. |
| SOQL query returns no rows | Confirm related records exist and the query uses the current record token `{!record.Id}` when it filters for the open record. For an optional parent lookup, use a typed fallback such as `{!record.ParentId fallback="001000000000000AAA"}`. |
| SOQL query returns more than one row | Use an aggregate such as `COUNT()`, or set **How To Read Query Results** (`QueryResultHandling__c`) to **Any record passes** (`ANY_ROW_PASSES`). |
| Formula errors | Confirm the formula returns true/false for pass/fail and uses valid field API names. |
| User does not see troubleshooting details | Confirm **Show Diagnostics** (`ShowDiagnostics__c`) is checked on the Check Set and the user has the **Record Health Check Admin** (`Record_Health_Check_Admin`) Permission Set. |

For deeper fixes, use
[Configuration Guide: Troubleshooting](../guides/03-configure-check-sets-and-rules.md#13-troubleshooting).

## Next steps

| Next step | What you will do |
| --- | --- |
| [Install and verify](02-install-and-verify.md) | Install the Framework and place the card |
| [Create your first Rule](03-create-your-first-rule.md) | Create your first Rule |
| [Configure Check Sets and Rules](../guides/03-configure-check-sets-and-rules.md) | Configure every Evaluation Type |
| [Reason Codes](../reference/contracts/01-reason-codes.md) | Diagnose Unable to Check and System Error outcomes |
