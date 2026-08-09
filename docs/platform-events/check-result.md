# Subscribe to the Check Result event

> [!NOTE]
> On this page, build and verify a Flow or Apex subscriber for `Record_Health_Check_Result__e` that
> routes finalized Check outcomes without relying on omitted values.

> [!TIP]
> **Event navigation:** [Publication behavior](../integration/lifecycle-events.md) ·
> **Build a Check Result subscriber** ·
> [Look up Check Result fields](../metadata/event-check-result.md)

The Check Result event carries one finalized Check status, severity, and Reason Code. It excludes
Found and Expected values, messages, queries, formulas, and diagnostic detail.

## Before creating a subscriber

Select `ACTIONABLE` or `ALL` in a programmatic request, or enable the documented interactive Check
setting. Review the [event metadata reference](../metadata/event-check-result.md) for publication
conditions and field definitions.

Create a subscriber-owned record with a unique Event ID. Store Run ID, Check and Check Set API names,
Record ID, Status, Reason Code, Severity, source, occurred time, contract version, Framework version,
and the restricted-detail indicator when those fields serve the use case.

## Subscribe with Flow

1. Create a **Platform Event-Triggered Flow** for **Record Health Check Result**.
2. Get the subscriber-owned receipt by `EventId__c` and end when it already exists.
3. Add a Decision element with explicit paths for `FAIL`, `UNABLE_TO_EVALUATE`, and `ERROR`.
4. Add `PASS` and `SKIPPED` paths when the publisher uses `ALL`.
5. Route using `Status__c`, `ReasonCode__c`, `Severity__c`, and the metadata API names.
6. Create the destination record before sending a notification or starting follow-on work.
7. Connect every fault path to restricted subscriber monitoring.
8. Activate and test with a deliberate sandbox run.

Do not query additional business data unless the Flow's effective access is appropriate. A true
`ContainsRestrictedDetail__c` value means Record Health Check withheld detail. It does not grant
access to that detail.

## Subscribe with Apex

Delegate the event batch from the trigger to a handler:

```apex
trigger RhcCheckResultSubscriber on rhc__Record_Health_Check_Result__e (
  after insert
) {
  RhcCheckResultSubscriberHandler.handle(Trigger.New);
}
```

Group follow-on work and DML across the complete trigger batch:

```apex
public with sharing class RhcCheckResultSubscriberHandler {
  /**
   * Routes actionable Check Result events in one bulk operation.
   * Persist a durable receipt before performing notifications or other side effects.
   *
   * @param events Complete trigger batch supplied by Trigger.New.
   */
  public static void handle(
    List<rhc__Record_Health_Check_Result__e> events
  ) {
    Map<String, rhc__Record_Health_Check_Result__e> newByEventId =
      new Map<String, rhc__Record_Health_Check_Result__e>();

    for (rhc__Record_Health_Check_Result__e eventRecord : events) {
      if (
        eventRecord.Status__c == 'FAIL' ||
        eventRecord.Status__c == 'UNABLE_TO_EVALUATE' ||
        eventRecord.Status__c == 'ERROR'
      ) {
        newByEventId.put(eventRecord.EventId__c, eventRecord);
      }
    }

    // Query existing unique Event IDs once.
    // Convert remaining events to subscriber-owned records in memory.
    // Insert once in user mode and monitor partial DML errors.
    // Route unsupported contract versions and event values to durable review.
  }
}
```

Do not call Record Health Check again from the subscriber unless the design has an explicit loop
barrier. A subscriber should normally store, route, or export the finalized result it received.

## Test the subscriber

Publish events for every supported status, deliver them with `Test.getEventBus().deliver()`, and
assert the routing and stored fields. Repeat an Event ID to verify duplicate handling. Include an
unknown Reason Code and contract version to verify the review path.

When ordered recovery matters, process events in trigger order and call
`EventBus.TriggerContext.currentContext().setResumeCheckpoint(eventRecord.ReplayId)` only after the
event's durable work succeeds. Use `EventBus.RetryableException` for bounded retries of transient
conditions, such as a short-lived lock. Persist and skip a permanently invalid event instead of
repeatedly blocking the batch. The shared [failure and recovery policy](README.md#failure-and-recovery-policy)
explains how this differs from `EventId__c` deduplication.

## Security and limits

The event omits sensitive evaluation values but can identify a Salesforce record. Apply sharing,
object access, field access, and retention checks to the subscriber-owned destination. Keep Apex
queries and DML outside event loops.

## Related

- [Check Result metadata](../metadata/event-check-result.md)
- [Check Set Run subscription](check-set-run.md)
- [Log subscription](error-log.md)
- [Reason Codes](../reference/contracts/reason-codes.md)
- [External Pub/Sub API subscriber](external-pub-sub-api.md)
