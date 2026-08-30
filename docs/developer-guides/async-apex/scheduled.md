# Run Record Health Check from Scheduled Apex

Use this page when a developer-owned job must run on a schedule.

> [!NOTE]
> Use Scheduled Apex when Record Health Check should run automatically at a recurring time. The
> scheduled class should start Queueable or Batch Apex instead of checking all records itself.

> [!IMPORTANT]
> **Audience: Salesforce developers and scheduling administrators.** The packaged `scheduleDaily`
> helper is Apex-only and does not appear as a class an administrator can select directly in
> **Schedule Apex**. A developer can provide a custom `Schedulable` wrapper. For a no-code schedule,
> use a Scheduled-Triggered Flow with the packaged Flow action when its record selection fits.

## Choose the scheduling pattern

| Example | Use | Why |
| --- | --- | --- |
| The same 400 Account IDs must run every day | Packaged daily scheduler | The IDs are known and intentionally stay the same. |
| Every night, check all Accounts modified in the last 30 days | Custom scheduler that starts a query-backed Batch | The matching Accounts change, so the Batch must query them each night. |

The packaged schedule captures record IDs when the schedule is created. Records added later are
not included, and removed IDs are not automatically replaced. This behavior is correct only when
the list of records is intentionally fixed.

Also decide where results go:

| Scheduled work | Result choices |
| --- | --- |
| Packaged daily scheduler | Publish `ACTIONABLE` or `ALL` Platform Events, or use `NONE` when only job completion matters. |
| Custom scheduler that starts a custom Batch | Save `response.results` directly, publish Platform Events, or retain no individual results. |

## Before you start

1. Decide whether every run uses the same record IDs or queries the records again.
2. Assign the scheduling user the packaged **Record Health Check User** Permission Set. Use
   **Record Health Check Admin** only when the user also configures Checks or views diagnostics.
   Both include **Custom Permission label:** Record Health Check Run, **Custom Permission API
   name:** `rhc__Record_Health_Check_Run`, and the required Apex class access.
3. Confirm that the scheduling user has the object, record, field, and Custom Metadata access the
   selected Checks require.
4. Copy the Check Set **Qualified API Name** from **Setup → Custom Metadata Types → Record Health
   Check Set → Manage Records**.
5. Choose a result destination from the table above. Prepare the custom result object or Platform
   Event receiver before creating the schedule.
6. Choose a stable, unique scheduled-job name.

The scheduling user's time zone controls the start time. Verify that user's Salesforce time zone
before enabling a production schedule.

The default packaged Batch scope is 100 and is not a Setup setting. Ask a developer for a custom
Batch when a smaller tested scope is required.

## Example: Schedule the same record IDs every day

Schedule the same known IDs to run daily at 2:00 AM in the scheduling user's time zone:

```apex
// Copy the exact Check Set Qualified API Name from Setup.
// A Check Set included with the installed package might be rhc__Example_Account_Check_Builder_Guide.
String checkSetApiName = 'My_Account_Checks';

String scheduledJobId = rhc.RecordHealthCheckScheduled.scheduleDaily(
  'Nightly Account Health',
  checkSetApiName,
  accountIds,
  // Use ACTIONABLE to publish only FAIL, UNABLE_TO_EVALUATE, and ERROR.
  // Use ALL to publish every result, including PASS and SKIPPED.
  // Use NONE only when scheduled-job and Batch-job completion are enough.
  rhc.RecordHealthCheckEventPublication.ACTIONABLE
);
```

The packaged scheduling class accepts:

- a job name containing 1–80 characters;
- a Check Set Qualified API Name copied from Setup;
- 1–2,000 distinct, non-null record IDs;
- every remaining ID belongs to the selected Check Set object, or scheduling is rejected; and
- an explicit event-publication mode.

Invalid input or missing permission is rejected before Salesforce creates a `CronTrigger`.
Authorization is checked again when the schedule fires. Each firing starts the packaged Batch
class.

The returned `scheduledJobId` identifies the recurring schedule, not the Batch job started each
day. Monitor each Batch separately in **Setup → Apex Jobs**. Passing `NONE` creates no
health-result destination, so use it only when job completion is sufficient.

The packaged daily schedule checks up to 100 records in each Batch transaction. The scheduled API
does not currently accept a different Batch size. To choose one, create a custom
scheduler that calls `rhc.RecordHealthCheckBatch.run(..., scopeSize)`.

## Example: Query the current records every time the schedule runs

First create the complete `AccountHealthBatch` described in [Batch Apex](./batch.md). That example
uses `NONE` and saves `response.results` directly. Then create a small scheduler whose only job is
to start that Batch:

```apex
public with sharing class NightlyAccountHealthSchedule
  implements Schedulable {
  public void execute(SchedulableContext context) {
    // Copy the exact Check Set Qualified API Name from Setup.
    String checkSetApiName = 'My_Account_Checks';

    // AccountHealthBatch queries current Accounts, publishes no result
    // events, and saves its response.results directly.
    Database.executeBatch(
      new AccountHealthBatch(checkSetApiName),
      25
    );
  }
}
```

Schedule the custom class from Setup:

1. In Setup, enter **Apex Classes** in Quick Find and select **Apex Classes**.
2. Select **Schedule Apex**.
3. Enter a job name, such as `Nightly Account Health`.
4. Select `NightlyAccountHealthSchedule` as the Apex class.
5. Choose the frequency, start date, end date, and preferred start time.
6. Select **Save**.
7. Open **Setup → Scheduled Jobs** and confirm that the schedule appears.

The same schedule can be created from Apex:

```apex
String scheduledJobId = System.schedule(
  'Nightly Account Health',
  '0 0 2 * * ?',
  new NightlyAccountHealthSchedule()
);
```

The value `'0 0 2 * * ?'` is Salesforce's scheduling expression for every day at 2:00 AM in the
scheduling user's time zone.

## Monitor the complete chain

To remove a schedule, open **Setup → Scheduled Jobs**, find the exact job name, and select **Del**.
Confirm the job owner and next run before deleting it.

A scheduled run has three different IDs:

| ID | What it tracks |
| --- | --- |
| `CronTrigger` ID | The recurring schedule |
| `AsyncApexJob` ID | The Batch or Queueable job started by one firing |
| Record Health Check `runId` | The health-check results created by one run |

Save these IDs together only when staff must follow one run from its schedule to its health
results. Check these failures separately:

- the schedule did not fire or could not start the Batch or Queueable job;
- the Batch or Queueable job failed;
- Record Health Check returned `ERROR` or `UNABLE_TO_EVALUATE`; or
- the Flow, Apex trigger, or integration receiving Platform Events failed to process one.

Use one stable job name for one logical schedule. A random or timestamped name can create duplicate
schedules and consume scheduled-job capacity. When a request changes, deliberately abort or replace
the known schedule.

## Test the schedule

Schedule the class between `Test.startTest()` and `Test.stopTest()`. Assert that it starts the
expected Batch or Queueable job or saves the expected result. Keep scheduler tests separate
from detailed health-result and Batch-group tests.

Before production activation, verify the schedule in a sandbox as the real scheduling user or with
equivalent access.

## Troubleshooting

| Symptom | Check first |
| --- | --- |
| No `CronTrigger` is created | Custom Permission, job-name length, Check Set Qualified API Name, and record-ID count |
| The schedule exists but no Batch starts | The scheduling user's current access and the latest Scheduled Apex failure |
| Batch completes but no outcomes are retained | Event-publication mode and the Flow, Apex trigger, integration, or storage that should receive them |
| The same records run every day | Expected for the packaged scheduling class; use a query-backed Batch to query the records again |
| The job runs at the wrong local time | The scheduling user's Salesforce time zone and CRON expression |
| Duplicate schedules consume slots | Reuse one stable name and replace the known schedule deliberately |

## Related

- [API overview](../README.md)
- [Batch Apex](./batch.md)
- [Queueable Apex](./queueable.md)
- [Apex API](../run-from-apex.md)
- [Check Set Run event](../../save-results/save-run-summaries.md)
