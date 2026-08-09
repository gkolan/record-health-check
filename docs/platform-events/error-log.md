# Subscribe to the Log event

> [!NOTE]
> On this page, build and verify a restricted Flow or Apex subscriber for
> `Record_Health_Check_Log__e` without creating a logging loop.

> [!TIP]
> **Event navigation:** [Publication behavior](../integration/lifecycle-events.md) ·
> **Build a Log subscriber** ·
> [Look up Log fields](../metadata/event-log.md)

The Log event reports Framework `ERROR` diagnostics when error-event publication is enabled for the
Check Set. It publishes immediately and can contain record and user IDs, exception messages,
exception types, and stack traces.

## Before creating a subscriber

Restrict event access and every stored copy to approved operational users. Define retention before
storing diagnostics. Review the [Log event metadata reference](../metadata/event-log.md) for the
complete field contract and limitations.

Create a protected destination with a unique Event ID. Useful fields include Run ID, occurred time,
error code, Check Set and Check API names, Record ID, User ID, exception type, message, stack trace,
contract version, and Framework version. Separate access to messages and stack traces from general run
history.

## Subscribe with Flow

1. Create a **Platform Event-Triggered Flow** for **Record Health Check Log**.
2. Get the protected destination record by `EventId__c` and end when it already exists.
3. Create the diagnostic record before starting notifications or follow-on automation.
4. Route stable error codes to approved operational queues and unknown codes to review.
5. Keep message and stack-trace fields out of email, chat, and unrestricted records.
6. Connect fault paths to monitoring that does not run another Record Health Check.
7. Activate the Flow and test with synthetic, non-production diagnostic values.

The subscriber must not call Record Health Check or republish Log events. Keep the Flow limited to
storing restricted diagnostics and notifying approved operational users.

## Subscribe with Apex

Keep the trigger thin and pass the complete event batch to one restricted handler:

```apex
trigger RhcLogSubscriber on rhc__Record_Health_Check_Log__e (after insert) {
  RhcLogSubscriberHandler.handle(Trigger.New);
}
```

Process the complete batch in a restricted handler:

```apex
public without sharing class RhcLogSubscriberHandler {
  /**
   * Persists a restricted batch of Framework diagnostics.
   * Readers must independently enforce the approved access boundary.
   *
   * @param events Complete trigger batch supplied by Trigger.New.
   */
  public static void handle(List<rhc__Record_Health_Check_Log__e> events) {
    Set<String> eventIds = new Set<String>();
    for (rhc__Record_Health_Check_Log__e eventRecord : events) {
      eventIds.add(eventRecord.EventId__c);
    }

    // Query protected diagnostic records once by unique Event ID.
    // Copy only approved fields, insert once, and monitor partial DML errors.
    // Never include real messages or stack traces in unrestricted notifications.
  }
}
```

`without sharing` does not remove object or field checks. Use it only when the approved operational
design requires a protected system-owned store, and enforce object and field access at every reader.
The handler must not call Record Health Check. The package's internal loop guard is not a subscriber
API.

## Test the subscriber

Publish a Log event containing synthetic message and stack-trace text. Deliver it with
`Test.getEventBus().deliver()` and assert the protected stored record. Publish the same Event ID
again and assert one record. Exercise a handler failure and verify that no second Log event is
published.

## Known limits

Publish Immediately allows an accepted event to survive a later publisher rollback. An uncatchable
governor-limit failure can still prevent Record Health Check from reaching its publish step. Keep Salesforce debug
logs and platform exception monitoring available.

## Related

- [Log event metadata](../metadata/event-log.md)
- [Check Result subscription](check-result.md)
- [Lifecycle event behavior](../integration/lifecycle-events.md)
- [Troubleshoot Record Health Check](../guides/troubleshoot-with-show-diagnostics.md)
- [External Pub/Sub API subscriber](external-pub-sub-api.md)
