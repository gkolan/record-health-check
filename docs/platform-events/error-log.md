# Save or route restricted Record Health Check errors

Use the **Record Health Check Log** Platform Event when restricted administrator, developer, or
support automation must receive technical errors encountered by Record Health Check.

| Setup value | Name |
| --- | --- |
| Platform Event label | Record Health Check Log |
| API name | `Record_Health_Check_Log__e` |
| Apex name after package installation | `rhc__Record_Health_Check_Log__e` |

This event can contain Salesforce record and user IDs, exception messages, exception types, and
stack traces. Do not use it for ordinary health-result workflows or broad notifications. Use the
[Check Result event](check-result.md) for `FAIL`, `UNABLE_TO_EVALUATE`, and `ERROR` outcomes that
business automation needs.

## Before you receive this event

The **Publish Error Log Event** checkbox on each Check Set is cleared by default. Select it only
after approving restricted technical-detail publication for that Set. Leaving it cleared does not
turn off Salesforce debug logs.

The installed **Record Health Check User** and **Record Health Check Admin** Permission Sets do not
provide access to this event. Assign the packaged **Record Health Check Error Log Publisher**
Permission Set narrowly to each running user whose Check Sets keep this setting enabled. It grants
Create and the Read permission Salesforce requires with Platform Event Create, so treat every
assignee as authorized for restricted error data. Grant subscriber automation access separately and
only where needed. Without publisher access, Salesforce rejects the publish operation and no Log
event is emitted.

To grant receiver access, open **Setup → Permission Sets → [restricted support permission set] →
Object Settings → Record Health Check Log**, enable the minimum event access, and assign the
Permission Set only to approved support identities. Grant the protected destination object and its
Message and Stack Trace field permissions separately. To opt a Set out, open **Custom Metadata
Types → Record Health Check Set → Manage Records**, edit it, and clear **Publish Error Log Event**.

Define all of these controls before creating automation:

- who can receive and read the event;
- which fields may be saved;
- how long saved errors are retained;
- where processing failures are monitored; and
- which destinations must never receive messages or stack traces, such as broad email or chat
  channels.

See the [complete Log event field reference](../metadata/event-log.md).

## Recommended: Save restricted errors with Flow

### 1. Create a protected custom object

Create a custom object owned by your team, such as **Record Health Check Error**
(`Record_Health_Check_Error__c`). This is an example; the package does not create it.

Add only fields approved by your security team:

| Destination field | Suggested type | Platform Event field |
| --- | --- | --- |
| Event ID | Text(80), Unique | `$Record.EventId__c` |
| Run ID | Text(120) | `$Record.RunId__c` |
| Occurred At | Date/Time | `$Record.OccurredAt__c` |
| Code | Text(120) | `$Record.Code__c` |
| Check Set Developer Name | Text(120) | `$Record.CheckSetDeveloperName__c` |
| Check Developer Name | Text(120) | `$Record.CheckDeveloperName__c` |
| Salesforce Record ID | Text(18) | `$Record.RecordId__c` |
| Running User ID | Text(18) | `$Record.UserId__c` |
| Exception Type | Text(120) | `$Record.ExceptionType__c` |
| Message | Long Text Area | `$Record.Message__c` |
| Stack Trace | Long Text Area | `$Record.StackTrace__c` |
| Contract Version | Text(10) | `$Record.ContractVersion__c` |

Message and Stack Trace are optional. Omit them when the use case needs only error counts and codes.
If you save them, restrict those fields and every report, export, backup, or integration that can
read them.

### 2. Create the Platform Event-triggered Flow

1. In Setup, open **Flows**, select **New Flow**, and choose **Platform Event-Triggered Flow**.
2. Select **Record Health Check Log**.
3. Use **Get Records** to find `Record_Health_Check_Error__c` where Event ID equals
   `$Record.EventId__c`.
4. End successfully when the Event ID already exists.
5. Create the protected error record before sending any approved notification.
6. Route known codes to a restricted support queue and unknown codes to review.
7. Connect fault paths to monitoring that does not run another health check.
8. Test with synthetic error text, then activate the Flow.

Do not call Record Health Check or publish another Log event from this Flow. Keep it focused on
saving the error and notifying approved support staff.

`Code__c` is diagnostic classification that can evolve. Do not use it as a public business Reason
Code or a permanent Flow Decision contract; route unknown codes to restricted review.

## Alternative: Save restricted errors with Apex

Use Apex when a development team needs bulk processing or controlled routing. The following example
saves only identifying fields and the error code. Add Message or Stack Trace only after an access
and retention review.

```apex
trigger RecordHealthCheckLogTrigger on rhc__Record_Health_Check_Log__e (
  after insert
) {
  RecordHealthCheckLogHandler.saveErrors(Trigger.new);
}
```

```apex
public with sharing class RecordHealthCheckLogHandler {
  public static void saveErrors(
    List<rhc__Record_Health_Check_Log__e> events
  ) {
    Set<String> eventIds = new Set<String>();
    for (rhc__Record_Health_Check_Log__e eventRecord : events) {
      eventIds.add(eventRecord.EventId__c);
    }

    Set<String> savedEventIds = new Set<String>();
    for (Record_Health_Check_Error__c savedError : [
      SELECT Event_Id__c
      FROM Record_Health_Check_Error__c
      WHERE Event_Id__c IN :eventIds
    ]) {
      savedEventIds.add(savedError.Event_Id__c);
    }

    List<Record_Health_Check_Error__c> errorsToSave =
      new List<Record_Health_Check_Error__c>();

    for (rhc__Record_Health_Check_Log__e eventRecord : events) {
      if (savedEventIds.contains(eventRecord.EventId__c)) {
        continue;
      }

      errorsToSave.add(
        new Record_Health_Check_Error__c(
          Event_Id__c = eventRecord.EventId__c,
          Run_Id__c = eventRecord.RunId__c,
          Occurred_At__c = eventRecord.OccurredAt__c,
          Code__c = eventRecord.Code__c,
          Check_Set_Developer_Name__c = eventRecord.CheckSetDeveloperName__c,
          Check_Developer_Name__c = eventRecord.CheckDeveloperName__c,
          Salesforce_Record_Id__c = eventRecord.RecordId__c,
          Running_User_Id__c = eventRecord.UserId__c,
          Exception_Type__c = eventRecord.ExceptionType__c
        )
      );
      savedEventIds.add(eventRecord.EventId__c);
    }

    if (!errorsToSave.isEmpty()) {
      List<Database.SaveResult> saveResults = Database.insert(
        errorsToSave,
        false
      );
      // Send each failed SaveResult to restricted monitoring owned by your team.
    }
  }
}
```

`rhc__` appears on the Platform Event because it comes from the installed package. The example
error object has no prefix because your team creates it in your org.

`RecordHealthCheckLogger.enterSubscriberContext()` is package-internal and cannot be called by Apex
created in your org. Prevent a loop by never calling Record Health Check from this trigger
or handler. Production code must also inspect every failed `Database.SaveResult`.

## Understand Publish Immediately

The Log event uses **Publish Immediately**. Record Health Check holds errors until its request
reaches a normal completion point and then publishes them in groups of up to 100. An event accepted
before a later transaction rollback is not rolled back with that transaction.

This does not guarantee an event for every failure. A transaction that stops immediately after
reaching an uncatchable Salesforce limit might never reach the publication step. Keep Salesforce
debug logs and your normal Apex exception monitoring available.

Salesforce accepting the event also does not prove that the receiving Flow, Apex trigger, or
integration processed it. Monitor that automation separately.

## Test before activation

Test these cases with synthetic values in a sandbox:

1. An event creates one protected error record.
2. Reusing the same Event ID does not create another record or notification.
3. A missing optional Record ID, Check, or exception field does not fail processing.
4. An unknown Code or Contract Version goes to a review path.
5. A destination save failure is visible only to approved support staff.
6. Receiving automation does not call Record Health Check or create another Log event.
7. Users without access cannot read the event, object, reports, or restricted fields.

In an Apex test, publish a Log event and call `Test.getEventBus().deliver()` before asserting the
saved record.

## Related

- [Record Health Check Log event fields](../metadata/event-log.md)
- [Troubleshoot Record Health Check](../guides/troubleshoot-with-show-diagnostics.md)
- [Save individual Check results](check-result.md)
- [Choose whether to publish result events](../integration/lifecycle-events.md)
- [Failure and recovery policy](README.md#failure-and-recovery-policy)
