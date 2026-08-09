# Run Record Health Check from Batch Apex

> [!NOTE]
> On this page, choose the packaged fixed-population Batch or a custom query-backed Batch, size its
> scopes for the selected Check Set, and give completed outcomes an explicit destination.

## Choose the Batch pattern

| Population | Use | Result ownership |
| --- | --- | --- |
| You already have 1–2,000 record IDs | Packaged `rhc.RecordHealthCheckBatch` | Request lifecycle events or monitor job completion only |
| Records must be discovered when the job starts | Custom query-backed Batch | Persist approved results, publish lifecycle events, or carry a small bounded summary |

An `AsyncApexJob` tells you whether Batch execution completed. It does not contain Record Health
Check outcomes. Decide how outcomes will be consumed before submitting the job.

## Packaged Batch

Use the packaged `rhc.RecordHealthCheckBatch` when the record IDs are already known:

```apex
Id jobId = rhc.RecordHealthCheckBatch.run(
  'rhc__Account_Data_Quality',
  accountIds,
  rhc.RecordHealthCheckEventPublication.ACTIONABLE
);
```

`run` requires **Record Health Check Run** (`rhc__Record_Health_Check_Run`), a nonblank qualified Check Set identity, and 1–2,000
distinct non-null record IDs. Null IDs and duplicates are removed before the population limit is
checked. The packaged adapter uses execute scopes of 100, safely below the 200-record engine
ceiling, and rechecks authorization in `start` and every `execute` transaction. Rejected input
creates no Batch job. The public constructor enforces the same authorization and population
contract as `run`, so direct construction cannot reserve Batch capacity with invalid state.

The packaged adapter captures the supplied IDs at submission. It does not discover records added
later. Every execute scope uses the shared Run ID `batch-<AsyncApexJobId>`; use the evaluated record
ID and the lifecycle event's unique `EventId__c` to identify individual outcomes. A custom Batch can
choose a distinct scope correlation value when its downstream design requires one.

Create a custom query-backed Batch only when record discovery must happen when the job starts. Each
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
      'SELECT Id FROM Account WITH USER_MODE'
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

    rhc.RecordHealthCheckResponse response = rhc.RecordHealthCheck.evaluate(
      rhc.RecordHealthCheckRequest.forCheckSet(
          checkSetQualifiedApiName,
          recordIds
        )
        .withExecutionOrigin(rhc.RecordHealthCheckExecutionOrigin.BATCH)
        .withRunId(
          'batch-' + context.getJobId() + '-' + recordIds[0]
        )
        .withEventPublication(
          rhc.RecordHealthCheckEventPublication.ACTIONABLE
        )
    );

    // Hand response.results to an approved bulk persistence service here,
    // or rely on the explicitly requested ACTIONABLE lifecycle events.
  }

  public void finish(Database.BatchableContext context) {
  }
}
```

The custom discovery query is subscriber code. It must enforce the intended object, field, and
record access independently of the Framework evaluation. This example selects only `Id` and uses
user mode. When a real filter uses dynamic values, bind them rather than concatenating user input.

The example deliberately does not implement cross-scope aggregation. Local variables disappear at
the end of `execute`. Use durable subscriber-owned storage when results must survive, or add
`Database.Stateful` only for a small bounded summary that has been reviewed for serialization and
heap cost. Lifecycle events are independent, asynchronous deliveries, so the subscriber must be
safe when Salesforce delivers the same event more than once.

Choose the scope size from the number and shape of active Checks. For a Check Set with several
Formula Checks, the planned-evaluation ceiling may require a much smaller scope than the public
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
events. The packaged adapter correlates scopes with one Batch job Run ID. The custom example adds
the first record ID to create a scope-specific Run ID.

Batch Apex has no Queueable-style duplicate signature. An automation caller that can retry must
save its own unique request key before calling `run`, or reconcile an existing `AsyncApexJob`
before resubmission. Do not blindly retry on timeout: duplicate Batch jobs consume org capacity
and can repeat lifecycle events even though health evaluation itself is read-only.

An uncaught scope failure is logged with stable reason `BATCH_SCOPE_FAILED`, flushed through the
configured error-event channel, and rethrown so the platform job remains visibly failed.

Do not create a per-record fallback when a Check cannot evaluate in bulk. Resolve unsupported
shapes in memory or return the documented unable status.

## Test the batch

Execute one Batch in a test method between `Test.startTest()` and `Test.stopTest()`. Keep the test
population within one execute scope because Salesforce permits only one Batch execution in a test
method. Query `AsyncApexJob` to assert platform completion, then assert the result destination the
design actually owns:

- subscriber-owned records when the custom Batch persists results;
- subscriber behavior in a separate Platform Event test when it publishes events; or
- bounded state exposed by the custom Batch when it deliberately implements `Database.Stateful`.

Add focused cases for `FAIL`, `UNABLE_TO_EVALUATE`, `ERROR`, an uncaught scope failure, duplicate
submission handling, and the real executing user's access.

## Related

- [Queueable Apex](queueable.md)
- [Scheduled Apex](scheduled.md)
- [Apex API limits](apex-api.md#limits-and-access)
- [Check Set Run event](../platform-events/check-set-run.md)
