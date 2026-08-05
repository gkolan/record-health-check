# Subscribe to the Check Set Run event

> [!NOTE]
> On this page, subscribe to `Record_Health_Check_Set_Run__e` with a platform event-triggered Flow or a bulk Apex trigger and store one completion summary per Event ID.

The Check Set Run event contains completion counts for one deliberate Check Set run. It publishes
after commit, so a rolled-back publisher transaction produces no delivered event.

## Before creating a subscriber

Enable publication through the programmatic request option or the documented interactive Check Set
setting. Review the [event metadata reference](../metadata/03-event-set-run.md) for every field and
publication condition.

Create a subscriber-owned destination with a unique Text field for `EventId__c`. A useful run-history
record also stores Run ID, Check Set API Name, Record ID, source, occurred time, contract version,
Framework version, status derived from the counts, and each result count.

## Subscribe with Flow

1. Create a **Platform Event-Triggered Flow**.
2. Select **Record Health Check Set Run** as the event.
3. Add **Get Records** for the destination object using the event's `EventId__c`.
4. Add a Decision element. End the Flow when a matching receipt already exists.
5. Add branches for system errors, unable results, failed results, and all-clear completion.
6. Create the run-history record and copy only the required event fields.
7. Add fault handling that records a restricted subscriber failure without starting another
   health-check run.
8. Activate the Flow and publish a sandbox run with a known Run ID.

Derive the overall status in this order:

```text
SystemErrorCount > 0
UnableCount > 0
FailedCount > 0
PassedCount > 0
otherwise Skipped
```

Flow interviews run asynchronously from the publisher. A completed Flow does not report back to the
original Apex, Flow, or Lightning caller.

## Subscribe with Apex

Keep the trigger thin and perform one bulk handler call:

```apex
trigger RhcSetRunSubscriber on Record_Health_Check_Set_Run__e (
  after insert
) {
  RhcSetRunSubscriberHandler.handle(Trigger.New);
}
```

The handler should collect all Event IDs, query existing receipts once, and insert only new rows:

```apex
public with sharing class RhcSetRunSubscriberHandler {
  public static void handle(List<Record_Health_Check_Set_Run__e> events) {
    Set<String> eventIds = new Set<String>();
    for (Record_Health_Check_Set_Run__e eventRecord : events) {
      eventIds.add(eventRecord.EventId__c);
    }

    // Query the subscriber-owned receipt object once by its unique Event ID.
    // Build all new run-history rows in memory, then perform one user-mode DML call.
    // Route unknown contract versions to review instead of discarding them.
  }
}
```

Use `RunId__c` to correlate Rule Result events with the summary. Use `EventId__c`, not Run ID, as
the unique delivery key because one run can produce several events.

## Test the subscriber

Publish a complete event in an Apex test, call `Test.getEventBus().deliver()`, and assert the stored
summary. Publish the same Event ID twice and assert one stored row. Add tests for system error,
unable, failed, pass, and missing Record ID paths.

## Security and limits

The event can contain a Salesforce Record ID. Protect stored history according to the referenced
record's sensitivity, and grant destination access only to approved users. Keep the handler
bulk-safe because Salesforce can deliver many events in one trigger context.

## Related

- [Check Set Run metadata](../metadata/03-event-set-run.md)
- [Rule Result subscription](02-rule-result.md)
- [Apex Batch example](../api/04-batch.md)
- [Lifecycle event behavior](../integration/03-lifecycle-events.md)
