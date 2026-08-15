# Record Health Check Set Run Platform Event

| Setup value | Name |
| --- | --- |
| Label | Record Health Check Set Run |
| API name | `Record_Health_Check_Set_Run__e` |

This Platform Event gives one summary for each Salesforce record after a Check Set finishes. It
reports how many Checks passed, failed, were skipped, could not be evaluated, or encountered a
system error.

For example, a scheduled process checks 5,000 Accounts every night. Your Platform Event-triggered
Flow can save one Set Run event per Account in a custom history object. A report can then show each
Account's latest totals without saving a separate event for every Check.

Use the [Record Health Check Result event](event-check-result.md) instead when the receiving Flow,
Apex trigger, or integration needs to know which individual Check passed or failed.

## When this event is useful

Use this event when automation needs to:

- save one health-check summary per record for reports or trends;
- notify an administrator when **Unable Count** or **System Error Count** is greater than zero;
- start follow-up work after the health-check transaction commits; or
- confirm that a requested Check Set run reached its result-publication step.

For a decision that must happen immediately in the same Flow or Apex transaction, use the results
returned directly by the [Flow action](../integration/flow-actions.md) or
[Apex API](../api/apex-api.md). A Platform Event is delivered separately after publication.

## When Record Health Check publishes this event

The event is optional. The way the health check starts determines which setting controls it.

### A person clicks Run or Rerun on the Lightning card

Select **Publish User Run Event** on the Check Set to publish the Set Run event. An automatic card
refresh does not publish it. This prevents opening or refreshing a record page from creating event
traffic.

### Flow, Apex, Batch, Queueable, Future, or Scheduled Apex starts the run

The code or Flow action chooses the publication value. The Check Set's **Publish User Run Event**
checkbox does not control these runs.

| Publication value | Is a Set Run event published? |
| --- | --- |
| `ALL` | Yes. Record Health Check also publishes every individual Check Result, including `PASS` and `SKIPPED`. |
| `ACTIONABLE` | Yes, but only when at least one result is `FAIL`, `UNABLE_TO_EVALUATE`, or `ERROR`. If every result is `PASS` or `SKIPPED`, no result event or Set Run event is published. |
| `NONE` | No Platform Events are published. The Flow or Apex code can use or save the returned results directly. |

See [Choose whether to publish result events](../integration/lifecycle-events.md) for examples from
every supported way to start a run.

## When Salesforce delivers it

This is a **High Volume Platform Event** with **Publish After Commit** behavior. Salesforce makes an
accepted event available only after the transaction that ran the health check commits. If that
transaction rolls back, Salesforce does not deliver the event.

Publication is best effort. Salesforce accepting the publication request does not prove that a
Platform Event-triggered Flow, Apex trigger, or integration processed the event successfully.
Monitor the receiving automation separately.

## Access

The installed **Record Health Check User** and **Record Health Check Admin** Permission Sets include
create and read access for this Platform Event. The person or process starting a health check still
needs the appropriate permission set and access to the Salesforce records and fields used by the
Checks.

Also give the receiving Flow, Apex class, or integration only the access it needs for any custom
history object or follow-up records it uses.

## Fields

The API names below are the field names used by Flow, Apex, and integrations.

| Field label | API name | Type | What it contains |
| --- | --- | --- | --- |
| Event ID | `EventId__c` | Text(80), required | Unique ID generated for this event. Save it in a unique field to prevent duplicate follow-up work. |
| Run ID | `RunId__c` | Text(120), required | ID shared by the Set Run event, its Check Result events, and the direct Flow or Apex response. |
| Phase | `Phase__c` | Text(30), required | Always `COMPLETED` in the current contract. |
| Check Set Qualified API Name | `CheckSetQualifiedApiName__c` | Text(80), required | Exact Qualified API Name of the Check Set that ran, such as `My_Account_Checks` or an installed-package name such as `rhc__Account_Data_Quality`. |
| Record ID | `RecordId__c` | Text(18) | Salesforce record summarized by this event. Record Health Check supplies it for current runs. |
| Occurred At | `OccurredAt__c` | Date/Time, required | Date and time when Record Health Check created the event. |
| Source | `Source__c` | Text(30), required | How the run started: `APEX_API`, `FLOW`, `USER_INITIATED`, `SCHEDULED`, `BATCH`, `QUEUEABLE`, `FUTURE`, or `AGENT`. |
| Contract Version | `ContractVersion__c` | Text(10), required | Version of this event's field contract. The current value is `1.0`. |
| Framework Version | `FrameworkVersion__c` | Text(20), required | Record Health Check code version that created the event. |
| Eligible Check Count | `EligibleCheckCount__c` | Number(5,0) | Number of active Checks selected for the run. |
| Evaluated Check Count | `EvaluatedCheckCount__c` | Number(5,0) | Number of Check results included in this record's summary. |
| Passed Count | `PassedCount__c` | Number(5,0) | Results with status `PASS`. |
| Failed Count | `FailedCount__c` | Number(5,0) | Results with status `FAIL`. |
| Skipped Count | `SkippedCount__c` | Number(5,0) | Results with status `SKIPPED`. |
| Unable Count | `UnableCount__c` | Number(5,0) | Results with status `UNABLE_TO_EVALUATE`. |
| System Error Count | `SystemErrorCount__c` | Number(5,0) | Results with status `ERROR`. |

The Set Run event does not include messages, SOQL, formula values, Found values, Expected values, or
stack traces. It does contain a Salesforce record ID, so protect saved copies according to the
sensitivity of that record.

## Example event

This example represents an administrator-created Check Set named `My_Account_Checks`. Its Qualified
API Name does not start with `rhc__`. Copy the exact **Qualified API Name** from the Check Set in
Setup; do not add or remove a namespace prefix.

```json
{
  "ContractVersion__c": "1.0",
  "FrameworkVersion__c": "2.0.4",
  "EventId__c": "rhc-run-001-0123456789abcdef",
  "RunId__c": "rhc-run-001",
  "Phase__c": "COMPLETED",
  "CheckSetQualifiedApiName__c": "My_Account_Checks",
  "RecordId__c": "001000000000001AAA",
  "OccurredAt__c": "2026-07-21T15:30:00.000Z",
  "Source__c": "SCHEDULED",
  "EligibleCheckCount__c": 5,
  "EvaluatedCheckCount__c": 5,
  "PassedCount__c": 3,
  "FailedCount__c": 1,
  "SkippedCount__c": 1,
  "UnableCount__c": 0,
  "SystemErrorCount__c": 0
}
```

The IDs, date, and counts are illustrative. A receiving integration should allow Record Health
Check to add fields to contract version `1.0` without failing.

## Prevent duplicate work

Salesforce can deliver a Platform Event more than once. Before creating a history record,
notification, or other follow-up work, check whether the destination already contains
`EventId__c`. Store it in a **Unique** field when possible, and make the remaining actions safe to
run again.

Use `RunId__c` to connect this summary to its Check Result events. Do not use Run ID as the unique
event receipt because one run can contain a Set Run event for every Salesforce record checked.

Platform Event retention is temporary. Save the event to your own custom object or external system
when the business needs a longer history. For a complete Flow and Apex example, see
[Save Check Set run summaries](../platform-events/check-set-run.md).

## Related

- [Save Check Set run summaries with Flow or Apex](../platform-events/check-set-run.md)
- [Choose whether to publish result events](../integration/lifecycle-events.md)
- [Record Health Check Result Platform Event](event-check-result.md)
- [Record Health Check Log Platform Event](event-log.md)
- [Check Set fields](fields-check-set.md)
