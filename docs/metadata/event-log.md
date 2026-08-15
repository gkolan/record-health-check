# Record Health Check Log Platform Event

| Setup value | Name |
| --- | --- |
| Label | Record Health Check Log |
| API name | `Record_Health_Check_Log__e` |

This Platform Event reports technical errors that Record Health Check encounters while it is trying
to run. It can include an Apex exception message and stack trace, so use it only for restricted
administrator, developer, or support monitoring.

This event is different from the result events:

| If you need to know... | Use... |
| --- | --- |
| Whether a Salesforce record passed or failed a Check | [Record Health Check Result](event-check-result.md) |
| The totals for an entire Check Set run | [Record Health Check Set Run](event-set-run.md) |
| Why Record Health Check encountered a technical error | **Record Health Check Log**, described on this page |

## When this event is useful

Create a Platform Event-triggered Flow, Apex trigger, or integration for this event when your team
needs to:

- notify a restricted support channel when Record Health Check encounters an error;
- save errors in a custom object for longer than Salesforce retains Platform Events;
- investigate errors from the same run by using **Run ID**; or
- compare errors before and after a Check Set, Check, formula, or Apex change.

Do not use this event to decide whether a record is ready for a business process. Use the Check
Result event or the results returned directly to Flow or Apex for that purpose.

## Before you create receiving automation

The **Record Health Check User** and **Record Health Check Admin** Permission Sets do not provide
access to this event. That is intentional because it can contain restricted troubleshooting details.

Give access to `Record_Health_Check_Log__e` separately and only to the users or integration that
must receive these errors. Also restrict access to any custom object, external system, email, or
collaboration channel where the receiving automation sends the details.

For step-by-step Flow and Apex examples, see
[Save or route Record Health Check errors](../platform-events/error-log.md).

## When Record Health Check publishes the event

The **Publish Error Log Event** checkbox on each Check Set controls this event. The checkbox is on
by default.

- Leave it selected when restricted error monitoring is configured or may be needed.
- Clear it when your org must not publish technical error details for that Check Set.
- Clearing it does not turn off Salesforce debug logs.
- If Record Health Check cannot find or load the Check Set, it leaves publication enabled so that
  the configuration error can still be reported.

Record Health Check creates this event only for an `ERROR`. It does not create one for informational,
warning, or debug messages.

The event is configured as a **High Volume Platform Event** with **Publish Immediately** behavior.
Record Health Check holds errors until the current request reaches its normal completion point, then
publishes them in groups of up to 100. If Salesforce accepts an event and later work in the same
transaction rolls back, the event is not rolled back with that work.

Publication is best effort. A transaction that stops immediately because it reaches an uncatchable
Salesforce limit might never reach the publication step. Salesforce accepting a Platform Event also
does not prove that a Flow, Apex trigger, or external integration processed it successfully. Monitor
both the Salesforce process that runs Record Health Check and the automation that receives the
events.

## Fields

The API names below are the field names used by Flow, Apex, and integrations.

| Field label | API name | Type | What it contains |
| --- | --- | --- | --- |
| Event ID | `EventId__c` | Text(80), required | Unique ID generated for this error event. Save it in a unique field to prevent the same event from creating duplicate work. |
| Run ID | `RunId__c` | Text(120), required | ID that connects errors from the same Record Health Check run. |
| Occurred At | `OccurredAt__c` | Date/Time, required | Date and time when Record Health Check created the event. |
| Contract Version | `ContractVersion__c` | Text(10), required | Version of this event's field contract. The current value is `1.0`. |
| Framework Version | `FrameworkVersion__c` | Text(20) | Record Health Check code version that created the event. |
| Level | `Level__c` | Text(10), required | Always `ERROR` for events published by Record Health Check. |
| Code | `Code__c` | Text(120) | Technical error code, such as `APEX_EVALUATOR_ERROR` or `UNHANDLED_EXCEPTION`. These codes can change as the package implementation changes. |
| Message | `Message__c` | Long Text Area(32,768) | Cleaned exception message or a short summary of the error details available to Record Health Check. |
| Exception Type | `ExceptionType__c` | Text(120) | Apex exception type, when an exception caused the error. |
| Stack Trace | `StackTrace__c` | Long Text Area(32,768) | Cleaned Apex stack trace, when one is available. |
| Record ID | `RecordId__c` | Text(18) | Salesforce record that was being checked, when known. |
| Check Set Developer Name | `CheckSetDeveloperName__c` | Text(120) | Developer Name of the Check Set associated with the error, when known. |
| Check Developer Name | `CheckDeveloperName__c` | Text(120) | Developer Name of the Check associated with the error, when known. |
| User ID | `UserId__c` | Text(18) | ID of the Salesforce user whose transaction ran Record Health Check. |

**Developer Name or Qualified API Name?** These two event fields contain developer names used by
the package while it runs. When Apex or Flow starts a health check, continue to pass the Check Set's
exact **Qualified API Name** copied from Setup. See
[Check Set fields](fields-check-set.md) for the distinction.

## Example event

This example shows the shape of a Log event. The IDs and error details are illustrative.

```json
{
  "ContractVersion__c": "1.0",
  "FrameworkVersion__c": "2.0.4",
  "EventId__c": "rhc-run-001-APEX_EVALUATOR_ERRO-18273",
  "RunId__c": "rhc-run-001",
  "OccurredAt__c": "2026-07-21T15:30:00.000Z",
  "Level__c": "ERROR",
  "Code__c": "APEX_EVALUATOR_ERROR",
  "CheckSetDeveloperName__c": "Account_Readiness",
  "CheckDeveloperName__c": "Account_Strategic_Readiness",
  "RecordId__c": "001000000000001AAA",
  "UserId__c": "005000000000001AAA",
  "ExceptionType__c": "System.QueryException",
  "Message__c": "Illustrative cleaned exception message",
  "StackTrace__c": "Illustrative cleaned stack trace"
}
```

Do not paste real production event bodies into unrestricted tickets, chat channels, or public
documentation. A message or stack trace can contain record IDs, field names, or other details about
your org.

## Prevent duplicate work and logging loops

Salesforce can deliver a Platform Event more than once. Before creating a case, notification, or
saved error record, check whether your destination already contains `EventId__c`. Store that field
as **Unique** when the destination supports it. Make the rest of the processing safe to run again.

`RecordHealthCheckLogger.enterSubscriberContext()` is an internal package safeguard, not an Apex API
available to code created in an installing org. The practical safeguard is to keep the receiving
trigger focused on saving or routing the error and never call Record Health Check from it.

```apex
trigger RecordHealthCheckLogSubscriber on rhc__Record_Health_Check_Log__e (after insert) {
  // Pass the events to your restricted handler. The handler should check EventId__c
  // before creating a record, notification, or other follow-up work.
  MyRecordHealthCheckLogHandler.handle(Trigger.new);
}
```

`rhc__` appears in this example because the Platform Event and Apex class come from the installed
Record Health Check package. Your handler class, such as `MyRecordHealthCheckLogHandler`, belongs to
your org and does not use the package prefix.

Do not start another health check or deliberately publish another Log event from automation that
receives this event. That can create a repeating loop.

## What this event cannot guarantee

| Situation | What to do |
| --- | --- |
| A transaction stops before Record Health Check can publish its held errors | Keep Salesforce debug logs and your normal Apex exception monitoring available. |
| Salesforce accepts the event, but receiving automation later fails | Monitor the Platform Event-triggered Flow, Apex trigger, or integration separately. |
| Your team needs a lasting error history | Save the event to a restricted custom object or external monitoring system because Platform Event retention is temporary. |
| Record ID, Check Set, or Check is blank | Continue investigating with Run ID, Code, User ID, and time. The error can occur before Record Health Check knows every value. |
| Your automation needs stable business outcome codes | Use the public [Reason Code reference](../reference/contracts/reason-codes.md). `Code__c` on this technical event can contain package-internal codes. |

## Related

- [Save or route Record Health Check errors](../platform-events/error-log.md)
- [Choose whether to publish result events](../integration/lifecycle-events.md)
- [Record Health Check Set Run Platform Event](event-set-run.md)
- [Record Health Check Result Platform Event](event-check-result.md)
- [Troubleshoot Record Health Check](../guides/troubleshoot-with-show-diagnostics.md)
