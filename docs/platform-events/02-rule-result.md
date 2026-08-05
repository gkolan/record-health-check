# Subscribe to the Rule Result event

> [!NOTE]
> Use this page to subscribe to `Record_Health_Check_Rule_Result__e` with Flow or Apex and route finalized Rule outcomes without exposing values that the event intentionally omits.

The Rule Result event carries one finalized Rule status, severity, and Reason Code. It excludes
Found and Expected values, messages, queries, formulas, and diagnostic detail.

## Before creating a subscriber

Select `ACTIONABLE` or `ALL` in a programmatic request, or enable the documented interactive Rule
setting. Review the [event metadata reference](../metadata/04-event-rule-result.md) for publication
conditions and field definitions.

Create a subscriber-owned record with a unique Event ID. Store Run ID, Rule and Check Set API names,
Record ID, Status, Reason Code, Severity, source, occurred time, contract version, Framework version, and
the restricted-detail indicator when those fields serve the use case.

## Subscribe with Flow

1. Create a **Platform Event-Triggered Flow** for **Record Health Check Rule Result**.
2. Get the subscriber-owned receipt by `EventId__c` and end when it already exists.
3. Add a Decision element with explicit paths for `FAIL`, `UNABLE_TO_EVALUATE`, and `ERROR`.
4. Add `PASS` and `SKIPPED` paths when the publisher uses `ALL`.
5. Route using `Status__c`, `ReasonCode__c`, `Severity__c`, and the metadata API names.
6. Create the destination record before sending a notification or starting follow-on work.
7. Connect every fault path to restricted subscriber monitoring.
8. Activate and test with a deliberate sandbox run.

Do not query additional business data unless the Flow's effective access is appropriate. A true
`ContainsRestrictedDetail__c` value means Record Health Check withheld detail. It does not grant access to that
detail.

## Subscribe with Apex

Delegate the event batch from the trigger to a handler:

```apex
trigger RhcRuleResultSubscriber on Record_Health_Check_Rule_Result__e (
  after insert
) {
  RhcRuleResultSubscriberHandler.handle(Trigger.New);
}
```

Group follow-on work and DML across the complete trigger batch:

```apex
public with sharing class RhcRuleResultSubscriberHandler {
  public static void handle(
    List<Record_Health_Check_Rule_Result__e> events
  ) {
    Map<String, Record_Health_Check_Rule_Result__e> newByEventId =
      new Map<String, Record_Health_Check_Rule_Result__e>();

    for (Record_Health_Check_Rule_Result__e eventRecord : events) {
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
  }
}
```

Do not call Record Health Check again from the subscriber unless the design has an explicit loop
barrier. A subscriber should normally store, route, or export the finalized result it received.

## Test the subscriber

Publish events for every supported status, deliver them with `Test.getEventBus().deliver()`, and
assert the routing and stored fields. Repeat an Event ID to verify duplicate handling. Include an
unknown Reason Code and contract version to verify the review path.

## Security and limits

The event omits sensitive evaluation values but can identify a Salesforce record. Apply sharing,
object access, field access, and retention rules to the subscriber-owned destination. Keep Apex
queries and DML outside event loops.

## Related

- [Rule Result metadata](../metadata/04-event-rule-result.md)
- [Check Set Run subscription](01-check-set-run.md)
- [Log subscription](03-error-log.md)
- [Reason Codes](../reference/contracts/01-reason-codes.md)
