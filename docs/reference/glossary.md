# Glossary

Use this page to look up Record Health Check and Salesforce terms.

> [!NOTE]
> Use this page when a term in Setup, Apex, Flow, a result, or a Platform Event needs a plain-language
> definition. Each entry links to the page with the complete behavior.

To find Check definitions, go to **Setup → Custom Metadata Types**, then select **Manage Records**
beside **Record Health Check Set** or **Record Health Check**.

## Check Set

A group of Checks for one Salesforce object. A Check Set also controls how its Lightning record-page
card runs and displays results. In Setup, its Custom Metadata Type is **Record Health Check Set**
(`Record_Health_Check_Set__mdt`). See [Check Set fields](./custom-metadata/check-set-fields.md).

Example: an administrator might create an Account Check Set named **My Account Checks** and add
Checks for Billing Country, Active Owner, and recent activity.

## Check

One data-quality question inside a Check Set. A Check defines what Salesforce evaluates, what counts
as passing, its failure severity, and the messages shown to a user. In Setup, its Custom Metadata
Type is **Record Health Check** (`Record_Health_Check__mdt`). See
[Check fields](./custom-metadata/check-fields.md).

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
  `rhc__Example_Account_Check_Builder_Guide`.

Do not add or remove `rhc__`. See
[Use the correct Check Set and Check API names](./configuration/names-and-api-identities.md).

## Evaluation Type

The method a Check uses to answer its question.

| Setup label (API value) | What it does | Reference |
| --- | --- | --- |
| Verify with a formula (`FORMULA`) | Evaluates a Salesforce formula against the checked record | [Formula](./evaluation/formula.md) |
| Verify with a query (`QUERY`) | Runs one SOQL query and compares its result with an expected value | [Query](./evaluation/query.md) |
| Compare two queries (`COMPARE_TWO_QUERIES`) | Runs two SOQL queries and compares their results | [Compare two queries](./evaluation/compare-two-queries.md) |
| Verify with Apex (`APEX`) | Calls a developer-owned class that implements `rhc.RecordHealthCheckPlugin` | [Custom Apex Check](../developer-guides/write-an-apex-check.md) |

## Found and Expected

**Found** is the value the Check observed. **Expected** is the value or condition required for the
Check to pass.

Example: a Check might find `25` open Cases and expect a value less than `10`. The displayed values
can be formatted as numbers, money, percentages, dates, picklist labels, or lists without changing
the comparison. See [Display value format](./configuration/display-found-and-expected.md).

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
a message an administrator can edit. Normal card results emphasize the user-facing message; an
administrator can temporarily enable **Show Diagnostics** on the Check Set to see authorized detail.
Flow and Apex responses expose Reason Code directly. See [Reason Codes](./results/reason-codes.md).

## Prerequisite Check

An earlier Check that must return `PASS` before another Check runs. **Prerequisite Check** in Setup
stores the earlier Check's Developer Name, not its Check Title or Qualified API Name. Both Checks
must belong to the same Check Set, and the prerequisite needs a smaller Evaluation Order number so
it runs earlier and appears earlier on the card.

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
[Merge tokens](./merge-syntax/README.md).

## Custom Apex Check

An Apex class created by your team for a Check that cannot be expressed with Formula or Query. The
class implements `rhc.RecordHealthCheckPlugin`, receives the records to check, and returns one result
for every record ID. It must use the running user's access and must not change data or start other
work. See [Custom Apex Check contract](../developer-guides/write-an-apex-check.md).

## Record Health Check Run

The Custom Permission required to start a health check:
`rhc__Record_Health_Check_Run`. It is included in the four installed runner Permission Sets: Card
User, User, Admin, and MCP Integration. Error Log Publisher does not include it. The Custom
Permission is not itself a Permission Set. See
[Security and data access](../architecture/security-and-data-access.md#choose-the-correct-permission-set).

## Record Health Check Error Log Publisher

The packaged Error Log Publisher Permission Set grants Create and Read access only to the restricted
`rhc__Record_Health_Check_Log__e` Platform Event. It does not include **Record Health Check Run** and
does not let its assignee start a Check. Assign it separately and narrowly only when a Check Set's
default-off **Publish Error Log Event** setting is deliberately enabled. See
[Save restricted errors](../save-results/save-restricted-errors.md).

## Show Diagnostics

A Check Set setting that allows troubleshooting detail to be returned. Detail appears only when the
running user also has the **Record Health Check View Diagnostics**
(`rhc__Record_Health_Check_View_Diagnostics`) Custom Permission. The Diagnostics Viewer and Admin
Permission Sets include that permission; the Card User and User Permission Sets do not. See
[Security and data access](../architecture/security-and-data-access.md#the-diagnostics-custom-permission).

## Platform Event publication

The choice that controls whether a programmatic run publishes health-result Platform Events:

On the Lightning card, administrators use the **Publish User Run Event** setting on the Check Set
and **Publish User Result Event** on each Check. Apex and Flow instead choose one of these API values:

| Value | Events published |
| --- | --- |
| `NONE` | No health-result events |
| `ACTIONABLE` | Check Result events only for `FAIL`, `UNABLE_TO_EVALUATE`, and `ERROR`, plus one completed Set Run heartbeat for every scanned record, including all-pass and all-skipped runs |
| `ALL` | Every result, including `PASS` and `SKIPPED` |

Publishing an event does not save a result-history record. A receiving Flow, Apex trigger, or
external integration must save the event if the org needs a permanent record. See
[Lifecycle events](../save-results/when-to-use-platform-events.md).

## Installed examples

The package includes four Check Sets whose Developer Names begin with `Example_` and whose Card
Titles begin with `Example:`. They demonstrate configuration for Account, Contact, and Opportunity.
Create separate Check Sets for your org's business rules instead of renaming an installed example.
See
[Keep Example starter configuration explicit](./configuration/names-and-api-identities.md#keep-example-starter-configuration-explicit).

## Related

- [How Record Health Check works](../start-here/what-it-does.md)
- [Configure Check Sets and Checks](../build-checks/configure-check-sets-and-checks.md)
- [Reason Codes](./results/reason-codes.md)
- [Metadata reference](./custom-metadata/README.md)
