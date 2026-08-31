# Salesforce debug logs

Use this guide only after the card diagnosis and reviewed browser-console support report do not
identify the failed phase and corrective action. Debug logs are developer evidence for uncatchable
governor limits, Salesforce internal failures, asynchronous transactions, and novel framework
defects. They are not the normal first troubleshooting step.

## Before you start

Collect these values before enabling a trace:

- the exact time and timezone of the failed run;
- the affected execution user;
- the Check Set and Check Qualified API Names;
- the Run ID and Diagnostic ID, when available; and
- the entry point: Lightning, Flow, Apex, Queueable, Batch, Scheduled Apex, or Platform Event.

Start with [browser-console diagnostics](./browser-console.md) when the problem occurs on the
Lightning record page.

When the card, Flow, and asynchronous results disagree for the same saved record, use the
[execution-context war room](./execution-context-war-room.md) to identify the correct execution
user and job before enabling trace flags.

## Capture the correct log

1. In **Setup**, open **Debug Logs**.
2. Add a trace flag for the user who performs the failing transaction.
3. For Queueable, Batch, or Scheduled Apex, confirm which user executes the background transaction
   and trace that user as well.
4. Reproduce the problem once and record the exact time and Run ID.
5. Open the matching log, then disable the temporary trace flag.

Avoid leaving verbose tracing enabled while unrelated users continue working. Log availability is
time-limited, and an uncatchable Salesforce limit can prevent Record Health Check from writing its
final diagnostic line.

## Search the log

Search in this order:

1. The Run ID, Check Set Qualified API Name, or Check Qualified API Name.
2. `[RHC]`.
3. `EXCEPTION_THROWN` and `FATAL_ERROR`.
4. `LIMIT_USAGE_FOR_NS`.
5. The first exception that occurs before later wrapper exceptions.

Identify the phase in which the first relevant failure occurred:

| Phase | Typical evidence |
| --- | --- |
| Configuration loading | Missing, inactive, invalid, or inaccessible Check metadata |
| Record preparation | Record visibility, field access, object mismatch, or request-size problems |
| Formula, Query, or Apex evaluation | Evaluator exception, query failure, plugin contract problem, or limit usage |
| Display rendering | Merge syntax, formatting, currency, or completed-text problems |
| Event publication | Event access, publication failure, or transaction rollback |

## Asynchronous Apex evidence

Background work can cross several transactions. Capture the job identity as well as the log.

| Entry point | Evidence to retain |
| --- | --- |
| Queueable | `AsyncApexJob` ID, submitting user, worker status, Finalizer output, and Run ID |
| Batch | Batch job ID, failing scope, redacted first record IDs, running user, and Run ID |
| Scheduled Apex | Scheduled job identity, scheduled user, launched Batch job ID, and Run ID |

Use the [Asynchronous Apex guides](../developer-guides/async-apex/README.md) for each execution
contract. A completed Apex job does not mean every health Check passed.

## Restricted Error Log event

`Record_Health_Check_Log__e` provides structured `ERROR` details for restricted monitoring. It is
disabled by default and requires both **Publish Error Log Event** on the Check Set and the Error Log
Publisher permission.

Use this event for ongoing monitoring. Use a debug log for a bounded investigation when structured
diagnostics are incomplete. See the [Error Log event field reference](../reference/platform-event-metadata/error-log.md).

## Redact before sharing

Remove customer data, record and user IDs, org IDs, session IDs, access tokens, authentication
URLs, queries containing sensitive values, and unrelated transactions. Retain the Run ID,
Diagnostic ID, relevant exception type, first relevant stack location, and the minimum context
needed to reproduce the defect.

## Related

- [Browser-console diagnostics](./browser-console.md)
- [Result statuses and card labels](../reference/results/statuses-and-labels.md)
- [Reason Codes](../reference/results/reason-codes.md)
- [Security and data access](../architecture/security-and-data-access.md)
