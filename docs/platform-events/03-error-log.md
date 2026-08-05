# Subscribe to the Log event

> [!NOTE]
> Use this page to subscribe to `Record_Health_Check_Log__e` with a restricted Flow or Apex subscriber and prevent subscriber errors from producing a logging loop.

The Log event reports Framework `ERROR` diagnostics when error-event publication is enabled for the
Check Set. It publishes immediately and can contain record and user IDs, exception messages,
exception types, and stack traces.

## Before creating a subscriber

Restrict event access and every stored copy to approved operational users. Define retention before
storing diagnostics. Review the [Log event metadata reference](../metadata/05-event-log.md) for the
complete field contract and limitations.

Create a protected destination with a unique Event ID. Useful fields include Run ID, occurred time,
error code, Check Set and Rule API names, Record ID, User ID, exception type, message, stack trace,
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

Flow cannot call the Apex subscriber loop guard automatically. The Flow design must not invoke
Record Health Check or republish Log events. Use an Apex subscriber when the processing path can
enter Record Health Check logging code.

## Subscribe with Apex

The trigger must enter subscriber context before any processing:

```apex
trigger RhcLogSubscriber on Record_Health_Check_Log__e (after insert) {
  RecordHealthCheckLogger.enterSubscriberContext();
  RhcLogSubscriberHandler.handle(Trigger.New);
}
```

Process the complete batch in a restricted handler:

```apex
public without sharing class RhcLogSubscriberHandler {
  public static void handle(List<Record_Health_Check_Log__e> events) {
    Set<String> eventIds = new Set<String>();
    for (Record_Health_Check_Log__e eventRecord : events) {
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

- [Log event metadata](../metadata/05-event-log.md)
- [Rule Result subscription](02-rule-result.md)
- [Lifecycle event behavior](../integration/03-lifecycle-events.md)
- [Troubleshoot with Show Diagnostics](../guides/07-troubleshoot-with-show-diagnostics.md)
