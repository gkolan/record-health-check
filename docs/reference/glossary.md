# Record Health Check glossary

> [!NOTE]
> Use this page when a term in Setup, Apex, Flow, a result, or a Platform Event needs a plain-language
> definition. Each entry links to the page with the complete behavior.

## Check Set

A group of Checks for one Salesforce object. A Check Set also controls how its Lightning record-page
card runs and displays results. In Setup, its Custom Metadata Type is **Record Health Check Set**
(`Record_Health_Check_Set__mdt`). See [Check Set fields](../metadata/fields-check-set.md).

Example: an administrator might create an Account Check Set named **My Account Checks** and add
Checks for Billing Country, Active Owner, and recent activity.

## Check

One data-quality question inside a Check Set. A Check defines what Salesforce evaluates, what counts
as passing, its failure severity, and the messages shown to a user. In Setup, its Custom Metadata
Type is **Record Health Check** (`Record_Health_Check__mdt`). See
[Check fields](../metadata/fields-check.md).

## Check Title

The user-facing name of a Check, such as **Billing country is complete**. It is not the API name used
by Apex or Flow. An administrator can change a Check Title without changing the Check's identity.

## Developer Name

The record name Salesforce stores for Custom Metadata, such as `Billing_Country_Complete`. A
prerequisite field uses the Developer Name of another Check in the same Check Set. Do not use a
Developer Name as a substitute when an Apex or Flow input asks for **Qualified API Name**.

## Qualified API Name

The exact Custom Metadata record identity used by Lightning App Builder, Apex, Flow, and Platform
Events. Copy it from the **Qualified API Name** field in Setup.

- A Check Set created by an administrator in your org might be `My_Account_Checks`.
- A Check Set included with the installed package might be
  `rhc__Example_Account_Profile_Readiness`.

Do not add or remove `rhc__`. See
[Use the correct Check Set and Check API names](framework/configuration-identity.md).

## Evaluation Type

The method a Check uses to answer its question.

| Setup value | What it does | Reference |
| --- | --- | --- |
| `FORMULA` | Evaluates a Salesforce formula against the checked record | [Formula](evaluation/formula.md) |
| `QUERY` | Runs one SOQL query and compares its result with an expected value | [Query](evaluation/query.md) |
| `COMPARE_TWO_QUERIES` | Runs two SOQL queries and compares their results | [Compare two queries](evaluation/compare-two-queries.md) |
| `APEX` | Calls a class that implements `rhc.RecordHealthCheckPlugin` | [Custom Apex Check](evaluation/apex-check-contract.md) |

## Found and Expected

**Found** is the value the Check observed. **Expected** is the value or condition required for the
Check to pass.

Example: a Check might find `25` open Cases and expect a value less than `10`. The displayed values
can be formatted as numbers, money, percentages, dates, picklist labels, or lists without changing
the comparison. See [Display value format](contracts/display-value-format.md).

## Status

The result of one Check for one Salesforce record.

| API Status | Lightning card wording | Meaning |
| --- | --- | --- |
| `PASS` | Pass | The record met the Check |
| `FAIL` | Failed, Warning, or Info | The record did not meet the Check; wording follows Failure Severity |
| `SKIPPED` | Skipped | The Check did not apply, or its prerequisite did not pass |
| `UNABLE_TO_EVALUATE` | Unable to Check | Missing access, data, or valid configuration prevented an answer |
| `ERROR` | System Error | An unexpected Apex or Salesforce problem occurred |

The Run Check Set Flow action also returns one overall Status. It uses the first matching status in
this order: `ERROR`, `UNABLE_TO_EVALUATE`, `FAIL`, `PASS`, then `SKIPPED`. Apex responses provide the
individual results and a count for each Status; they do not provide one overall Status field.

## Failure Severity

The importance assigned to a `FAIL`. It does not change whether the Check passes.

| Setup value | Lightning card wording |
| --- | --- |
| `CRITICAL` | Failed |
| `WARNING` | Warning |
| `INFO` | Info |

## Reason Code

A stable `UPPER_SNAKE_CASE` value that explains why a Check was skipped, could not be evaluated, or
encountered an error. Examples include `PREREQUISITE_NOT_MET`, `RECORD_NOT_VISIBLE`, and
`INVALID_SOQL_TEMPLATE`.

Use Status and Reason Code in Flow, Apex, or integration decisions. Do not make automation depend on
a message an administrator can edit. See [Reason Codes](contracts/reason-codes.md).

## Prerequisite Check

An earlier Check that must return `PASS` before another Check runs. **Prerequisite Check** in Setup
stores the earlier Check's Developer Name, not its Check Title or Qualified API Name. Both Checks
must belong to the same Check Set, and the prerequisite needs a lower Evaluation Order.

## Applicability

The rule that decides whether a Check applies to the current record. A Check can apply to all
records, only when a formula is true, or only when a count query meets its configured comparison.
When the rule is not met, the result is `SKIPPED`; that is not a pass or a failure.

## Merge token

A placeholder that Record Health Check replaces when a Check runs. For example,
`{!record.Name}` inserts the checked record's Name, and `{!rhcResult.foundValue}` inserts the
displayed Found value.

```text
Review {!record.Name fallback="this record"} before approval.
```

The optional quoted `fallback` is used when the value is blank. See
[Merge tokens](contracts/merge-tokens.md).

## Custom Apex Check

An Apex class created by your team for a Check that cannot be expressed with Formula or Query. The
class implements `rhc.RecordHealthCheckPlugin`, receives the records to check, and returns one result
for every record ID. It must use the running user's access and must not change data or start other
work. See [Custom Apex Check contract](evaluation/apex-check-contract.md).

## Record Health Check Run

The Custom Permission required to start a health check:
`rhc__Record_Health_Check_Run`. It is included in both installed Permission Sets. It is not itself a
Permission Set. See [Security and data access](framework/security.md#choose-the-correct-permission-set).

## Show Diagnostics

A Check Set setting that allows troubleshooting detail to be returned. Detail appears only when the
running user also has the **Record Health Check View Diagnostics**
(`rhc__Record_Health_Check_View_Diagnostics`) Custom Permission. The Admin Permission Set includes
that permission; the User Permission Set does not. See
[Security and data access](framework/security.md#the-diagnostics-custom-permission).

## Platform Event publication

The choice that controls whether a programmatic run publishes health-result Platform Events:

| Value | Events published |
| --- | --- |
| `NONE` | No health-result events |
| `ACTIONABLE` | Only `FAIL`, `UNABLE_TO_EVALUATE`, and `ERROR` results |
| `ALL` | Every result, including `PASS` and `SKIPPED` |

Publishing an event does not save a result-history record. A receiving Flow, Apex trigger, or
external integration must save the event if the org needs a permanent record. See
[Lifecycle events](../integration/lifecycle-events.md).

## Installed examples

The package includes four Check Sets whose Developer Names begin with `Example_` and whose Card
Titles begin with `Example:`. They demonstrate configuration for Account, Contact, and Opportunity.
Create separate Check Sets for your org's business rules instead of renaming an installed example.
See
[Keep Example starter configuration explicit](framework/configuration-identity.md#keep-example-starter-configuration-explicit).

## Related

- [Architecture](framework/architecture.md)
- [Reason Codes](contracts/reason-codes.md)
- [Metadata reference](../metadata/README.md)
- [How Record Health Check works](../installation/how-it-works.md)
