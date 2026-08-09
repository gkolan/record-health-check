# Run Record Health Check from Queueable Apex

> [!NOTE]
> On this page, create a Queueable Apex wrapper that evaluates one bounded record scope in a separate transaction and preserves a correlation ID.

Queueable Apex is the preferred asynchronous pattern for new work that fits in one Record Health
Check request. It provides an `AsyncApexJob` ID, supports constructor state that is not limited to
simple values, and can chain follow-on work when the design requires another transaction.

## Packaged Queueable

For a bounded scope, enqueue the packaged adapter directly:

```apex
Id jobId = rhc.RecordHealthCheckQueueable.enqueue(
  'rhc__Account_Data_Quality',
  accountIds,
  rhc.RecordHealthCheckEventPublication.ACTIONABLE
);
```

The returned `AsyncApexJob` ID reports Queueable execution. It does not contain health outcomes.
Choose `ACTIONABLE` or `ALL` when an event subscriber owns the results; otherwise use a custom
Queueable that hands `response.results` to an approved persistence or notification service.

## Custom Queueable example

Create a class that accepts the qualified Check Set identity and a bounded list of record IDs:

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
    rhc.RecordHealthCheckRequest request = rhc.RecordHealthCheckRequest.forCheckSet(
      checkSetQualifiedApiName,
      recordIds
    )
      .withExecutionOrigin(rhc.RecordHealthCheckExecutionOrigin.QUEUEABLE)
      .withRunId('queueable-' + context.getJobId())
      .withEventPublication(rhc.RecordHealthCheckEventPublication.ACTIONABLE);

    rhc.RecordHealthCheckResponse response = rhc.RecordHealthCheck.evaluate(request);
    if (response.summary.systemError > 0 || response.summary.unable > 0) {
      // Persist a restricted operational record or notify approved monitoring.
    }
  }

  public void execute(FinalizerContext context) {
    if (context.getResult() == ParentJobResult.UNHANDLED_EXCEPTION) {
      // Send cleaned-up job context to approved operational monitoring.
      // Do not copy record data or an unfiltered stack trace into user-visible fields.
    }
  }
}
```

Enqueue the class from Apex with a scope that already satisfies the public limits:

```apex
Id jobId = System.enqueueJob(
  new AccountHealthQueueable(
    'rhc__Account_Data_Quality',
    accountIds
  )
);
```

## Failure handling

`enqueue` requires the **Record Health Check Run** (`rhc__Record_Health_Check_Run`) Custom Permission, a nonblank qualified Check Set
identity, and 1–200 distinct non-null record IDs. Null IDs and duplicates are removed before the
limit is checked. Invalid or unauthorized input is rejected before an `AsyncApexJob` is created,
and authorization is checked again when the job executes. The public constructor applies the same
checks, so calling `System.enqueueJob` directly cannot bypass the submission boundary.

Equivalent pending requests use a platform `QueueableDuplicateSignature` derived from the
normalized Check Set, publication contract, and record IDs. A concurrent/retried duplicate throws
`DuplicateMessageException` instead of consuming another Queueable slot. Record order, nulls, and
duplicate IDs do not change the signature. Callers should treat that exception as an accepted
in-flight request, then reconcile using their stored job/run correlation rather than retrying in a
tight loop.

An `ERROR` result is data returned by the Framework. An uncaught exception fails the Queueable job.
The Finalizer observes that second channel even when the Queueable transaction rolls back. Store
the Queueable job ID with the Framework `runId` when operational staff must correlate an
`AsyncApexJob` with captured health results.

Queueable Apex does not increase the per-request Record Health Check limits. Split work before
enqueueing or use Batch Apex when the population requires multiple scopes.

The Queueable runs with the effective access of the user who enqueued it. Assign the packaged User
or Admin permission set for the adapter class, run permission, and framework Custom Metadata
access; separately grant the business-object access required by the selected Checks.

## Test the Queueable

Use `Test.startTest()` and `Test.stopTest()` to execute the queued job. Assert the response-driven
follow-on work or event subscriber, the source or correlation value, and the Finalizer's cleaned-up
handling of an uncaught failure. Query `AsyncApexJob` only for platform job status; assert health
outcomes through the destination selected by the design.

## Related

- [Batch Apex](batch.md)
- [Scheduled Apex](scheduled.md)
- [Apex API](apex-api.md)
- [Platform Event subscriptions](../platform-events/README.md)
