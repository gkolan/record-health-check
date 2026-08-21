# Run Record Health Check from Queueable Apex

> [!NOTE]
> Use Queueable Apex when up to 200 known record IDs should run in a separate transaction and the
> submitting process does not need the response immediately.

> [!IMPORTANT]
> **Audience: Salesforce developers.** Flow Builder cannot enqueue the packaged helper directly.
> An administrator can monitor the returned job ID in **Setup → Apex Jobs**, but a developer must
> choose the packaged or custom Queueable and its result destination.

## What Queueable changes

Queueable Apex moves evaluation out of the submitting transaction. Salesforce returns an
`AsyncApexJob` ID when the job is accepted.

The job ID and the health results are different things:

- The job ID shows whether Salesforce queued, ran, completed, or failed the Apex job.
- The Record Health Check response contains `PASS`, `FAIL`, `SKIPPED`,
  `UNABLE_TO_EVALUATE`, and `ERROR` results.
- **Setup → Apex Jobs** does not display the health results.

Choose where health results will go before enqueueing the job. A custom Queueable can save
`response.results` directly. The packaged Queueable can publish Platform Events for a Flow, Apex
trigger, or integration. If neither is configured, only the Apex job status remains available.

## Choose the Queueable pattern

| Example | Use | Why |
| --- | --- | --- |
| A Case update already has 80 Case IDs, and a Platform Event-Triggered Flow handles failures | Packaged Queueable | The IDs are known, the request is below 200, and custom code does not need the response. |
| After checking 80 Accounts, Apex must save one review record for every `FAIL` | Custom Queueable | The Queueable must inspect `response.results` and save selected results. |
| A nightly job must query current records, or more than 200 records can run | [Batch Apex](batch.md) | Queueable accepts only known IDs in one request. |

The record IDs must already be known before either Queueable starts. The difference is where the
results go:

- The packaged Queueable returns a job ID and can publish Platform Events.
- A custom Queueable can read and save `response.results` directly.
- With `NONE` and no direct saving, only the Apex job status remains available.

## Before you start

1. Assign the submitting user the packaged **Record Health Check User** Permission Set. Use
   **Record Health Check Admin** only when the user also configures Checks or views diagnostics.
   Both include **Custom Permission label:** Record Health Check Run, **Custom Permission API
   name:** `rhc__Record_Health_Check_Run`, and access to the packaged Queueable class.
2. Confirm access to the target records, fields, and Record Health Check Custom Metadata.
3. Collect no more than 200 distinct, non-null record IDs.
4. Copy the Check Set **Qualified API Name** from **Setup → Custom Metadata Types → Record Health
   Check Set → Manage Records**. Do not add or remove `rhc__` yourself.
5. Decide whether a custom Queueable saves `response.results`, the packaged Queueable publishes
   Platform Events, or only Apex job completion is required.

## Example: Use the packaged Queueable

Use the packaged Queueable class when Platform Events or job completion provide everything the process
needs:

```apex
// Copy the exact Check Set Qualified API Name from Setup.
// A Check Set included with the installed package might be rhc__Account_Data_Quality.
String checkSetApiName = 'My_Account_Checks';

// accountIds is a List<Id> collected by the process that changed the records.
Id jobId = rhc.RecordHealthCheckQueueable.enqueue(
  checkSetApiName,
  accountIds,
  // Use ACTIONABLE to publish only FAIL, UNABLE_TO_EVALUATE, and ERROR.
  // Use ALL to publish every result, including PASS and SKIPPED.
  // Use NONE only when Apex job completion is enough. This packaged
  // Queueable returns jobId and does not return individual health results.
  rhc.RecordHealthCheckEventPublication.ACTIONABLE
);
```

This call performs submission checks before creating a job. It requires:

- a nonblank qualified Check Set name;
- between 1 and 200 distinct, non-null record IDs after nulls and duplicates are removed;
- every remaining ID belongs to the selected Check Set object, or the entire submission is rejected; and
- the **Record Health Check Run** Custom Permission.

The job checks authorization again when it executes. With `NONE`, the packaged job does not send
health results anywhere; **Setup → Apex Jobs** shows only whether the Queueable completed.

## Example: Save results from a custom Queueable

Use a custom class when Apex must inspect and save `response.results` or `response.summary`.

The example saves failures to **Saved Health Check Result** (`Saved_Health_Check_Result__c`), an
example custom object that is not included with Record Health Check. Before using the code, create
that custom object and the fields shown below, or replace those API names with an approved result
object already in the org.

Create fields for Apex Job ID, Run ID, Checked Record ID, Check API Name, Status, Severity, and
Reason Code. Grant the running user Create access to the object and fields.

> [!IMPORTANT]
> This example does not compile until `Saved_Health_Check_Result__c` and its example fields exist in
> the org.

```apex
public with sharing class AccountHealthQueueable
  implements Queueable, Finalizer {
  private final String checkSetQualifiedApiName;
  private final List<Id> recordIds;

  public AccountHealthQueueable(
    String checkSetQualifiedApiName,
    List<Id> recordIds
  ) {
    this.checkSetQualifiedApiName = checkSetQualifiedApiName;
    this.recordIds = new List<Id>(recordIds);
  }

  public void execute(QueueableContext context) {
    System.attachFinalizer(this);

    rhc.RecordHealthCheckRequest request =
      rhc.RecordHealthCheckRequest.forCheckSet(
        checkSetQualifiedApiName,
        recordIds
      )
      .withExecutionOrigin(rhc.RecordHealthCheckExecutionOrigin.QUEUEABLE)
      .withRunId('queueable-' + context.getJobId())
      // NONE publishes no Platform Events because this Queueable reads and
      // saves response.results directly.
      .withEventPublication(
        rhc.RecordHealthCheckEventPublication.NONE
      );

    rhc.RecordHealthCheckResponse response =
      rhc.RecordHealthCheck.evaluate(request);

    // Save one record for every result that may require attention.
    List<Saved_Health_Check_Result__c> recordsToInsert =
      new List<Saved_Health_Check_Result__c>();
    for (rhc.RecordHealthCheckResultItem item : response.results) {
      rhc.RecordHealthCheckEvaluationResult result = item.evaluation;
      if (
        result.status == rhc.RecordHealthCheckStatus.FAIL ||
        result.status == rhc.RecordHealthCheckStatus.UNABLE_TO_EVALUATE ||
        result.status == rhc.RecordHealthCheckStatus.ERROR
      ) {
        recordsToInsert.add(
          new Saved_Health_Check_Result__c(
            Apex_Job_Id__c = context.getJobId(),
            Run_Id__c = response.runId,
            Checked_Record_Id__c = String.valueOf(result.recordId),
            Check_API_Name__c = result.checkQualifiedApiName,
            Status__c = result.status,
            Severity__c = result.severity,
            Reason_Code__c = result.reasonCode
          )
        );
      }
    }

    if (!recordsToInsert.isEmpty()) {
      Database.insert(recordsToInsert, AccessLevel.USER_MODE);
    }
  }

  public void execute(FinalizerContext context) {
    if (context.getResult() == ParentJobResult.UNHANDLED_EXCEPTION) {
      // Report cleaned-up job context to approved monitoring.
      // Do not expose record data or an unfiltered stack trace.
    }
  }
}
```

Enqueue the custom class:

```apex
// Copy the exact Check Set Qualified API Name from Setup.
String checkSetApiName = 'My_Account_Checks';

// accountIds is a List<Id> collected by the process that changed the records.
Id jobId = System.enqueueJob(
  new AccountHealthQueueable(
    checkSetApiName,
    accountIds
  )
);
```

The Finalizer runs once after the Queueable ends. It can report an uncaught Queueable exception even
when the Queueable transaction rolls back. An `ERROR` in `response.results` is different: Record
Health Check caught that problem and returned it as a health result.

## Understand duplicate submissions

The packaged Queueable class creates a platform `QueueableDuplicateSignature` from the submitting
user, Check Set, publication mode, and record IDs after it removes nulls, repeated IDs, and
record-order differences. Equivalent work submitted by a different user receives a separate job;
deduplication prevents accidental retries by the same submitting principal.

If an equivalent job is already pending, Salesforce throws `DuplicateMessageException` instead of
using another Queueable slot. This means an equivalent job is already waiting to run. Use the saved
job ID and Run ID to find that job; do not retry in a tight loop.

## Monitor a run

1. Save the returned `AsyncApexJob` ID when staff must find the job later.
2. For the custom pattern, save the Record Health Check `runId` with that job ID on the result
   record.
3. Open **Setup → Apex Jobs** to review platform status and uncaught failures.
4. Review the selected result destination for health outcomes.
5. Review the Finalizer's approved monitoring channel for an uncaught job failure.

The job runs with the effective access of the user who enqueued it. Moving work to Queueable Apex
does not increase Record Health Check limits or grant more access.

## Test the Queueable

Place the enqueue call between `Test.startTest()` and `Test.stopTest()` so the job runs in the test.
Assert:

- the result-saving, notification, or event behavior;
- the saved job ID and Run ID;
- handling for `FAIL`, `UNABLE_TO_EVALUATE`, and `ERROR`; and
- the Finalizer's cleaned-up handling of an uncaught exception.

Query `AsyncApexJob` only to verify platform job status. Assert health outcomes through the result
destination selected by the design.

## Troubleshooting

| Symptom | Check first |
| --- | --- |
| No job is created | Qualified Check Set name, ID count, and the submitting user's Custom Permission |
| `DuplicateMessageException` is thrown | Whether an equivalent job is already waiting; find that job instead of retrying |
| The packaged job completes but no event results are visible | Event Publication, Check publication settings, and the Flow, Apex trigger, or integration receiving the events |
| The custom job completes but no saved results are visible | The custom object's Create access, field access, result filters, and insert code |
| The job fails after it starts | **Setup → Apex Jobs**, Finalizer monitoring, and the executing user's access |
| Records return `UNABLE_TO_EVALUATE` | Reason codes plus record, field, and Check configuration access |
| More than 200 records must run | Split intentionally or use Batch Apex |

## Related

- [API overview](README.md)
- [Batch Apex](batch.md)
- [Scheduled Apex](scheduled.md)
- [Apex API](apex-api.md)
- [Platform Event subscriptions](../platform-events/README.md)
