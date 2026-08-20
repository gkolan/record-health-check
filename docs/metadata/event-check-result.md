# Check Result Platform Event (`Record_Health_Check_Result__e`)

> [!NOTE]
> On this page, look up every Check Result event field, learn exactly when the event publishes, and
> understand what a receiving Flow, Apex trigger, or integration must do with one finalized Check
> outcome.

> [!TIP]
> **Event navigation:** [Publication behavior](../integration/lifecycle-events.md) ·
> [Build Check Result receiving automation](../platform-events/check-result.md) ·
> **Look up Check Result fields**

`Record_Health_Check_Result__e` contains the finalized public outcome of one Check in a
deliberately initiated run. It is a high-volume Salesforce Platform Event with **Publish After
Commit** behavior.

Use the [lifecycle-events overview](../integration/lifecycle-events.md) for publication sources,
commit timing, event selection, and receiving-process failure guidance.

## When to use this event

Choose the Check Result event only when a separate process needs per-Check information.

| Possibility | What the receiving process can do |
| --- | --- |
| Check history | Persist status and Reason Code trends for each Check and Salesforce record |
| Targeted alerts | Notify an owning team when a selected Check returns `FAIL` or `ERROR` |
| Automation routing | Route by `Status__c`, `ReasonCode__c`, `Severity__c`, and stable Check Developer Name |
| Configuration analytics | Identify Checks that often skip or cannot evaluate |
| Cross-system readiness | Send minimal finalized outcomes without sending Found, Expected, or administrator-authored messages |

Use the Set Run event instead when one completion summary is sufficient. Use the result returned
directly to Flow or Apex when that process must make an immediate decision.

## Publication conditions

For a user selecting Run or Rerun on the Lightning card, the Check's **Publish User Result Event**
setting must be checked. The card then publishes this event for that Check after the explicit run
completes, including `PASS` and `SKIPPED` results.

For Flow, Apex, Queueable, Batch, or Scheduled Apex, the caller controls publication directly:

| Event Publication choice | Check Result events |
| --- | --- |
| `NONE` | None |
| `ACTIONABLE` | Only `FAIL`, `UNABLE_TO_EVALUATE`, and `ERROR` |
| `ALL` | Every result, including `PASS` and `SKIPPED` |

Programmatic callers do not use **Publish User Result Event**. In every case, Salesforce delivers
the event only after the transaction completes successfully.

Automatic Lightning record-page evaluation, a receiving-event transaction, blank sources, and unknown sources
do not publish.

`USER_INITIATED` events contain the outcomes returned by the progressive Lightning browser run.
They are filtered to the requested record and the Checks in the resolved Check Set, but the
publication step does not run those Checks again. Treat them as advisory monitoring data. Automation
that makes a security-sensitive or business-critical change must run the Check again through Apex
or Flow before acting. Other supported sources publish directly from their Apex evaluations.

## Event definition

| Property | Value |
| --- | --- |
| Salesforce metadata type | Platform Event |
| API name | `Record_Health_Check_Result__e` |
| Setup label | Record Health Check Result |
| Event type | High Volume |
| Publish behavior | Publish After Commit |
| Contract version | `1.0` |

## Fields

| Setup label | API name | Type | Required/default | Meaning |
| --- | --- | --- | --- | --- |
| Event ID | `EventId__c` | Text(80) | Required; generated | Unique application-level key for this publication. It retains a Run ID prefix but includes an internal nonce. |
| Run ID | `RunId__c` | Text(120) | Required; supplied or generated | Correlates this result with its Check Set run, response, and Record Health Check logs. |
| Check Set Qualified API Name | `CheckSetQualifiedApiName__c` | Text(80) | Required | Parent Check Set `QualifiedApiName`. |
| Check Qualified API Name | `CheckQualifiedApiName__c` | Text(80) | Required | Finalized Check `QualifiedApiName`. |
| Record ID | `RecordId__c` | Text(18) | Optional | Salesforce record evaluated when one record is available. |
| Status | `Status__c` | Text(30) | Required | `PASS`, `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, or `ERROR`. |
| Reason Code | `ReasonCode__c` | Text(80) | Optional | Stable public Reason Code. Diagnostics-only codes are not published here. |
| Severity | `Severity__c` | Text(20) | Optional | `CRITICAL`, `WARNING`, or `INFO` when applicable. |
| Occurred At | `OccurredAt__c` | DateTime | Required; generated | UTC time when Record Health Check constructed the event. |
| Source | `Source__c` | Text(30) | Required; caller-derived | `APEX_API`, `FLOW`, `USER_INITIATED`, `SCHEDULED`, `BATCH`, `QUEUEABLE`, `FUTURE`, or `AGENT`. |
| Contract Version | `ContractVersion__c` | Text(10) | Required; `1.0` | Version of this event schema. |
| Framework Version | `FrameworkVersion__c` | Text(20) | Required | Record Health Check implementation version that produced the event. |
| Contains Restricted Detail | `ContainsRestrictedDetail__c` | Checkbox | Defaults to false | Always `false` in the current Check Result event contract because this event never includes restricted diagnostic detail. |

## Example event body

```json
{
  "ContractVersion__c": "1.0",
  "FrameworkVersion__c": "current-release",
  "EventId__c": "rhc-run-001-0123456789abcdef",
  "RunId__c": "rhc-run-001",
  "CheckSetQualifiedApiName__c": "Account_Readiness",
  "CheckQualifiedApiName__c": "Has_At_Least_One_Contact",
  "RecordId__c": "001000000000001AAA",
  "Status__c": "FAIL",
  "ReasonCode__c": null,
  "Severity__c": "WARNING",
  "OccurredAt__c": "2026-07-21T15:30:00.000Z",
  "Source__c": "USER_INITIATED",
  "ContainsRestrictedDetail__c": false
}
```

These names represent configuration created by an administrator in your org, so they do not have an
`rhc__` prefix. An installed-package Check can have that prefix. Always use the exact Qualified API
Name from Setup. Receiving integrations must ignore new fields they do not recognize.

## Interpret the outcome

| Status | What the receiving process should understand |
| --- | --- |
| `PASS` | The Check's business condition was satisfied. |
| `FAIL` | The Check evaluated normally and found a business condition that needs attention. |
| `SKIPPED` | The Check did not apply, a prerequisite was not met, or configured empty-result behavior selected skip. |
| `UNABLE_TO_EVALUATE` | Access, configuration, dependency, or available data prevented a reliable decision. Use `ReasonCode__c`. |
| `ERROR` | An unexpected Record Health Check, custom Apex, or Salesforce problem occurred. Investigate logs and the Log event. |

Route `PASS`, `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, and `ERROR` separately. Branch on Status,
Reason Code, and Developer Name; display messages are intentionally absent from this contract.

## Receiving-process checklist

| Concern | What the Flow, Apex trigger, or integration must do |
| --- | --- |
| Duplicate delivery | Keep unique with `EventId__c` and make follow-on work safe to repeat. |
| Routing | Use API values, not translated labels or administrator-authored text. |
| Future values | Send unknown additive Reason Codes and statuses to a safe review path. |
| Run correlation | Use `RunId__c` to group Check Result events with their Set Run summary. |
| Retention | Persist events when history beyond Platform Event retention is required. |
| Additional data | Query using the receiving user's own Salesforce access. |
| Restricted detail | Treat `ContainsRestrictedDetail__c` as reserved for compatibility. It is always `false` in the current Check Result contract. |

## Limits and security

The event excludes messages, SOQL, Found, Expected, stack traces, user identity, and
`adminDetail`. `ContainsRestrictedDetail__c` is a presence flag only. `RecordId__c` can identify a
Salesforce record, so access to receiving automation and saved result records must match the referenced data's
sensitivity.

Publication can fail and is sent in groups of 100. A publication or receiving-process failure does
not change the finalized Check status.

## Related

- [Subscribe with Flow or Apex](../platform-events/check-result.md)
- [Lifecycle-events overview](../integration/lifecycle-events.md)
- [Check Set Run Platform Event](event-set-run.md)
- [Log Platform Event](event-log.md)
- [Check fields](fields-check.md): **Publish User Result Event**
- [Reason Codes](../reference/contracts/reason-codes.md)
