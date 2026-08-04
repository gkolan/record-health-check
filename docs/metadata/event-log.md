# Log Platform Event (`Record_Health_Check_Log__e`)

`Record_Health_Check_Log__e` carries structured Framework `ERROR` information. Unlike the two
lifecycle events, it uses **Publish Immediately**, contains restricted diagnostic detail, and is
enabled by default through the Check Set's **Publish Error Log Event** setting.

Use this event for restricted technical operations and support, not readiness workflows.

## When to use this event

| Possibility | What the subscriber can do |
| --- | --- |
| Persisted error history | Persist Framework errors beyond debug-log and Platform Event retention |
| Technical alerting | Notify a restricted support channel when a new error Code or exception appears |
| Incident correlation | Group errors by Run ID, Salesforce record, Check Set, Rule, user, and Framework version |
| Release monitoring | Compare error rates before and after a Framework or configuration deployment |
| Reproduction support | Use record and metadata identifiers to reproduce a failure under controlled access |

Use the Log event for ERROR diagnostics; use Rule Result and Set Run events for finalized
outcomes.

The packaged User and Admin Permission Sets do **not** grant create or read access on
`Record_Health_Check_Log__e`. Grant that object access separately to the restricted users or
integration that subscribe to error diagnostics.

## How publication works

`RecordHealthCheckLogger` holds each Framework log entry whose level is `ERROR`. The public Apex,
Flow, and Lightning boundaries call `flush()`, which publishes held events in chunks of 100 and
clears held entries for the transaction.

| Behavior | Log event |
| --- | --- |
| Event type | High Volume |
| Publish behavior | Publish Immediately |
| Default | Enabled (`PublishErrorLogEvent__c = true`) |
| Published levels | `ERROR` only |
| Check Set Custom Metadata field | `PublishErrorLogEvent__c`; uncheck to opt out for that Check Set |
| Contract version | `1.0` |
| Failure behavior | Best effort; publishing failure is logged and does not change the health-check result |

`Publish Immediately` allows an accepted event to survive a later transaction rollback. However, an
uncatchable governor-limit abort can prevent `flush()` from running, so this event is not a complete
replacement for Salesforce debug logs and platform exception monitoring.

When the Framework cannot resolve a Check Set, publication remains enabled. This preserves error
visibility for missing or invalid configuration. Unchecking the field affects only Log platform
events; Salesforce debug-log output is unchanged.

## Fields

| Setup label | API name | Type | Required/default | Meaning |
| --- | --- | --- | --- | --- |
| Event ID | `EventId__c` | Text(80) | Required; generated | Application-level unique key. |
| Run ID | `RunId__c` | Text(120) | Required; generated or inherited | Correlates errors from one Framework run. |
| Occurred At | `OccurredAt__c` | DateTime | Required; generated | UTC event-construction time. |
| Contract Version | `ContractVersion__c` | Text(10) | Required; `1.0` | Version of the diagnostics-event schema. |
| Framework Version | `FrameworkVersion__c` | Text(20) | Optional; Framework supplied | Framework release that produced the error. |
| Level | `Level__c` | Text(10) | Required; `ERROR` | Log level. Record Health Check publishes only `ERROR` events. |
| Code | `Code__c` | Text(120) | Optional | Stable or internal event code such as `APEX_EVALUATOR_ERROR` or `UNHANDLED_EXCEPTION`. |
| Message | `Message__c` | Long Text Area(32,768) | Optional | Cleaned-up exception message or compact sorted field summary. |
| Exception Type | `ExceptionType__c` | Text(120) | Optional | Apex exception type when an exception is available. |
| Stack Trace | `StackTrace__c` | Long Text Area(32,768) | Optional | Cleaned-up Apex stack trace. |
| Record ID | `RecordId__c` | Text(18) | Optional | Salesforce record being evaluated, when known. |
| Check Set Developer Name | `CheckSetDeveloperName__c` | Text(120) | Optional | Check Set `DeveloperName` associated with the error. |
| Rule Developer Name | `RuleDeveloperName__c` | Text(120) | Optional | Rule `DeveloperName` associated with the error. |
| User ID | `UserId__c` | Text(18) | Optional | Running Salesforce user from `UserInfo.getUserId()`. |

## Example event body

```json
{
  "ContractVersion__c": "1.0",
  "FrameworkVersion__c": "current-release",
  "EventId__c": "rhc-run-001-APEX_EVALUATOR_ERRO-18273",
  "RunId__c": "rhc-run-001",
  "OccurredAt__c": "2026-07-21T15:30:00.000Z",
  "Level__c": "ERROR",
  "Code__c": "APEX_EVALUATOR_ERROR",
  "CheckSetDeveloperName__c": "Account_Readiness",
  "RuleDeveloperName__c": "Account_Strategic_Readiness",
  "RecordId__c": "001000000000001AAA",
  "UserId__c": "005000000000001AAA",
  "ExceptionType__c": "System.QueryException",
  "Message__c": "Illustrative cleaned-up exception message",
  "StackTrace__c": "Illustrative cleaned-up stack trace"
}
```

Use illustrative cleaned-up values in public documentation and unrestricted support channels;
keep real stack traces, IDs, and production error messages out of those surfaces.

## Security requirements

This event can contain a record ID, user ID, exception message, exception type, and stack trace.
Treat the event and every persisted copy as restricted operational data.

| Concern | Requirement |
| --- | --- |
| Access | Grant event subscription and persisted-log access only to approved administrators or support staff. |
| Subscriber permissions | Apply least privilege to the Apex class, Flow, integration user, and destination object. |
| Retention | Define deletion requirements for persisted diagnostics. |
| External sharing | Share Log event data only after a security review. |
| Safe handling | Assume an exception message can still contain organization-specific identifiers. |
| Custom additions | Keep Found, Expected, and source field values out of custom logging. |

## Subscriber loop protection

A subscriber that processes `Record_Health_Check_Log__e` must call
`RecordHealthCheckLogger.enterSubscriberContext()` before its work. This prevents an error raised by
the subscriber from publishing another Log event onto the same channel.

```apex
trigger RecordHealthCheckLogSubscriber on Record_Health_Check_Log__e (after insert) {
    RecordHealthCheckLogger.enterSubscriberContext();
    // Hand off only to restricted processing that is safe to run again.
}
```

The subscriber must also keep unique by `EventId__c`, handle replay, and make follow-on work safe to
repeat.

## Known limitations

| Limitation | Design response |
| --- | --- |
| An uncatchable governor-limit abort can prevent `flush()` and produce no Log event. | Keep Salesforce debug logs and platform exception monitoring available. |
| Publish acceptance does not prove delivery, persistence, alerting, or investigation. | Monitor the subscriber and every downstream destination independently. |
| Platform Event retention is temporary. | Persist events in a subscriber-owned store when long-term history is required. |
| Record ID or metadata name can be blank when the failure occurred before that context was known. | Treat those fields as optional during correlation. |
| `Code__c` can contain Framework-internal codes. | Use the public [Reason Code registry](../reference/reference-reason-codes.md) only for public Rule outcomes. |

## Related

- [Subscribe with Flow or Apex](../platform-events/error-log.md)
- [Lifecycle-events overview](../integration/lifecycle-events.md)
- [Check Set Run Platform Event](event-set-run.md)
- [Rule Result Platform Event](event-rule-result.md)
- [Troubleshoot with Show Diagnostics](../guides/troubleshoot-with-show-diagnostics.md)
- [Reason Codes](../reference/reference-reason-codes.md)
