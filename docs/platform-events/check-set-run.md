# Subscribe to the Check Set Run event

> [!NOTE]
> On this page, subscribe to `Record_Health_Check_Set_Run__e` with a platform event-triggered Flow or a bulk Apex trigger and store one completion summary per Event ID.

> [!TIP]
> **Event navigation:** [Publication behavior](../integration/lifecycle-events.md) ·
> **Build a Check Set Run subscriber** ·
> [Look up Check Set Run fields](../metadata/event-set-run.md)

The Check Set Run event contains completion counts for one deliberate Check Set run. It publishes
after commit, so a rolled-back publisher transaction produces no delivered event.

## Before creating a subscriber

Enable publication through the programmatic request option or the documented interactive Check Set
setting. Review the [event metadata reference](../metadata/event-set-run.md) for every field and
publication condition.

Create a subscriber-owned destination with a unique Text field for `EventId__c`. A useful run-history
record also stores Run ID, Check Set API Name, Record ID, source, occurred time, contract version,
Framework version, status derived from the counts, and each result count.

## Subscribe with Flow

### Worked destination model

The following subscriber-owned model is an example, not package metadata. Replace the object name
with the history object approved for the org.

| Destination field | Type | Source or derivation |
| --- | --- | --- |
| `EventId__c` | Text(80), Unique, External ID | `$Record.EventId__c` |
| `RunId__c` | Text(120) | `$Record.RunId__c` |
| `CheckSetQualifiedApiName__c` | Text(80) | `$Record.CheckSetQualifiedApiName__c` |
| `EvaluatedRecordId__c` | Text(18) | `$Record.RecordId__c` |
| `OccurredAt__c` | Date/Time | `$Record.OccurredAt__c` |
| `Source__c` | Text(30) | `$Record.Source__c` |
| `Status__c` | Picklist or Text | Derived from the counts below |
| Result count fields | Number(5,0) | Copy each corresponding event count |
| `ContractVersion__c` | Text(10) | `$Record.ContractVersion__c` |
| `FrameworkVersion__c` | Text(20) | `$Record.FrameworkVersion__c` |

### Build the Flow

1. Create a **Platform Event-Triggered Flow**.
2. Select **Record Health Check Set Run** as the event.
3. Add **Get Records** for the destination object where `EventId__c` equals the triggering event's
   `$Record.EventId__c` value. Store only the first record.
4. Add a **New event?** Decision. End the Flow when the returned record ID is not null.
5. Add branches for system errors, unable results, failed results, and all-clear completion.
6. Assign the derived status and create the run-history record using the mapping above. Create this
   durable receipt before any notification or downstream action.
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

The Flow's effective user needs Read access to the event and Create and field access on the
destination. Restrict access to the stored record according to the sensitivity of
`EvaluatedRecordId__c`. In Setup, review failed and paused Flow interviews and configure operational
alerts; a successful publisher does not prove that the Flow completed.

## Subscribe with Apex

Keep the trigger thin and perform one bulk handler call:

```apex
trigger RhcSetRunSubscriber on rhc__Record_Health_Check_Set_Run__e (
  after insert
) {
  RhcSetRunSubscriberHandler.handle(Trigger.New);
}
```

The handler should collect all Event IDs, query existing receipts once, and insert only new rows:

```apex
public with sharing class RhcSetRunSubscriberHandler {
  /**
   * Stores new run summaries from one platform-event trigger delivery.
   * The production implementation must query and write the subscriber-owned
   * history object in bulk and keep EventId__c unique.
   *
   * @param events Complete trigger batch supplied by Trigger.New.
   */
  public static void handle(List<rhc__Record_Health_Check_Set_Run__e> events) {
    Set<String> eventIds = new Set<String>();
    for (rhc__Record_Health_Check_Set_Run__e eventRecord : events) {
      eventIds.add(eventRecord.EventId__c);
    }

    // Query the subscriber-owned receipt object once by its unique Event ID.
    // Build all new run-history rows in memory, then perform one user-mode DML call.
    // Inspect every Database.SaveResult when using partial-success DML.
    // Route unknown contract versions to review instead of discarding them.
  }
}
```

Use `RunId__c` to correlate Check Result events with the summary. Use `EventId__c`, not Run ID, as
the unique delivery key because one run can produce several events.

## Test the subscriber

Publish a complete event in an Apex test, call `Test.getEventBus().deliver()`, and assert the stored
summary. Publish the same Event ID twice and assert one stored row. Add tests for system error,
unable, failed, pass, missing Record ID, partial DML, and an unsupported contract-version path.

## Security and limits

The event can contain a Salesforce Record ID. Protect stored history according to the referenced
record's sensitivity, and grant destination access only to approved users. Keep the handler
bulk-safe because Salesforce can deliver many events in one trigger context.

## Related

- [Check Set Run metadata](../metadata/event-set-run.md)
- [Check Result subscription](check-result.md)
- [Apex Batch example](../api/batch.md)
- [Lifecycle event behavior](../integration/lifecycle-events.md)
