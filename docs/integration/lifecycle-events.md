# Lifecycle events

> [!NOTE]
> On this page, decide whether a subscriber needs Check Set Run or Rule Result lifecycle events and enable an after-commit contract without making the Lightning, Flow, or Apex caller wait.

Use lifecycle events when an independent subscriber needs completion information after an explicit
Record Health Check run. This reference documents publication behavior, event bodies,
permissions, retention, replay, and subscriber requirements.

Start with the **Check Set Run** event when the subscriber needs one summary per review. Add **Rule
Result** events only when the subscriber needs per-Rule status, reason, and severity.

## Choose the event detail

| Subscriber needs… | Event | Start with |
| --- | --- | --- |
| One summary for a completed Check Set | [`Record_Health_Check_Set_Run__e`](../metadata/event-set-run.md) | Check Set **Publish User Run Event** |
| One result for each selected Rule | [`Record_Health_Check_Rule_Result__e`](../metadata/event-rule-result.md) | Rule **Publish User Result Event** |
| Restricted Framework error diagnostics | [`Record_Health_Check_Log__e`](../metadata/event-log.md) | Check Set **Publish Error Log Event** (default on; uncheck to opt out) |
| The immediate decision in the current transaction | Neither lifecycle event | Use the Lightning, Apex, or Flow response instead |

The Set Run and Rule Result events are **high-volume Platform Events** configured as **Publish
After Commit**. They carry the
evaluated record's ID in `RecordId__c` when one is available, but exclude queries, messages, user
identity, and field values. Automatic record-page checks never publish;
explicit Run and Rerun actions can publish when enabled.

**Publish After Commit** means Salesforce delivers the event only if the transaction that ran the
health check commits successfully. This prevents a subscriber from recording or acting on a result
from work that Salesforce later rolled back. The tradeoff is that the caller cannot wait for the
subscriber or use the event for an immediate decision; Apex and Flow must branch on the synchronous
result instead.

## What these events are

- Minimal completion facts for one Check Set run and its server-finalized Rule results.
- A way for subscribers to build history, notifications, exports, analytics, or other automation
  without coupling to the health-check call itself.

## What these events are not

- They are not the synchronous health-check response.
- They are not a guaranteed or permanent audit log; Salesforce retains high-volume platform events
  for 72 hours, not indefinitely.
- They are not exactly-once commands. Subscribers must handle duplicates and replay safely.
- Publish acceptance does not prove delivery or successful subscriber processing.

For the end-to-end model, start with [Integrate Record Health Check](../integration/README.md).

## Prerequisites and sandbox quick start

1. Assign subscriber access to the selected platform event (object permissions on the event) and
   choose Flow, Apex, or Pub/Sub API as the subscriber technology. Custom fields on these platform
   events are not field-level-security permissionable; granting event object access is enough for
   field visibility in subscriber UIs. The User and Admin Permission Sets grant create/read on Set
   Run and Rule Result events. They do **not** grant `Record_Health_Check_Log__e`; grant Log object
   access separately to the users or integration that subscribe to error diagnostics.
2. In a sandbox, enable **Publish User Run Event** on one Check Set. Leave Rule publication off for the
   first test.
3. Subscribe before clicking Run or Rerun; automatic page load cannot publish.
4. Verify one `COMPLETED` Set event after commit, then test rollback, replay, and duplicate handling.
5. Enable individual Rule events only after the Set subscriber is operating within event
   allocations.

## When events publish

Publishing runs from deliberate public Apex, packaged Flow, and user-initiated Lightning component
runs. Automatic Lightning record-page runs never publish.

| Source constant | Meaning in shipped callers |
| --- | --- |
| `APEX_API` | Public `RecordHealthCheck` Apex methods |
| `FLOW` | Packaged Flow actions |
| `USER_INITIATED` | An explicit Run or Rerun action in the Lightning component |
| `SCHEDULED` | Packaged scheduled Apex adapter |
| `BATCH` | Packaged Batch Apex adapter |
| `QUEUEABLE` | Packaged Queueable Apex adapter |
| `FUTURE` | Attribution value for legacy future callers migrating to Queueable |
| `AGENT` | Attribution value for agent/tool callers that use the public Apex API |
| `RUN_ON_LOAD` | Lightning automatic page load; controller keeps publication off |

Lightning automatic loads never publish. Programmatic callers publish only when they select a
publication mode other than `NONE` and Check Set / Rule metadata permits the event. Event
subscribers call `enterSubscriberContext()` so nested Framework work does not publish again.

Keeping page-load publication off protects platform-event allocations. Subscriber context keeps a
subscriber from publishing another lifecycle event indefinitely. Each published event still carries
the caller's source so operators can see which entry point produced it.

Publish failures are logged and **do not** change Rule or Check Set results.

Events are chunked in batches of **100** (`PUBLISH_CHUNK_SIZE`).

## Publication settings

Lifecycle publication starts off because events consume the org's Platform Event allocation and
may trigger subscriber automation, storage, notifications, or external processing. Error-log
publication starts on so framework failures are observable unless an administrator opts a Check
Set out.

| Metadata | Field | Default | What it controls |
| --- | --- | --- | --- |
| Check Set | **Publish User Run Event** (`PublishUserRunEvent__c`) | Off | One `Record_Health_Check_Set_Run__e` per evaluated record after a completed deliberate LWC, Apex, or Flow run |
| Rule | **Publish User Result Event** (`PublishUserResultEvent__c`) | Off | One `Record_Health_Check_Rule_Result__e` per server-finalized Rule result in a deliberate LWC, Apex, or Flow run |
| Check Set | **Publish Error Log Event** (`PublishErrorLogEvent__c`) | On | A `Record_Health_Check_Log__e` for each Framework `ERROR` associated with the Check Set |

Page-load card evaluations never publish lifecycle events even if their checkboxes are on. Error
Log events are independent of deliberate-run source restrictions and publish immediately when an
`ERROR` is captured. If the Framework cannot resolve a Check Set, Log publication remains enabled.

For a user-initiated Lightning run, the completion call publishes the outcomes returned by the
progressive browser evaluation after filtering them to the requested record and the Rules in the
resolved Check Set. It does not re-evaluate the Rules in the completion transaction. Treat these
Lightning lifecycle events as advisory telemetry: subscribers that make security-sensitive or
business-critical changes must re-evaluate the record through a server-side Apex or Flow entry
point before acting. Apex- and Flow-originated lifecycle events are produced directly from their
server-side evaluations.

## Contract versions on events

| Field | Value | Meaning |
| --- | --- | --- |
| `ContractVersion__c` | `1.0` | Lifecycle event contract (`RecordHealthCheckLifecyclePublisher.CONTRACT_VERSION`) |
| `FrameworkVersion__c` | Current package value | Framework release that produced the event |

This is separate from the synchronous `RecordHealthCheckResponse` contract. The event and
synchronous response schemas version independently, so consumers must read the version field from
the event they are processing.

Subscribers should store or inspect `ContractVersion__c`, not infer the event shape from
`FrameworkVersion__c`. A Record Health Check release can change implementation behavior without changing the event
schema; an incompatible event-field change requires a new contract version.

## What is never included on an event

The Set Run and Rule Result events intentionally omit:

- User Id
- User-facing messages
- Found / Expected values
- SOQL and formula source
- `adminDetail` text

They include `RecordId__c` when one evaluated record is available. Subscribers join to additional
Salesforce data under their own security model using the Record ID, metadata Qualified API Names, and
`RunId__c`.

---

## Event metadata references

| Platform Event | Detailed reference | Purpose |
| --- | --- | --- |
| `Record_Health_Check_Set_Run__e` | [Check Set Run Platform Event](../metadata/event-set-run.md) | One completion summary and outcome counts for a Check Set run |
| `Record_Health_Check_Rule_Result__e` | [Rule Result Platform Event](../metadata/event-rule-result.md) | One finalized public Rule outcome |
| `Record_Health_Check_Log__e` | [Log Platform Event](../metadata/event-log.md) | Restricted Framework `ERROR` diagnostics |

## Admin checklist before enabling

1. Review org platform-event allocations and existing subscribers.
2. Enable publication only for deliberate LWC, Apex, Flow, scheduled, or batch runs.
3. Start with a sandbox subscriber (Flow, Apex trigger, or export).
4. Use the platform event replay ID and subscriber error handling required by your business process;
   a publishing or subscriber error does not change the completed health result.
5. Treat `RecordId__c` as optional and correlate with `RunId__c` and metadata Qualified API Names.

## Subscriber failure guidance

| Symptom | Likely cause | What to investigate |
| --- | --- | --- |
| No event after page open | Automatic runs are blocked from publishing | Click Run/Rerun or invoke Apex/Flow deliberately |
| No event after an explicit run | Metadata switch is off, source is blocked, or transaction rolled back | Check the publication field, source, logs, and commit outcome |
| Duplicate processing | Replay or subscriber retry delivered the event again | Keep unique by `EventId__c`; make follow-on work safe to repeat |
| Missing record context | The run had no single record, or a record ID was not available at publish | Correlate with `RunId__c` and metadata names; `RecordId__c` is set only when available |
| Subscriber failure | Subscriber limits, access, or business logic failed independently | Monitor and retry in the subscriber; keep the completed health result as already finalized |

## Diagnostics events are a separate channel

`Record_Health_Check_Log__e` serves a different purpose from the two lifecycle-result events. It
carries restricted Framework `ERROR` diagnostics and uses **Publish Immediately**.

| Property | Lifecycle events (Set / Rule) | Diagnostics event (Log) |
| --- | --- | --- |
| Purpose | Completion facts | Errors that need reproducing |
| Default | Optional per Set/Rule (off) | **On by default**; opt out per Check Set with `PublishErrorLogEvent__c` |
| Publish behavior | Publish After Commit | **Publish Immediately**: survives the rollback a failing check triggers |
| Carries error detail | No: record ID + counts/status only | Yes: record ID plus message, exception type, stack trace |
| Level | All completed runs | `ERROR` only |
| Access | Standard subscriber | **Restricted**: only grant access to the subscriber when appropriate |

The Log event is independent of **Publish User Run Event** and **Publish User Result Event**. It is controlled
by the Check Set's default-on **Publish Error Log Event** field. Its complete event body, security
requirements, subscriber loop guard, possibilities, and known limitations are in the [Log Platform
Event reference](../metadata/event-log.md).

## Related

- [Platform Event subscription guides](../platform-events/README.md)
- [Apex API](../api/apex-api.md)
- [Flow actions](flow-actions.md)
- [Lightning component](lightning-component.md)
- [Check Set fields](../metadata/fields-check-set.md): Publish User Run Event and Publish Error Log Event
- [Rule fields](../metadata/fields-check-rule.md): Publish User Result Event
- [Check Set Run Platform Event](../metadata/event-set-run.md)
- [Rule Result Platform Event](../metadata/event-rule-result.md)
- [Log Platform Event](../metadata/event-log.md)
- [Revalidate an installation](../installation/04-upgrading.md)
- [Reason Codes](../reference/reference-reason-codes.md)
