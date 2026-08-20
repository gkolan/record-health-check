# Check Many Records with Batch Apex

Use Batch Apex when Record Health Check should automatically check many records after they change
or at a scheduled time. For example, a process changes Accounts or related Contacts, so the
affected Accounts should be checked after those changes finish. Another process might check all
recently modified Accounts every night at 2:00 AM.

Salesforce checks the records in smaller groups. You choose the maximum number of records in each
group so the Checks have enough room to run within Salesforce transaction limits.

## Make two decisions

First, decide how the Batch gets the Accounts:

| What needs to happen? | Follow this example |
| --- | --- |
| A process modified Accounts or related records, such as Contacts, and the affected Accounts should be checked now | [Example: Check affected Accounts now](#example-check-affected-accounts-now) |
| A scheduled process should find the matching Accounts and run Record Health Check automatically every night at 2:00 AM | [Example: Check recently changed Accounts every night](#example-check-recently-changed-accounts-every-night) |

“Start now” means that Salesforce adds the Batch job to its background work immediately. It does
not mean that the health results are returned to the person before the Apex request finishes.

Next, decide where the health results go:

| Result destination | What it requires |
| --- | --- |
| Save result records directly in Salesforce | A custom Batch that reads `response.results` during `execute()` |
| Send results to another process | Platform Events and a receiving Flow, Apex trigger, or integration |
| Keep no individual health results | `NONE`; monitor only whether the job completed in **Setup → Apex Jobs** |

These decisions are independent. A Batch can start now or on a schedule. A custom Batch can save
results directly or publish Platform Events. The packaged Batch can publish Platform Events, but it
cannot return individual results to the code that started it.

Each example below is a complete workflow, so it combines several choices:

| Example | How it gets Accounts | When it starts | Where results go |
| --- | --- | --- | --- |
| Check affected Accounts now | Uses Account IDs collected by the earlier process | Submitted immediately after that process | Publishes `ACTIONABLE` Platform Events |
| Check recently changed Accounts every night | Queries Accounts modified in the last 30 days | Every night at 2:00 AM | Saves detailed and summary records directly |

These are example choices. The custom Batch can publish Platform Events instead of saving records.
The packaged Batch can use `NONE` when only job completion matters.

## Before you start

1. Assign the person who starts or schedules the job the packaged **Record Health Check User**
   Permission Set. Use **Record Health Check Admin** only when that person must also configure
   Checks or view diagnostics. Both Permission Sets include:
   - **Custom Permission label:** Record Health Check Run
   - **Custom Permission API name:** `rhc__Record_Health_Check_Run`
   - access to the packaged Apex classes needed to run Record Health Check

   The Custom Permission is included in either Permission Set and does not need a separate
   assignment.
2. Confirm that the person can read the records and fields used by the Check Set.
3. In Setup, go to **Custom Metadata Types → Record Health Check Set → Manage Records**.
4. Find the Check Set and copy its **Qualified API Name**.
5. Prepare the result destination selected above:
   - For Platform Events, activate the receiving Flow, Apex trigger, or integration.
   - For direct saving, grant the running user Create access to the result objects and fields, plus
     access to the custom Batch and Scheduled Apex classes.

### Which Check Set name belongs in the Apex code?

| Check Set | Qualified API Name example |
| --- | --- |
| Created by an administrator in your org | `My_Account_Checks` |
| Included with the installed Record Health Check package | `rhc__Account_Data_Quality` |

The code examples use `My_Account_Checks`. Replace it with the exact **Qualified API Name** shown in
Setup. Do not add or remove `rhc__`; Salesforce includes that prefix when the Check Set came from
the installed package.

## Example: Check affected Accounts now

Use this approach when a process knows which Accounts may have been affected. The process might
have modified the Accounts directly. It might instead have modified related records, such as
Contacts, and now need to check the Accounts related to those Contacts.

This example uses the packaged Batch because the Account IDs are already known. The packaged Batch
returns a job ID and can publish results as Platform Events. It does not return
`response.results` to the code that starts the job.

In this example:

- a process modified some Accounts and some Contacts;
- the process collected the IDs of the Accounts it modified and the Account IDs from the modified
  Contacts;
- the health check starts after those changes finish;
- Salesforce checks no more than 25 Accounts in one transaction; and
- only results that may require attention are published as Platform Events.

```apex
// Collect every Account that may be affected.
// These two input variables come from the process that modified the records.
Set<Id> affectedAccountIds = new Set<Id>();
affectedAccountIds.addAll(modifiedAccountIds);
affectedAccountIds.addAll(accountIdsFromModifiedContacts);

// run(...) requires a List<Id>.
List<Id> accountIdsToCheck = new List<Id>(affectedAccountIds);

// Copy the exact Check Set Qualified API Name from Setup.
// This example uses a Check Set created by an administrator.
String checkSetApiName = 'My_Account_Checks';

// Start the Batch now. Salesforce checks up to 25 Accounts per transaction.
Id jobId = rhc.RecordHealthCheckBatch.run(
  checkSetApiName,
  accountIdsToCheck,
  // Use ACTIONABLE to publish only FAIL, UNABLE_TO_EVALUATE, and ERROR.
  // Use ALL to publish every result, including PASS and SKIPPED.
  // Use NONE only when job completion is enough. This packaged Batch returns
  // jobId, so NONE does not retain each Account's health result.
  rhc.RecordHealthCheckEventPublication.ACTIONABLE,
  25
);
```

### What each value means

| Value | Meaning |
| --- | --- |
| `checkSetApiName` | The Check Set Salesforce runs |
| `accountIdsToCheck` | The exact Accounts Salesforce checks |
| `ACTIONABLE` | Publish only `FAIL`, `UNABLE_TO_EVALUATE`, and `ERROR` Check Results, plus a completed Check Set Run heartbeat for every scanned record |
| `25` | Check no more than 25 Accounts in one Salesforce transaction |
| `jobId` | The ID used to find this Batch job in **Setup → Apex Jobs** |

The packaged Batch accepts 1–2,000 distinct record IDs. It removes null and repeated IDs before it
checks that limit. It checks only the IDs supplied when the job starts. It does not automatically
include records created or changed later.

If the fourth argument is omitted, the package checks up to 100 records per transaction. To choose
a different number, supply any whole number from 1 through 200.

## Example: Check recently changed Accounts every night

Use this approach when Salesforce must find the records again every time the job runs. This example
finds Accounts modified during the last 30 days, checks them in groups of 25, and runs every night.
It saves the results directly because that is the result destination selected for this example.

This requires two Apex classes:

1. `AccountHealthBatch` finds and checks the Accounts.
2. `NightlyAccountHealthSchedule` starts that Batch at the scheduled time.

### 1. Create the Batch class

The complete class below uses `NONE`, saves each detailed result during `execute()`, and creates one
summary record during `finish()`. The scheduled class in Step 2 starts this same Batch class.

A custom Batch can save health results directly to records instead of publishing Platform Events.
Use this approach when the results should remain in Salesforce and the process does not need a
separate Flow, Apex trigger, or integration to receive them.

This option requires a custom Batch such as `AccountHealthBatch`. The packaged
`rhc.RecordHealthCheckBatch.run(...)` method starts a job and returns its job ID; it does not return
the individual health results to the calling code.

#### What belongs in `execute()` and `finish()`

The example below shows both safe ways to collect results. Use either option by itself or use both
when the org needs detailed records and one Batch summary:

- `execute()` creates one detailed record for each Check result while that group is still in
  memory.
- Small number counters are kept with `Database.Stateful`, and `finish()` creates one summary
  record after Salesforce has attempted every group.

> [!IMPORTANT]
> The code below does not compile until these custom objects and fields exist. Record Health Check
> does not include objects for saving Batch history.

Before using the example, create these custom objects in **Setup → Object Manager**:

1. **Saved Health Check Result** (`Saved_Health_Check_Result__c`) stores one Check result for one
   Salesforce record. Create the fields used in `execute()`: Batch Job ID, Run ID, Checked Record
   ID, Check API Name, Status, Severity, and Reason Code. Use an Auto Number for the standard Record
   Name field when users do not need to name each result.
2. **Saved Health Check Run** (`Saved_Health_Check_Run__c`) stores one summary for the completed
   Batch. Create the fields used in `finish()`: Batch Job ID, Check Set API Name, Passed, Failed,
   Skipped, Unable to Evaluate, Error, and Completed At. Use an Auto Number for the standard Record
   Name field when users do not need to name each run.

The names above are examples. If the org uses different names, replace every example object and
field API name with the exact API names from Object Manager.

```apex
public with sharing class AccountHealthBatch
  implements Database.Batchable<Account>, Database.Stateful {
  private final String checkSetApiName;

  // Database.Stateful keeps these five small counters between execute() calls.
  // Do not store every detailed result in a class-level List.
  private Integer passed = 0;
  private Integer failed = 0;
  private Integer skipped = 0;
  private Integer unable = 0;
  private Integer systemError = 0;

  public AccountHealthBatch(String checkSetApiName) {
    this.checkSetApiName = checkSetApiName;
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    // Salesforce runs this query again each time a new Batch job starts.
    return Database.getQueryLocator(
      'SELECT Id FROM Account ' +
      'WHERE LastModifiedDate = LAST_N_DAYS:30 ' +
      'WITH USER_MODE'
    );
  }

  public void execute(
    Database.BatchableContext context,
    List<Account> accountsInThisTransaction
  ) {
    List<Id> accountIds = new List<Id>();
    for (Account accountRecord : accountsInThisTransaction) {
      accountIds.add(accountRecord.Id);
    }

    rhc.RecordHealthCheckResponse response = rhc.RecordHealthCheck.evaluate(
      rhc.RecordHealthCheckRequest.forCheckSet(
          checkSetApiName,
          accountIds
        )
        .withExecutionOrigin(rhc.RecordHealthCheckExecutionOrigin.BATCH)
        .withRunId(
          'batch-' + context.getJobId() + '-' + accountIds[0]
        )
        // NONE publishes no health-result Platform Events.
        // response.results still contains every status, including PASS.
        .withEventPublication(
          rhc.RecordHealthCheckEventPublication.NONE
        )
    );

    // Save every detailed result now.
    // One Account can produce several rows because each Check has its own result.
    // Saved_Health_Check_Result__c is a custom object created in your org.
    List<Saved_Health_Check_Result__c> recordsToInsert =
      new List<Saved_Health_Check_Result__c>();

    for (rhc.RecordHealthCheckResultItem item : response.results) {
      rhc.RecordHealthCheckEvaluationResult result = item.evaluation;

      recordsToInsert.add(
        new Saved_Health_Check_Result__c(
          Batch_Job_Id__c = context.getJobId(),
          Run_Id__c = response.runId,
          Checked_Record_Id__c = String.valueOf(result.recordId),
          Check_API_Name__c = result.checkQualifiedApiName,
          Status__c = result.status,
          Severity__c = result.severity,
          Reason_Code__c = result.reasonCode
        )
      );
    }

    // Insert this group's results before this execute() transaction ends.
    // USER_MODE applies the running user's object and field permissions.
    // If an insert fails, this execute() transaction fails and Salesforce
    // shows the failed group in Setup → Apex Jobs.
    Database.insert(recordsToInsert, AccessLevel.USER_MODE);

    // Keep only small totals for one final summary record.
    // These five Integer values are safe to retain between transactions.
    passed += response.summary.passed;
    failed += response.summary.failed;
    skipped += response.summary.skipped;
    unable += response.summary.unable;
    systemError += response.summary.systemError;
  }

  public void finish(Database.BatchableContext context) {
    // finish() runs once after Salesforce has attempted every group.
    // Create one summary record; do not try to insert all detailed results here.
    // Saved_Health_Check_Run__c is a custom object created in your org.
    Saved_Health_Check_Run__c runSummary = new Saved_Health_Check_Run__c(
      Batch_Job_Id__c = context.getJobId(),
      Check_Set_API_Name__c = checkSetApiName,
      Passed__c = passed,
      Failed__c = failed,
      Skipped__c = skipped,
      Unable_To_Evaluate__c = unable,
      Error__c = systemError,
      Completed_At__c = System.now()
    );

    Database.insert(runSummary, AccessLevel.USER_MODE);
  }
}
```

The SOQL filter controls which Accounts are checked. Replace
`LastModifiedDate = LAST_N_DAYS:30` with the rule required by the real process. Avoid an
unrestricted `SELECT Id FROM Account` unless checking every Account is deliberate and has been
tested with a realistic number of records.

Test the Batch before scheduling it:

```apex
// Copy the exact Check Set Qualified API Name from Setup.
String checkSetApiName = 'My_Account_Checks';

// Start the Batch now with no more than 25 Accounts per transaction.
Id jobId = Database.executeBatch(
  new AccountHealthBatch(checkSetApiName),
  25
);
```

#### Result-collection choices

Record Health Check provides two ways for Batch code to receive results:

1. Read `response.results` immediately inside `execute()`.
2. Publish Platform Events for separate automation to receive.

`finish()` does not receive another Record Health Check response. It can use only small values the
Batch deliberately kept with `Database.Stateful`, records it queries after `execute()` saved them,
or the Batch job ID from `context.getJobId()`.

| Need | Where to handle it | What to do |
| --- | --- | --- |
| Keep every Check result for reporting | `execute()` | Convert `response.results` to custom-object records and insert each group immediately. |
| Keep only one total for the complete Batch | `execute()` and `finish()` | Add `response.summary` counts to small `Database.Stateful` counters, then create one summary record in `finish()`. |
| Update Accounts or start other business work for each group | `execute()` | Use `response.results` while the current group is in memory. Keep queries and record updates outside the result loop. |
| Let a Flow, Apex trigger, or external integration receive results separately | Platform Events | Use `ACTIONABLE` or `ALL` and follow [Send results with Platform Events](#send-results-with-platform-events). |
| Monitor only whether Salesforce completed the Batch | Apex Jobs | Use `NONE`, do not save result records, and monitor **Setup → Apex Jobs**. Individual health results will not be retained. |

Do not collect every detailed result in a class-level list and wait for `finish()` to insert it.
Local variables from earlier `execute()` calls are not automatically available in `finish()`.
Keeping all results with `Database.Stateful` can exceed memory limits on a large job. Saving each
group's results inside `execute()` avoids that problem.

If one `execute()` transaction fails, records saved by earlier successful transactions remain.
The counters used by `finish()` do not include results from that failed group because Record Health
Check did not return a completed response for it. Design retries so they do not create duplicate
result records.

### 2. Create the Scheduled Apex class

This scheduler reuses the `AccountHealthBatch` class above. It does not repeat the health-check or
result-saving code.

```apex
public with sharing class NightlyAccountHealthSchedule
  implements Schedulable {
  public void execute(SchedulableContext context) {
    // Copy the exact Check Set Qualified API Name from Setup.
    String checkSetApiName = 'My_Account_Checks';

    // Start AccountHealthBatch with up to 25 Accounts at a time.
    // AccountHealthBatch uses NONE and saves response.results directly.
    Database.executeBatch(
      new AccountHealthBatch(checkSetApiName),
      25
    );
  }
}
```

### 3. Schedule it from Setup

1. Add and test both Apex classes in a sandbox.
2. Deploy the tested classes to the org where the health check should run.
3. In Setup, enter **Apex Classes** in Quick Find and select **Apex Classes**.
4. Select **Schedule Apex**.
5. Enter a job name, such as `Nightly Account Health Check`.
6. Select `NightlyAccountHealthSchedule` as the Apex class.
7. Choose how often the job runs, its start and end dates, and its preferred start time.
8. Select **Save**.
9. Open **Setup → Scheduled Jobs** and confirm that the schedule appears.

The selected time uses the scheduling person's Salesforce time zone. That person must continue to
have the permissions and record access listed in [Before you start](#before-you-start).

After the schedule runs, use **Setup → Apex Jobs** to monitor the Batch it started. The scheduled
job and each Batch run are separate jobs in Salesforce.

The same daily 2:00 AM schedule can also be created from Apex:

```apex
String scheduledJobId = System.schedule(
  'Nightly Account Health Check',
  '0 0 2 * * ?',
  new NightlyAccountHealthSchedule()
);
```

The returned `scheduledJobId` identifies the recurring schedule. It does not identify an
individual nightly Batch run. See [Scheduled Apex](scheduled.md) for more scheduling details.

## Send results with Platform Events

Use Platform Events when a Flow, Apex trigger, or external integration should react to health
results independently of the Batch. The number of records is not the deciding factor. Platform
Events can handle large jobs, but they require a receiver and count toward the org's Platform Event
usage limits.

A Platform Event is a message sent after a health check finishes. Create one of these receivers
before running the Batch:

- a **Platform Event-Triggered Flow** that saves results or sends notifications;
- an **Apex trigger** that handles the results in Salesforce; or
- an integration that receives the events outside Salesforce.

Choose the publication value in the Apex request: `ACTIONABLE` sends only `FAIL`,
`UNABLE_TO_EVALUATE`, and `ERROR`; `ALL` also sends `PASS` and `SKIPPED`; and `NONE` sends no
health-result events.

Record Health Check provides two useful events:

- **Check Set Run** provides a summary of one completed Check Set run.
- **Check Result** provides the status, severity, and Reason Code for an individual Check.

Publishing must also be enabled on the Check Set or Check. Selecting `ALL` or `ACTIONABLE` in Apex
does not override a disabled publication setting. Follow [Subscribe to the Check Set Run
event](../platform-events/check-set-run.md) or [Subscribe to the Check Result
event](../platform-events/check-result.md) to enable publication and build the receiving Flow or
Apex trigger.

Platform Events are not permanent result storage. The receiving Flow, Apex trigger, or integration
must save the information when the organization needs history, reporting, or follow-up work.

Use **Setup → Apex Jobs** only to confirm whether the Batch ran successfully. A completed Batch can
still produce `FAIL` health results. In that case the Batch worked, but a record did not meet one or
more Checks.

## Choose the Batch size

The final number is how many records Salesforce checks at one time:

```apex
Database.executeBatch(new AccountHealthBatch(checkSetApiName), 25);
//                                                           ^^ check up to 25 Accounts at a time
```

Use any whole number from `1` through `200`. Start with `25` and test it in a sandbox.

- Lower it to `10` or `5` if the job reaches a Salesforce transaction limit.
- Raise it only after testing shows that the Check Set has room to process more records at once.

Formula Checks often need a smaller Batch size. For example, four Formula Checks across 25
Accounts require at least 100 formula evaluations, but Record Health Check allows 95 in one
transaction. Lowering the Batch size reduces the formula work in each transaction.

The Batch size does not limit the total number of records a custom Batch can find. Salesforce
allows a `Database.QueryLocator` to find up to 50 million records, but large jobs must still be
tested to confirm that they finish in the required time.

## Monitor each run

1. Open **Setup → Apex Jobs**.
2. Find the Batch using its `jobId`, start time, or Apex class name.
3. Review the processed, failed, and remaining Batch counts.
4. Review **Saved Health Check Results** when the custom Batch saves results directly. When the
   Batch publishes Platform Events instead, review the receiving Flow, Apex trigger, or
   integration.
5. If a group of records fails with an exception, review the
   [`BATCH_SCOPE_FAILED` error event](../platform-events/error-log.md).

One failed group does not remove results produced by earlier successful groups. Retrying a Batch
can create the same saved result again or publish the same result again. Add a unique key to the
custom result object to prevent duplicate saved records. Automation receiving events should use
each event's unique `EventId__c` to avoid handling the same event twice.

Before retrying a job after a timeout, check **Setup → Apex Jobs** to confirm whether the original
job was created. Starting the same job twice can produce duplicate results.

## Test before using it in production

In an Apex test, place one Batch submission between `Test.startTest()` and `Test.stopTest()`. Keep
all test records in one group because Salesforce permits only one Batch execution in a test method.

Test at least:

- records that produce `PASS`, `FAIL`, `UNABLE_TO_EVALUATE`, and `ERROR`;
- a `SKIPPED` result when one of the Checks can be skipped;
- the custom result and summary records created by the example;
- the Flow, Apex trigger, or integration when the Batch publishes Platform Events;
- a Batch group that throws an exception;
- protection against starting or handling the same job twice; and
- access for a user with the same permissions as the person who runs the production job.

## Troubleshooting

| What happened? | What to check |
| --- | --- |
| No Batch job was created | Confirm the user's Permission Set, the Check Set Qualified API Name, and the number of supplied IDs. |
| The scheduled job exists, but no Batch starts | Confirm the scheduling user's current permissions and review the latest Scheduled Apex failure. |
| The custom Batch completed, but no saved results appeared | Confirm that `response.results` was converted and inserted, and review failed groups in **Apex Jobs**. |
| The packaged Batch completed, but no event results appeared | Confirm `ALL` or `ACTIONABLE`, the Check Set and Check publication settings, and the Flow, Apex trigger, or integration receiving the events. |
| The Batch completed and records have `FAIL` results | The job worked; those records did not meet one or more Checks. Review the individual health results. |
| A group reaches a formula or Salesforce transaction limit | Lower the number of records checked per transaction and test again. |
| An affected Account is missing | Confirm that the earlier process added the Account ID directly or collected it from the modified related record. The Batch checks only the supplied Account IDs. |
| A retry produced duplicate results | Confirm whether the original job already existed. Use a unique key on saved result records or `EventId__c` for Platform Events. |

## Related

- [Apex API](apex-api.md)
- [Queueable Apex](queueable.md)
- [Scheduled Apex](scheduled.md)
- [Check Set Run event](../platform-events/check-set-run.md)
