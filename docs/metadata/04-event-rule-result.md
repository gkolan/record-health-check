# Rule Result Platform Event (`Record_Health_Check_Rule_Result__e`)

`Record_Health_Check_Rule_Result__e` contains the finalized public outcome of one Rule in a
deliberately initiated run. It is a high-volume Salesforce Platform Event with **Publish After
Commit** behavior.

Use the [lifecycle-events overview](../integration/03-lifecycle-events.md) for publication sources,
transaction timing, event selection, and subscriber failure guidance.

## When to use this event

Choose the Rule Result event only when the subscriber needs per-Rule information.

| Possibility | What the subscriber can do |
| --- | --- |
| Rule history | Persist status and Reason Code trends for each Rule and Salesforce record |
| Targeted alerts | Notify an owning team when a selected Rule returns `FAIL` or `ERROR` |
| Automation routing | Route by `Status__c`, `ReasonCode__c`, `Severity__c`, and stable Rule Developer Name |
| Configuration analytics | Identify Rules that often skip or cannot evaluate |
| Cross-system readiness | Send minimal finalized outcomes without sending Found, Expected, or administrator-authored messages |

Use the Set Run event instead when one completion summary is sufficient. Use a synchronous response
when the current transaction must branch immediately.

## Publication conditions

The Framework publishes one event for a Rule only when every condition is true:

| Required condition | What to verify |
| --- | --- |
| Publication is enabled | **Publish User Result Event** (`PublishUserResultEvent__c`) is checked on the Rule. |
| The result is final | The Rule finished during a deliberate Rule or Check Set run. |
| The source is allowed | Source is `APEX_API`, `FLOW`, `USER_INITIATED`, `SCHEDULED`, `BATCH`, `QUEUEABLE`, `FUTURE`, or `AGENT`. |
| Work is committed | The Salesforce transaction commits. |

Automatic Lightning record-page evaluation, subscriber context, blank sources, and unknown sources
do not publish.

`USER_INITIATED` events contain the outcomes returned by the progressive Lightning browser run.
They are filtered to the requested record and the Rules in the resolved Check Set, but they are not
server-attested. Treat them as advisory monitoring data. Automation that makes security-sensitive or
business-critical changes must re-evaluate through a server-side Apex or Flow entry point before
acting. Other supported sources publish directly from their server-side evaluations.

## Event definition

| Property | Value |
| --- | --- |
| Salesforce metadata type | Platform Event |
| API name | `Record_Health_Check_Rule_Result__e` |
| Setup label | Record Health Check Rule Result |
| Event type | High Volume |
| Publish behavior | Publish After Commit |
| Contract version | `1.0` |

## Fields

| Setup label | API name | Type | Required/default | Meaning |
| --- | --- | --- | --- | --- |
| Event ID | `EventId__c` | Text(80) | Required; generated | Deterministic application-level key derived from Run ID, Rule identity, and Record ID. |
| Run ID | `RunId__c` | Text(120) | Required; supplied or generated | Correlates this result with its Check Set run, response, and Framework logs. |
| Check Set Qualified API Name | `CheckSetQualifiedApiName__c` | Text(80) | Required | Parent Check Set `QualifiedApiName`. |
| Rule Qualified API Name | `RuleQualifiedApiName__c` | Text(80) | Required | Finalized Rule `QualifiedApiName`. |
| Record ID | `RecordId__c` | Text(18) | Optional | Salesforce record evaluated when one record is available. |
| Status | `Status__c` | Text(30) | Required | `PASS`, `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, or `ERROR`. |
| Reason Code | `ReasonCode__c` | Text(80) | Optional | Stable public Reason Code. Diagnostics-only codes are not published here. |
| Severity | `Severity__c` | Text(20) | Optional | `CRITICAL`, `WARNING`, or `INFO` when applicable. |
| Occurred At | `OccurredAt__c` | DateTime | Required; generated | UTC time when the Framework constructed the event. |
| Source | `Source__c` | Text(30) | Required; caller-derived | `APEX_API`, `FLOW`, `USER_INITIATED`, `SCHEDULED`, `BATCH`, `QUEUEABLE`, `FUTURE`, or `AGENT`. |
| Contract Version | `ContractVersion__c` | Text(10) | Required; `1.0` | Version of this event schema. |
| Framework Version | `FrameworkVersion__c` | Text(20) | Required | Framework release that produced the event. |
| Contains Restricted Detail | `ContainsRestrictedDetail__c` | Checkbox | Defaults to false | Indicates that restricted detail existed on the in-memory result. It does not publish that detail. |

## Example event body

```json
{
  "ContractVersion__c": "1.0",
  "FrameworkVersion__c": "current-release",
  "EventId__c": "rhc-run-001-0123456789abcdef",
  "RunId__c": "rhc-run-001",
  "CheckSetQualifiedApiName__c": "rhc__Account_Readiness",
  "RuleQualifiedApiName__c": "rhc__Account_Has_Contact",
  "RecordId__c": "001000000000001AAA",
  "Status__c": "FAIL",
  "ReasonCode__c": null,
  "Severity__c": "WARNING",
  "OccurredAt__c": "2026-07-21T15:30:00.000Z",
  "Source__c": "USER_INITIATED",
  "ContainsRestrictedDetail__c": false
}
```

Values are illustrative. Consumers must ignore additive fields they do not recognize.

## Interpret the outcome

| Status | Subscriber interpretation |
| --- | --- |
| `PASS` | The Rule's business condition was satisfied. |
| `FAIL` | The Rule evaluated normally and found a business condition that needs attention. |
| `SKIPPED` | The Rule did not apply, a prerequisite was not met, or configured empty-result behavior selected skip. |
| `UNABLE_TO_EVALUATE` | Access, configuration, dependency, or available data prevented a reliable decision. Use `ReasonCode__c`. |
| `ERROR` | An unexpected Framework, evaluator, or platform problem occurred. Investigate logs and the Log event. |

Route `PASS`, `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, and `ERROR` separately. Branch on Status,
Reason Code, and Developer Name; display messages are intentionally absent from this contract.

## Subscriber design

| Concern | Subscriber responsibility |
| --- | --- |
| Duplicate delivery | Keep unique with `EventId__c` and make follow-on work safe to repeat. |
| Routing | Use API values, not translated labels or administrator-authored text. |
| Future values | Send unknown additive Reason Codes and statuses to a safe review path. |
| Run correlation | Use `RunId__c` to group Rule Result events with their Set Run summary. |
| Retention | Persist events when history beyond Platform Event retention is required. |
| Additional data | Query under the subscriber's own security context. |
| Restricted detail | Treat `ContainsRestrictedDetail__c = true` as a signal that restricted detail was withheld, not as permission to expose it. |

## Limits and security

The event excludes messages, SOQL, Found, Expected, stack traces, user identity, and
`adminDetail`. `ContainsRestrictedDetail__c` is a presence flag only. `RecordId__c` can identify a
Salesforce record, so access to subscribers and persisted results must match the referenced data's
sensitivity.

Publication is best effort and chunked in groups of 100. A publishing or subscriber failure does
not change the finalized Rule status.

## Related

- [Subscribe with Flow or Apex](../platform-events/02-rule-result.md)
- [Lifecycle-events overview](../integration/03-lifecycle-events.md)
- [Check Set Run Platform Event](03-event-set-run.md)
- [Log Platform Event](05-event-log.md)
- [Rule fields](02-fields-check-rule.md): **Publish User Result Event**
- [Reason Codes](../reference/contracts/01-reason-codes.md)
