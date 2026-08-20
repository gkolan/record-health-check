# Save Check Set run summaries

Use the **Record Health Check Set Run** Platform Event when a separate Flow, Apex trigger, or
integration needs one summary for each Salesforce record after its Check Set finishes.

| Setup value | Name |
| --- | --- |
| Platform Event label | Record Health Check Set Run |
| API name | `Record_Health_Check_Set_Run__e` |
| Apex name after package installation | `rhc__Record_Health_Check_Set_Run__e` |

For example, a scheduled Batch checks 5,000 Accounts every night. A Platform Event-triggered Flow
saves one summary per Account with the passed, failed, skipped, unable, and system-error totals.

Use the [Check Result event](check-result.md) instead when receiving automation must know which
individual Check passed or failed.

## Before you use this event

If the same Flow or Apex code that runs the health check can save the returned results, use `NONE`
and handle them directly. Use this event only when separate automation needs the summary.

Publication depends on how the health check starts:

- Flow, Apex, Batch, Queueable, Future, and Scheduled Apex publish a Set Run event with `ALL`.
- `ACTIONABLE` publishes a completed Set Run heartbeat for every scanned record, including
  all-pass and all-skipped runs. It limits individual Check Result events to `FAIL`,
  `UNABLE_TO_EVALUATE`, and `ERROR`.
- `NONE` publishes no result Platform Events.
- When a person clicks Run or Rerun on the Lightning card, select **Publish User Run Event** on the
  Check Set. Automatic page-load checks do not publish it.

See the [complete event field reference](../metadata/event-set-run.md).

## Recommended: Save summaries with Flow

### 1. Create a history object

Create a custom object owned by your team, such as **Health Check Run History**
(`Health_Check_Run_History__c`). This is an example; Record Health Check does not create it.

Add the fields your reports and receiving automation need:

| Destination field | Suggested type | Platform Event field or value |
| --- | --- | --- |
| Event ID | Text(80), Unique | `$Record.EventId__c` |
| Run ID | Text(120) | `$Record.RunId__c` |
| Check Set Qualified API Name | Text(80) | `$Record.CheckSetQualifiedApiName__c` |
| Salesforce Record ID | Text(18) | `$Record.RecordId__c` |
| Occurred At | Date/Time | `$Record.OccurredAt__c` |
| Source | Text(30) | `$Record.Source__c` |
| Overall Status | Text(30) or restricted picklist | Derived from the result counts |
| Eligible Check Count | Number(5,0) | `$Record.EligibleCheckCount__c` |
| Evaluated Check Count | Number(5,0) | `$Record.EvaluatedCheckCount__c` |
| Passed Count | Number(5,0) | `$Record.PassedCount__c` |
| Failed Count | Number(5,0) | `$Record.FailedCount__c` |
| Skipped Count | Number(5,0) | `$Record.SkippedCount__c` |
| Unable Count | Number(5,0) | `$Record.UnableCount__c` |
| System Error Count | Number(5,0) | `$Record.SystemErrorCount__c` |
| Contract Version | Text(10) | `$Record.ContractVersion__c` |

Mark Event ID as **Unique**. One run can check many records, so Run ID is not the unique history key.

### 2. Derive an overall status

The event contains counts rather than an overall status. If your history object needs one, evaluate
the counts in this order:

1. `ERROR` when System Error Count is greater than zero.
2. `UNABLE_TO_EVALUATE` when Unable Count is greater than zero.
3. `FAIL` when Failed Count is greater than zero.
4. `PASS` when Passed Count is greater than zero.
5. `SKIPPED` when none of the earlier counts is greater than zero.

This order prevents one passed Check from hiding a failure or technical problem in the same run.

### 3. Create the Platform Event-triggered Flow

1. In Setup, open **Flows**, select **New Flow**, and choose **Platform Event-Triggered Flow**.
2. Select **Record Health Check Set Run**.
3. Use **Get Records** to find `Health_Check_Run_History__c` where Event ID equals
   `$Record.EventId__c`.
4. End successfully when a record already exists.
5. Use a Decision to derive Overall Status in the order above.
6. Create the history record before sending a notification or creating follow-up work.
7. Connect fault paths to a named destination such as a restricted Flow error record, monitored
   queue, or your organization's Flow error notification process.
8. Test in a sandbox, then activate the Flow.

The Flow runs separately from the health check. Its failure does not change the result already
returned to the user, Flow, Apex code, or Batch job.

## Alternative: Save summaries with Apex

Use Apex when a development team needs bulk processing or complex routing. This example saves to
the example `Health_Check_Run_History__c` object. Replace these API names with the object and fields
your team creates.

```apex
trigger RecordHealthCheckSetRunTrigger on rhc__Record_Health_Check_Set_Run__e (
  after insert
) {
  RecordHealthCheckSetRunHandler.saveSummaries(Trigger.new);
}
```

```apex
public with sharing class RecordHealthCheckSetRunHandler {
  public static void saveSummaries(
    List<rhc__Record_Health_Check_Set_Run__e> events
  ) {
    Set<String> eventIds = new Set<String>();
    for (rhc__Record_Health_Check_Set_Run__e eventRecord : events) {
      eventIds.add(eventRecord.EventId__c);
    }

    Set<String> savedEventIds = new Set<String>();
    for (Health_Check_Run_History__c savedRun : [
      SELECT Event_Id__c
      FROM Health_Check_Run_History__c
      WHERE Event_Id__c IN :eventIds
    ]) {
      savedEventIds.add(savedRun.Event_Id__c);
    }

    List<Health_Check_Run_History__c> runsToSave =
      new List<Health_Check_Run_History__c>();

    for (rhc__Record_Health_Check_Set_Run__e eventRecord : events) {
      if (savedEventIds.contains(eventRecord.EventId__c)) {
        continue;
      }

      runsToSave.add(
        new Health_Check_Run_History__c(
          Event_Id__c = eventRecord.EventId__c,
          Run_Id__c = eventRecord.RunId__c,
          Check_Set_Api_Name__c = eventRecord.CheckSetQualifiedApiName__c,
          Salesforce_Record_Id__c = eventRecord.RecordId__c,
          Occurred_At__c = eventRecord.OccurredAt__c,
          Source__c = eventRecord.Source__c,
          Overall_Status__c = overallStatus(eventRecord),
          Eligible_Check_Count__c = eventRecord.EligibleCheckCount__c,
          Evaluated_Check_Count__c = eventRecord.EvaluatedCheckCount__c,
          Passed_Count__c = eventRecord.PassedCount__c,
          Failed_Count__c = eventRecord.FailedCount__c,
          Skipped_Count__c = eventRecord.SkippedCount__c,
          Unable_Count__c = eventRecord.UnableCount__c,
          System_Error_Count__c = eventRecord.SystemErrorCount__c
        )
      );
      // Also prevent a repeated Event ID within this trigger delivery.
      savedEventIds.add(eventRecord.EventId__c);
    }

    if (!runsToSave.isEmpty()) {
      List<Database.SaveResult> saveResults = Database.insert(
        runsToSave,
        false
      );
      // Send each failed SaveResult to monitoring owned by your team.
    }
  }

  private static String overallStatus(
    rhc__Record_Health_Check_Set_Run__e eventRecord
  ) {
    if (eventRecord.SystemErrorCount__c != null && eventRecord.SystemErrorCount__c > 0) return 'ERROR';
    if (eventRecord.UnableCount__c != null && eventRecord.UnableCount__c > 0) return 'UNABLE_TO_EVALUATE';
    if (eventRecord.FailedCount__c != null && eventRecord.FailedCount__c > 0) return 'FAIL';
    if (eventRecord.PassedCount__c != null && eventRecord.PassedCount__c > 0) return 'PASS';
    return 'SKIPPED';
  }
}
```

`rhc__` appears on the Platform Event because it comes from the installed package. The example
history object has no prefix because your team creates it in your org.

Keep Event ID unique to protect against two transactions saving the same event at the same time.
Production code must inspect every failed `Database.SaveResult` and send it to monitoring.

## Access and limits

The installed **Record Health Check User** and **Record Health Check Admin** Permission Sets include
access to this event. Give the Flow or Apex code separate access to the history object and fields.

For an org-owned receiver Permission Set, open **Object Settings**, grant Read access to **Record
Health Check Set Run**, then grant Create and the approved field permissions on the history object.
The event has no Overall Status field; derive it from counts as shown above. `ACTIONABLE` still
publishes a heartbeat when every result passes or skips, so a missing history row indicates
publication or receiver failure rather than an expected clean-run omission.

The event contains a Salesforce Record ID. Protect saved history according to the referenced
record's sensitivity. Receiving automation cannot change the completed health-check result.

A `USER_INITIATED` Set Run summary is client-attested advisory data; the completion endpoint does
not re-evaluate browser-submitted statuses. Re-evaluate through Apex or Flow before using it for a
compliance-sensitive decision. For Batch, earlier per-record events can remain committed when a
later scope fails, so wait for the terminal job envelope before declaring the complete job outcome.

Process the entire Apex trigger group. Keep queries and record saves outside loops, as shown above.

## Test before activation

Test these cases in a sandbox:

1. System error, unable, failed, passed, and all-skipped counts derive the correct overall status.
2. Reusing the same Event ID does not create a second history record.
3. Two different events with the same Run ID are both saved.
4. A missing optional Record ID does not fail processing.
5. An unsupported Contract Version goes to a review path.
6. A destination save failure is visible to administrators.
7. Users without access cannot read the history.

In an Apex test, publish events and call `Test.getEventBus().deliver()` before asserting the saved
records.

## Related

- [Record Health Check Set Run event fields](../metadata/event-set-run.md)
- [Choose whether to publish result events](../integration/lifecycle-events.md)
- [Save individual Check results](check-result.md)
- [Use Batch Apex](../api/batch.md)
- [Failure and recovery policy](README.md#failure-and-recovery-policy)
