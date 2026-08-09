# Run Record Health Check from Scheduled Apex

> [!NOTE]
> On this page, schedule recurring health-check work by handing the record population to Batch Apex instead of evaluating an unbounded population in the scheduler transaction.

Scheduled Apex should start bounded Queueable work or a Batch Apex job. The scheduler transaction
should not query an unrestricted population and attempt to evaluate it in one request.

The basic scheduling pattern is: choose a known ID population for the packaged daily adapter, or
use a custom query-backed Batch when each run must discover the current population.

The packaged `rhc.RecordHealthCheckScheduled.scheduleDaily` adapter accepts a 1–80 character job name,
a nonblank qualified Check Set identity, and 1–2,000 distinct non-null record IDs. It requires
**Record Health Check Run** (`rhc__Record_Health_Check_Run`), rejects invalid input before creating a `CronTrigger`, and rechecks
authorization when the schedule fires before delegating to the packaged Batch adapter.
The public constructor enforces the same permission and population boundary.

The packaged schedule captures those record IDs when it is created and evaluates the same IDs on
every run. It does not discover records that later enter or leave a business population. Use a
custom scheduler that starts a query-backed Batch when each run must discover the current records.

## Packaged daily schedule

Schedule the known record population for 2:00 AM in the scheduling user's time zone:

```apex
String scheduledJobId = rhc.RecordHealthCheckScheduled.scheduleDaily(
  'Nightly Account Health',
  'rhc__Account_Data_Quality',
  accountIds,
  rhc.RecordHealthCheckEventPublication.ACTIONABLE
);
```

The returned ID identifies the `CronTrigger`. Each firing starts a packaged Batch job; monitor that
downstream `AsyncApexJob` separately. Passing `NONE` creates no health-result destination, so use it
only when job completion without retained outcomes satisfies the design.

## Dynamic-population schedule

Create a scheduler that starts the reviewed query-backed Batch implementation when the current
record population must be rediscovered:

```apex
public with sharing class NightlyAccountHealthSchedule
  implements Schedulable {
  public void execute(SchedulableContext context) {
    Database.executeBatch(
      new AccountHealthBatch('rhc__Account_Data_Quality'),
      25
    );
  }
}
```

Schedule the class from Setup or Apex:

```apex
String jobId = System.schedule(
  'Nightly Account Health',
  '0 0 2 * * ?',
  new NightlyAccountHealthSchedule()
);
```

## Operational design

Record the scheduled job ID, downstream Batch or Queueable job ID, and Framework Run IDs when the
process needs traceable history. Monitor failed scheduler starts separately from health-check
`ERROR` results and downstream asynchronous job failures.

Treat `jobName` as the unique key for a schedule. Use a predictable, stable name for one logical
schedule and handle Salesforce's duplicate-name exception as “already scheduled.” A retry with a
new/random name can consume another org scheduled-job slot. Abort or replace the known existing
job deliberately when its request must change; never create timestamp-named recurring retries.

The user who schedules the job owns its time zone and supplies the effective Apex, object, record,
and field access when it runs. Verify that access in a sandbox before enabling the schedule.

## Test the schedule

Schedule the class between `Test.startTest()` and `Test.stopTest()`. Assert the downstream job or
its persisted outcome. Keep the scheduler test separate from detailed evaluator tests.

## Troubleshoot a scheduled run

| Symptom | Check first |
| --- | --- |
| No `CronTrigger` was created | The caller's **Record Health Check Run** permission, job-name length, Check Set identity, and record-ID count |
| The schedule exists but no Batch job starts | The scheduling user's current run access and the most recent scheduled Apex failure |
| Batch completes but no outcomes are retained | The selected event-publication mode and the Set Run or Check Result subscriber |
| The same records run every day | This is expected for the packaged adapter; use a query-backed custom Batch to rediscover records |
| Duplicate schedules consume slots | Reuse one stable job name and replace the known schedule deliberately |

## Related

- [Batch Apex](batch.md)
- [Queueable Apex](queueable.md)
- [Apex API](apex-api.md)
- [Check Set Run event](../platform-events/check-set-run.md)
