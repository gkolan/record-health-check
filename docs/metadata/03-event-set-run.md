# Check Set Run Platform Event (`Record_Health_Check_Set_Run__e`)

`Record_Health_Check_Set_Run__e` contains one per-record completion summary for a deliberately initiated Check
Set run. It is a high-volume Salesforce Platform Event with **Publish After Commit** behavior.

Use the [lifecycle-events overview](../integration/03-lifecycle-events.md) for publication sources,
optional publication behavior, transaction timing, and subscriber failure guidance.

## When to use this event

Choose the Set Run event when a subscriber needs one summary per completed Check Set rather than
one event per Rule.

| Possibility | What the subscriber can do |
| --- | --- |
| Health history | Persist one row per `RunId__c` and record to show how overall readiness changes over time |
| Operational monitoring | Alert when `SystemErrorCount__c` or `UnableCount__c` is greater than zero |
| Adoption analytics | Measure deliberate reviews by Check Set, source, and time period |
| Process coordination | Start downstream work only after a deliberate Check Set run commits |
| Completion reporting | Compare passed, failed, skipped, unable, and system-error counts without receiving Rule detail |

For an immediate decision in the same transaction, use the synchronous
[Apex API](../api/01-apex-api.md) or [Flow action](../integration/02-flow-actions.md)
response instead.

## Publication conditions

The Framework publishes this event only when every condition is true:

| Required condition | What to verify |
| --- | --- |
| Publication is enabled | **Publish User Run Event** (`PublishUserRunEvent__c`) is checked on the Check Set. |
| The source is allowed | The completed run came from `APEX_API`, `FLOW`, `USER_INITIATED`, `SCHEDULED`, `BATCH`, `QUEUEABLE`, `FUTURE`, or `AGENT`. |
| Work is committed | The Salesforce transaction commits. |

Automatic Lightning record-page evaluation (`RUN_ON_LOAD`) never publishes. Subscriber context
(`SUBSCRIBER`), blank sources, and unknown sources are blocked to prevent feedback loops.

## Event definition

| Property | Value |
| --- | --- |
| Salesforce metadata type | Platform Event |
| API name | `Record_Health_Check_Set_Run__e` |
| Setup label | Record Health Check Set Run |
| Event type | High Volume |
| Publish behavior | Publish After Commit |
| Contract version | `1.0` |
| Phase | `COMPLETED` |

## Fields

| Setup label | API name | Type | Required/default | Meaning |
| --- | --- | --- | --- | --- |
| Event ID | `EventId__c` | Text(80) | Required; generated | Application-level unique key for consumers; keep the Salesforce replay ID for replay position only. |
| Run ID | `RunId__c` | Text(120) | Required; supplied or generated | Correlates the Set event, Rule Result events, synchronous response, and Framework logs. |
| Phase | `Phase__c` | Text(30) | Required; `COMPLETED` | Lifecycle phase. `COMPLETED` is the only supported value. |
| Check Set Qualified API Name | `CheckSetQualifiedApiName__c` | Text(80) | Required | Check Set `QualifiedApiName`; distinguishes packaged and subscriber definitions. |
| Record ID | `RecordId__c` | Text(18) | Required in framework publications | Salesforce record represented by this summary. |
| Occurred At | `OccurredAt__c` | DateTime | Required; generated | UTC time when the Framework constructed the event. |
| Source | `Source__c` | Text(30) | Required; caller-derived | `APEX_API`, `FLOW`, `USER_INITIATED`, `SCHEDULED`, `BATCH`, `QUEUEABLE`, `FUTURE`, or `AGENT`. |
| Contract Version | `ContractVersion__c` | Text(10) | Required; `1.0` | Version of this Platform Event schema, independent of synchronous response versions. |
| Framework Version | `FrameworkVersion__c` | Text(20) | Required | Framework release that produced the event. |
| Eligible Rule Count | `EligibleRuleCount__c` | Number(5,0) | Optional; generated | Rules included after the Framework selected definitions for the run. |
| Evaluated Rule Count | `EvaluatedRuleCount__c` | Number(5,0) | Optional; generated | Finalized Rule results. Equal to eligible count for completed events. |
| Passed Count | `PassedCount__c` | Number(5,0) | Optional; generated | Rule results with `PASS`. |
| Failed Count | `FailedCount__c` | Number(5,0) | Optional; generated | Rule results with `FAIL`. |
| Skipped Count | `SkippedCount__c` | Number(5,0) | Optional; generated | Rule results with `SKIPPED`. |
| Unable Count | `UnableCount__c` | Number(5,0) | Optional; generated | Rule results with `UNABLE_TO_EVALUATE`. |
| System Error Count | `SystemErrorCount__c` | Number(5,0) | Optional; generated | Rule results with `ERROR`. |

## Example event body

```json
{
  "ContractVersion__c": "1.0",
  "FrameworkVersion__c": "current-release",
  "EventId__c": "rhc-run-001-SET-184275",
  "RunId__c": "rhc-run-001",
  "Phase__c": "COMPLETED",
  "CheckSetQualifiedApiName__c": "rhc__Account_Readiness",
  "RecordId__c": "001000000000001AAA",
  "OccurredAt__c": "2026-07-21T15:30:00.000Z",
  "Source__c": "USER_INITIATED",
  "EligibleRuleCount__c": 5,
  "EvaluatedRuleCount__c": 5,
  "PassedCount__c": 3,
  "FailedCount__c": 1,
  "SkippedCount__c": 1,
  "UnableCount__c": 0,
  "SystemErrorCount__c": 0
}
```

Values are illustrative. Subscribers must tolerate additive fields within contract version `1.0`.

## Subscriber design

| Concern | Subscriber responsibility |
| --- | --- |
| Duplicate delivery | Keep unique follow-on work with `EventId__c`; use the Salesforce replay ID for replay position. |
| Retries | Treat delivery as at least once and make processing safe to repeat. |
| Retention | Persist the event when history beyond Platform Event retention is required. |
| Business data | Join under the subscriber's own sharing and field-access model. |
| Missing Record ID | Allow `RecordId__c` to be blank for future call patterns. |
| Rule-level causes | Subscribe to Rule Result when you need Rule-level causes; Set Run counts summarize outcomes only. |

## Limits and security

The event intentionally excludes user identity, messages, SOQL, Found, Expected, and diagnostic
details. It can contain a Salesforce Record ID, so restrict subscriber and persisted-history access
according to the sensitivity of the referenced objects.

Publication is best effort and chunked in groups of 100. Publish acceptance does not prove delivery
or successful subscriber processing, and subscriber failure never changes the completed Check Set result.

## Related

- [Subscribe with Flow or Apex](../platform-events/01-check-set-run.md)
- [Lifecycle-events overview](../integration/03-lifecycle-events.md)
- [Rule Result Platform Event](04-event-rule-result.md)
- [Log Platform Event](05-event-log.md)
- [Check Set fields](01-fields-check-set.md): **Publish User Run Event**
- [Reason Codes](../reference/contracts/01-reason-codes.md)
