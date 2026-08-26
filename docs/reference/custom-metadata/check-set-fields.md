# Check Set fields

This page is the complete field dictionary for Check Set metadata.

| Setup value | Name |
| --- | --- |
| Custom Metadata Type label | Record Health Check Set |
| Custom Metadata Type API name | `Record_Health_Check_Set__mdt` |

A Check Set decides which Salesforce object to check and how the Record Health Check card behaves.
Use this page when creating or reviewing a Check Set in **Setup → Custom Metadata Types → Record
Health Check Set → Manage Records**.

For a guided example that creates both a Check Set and its Checks, start with
[Create your first Check](../../step-by-step-guide/create-your-first-check.md).

## Choose the fields you need

| What you want to configure | Fields |
| --- | --- |
| Name the Check Set and choose its Salesforce object | [Label and Developer Name](#label-and-developer-name), [Object](#object-objectapiname__c), [Active](#active-isactive__c) |
| Choose when the card runs | [When Checks Run](#when-checks-run-cardrunmode__c), [Stop after a system error](#stop-after-a-system-error-stoponsystemerror__c) |
| Choose how the card looks | [Card Title](#card-title-cardtitle__c), [Card Subtitle](#card-subtitle-cardsubtitle__c), [Reveal Mode](#reveal-mode-cardrevealmode__c), [Run button fields](#run-button-fields) |
| Choose which result details appear | [Found/Expected Display](#foundexpected-display-foundexpecteddisplay__c), [Passed Checks](#passed-checks-passedchecksdisplay__c), [Skipped Checks](#skipped-checks-skippedchecksdisplay__c), [Summary Display](#summary-display-summarydisplay__c) |
| Troubleshoot a Check Set | [Show Diagnostics](#show-diagnostics-showdiagnostics__c) |
| Publish Platform Events | [Publish User Run Event](#publish-user-run-event-publishuserrunevent__c), [Publish Error Log Event](#publish-error-log-event-publisherrorlogevent__c) |

## Identity and Salesforce object

### Label and Developer Name

| Setup label | API name | Required | Limit | Example |
| --- | --- | --- | --- | --- |
| Label | `MasterLabel` | Yes | 80 characters | `Account readiness` |
| Developer Name | `DeveloperName` | Yes | 40 characters | `Account_Readiness` |

**Label** identifies the Custom Metadata record in Setup. It is not the title shown on the
Lightning card.

**Developer Name** is the stable name Salesforce creates from the label. After saving, Setup shows
the complete **Qualified API Name**. Copy that exact Qualified API Name when Flow or Apex asks for a
Check Set name:

- A Check Set created by an administrator in your org might be `Account_Readiness`.
- A Check Set included with the installed package might be `rhc__Account_Data_Quality`.

Do not add or remove `rhc__` yourself.

### Object (`ObjectApiName__c`)

| Attribute | Value |
| --- | --- |
| Type | Text(80), required |
| Default | None |
| Example | `Account`, `Opportunity`, or `My_Object__c` |

Enter the exact API name of the Salesforce object this Check Set checks. It must match the object of
the record page where the Record Health Check component is placed. For example, an Account Check
Set uses `Account` and belongs on an Account record page.

If the objects do not match, the component does not show the Check Set.

When the App Builder dropdown is empty, confirm **Active**, compare this Object API name with the
record page object, assign **Record Health Check Admin** to the page builder, and refresh Lightning
App Builder after the permission or metadata change.

### Active (`IsActive__c`)

| Attribute | Value |
| --- | --- |
| Type | Checkbox |
| Default | Selected (`true`) |

Leave **Active** selected to allow the Check Set to load and run. Clear it to temporarily disable
the entire Check Set without deleting it. The Lightning component then shows **Health Check
Unavailable** instead of running its Checks.

Clear Active for a reversible stop. **Hide** changes only the card's Run/Rerun control and does not
disable evaluation. Deleting the Set can break page selection and dependent Checks, so back up and
remove dependencies before deletion.

## Card text and display

### Card Title (`CardTitle__c`)

Required Text(255). This is the main heading users see on the Lightning record page. Use short text
that says what the card checks. Example: `Account readiness`.

### Card Subtitle (`CardSubtitle__c`)

Optional Text(255). This explanation appears immediately below Card Title. Use it to say when or why
the user should run the Check Set. Example: `Review before the weekly pipeline meeting.`

### Reveal Mode (`CardRevealMode__c`)

Reveal Mode changes how Check rows appear. It does not change which Checks run, their order, or
their results.

| Setup choice | Stored value | What the user sees |
| --- | --- | --- |
| All at once | `ALL_AT_ONCE` | All applicable Checks appear first as pending; results fill in as the Checks finish. |
| One by one | `ONE_BY_ONE` | A Check appears when Record Health Check reaches it. This is the default. |

This is an optional restricted picklist. The default is **One by one**.

### Found/Expected Display (`FoundExpectedDisplay__c`)

This field controls when the card shows the value found on the record and the value the Check
expected.

| Setup choice | Stored value | What the user sees |
| --- | --- | --- |
| On demand | `ON_DEMAND` | Users can expand a Check to see the values; failed Checks also show them inline. This is the default. |
| Failed checks only | `FAILURES_ONLY` | Values appear only for failed Checks. |
| Every check | `ALL_ROWS` | Values appear inline for every Check that provides them. |

This setting cannot display a value that the Check did not return. Also review whether a Found or
Expected value contains information that should not be shown to every card user.

### Passed Checks (`PassedChecksDisplay__c`)

| Setup choice | Stored value | What the user sees |
| --- | --- | --- |
| Show each check | `SHOW_EACH_CHECK` | Every passed Check remains in the list. This is the default. |
| Show count only | `SHOW_COUNT_ONLY` | Passed rows are hidden, but their total remains in the card summary. |

### Skipped Checks (`SkippedChecksDisplay__c`)

| Setup choice | Stored value | What the user sees |
| --- | --- | --- |
| Show each check | `SHOW_EACH_CHECK` | Every skipped Check remains in the list. This is the default. |
| Show count only | `SHOW_COUNT_ONLY` | Skipped rows are hidden, but their total remains in the card summary. |

A Check can be skipped because it does not apply to the record or because a prerequisite Check did
not pass. Hiding the row does not change the result.

### Summary Display (`SummaryDisplay__c`)

| Setup choice | Stored value | What the user sees |
| --- | --- | --- |
| Above Checks | `TOP` | The result summary appears above the Check rows. |
| Below Checks | `BOTTOM` | The result summary appears below the Check rows. This is the default. |

The setting applies to both the overall summary and category-based summaries. When Checks use
categories, the grouped category summaries replace the overall totals at the selected position.

## When Checks run

### When Checks Run (`CardRunMode__c`)

| Setup choice | Stored value | Behavior |
| --- | --- | --- |
| When the page opens | `RUN_ON_LOAD` | The card checks the record automatically. Afterward, it shows Rerun unless the Run Button Display is **Hide**. |
| When the user clicks Run | `RUN_ON_REQUEST` | The card waits for the user to click Run. This is the default. |

This setting controls only the Lightning card. Flow and Apex run when the Flow or Apex code calls
Record Health Check.

### Stop after a system error (`StopOnSystemError__c`)

| Attribute | Value |
| --- | --- |
| Type | Checkbox |
| Default | Cleared (`false`) |

Leave this field cleared when independent Checks should continue after one Check encounters an
unexpected system error. Select it when later Checks depend on the same technical operation and
continuing would likely repeat the error.

This field stops the run only after an `ERROR`. It does not stop after `FAIL`, `SKIPPED`, or
`UNABLE_TO_EVALUATE`.

## Run button fields

These fields control the Run and Rerun action in the Lightning card header.

### Run Button Display (`RunButtonDisplay__c`)

| Setup choice | Stored value |
| --- | --- |
| Label and icon | `LABEL_AND_ICON` (default) |
| Label only | `LABEL_ONLY` |
| Icon only | `ICON_ONLY` |
| Hide | `HIDE` |

Use **Hide** only when **When Checks Run** is **When the page opens**. A card that waits for a user
request must keep a visible way to start the run.

### Run Button Label (`RunButtonLabel__c`)

Optional Text(80). It labels the first Run action. Leave it blank to use **Run**. In **Icon only**
mode, this text is still the action's accessible name. Example: `Check now`.

### Rerun Button Label (`RerunButtonLabel__c`)

Optional Text(80). It labels the action after the first completed run. Leave it blank to use
**Rerun**. In **Icon only** mode, this text is still the action's accessible name. Example: `Check
again`.

### Run Button Icon (`RunButtonIcon__c`)

Optional Text(80). Enter an SLDS icon name in `category:name` format, such as `utility:refresh` or
`utility:play`. Leave it blank to use the card's built-in play icon. The same icon is used for Run
and Rerun.

## Troubleshooting

### Show Diagnostics (`ShowDiagnostics__c`)

| Attribute | Value |
| --- | --- |
| Type | Checkbox |
| Default | Cleared (`false`) |

Select this field temporarily when an administrator needs technical details on the card and in the
browser console. The user sees those details only when both conditions are true:

1. **Show Diagnostics** is selected on the Check Set.
2. The user has the **Record Health Check View Diagnostics** Custom Permission. The installed
   **Record Health Check Admin** Permission Set includes it.

Other users continue to see the standard card. Clear this field after troubleshooting because the
details can contain object names, field names, formulas, or queries. See
[Troubleshoot with Show Diagnostics](../../diagnostics/browser-console.md).

## Platform Events

### Publish User Run Event (`PublishUserRunEvent__c`)

| Attribute | Value |
| --- | --- |
| Type | Checkbox |
| Default | Cleared (`false`) |

Select this field only when a Platform Event-triggered Flow, Apex trigger, or integration must
receive a summary after a person clicks **Run** or **Rerun** on the Lightning card.

It does not publish when the card checks a record automatically as the page opens. It also does not
control Flow, Apex, Batch, Queueable, Future, Scheduled Apex, or agent runs. Those callers choose
`NONE`, `ACTIONABLE`, or `ALL` when they start the health check.

Leave it cleared when nothing receives the event. Publication uses your org's Platform Event
allocation. See [Record Health Check Set Run Platform Event](../platform-event-metadata/check-set-run.md).

### Publish Error Log Event (`PublishErrorLogEvent__c`)

| Attribute | Value |
| --- | --- |
| Type | Checkbox |
| Default | Cleared (`false`) |

Select this field only when restricted administrator or support automation needs technical Record
Health Check errors for this Check Set. Assign **Record Health Check Error Log Publisher** to each
running identity first. Leaving it cleared does not turn off Salesforce debug logs.

If Record Health Check cannot find the Check Set, it fails closed and does not publish restricted
error details without an explicit setting. See
[Record Health Check Log Platform Event](../platform-event-metadata/error-log.md) before granting access or saving these
restricted details.

## Quick configuration example

This Account Check Set waits for a user to request a check, shows all result rows, and does not
publish a Set Run Platform Event unless Flow or Apex separately requests publication.

| Field | Example value |
| --- | --- |
| Label | `Account readiness` |
| Developer Name | `Account_Readiness` |
| Object | `Account` |
| Active | Selected |
| Card Title | `Account readiness` |
| Card Subtitle | `Review before the weekly pipeline meeting.` |
| When Checks Run | `When the user clicks Run` |
| Reveal Mode | `One by one` |
| Run Button Display | `Label and icon` |
| Found/Expected Display | `On demand` |
| Passed Checks | `Show each check` |
| Skipped Checks | `Show each check` |
| Summary Display | `Below Checks` |
| Stop after a system error | Cleared |
| Show Diagnostics | Cleared |
| Publish User Run Event | Cleared |
| Publish Error Log Event | Cleared |

After saving, copy the **Qualified API Name** shown by Setup when Flow or Apex needs to identify this
Check Set.

## Related

- [Check fields](./check-fields.md)
- [Create your first Check](../../step-by-step-guide/create-your-first-check.md)
- [Configure Check Sets and Checks](../../build-checks/configure-check-sets-and-checks.md)
- [Choose whether to publish result events](../../save-results/when-to-use-platform-events.md)
