# Run Record Health Check from Batch Apex

> [!NOTE]
> On this page, process a large record population in Batch Apex scopes sized for the selected Check Set and capture each scope with a distinct correlation ID.

Use the packaged `RecordHealthCheckBatch` when the record IDs are already known:

```apex
Id jobId = RecordHealthCheckBatch.run(
  'rhc__Account_Data_Quality',
  accountIds,
  RecordHealthCheckEventPublication.ACTIONABLE
);
```

`run` requires `Record_Health_Check_Run`, a nonblank qualified Check Set identity, and 1–2,000
distinct non-null record IDs. Null IDs and duplicates are removed before the population limit is
checked. The packaged adapter uses execute scopes of 100, safely below the 200-record engine
ceiling, and rechecks authorization in `start` and every `execute` transaction. Rejected input
creates no Batch job. The public constructor enforces the same authorization and population
contract as `run`, so direct construction cannot reserve Batch capacity with invalid state.

Create a custom query-backed Batch only when record discovery must also happen asynchronously.
Each
`execute` scope is a separate transaction, so each scope must independently satisfy Record Health
Check limits.

## Batch example

Create a batch that queries record IDs and evaluates each scope once:

```apex
public with sharing class AccountHealthBatch
  implements Database.Batchable<Account> {
  private final String checkSetQualifiedApiName;

  public AccountHealthBatch(String checkSetQualifiedApiName) {
    this.checkSetQualifiedApiName = checkSetQualifiedApiName;
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    return Database.getQueryLocator(
      'SELECT Id FROM Account WHERE IsDeleted = false'
    );
  }

  public void execute(
    Database.BatchableContext context,
    List<Account> scope
  ) {
    List<Id> recordIds = new List<Id>();
    for (Account accountRecord : scope) {
      recordIds.add(accountRecord.Id);
    }

    RecordHealthCheckResponse response = RecordHealthCheck.evaluate(
      RecordHealthCheckRequest.forCheckSet(
          checkSetQualifiedApiName,
          recordIds
        )
        .withExecutionOrigin(RecordHealthCheckExecutionOrigin.BATCH)
        .withRunId(
          'batch-' + context.getJobId() + '-' + recordIds[0]
        )
        .withEventPublication(
          RecordHealthCheckEventPublication.ACTIONABLE
        )
    );

    // Persist or aggregate only the outcomes required by the use case.
  }

  public void finish(Database.BatchableContext context) {
  }
}
```

Choose the scope size from the number and shape of active Rules. For a Check Set with several
Formula Rules, the planned-evaluation ceiling may require a much smaller scope than the public
record ceiling.

Run the batch with an explicitly reviewed scope size:

```apex
Id jobId = Database.executeBatch(
  new AccountHealthBatch('rhc__Account_Data_Quality'),
  25
);
```

## Failure and retry behavior

One failed scope does not erase successful earlier scopes. Retried work can produce the same
business outcomes again, so use a stable uniqueness key when persisting results or handling
events. Correlate each scope with the Batch job ID and a scope-specific value.

Batch Apex has no Queueable-style duplicate signature. An automation caller that can retry must
persist its own idempotency key before calling `run`, or reconcile an existing `AsyncApexJob`
before resubmission. Do not blindly retry on timeout: duplicate Batch jobs consume org capacity
and can repeat lifecycle events even though health evaluation itself is read-only.

An uncaught scope failure is logged with stable reason `BATCH_SCOPE_FAILED`, flushed through the
configured error-event channel, and rethrown so the platform job remains visibly failed.

Do not create a per-record fallback when a Rule cannot evaluate in bulk. Resolve unsupported
shapes in memory or return the documented unable status.

## Test the batch

Execute one batch in a test method between `Test.startTest()` and `Test.stopTest()`. Assert the
captured outcome and query `AsyncApexJob` for completion. Add a focused test for a scope that
returns `FAIL`, `UNABLE_TO_EVALUATE`, or `ERROR`.

## Related

- [Queueable Apex](03-queueable.md)
- [Scheduled Apex](05-scheduled.md)
- [Apex API limits](01-apex-api.md#limits-and-access)
- [Check Set Run event](../platform-events/01-check-set-run.md)
