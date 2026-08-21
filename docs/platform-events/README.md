# Use Record Health Check Platform Events

Platform Events let a separate Flow, Apex trigger, or integration receive health-check results after
Record Health Check publishes them. Use them when another process must react to or save results
without being part of the process that ran the health check.

For example, a nightly scheduled Batch checks Accounts. A Platform Event-triggered Flow saves one
summary for each Account so administrators can report on changes over time.

Platform Events are optional. If the same Flow or Apex code that runs the health check can use or
save the returned results, choose `NONE` and handle those results directly. That is easier to follow
and does not use your org's Platform Event allocation.

## Decide whether you need a Platform Event

| Requirement | Recommended approach |
| --- | --- |
| The current Flow or Apex transaction needs the result immediately | Use the result returned by the [Flow action](../integration/flow-actions.md) or [Apex API](../api/apex-api.md). |
| A custom Batch must save results after each group of records | Use `NONE` and save the returned results in the Batch `execute()` method. |
| A separate Flow, Apex trigger, or integration must receive results | Publish a Platform Event. |
| Administrators need a lasting history | Save direct results or received events in a custom object created by your team. Platform Events are not permanent storage. |

## Choose a Platform Event

Record Health Check includes three Platform Events:

| Event | What one event represents | Use it when |
| --- | --- | --- |
| [Record Health Check Set Run](check-set-run.md) | One summary for one Salesforce record after its Check Set finishes | Totals are enough, such as 4 passed and 1 failed. Start here for history and dashboards. |
| [Record Health Check Result](check-result.md) | One result for one Check and one Salesforce record | Receiving automation must know the exact Check, status, severity, or Reason Code. |
| [Record Health Check Log](error-log.md) | One restricted technical error | A restricted administrator, developer, or support process must investigate Record Health Check errors. |

Use Set Run alone when counts answer the business need. Publishing a Result event for every Check
can create much more event traffic. Restrict Log access because its message and stack trace can
contain details about your org.

For the exact fields, see the [Platform Event metadata reference](../metadata/README.md#platform-events).

## Choose how to receive the event

| Receiving option | Use it when | Important consideration |
| --- | --- | --- |
| Platform Event-triggered Flow | An administrator needs to create records, route work, or send notifications without custom code. | Add a duplicate check before creating the destination record. Use fault paths for actions that can fail. |
| Apex trigger | A development team needs bulk processing, complex transformations, or reusable handlers. | Include tests, bulk-safe record operations, duplicate handling, and error monitoring. |
| External integration using Pub/Sub API | Middleware, a warehouse, or monitoring outside Salesforce needs the events. | Save a Replay ID only after durable processing and reconnect before Salesforce's retention window expires. |

Receiving automation runs separately from the health check. Its failure does not change the result
already returned to the user, Flow, Apex code, or Batch job.

## Quick start: Save Check Set summaries with Flow

This is the simplest Platform Event pattern when your org needs a history.

1. Create a custom object owned by your team, such as **Health Check Run History**
   (`Health_Check_Run_History__c`). This object is an example; the package does not create it.
2. Add a Text(80) field for Event ID. Mark the field **Unique** so one event cannot create the same
   history record twice.
3. Add Text fields for Run ID, Check Set API Name, Record ID, Source, and Contract Version; a
   Date/Time field for Occurred At; and Number(5,0) fields for each result count. Grant the Flow
   context Create access and intended administrators Read access through an org-owned Permission
   Set.
4. In **Setup → Flows**, select **New Flow → Platform Event-Triggered Flow**, then select **Record
   Health Check Set Run**.
5. Before creating history, use **Get Records** to look for the event's `EventId__c`. End the Flow
   successfully when it already exists.
6. Create the history record and map only the event fields your team approved.
7. Test one event, the same event a second time, and a Flow fault before activating it.

The Get Records check improves normal duplicate handling, while the destination field's Unique
constraint closes the race where two deliveries check before either creates the record. Connect the
Create Records fault path to monitored automation. Use Flow Debug where the current Salesforce UI
supports Platform Event test input, or publish a synthetic sandbox event and inspect **Paused and
Failed Flow Interviews** plus the destination record.

See [Save Check Set run summaries](check-set-run.md) for the complete field mapping and Apex option.

## Prevent duplicate work

Salesforce can deliver or replay an event more than once. Every receiving Flow, Apex trigger, or
integration must be safe when that happens.

- Store `EventId__c` in a **Unique** field before creating a notification, case, or other follow-up
  work.
- If that Event ID already exists, end successfully without repeating the work.
- Use `RunId__c` to connect events from the same health-check run. Do not use it as the unique event
  key because one run can produce events for many records and Checks.
- For an external Pub/Sub API integration, keep Replay ID as the event-stream position. It does not
  replace `EventId__c` as the application's duplicate key.

## Failure and recovery policy

Plan how receiving automation responds before activating it.

| Situation | What receiving automation should do |
| --- | --- |
| The Event ID already exists | End successfully without repeating the action. |
| A temporary record lock or external-service interruption occurs | Retry a limited number of times. Keep every action safe to repeat. |
| The event has an unsupported Contract Version or value | Save a review item and end processing so one event does not stop later events. |
| Some records in an Apex trigger fail to save | Record each failed Event ID and error. Do not report the entire group as successful. |
| The Flow, trigger, or integration is unavailable | Recover from saved destination records or the last external Replay ID. |
| An external integration is offline for longer than Salesforce retains the events | Reconcile from your saved history or original Salesforce records. The event bus is not permanent storage. |

For an Apex Platform Event trigger, Salesforce provides resume checkpoints and retryable exceptions
for ordered recovery. Use them only with a deliberate retry policy; they do not replace the unique
`EventId__c` check. See Salesforce's
[Platform Event Apex Trigger documentation](https://developer.salesforce.com/docs/atlas.en-us.platform_events.meta/platform_events/platform_events_subscribe_apex.htm).

## Understand retention and Replay ID

Salesforce stores high-volume Platform Events for 72 hours. Events older than that can sometimes
remain available, but Salesforce does not guarantee it. Save results to your own object or external
system when the business needs longer retention.

An external Pub/Sub API integration saves the Replay ID from the last event it processed durably.
After reconnecting, it requests events after that position. Replay IDs are opaque, are not
guaranteed to be consecutive, and must not be calculated. See Salesforce's
[Event Message Durability](https://developer.salesforce.com/docs/platform/pub-sub-api/guide/event-message-durability.html).

Review publishing and delivery allocations from **Setup → Company Information** and the event usage
views available for the org edition. A durable history object or external store, not the event bus,
is the recovery source after the retention window.

## Access and data protection

The installed **Record Health Check User** and **Record Health Check Admin** Permission Sets include
access to the Set Run and Check Result events. They do not include access to the restricted Log
event.

Also review access for:

- the Platform Event-triggered Flow, Apex class, or integration user;
- every custom object or external destination that stores an event;
- the Salesforce records referenced by `RecordId__c`; and
- any email, case, or collaboration channel that receives event details.

Grant Log event access separately and only to the administrators, developers, or support staff who
must investigate technical errors.

## Receiving automation checklist

Before activation, confirm that the Flow, Apex trigger, or integration:

- has only the event and destination access it needs;
- checks a unique `EventId__c` before repeating any work;
- handles new or unsupported values through a review path;
- records failures where administrators can monitor them; and
- has a documented retention and recovery process.

## Test before activation

Test all of these situations in a sandbox:

1. The expected event creates the expected destination record or action.
2. Sending the same Event ID again does not repeat the work.
3. A missing optional field does not fail the Flow, trigger, or integration.
4. An unsupported status or Contract Version goes to a review path.
5. A temporary failure retries only as designed.
6. A permanent failure is visible to administrators.
7. Users without access cannot read restricted event or destination data.
8. An external integration can reconnect from its saved Replay ID.

Monitor receiving failures, processing delay, Platform Event allocation usage, and review records
after activation.

## Related

- [Choose whether to publish result events](../integration/lifecycle-events.md)
- [Record Health Check Platform Event fields](../metadata/README.md#platform-events)
- [Save Check Set run summaries](check-set-run.md)
- [Save or route individual Check results](check-result.md)
- [Save or route restricted errors](error-log.md)
- [Receive events with Pub/Sub API](external-pub-sub-api.md)
