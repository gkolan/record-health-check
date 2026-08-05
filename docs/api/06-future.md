# Move from Future to Queueable Apex

> [!NOTE]
> Use this page when an existing integration starts Record Health Check from a future method. You
> will identify the caller, move the work to Queueable Apex, and verify the replacement before
> removing the future entry point.

Do not create a new future method for Record Health Check. Queueable Apex returns a job ID, accepts
typed constructor state, supports a Finalizer, and gives an administrator a clearer job to monitor
in **Setup → Apex Jobs**.

## Before you change the caller

Record the future method's callers, input limits, running user, expected follow-on work, and failure
notification. Confirm whether callers depend on the future method only to cross a transaction
boundary or also depend on behavior that is not documented.

Do not pass credentials, record contents, or other sensitive values into the replacement job. Pass
the qualified Check Set or Rule name, the bounded record IDs, and a correlation value the caller is
allowed to retain.

## Quick start: Replace the future method

1. Implement the [Queueable Apex pattern](03-queueable.md), including its Finalizer.
2. Set the execution origin to `RecordHealthCheckExecutionOrigin.QUEUEABLE`.
3. Keep each job within the public record and planned-evaluation limits.
4. Change one caller to enqueue the Queueable class and retain the returned `AsyncApexJob` ID.
5. Verify the returned health outcomes and the Finalizer's uncaught-failure path.
6. Move the remaining callers, then remove the future method after no caller references it.

## Verify the replacement

In a sandbox, test a passing result, a business failure, an unable-to-evaluate result, and an
invalid request. Confirm that **Setup → Apex Jobs** shows the Queueable job and that approved
monitoring can correlate its job ID with the Record Health Check `runId`.

Run the test as the user who starts the real job. Queueable Apex does not grant additional object,
record, field, Apex class, or Custom Metadata access.

## If the change cannot finish in one release

Keep the existing future method as a thin hand-off and prevent new callers from
using it. Do not add evaluation logic, queries, or persistence to that method. Track the remaining
callers explicitly so the temporary boundary does not become permanent by accident.

## Related

- [Queueable Apex](03-queueable.md)
- [Batch Apex](04-batch.md)
- [Apex API](01-apex-api.md)
- [Platform Event subscriptions](../platform-events/README.md)
