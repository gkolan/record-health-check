# Replace a Future Method with Queueable Apex

> [!NOTE]
> Use this page to replace an existing `@future` Record Health Check caller. Do not create a new
> future method for Record Health Check.

## Why replace the future method

Queueable Apex makes background work easier to monitor and maintain:

| Capability | Future method | Queueable Apex |
| --- | --- | --- |
| Returned Apex job ID | No | Yes |
| Typed constructor state | Limited to future-method parameter types | Yes |
| Finalizer for uncaught failure handling | No | Yes |
| Visible job in **Setup → Apex Jobs** | Limited | Yes |
| Supported pattern for new Record Health Check work | No | Yes |

This change affects how work is submitted and monitored. It should not change the meaning of the
Check, the records evaluated, or the handling of business results.

### Example: Replace an Account import future method

An existing `@future` method receives Account IDs after an import and runs a Check Set. Replace it
with a Queueable that accepts the same IDs. The import caller now receives an Apex job ID, and a
Finalizer reports an uncaught job failure. The selected Check Set and result handling stay the same.

The caller changes from a future-method call that returns no job ID:

```apex
LegacyAccountHealth.checkAccounts(accountIds);
```

to a Queueable submission that returns an Apex job ID:

```apex
// Copy the exact Check Set Qualified API Name from Setup.
String checkSetApiName = 'My_Account_Checks';

Id jobId = System.enqueueJob(
  new AccountHealthQueueable(
    checkSetApiName,
    new List<Id>(accountIds)
  )
);
```

`AccountHealthQueueable` is the complete custom class in the [Queueable Apex
example](queueable.md#example-save-results-from-a-custom-queueable). The returned `jobId` identifies
the replacement job in **Setup → Apex Jobs**. It does not contain the health results.

## Before you change the code

Document the existing behavior:

1. Find every caller of the future method.
2. Record which Check or Check Set it runs and how record IDs are collected.
3. Confirm the maximum number of records passed by each caller.
4. Identify the user context and required permission sets.
5. Identify where `PASS`, `FAIL`, `UNABLE_TO_EVALUATE`, and `ERROR` results go today.
6. Identify how an uncaught background-job failure is reported.
7. Confirm whether any caller depends on undocumented behavior.

Do not pass credentials, record contents, or other sensitive values into the replacement job. Pass
the Check or Check Set **Qualified API Name**, record IDs within the documented limit, and approved
text used to connect the job with its results.

## Quick start: Replace the caller

1. Implement the [custom Queueable example](queueable.md#example-save-results-from-a-custom-queueable),
   including its Finalizer.
2. Set the execution origin to `rhc.RecordHealthCheckExecutionOrigin.QUEUEABLE`.
3. Keep each job within the 200-record request limit and the planned-evaluation limit.
4. Update one caller to enqueue the Queueable class.
5. Save or send the returned `AsyncApexJob` ID when staff must find the job later.
6. Verify both returned health outcomes and the Finalizer's uncaught-failure path.
7. Migrate the remaining callers.
8. Remove the future method only after a code search confirms that nothing references it.

## What to test in a sandbox

Run the replacement as the user who starts the real job, or with equivalent access. Test:

- a `PASS` result;
- a business `FAIL` result;
- an `UNABLE_TO_EVALUATE` result;
- an invalid request that fails before or during execution;
- an uncaught Queueable exception observed by the Finalizer;
- duplicate submission behavior, if callers can retry.

Open **Setup → Apex Jobs** and confirm that the Queueable job appears. If the design retains health
results, confirm that staff can use the saved Record Health Check `runId` to find the matching Apex
job ID.

Queueable Apex does not grant extra access. Assign the actual running user the packaged **Record
Health Check User** Permission Set, or **Record Health Check Admin** if that user also configures
Checks or views diagnostics. Then confirm the user's access to the business objects, records, and
fields used by the selected Checks.

## If migration needs more than one release

Keep the future method only as temporary code that starts the Queueable implementation. Do not
add evaluation logic, queries, or result-saving code to it. Prevent new callers from using it and track
each remaining caller until the method can be removed.

## Troubleshooting

| Symptom | Check first |
| --- | --- |
| No job ID is returned | Submission validation, authorization, and whether the caller caught an exception |
| The job appears in Apex Jobs but no result is retained | The Queueable result destination and event-publication mode |
| The job fails only for the real user | That user's Custom Permission, Apex class, object, record, field, and metadata access |
| Duplicate jobs are submitted | The caller's retry handling and the Queueable duplicate-signature behavior |
| The old method cannot be removed | Search Apex, Flow, integrations, and tests for remaining references |

## Related

- [Queueable Apex](queueable.md)
- [Batch Apex](batch.md)
- [Apex API](apex-api.md)
- [Platform Event subscriptions](../platform-events/README.md)
