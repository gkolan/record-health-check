# Save or route individual Check results

Use this event only when the receiving process needs each Check outcome.

Use the **Record Health Check Result** Platform Event when a separate Flow, Apex trigger, or
integration must receive the result of an individual Check.

| Setup value | Name |
| --- | --- |
| Platform Event label | Record Health Check Result |
| API name | `Record_Health_Check_Result__e` |
| Apex name after package installation | `rhc__Record_Health_Check_Result__e` |

For example, create a review record when **Billing City is present** returns `FAIL`, or notify an
administrator when any Check returns `ERROR`.

The event identifies the Salesforce record, Check, status, severity, and Reason Code. It does not
contain Found, Expected, messages, formulas, SOQL, or troubleshooting details. See the
[complete field reference](../reference/platform-event-metadata/check-result.md).

## Before you use this event

First decide whether a Platform Event is necessary. If the Flow or Apex code that runs the health
check can save its returned results directly, use `NONE` and handle the results there. Use this event
only when separate automation must receive them.

Then choose what to publish:

| Publication value | Check Result events |
| --- | --- |
| `ALL` | Publishes `PASS`, `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, and `ERROR`. |
| `ACTIONABLE` | Publishes only `FAIL`, `UNABLE_TO_EVALUATE`, and `ERROR`. |
| `NONE` | Publishes no result Platform Events. |

Volume is approximately eligible Checks multiplied by evaluated records when using `ALL`. Use Set
Run summaries when counts are enough. Card publication uses each Check's **Publish User Result
Event** checkbox; programmatic `ALL` or `ACTIONABLE` controls publication directly and does not
consult that checkbox.

When a person clicks Run or Rerun on the Lightning card, select **Publish User Result Event** only
on the individual Checks that receiving automation needs. Automatic page-load checks do not
publish result events.

## Recommended: Receive results with Flow

Use a Platform Event-triggered Flow when an administrator needs to save results, create review work,
or send notifications without custom Apex.

### 1. Create a destination object

Create a custom object owned by your team, such as **Health Check Result History**
(`Health_Check_Result_History__c`). This is an example; Record Health Check does not create it.

Add only the fields your business needs. A useful starting point is:

| Destination field | Suggested type | Platform Event field |
| --- | --- | --- |
| Event ID | Text(80), Unique | `$Record.EventId__c` |
| Run ID | Text(120) | `$Record.RunId__c` |
| Salesforce Record ID | Text(18) | `$Record.RecordId__c` |
| Check Set Qualified API Name | Text(80) | `$Record.CheckSetQualifiedApiName__c` |
| Check Qualified API Name | Text(120) | `$Record.CheckQualifiedApiName__c` |
| Status | Text(30) or restricted picklist | `$Record.Status__c` |
| Reason Code | Text(120) | `$Record.ReasonCode__c` |
| Severity | Text(30) | `$Record.Severity__c` |
| Source | Text(30) | `$Record.Source__c` |
| Occurred At | Date/Time | `$Record.OccurredAt__c` |
| Contract Version | Text(10) | `$Record.ContractVersion__c` |

Mark **Event ID** as Unique. One health-check run can produce many events with the same Run ID, so
Run ID is not the duplicate key.

### 2. Create the Platform Event-triggered Flow

1. In Setup, open **Flows**, select **New Flow**, and choose **Platform Event-Triggered Flow**.
2. Select **Record Health Check Result** as the Platform Event.
3. Add **Get Records** for `Health_Check_Result_History__c` where Event ID equals
   `$Record.EventId__c`.
4. If a record already exists, end the Flow successfully. This prevents repeated delivery from
   creating repeated work.
5. Add a Decision for the statuses the Flow supports. Include `PASS` and `SKIPPED` only when the
   health check publishes `ALL`.
6. Create the history record before sending a notification or creating other follow-up work.
7. Connect fault paths to a destination administrators monitor.
8. Activate the Flow only after sandbox testing.

Route by API fields such as `Status__c`, `ReasonCode__c`, `Severity__c`, and the Check Qualified API
Name. Do not compare against the translated text shown on the Lightning card.

`ContainsRestrictedDetail__c` is always `false` in the current event contract. The field is reserved
for compatibility; it does not mean that another API can retrieve omitted Found, Expected, or
diagnostic details.

The event intentionally contains no Found, Expected, Pass Message, or Fix Message. Route `FAIL`,
`UNABLE_TO_EVALUATE`, and `ERROR` separately under `ACTIONABLE`; they all need attention but not the
same response. A `USER_INITIATED` event is client-attested: the completion endpoint does not
re-evaluate its browser-submitted status. Rerun the Check through Apex or Flow before an
irreversible, security-sensitive, or compliance action.

## Alternative: Receive results with Apex

Use Apex when a development team needs bulk processing or more complex routing. The following
example saves actionable events to the example `Health_Check_Result_History__c` object described
above. Replace the object and field API names with fields your team actually creates.

```apex
trigger RecordHealthCheckResultTrigger on rhc__Record_Health_Check_Result__e (
  after insert
) {
  RecordHealthCheckResultHandler.saveActionableResults(Trigger.new);
}
```

```apex
public without sharing class RecordHealthCheckResultHandler {
  public static void saveActionableResults(
    List<rhc__Record_Health_Check_Result__e> events
  ) {
    Set<String> eventIds = new Set<String>();

    for (rhc__Record_Health_Check_Result__e eventRecord : events) {
      if (
        eventRecord.Status__c == 'FAIL' ||
        eventRecord.Status__c == 'UNABLE_TO_EVALUATE' ||
        eventRecord.Status__c == 'ERROR'
      ) {
        eventIds.add(eventRecord.EventId__c);
      }
    }

    // Find results already saved during an earlier delivery or replay.
    Set<String> savedEventIds = new Set<String>();
    for (Health_Check_Result_History__c savedResult : [
      SELECT Event_Id__c
      FROM Health_Check_Result_History__c
      WHERE Event_Id__c IN :eventIds
    ]) {
      savedEventIds.add(savedResult.Event_Id__c);
    }

    List<Health_Check_Result_History__c> resultsToSave =
      new List<Health_Check_Result_History__c>();

    for (rhc__Record_Health_Check_Result__e eventRecord : events) {
      if (
        !eventIds.contains(eventRecord.EventId__c) ||
        savedEventIds.contains(eventRecord.EventId__c)
      ) {
        continue;
      }

      resultsToSave.add(
        new Health_Check_Result_History__c(
          Event_Id__c = eventRecord.EventId__c,
          Run_Id__c = eventRecord.RunId__c,
          Salesforce_Record_Id__c = eventRecord.RecordId__c,
          Check_Set_Api_Name__c = eventRecord.CheckSetQualifiedApiName__c,
          Check_Api_Name__c = eventRecord.CheckQualifiedApiName__c,
          Status__c = eventRecord.Status__c,
          Reason_Code__c = eventRecord.ReasonCode__c,
          Severity__c = eventRecord.Severity__c,
          Source__c = eventRecord.Source__c,
          Occurred_At__c = eventRecord.OccurredAt__c
        )
      );
    }

    if (!resultsToSave.isEmpty()) {
      // allOrNone=false lets the handler record or monitor individual failures.
      List<Database.SaveResult> saveResults = Database.insert(
        resultsToSave,
        false
      );
      // In production code, send each failed SaveResult to monitoring owned by your team.
    }
  }
}
```

`without sharing` makes this sample service handler responsible for its own destination access and
data policy; it does not grant users access to saved records. A production team can choose a
different sharing declaration, but must test event-context behavior and enforce object and field
permissions for every queried or written destination field.

`rhc__` appears on the Platform Event because it comes from the installed Record Health Check
package. `Health_Check_Result_History__c` has no `rhc__` prefix because it is an example custom
object created in your org.

The unique Event ID field provides a final duplicate safeguard if two transactions try to save the
same event at the same time. Production code must inspect every failed `Database.SaveResult` and
send it to monitoring owned by your team.

## Access and limits

The installed **Record Health Check Card User**, **Record Health Check User**, and **Record Health
Check Admin** Permission Sets include access to this Platform Event. Separately give the Flow or
Apex code the access required for the destination object and any follow-up records.

The event identifies a Salesforce record. Protect saved history according to that record's
sensitivity. Query additional business fields only when the running Flow or Apex context has the
appropriate object and field access.

Process the complete Apex trigger group. Keep SOQL and record saves outside event loops, as shown in
the example. Receiving automation cannot change a health-check result that has already completed.

## Test before activation

Test these cases in a sandbox:

1. Each supported status follows the expected path.
2. `ALL` includes `PASS` and `SKIPPED`; `ACTIONABLE` does not.
3. Reusing the same Event ID does not create another history record or notification.
4. An unknown Reason Code or Contract Version goes to a review path.
5. A missing optional field does not fail the Flow or Apex handler.
6. A destination-record failure is visible to administrators.
7. Users without destination access cannot read the saved results.

In an Apex test, publish test events and call `Test.getEventBus().deliver()` before asserting the
saved records.

See the shared [failure and recovery policy](./README.md#failure-and-recovery-policy) when ordered
Apex-trigger recovery or external replay is required.

## Related

- [Record Health Check Result event fields](../reference/platform-event-metadata/check-result.md)
- [Choose whether to publish result events](./when-to-use-platform-events.md)
- [Save Check Set run summaries](./save-run-summaries.md)
- [Save or route restricted errors](./save-restricted-errors.md)
- [Reason Codes](../reference/results/reason-codes.md)
