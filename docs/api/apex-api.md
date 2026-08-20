# Apex API

> [!NOTE]
> Use this page to run Record Health Check from Apex and read the returned results before the
> current transaction continues.

The `rhc.` before an Apex type tells Salesforce that the installed Record Health Check package owns
that type. The `rhc__` in a Check Set name has a different purpose: it appears when the package
delivered that Custom Metadata record. Always copy the Check or Check Set **Qualified API Name**
from Setup.

## When to use this API

Use this Apex API when code needs health results before the current transaction can
continue. For example, the Apex process can stop, choose a branch, or collect records that need
follow-up.

### Example: Stop account escalation when required data is missing

An Apex service prepares an Account escalation and already has the Account ID. Before continuing,
it runs **Account Data Quality**. A `FAIL` adds the Account to a review list; `PASS` allows the
escalation to continue. Use this API because the Apex service needs the result immediately.

Do not use this API for an unlimited number of records. Use
[Queueable Apex](queueable.md) when the work can happen later and fits in one request. Use
[Batch Apex](batch.md) when the records need several transactions.

## Before you start

1. Activate and test the Check or Check Set.
2. Assign the running user the packaged **Record Health Check User** Permission Set. Use
   **Record Health Check Admin** only when that user also configures Checks or views diagnostics.
   Both include **Custom Permission label:** Record Health Check Run, **Custom Permission API
   name:** `rhc__Record_Health_Check_Run`, and access to the package Apex classes.
3. Confirm that the running user can access the target records, fields, and Framework Custom
   Metadata required by the selected Checks.
4. In Setup, go to **Custom Metadata Types → Record Health Check Set → Manage Records** and copy the
   Check Set **Qualified API Name**. One included with the installed package normally begins with
   `rhc__`; one created by an administrator normally does not.
5. Keep the request at or below 200 records and review the planned-evaluation limits for the Check
   Set.
6. Decide which statuses the code must handle and whether Platform Events are required.

## Step 1: Build and run a Check Set request

Evaluate a Check Set for several records:

```apex
// Copy the exact Check Set Qualified API Name from Setup.
// A Check Set included with the installed package might be rhc__Account_Data_Quality.
String checkSetApiName = 'My_Account_Checks';

// accountIds is a List<Id> collected by the Apex process that needs the result.
rhc.RecordHealthCheckRequest request = rhc.RecordHealthCheckRequest.forCheckSet(
  checkSetApiName,
  accountIds
).withRunId('nightly-' + System.now().formatGMT('yyyyMMdd-HHmmss-SSS'));

rhc.RecordHealthCheckResponse response = rhc.RecordHealthCheck.evaluate(request);
Set<Id> recordsNeedingAttention = new Set<Id>();
for (rhc.RecordHealthCheckResultItem item : response.results) {
  if (item.evaluation.status == rhc.RecordHealthCheckStatus.FAIL) {
    recordsNeedingAttention.add(item.evaluation.recordId);
  }
}
```

The example collects business failures for the Apex process to handle. In production, pass that
set to the approved notification or result-saving code for the process. Do not write
record details to a debug log.

The code does four things:

1. Selects the Check Set named by `checkSetApiName`.
2. Supplies the Account IDs to check.
3. Adds a Run ID chosen by this Apex process so administrators can connect related jobs and results.
4. Treats `FAIL` as a returned business result instead of an Apex exception.

`withRunId` is optional. Use a value that is safe to retain and meaningful to the calling process.
Record Health Check generates a Run ID when the supplied value is blank.

## Step 2: Run one Check when a Check Set is unnecessary

Evaluate one Check by its Custom Metadata `QualifiedApiName`:

```apex
// Copy the exact Check Qualified API Name from Setup.
// A Check included with the installed package might start with rhc__.
String checkApiName = 'My_Customer_Contact_Required';

rhc.RecordHealthCheckResponse response = rhc.RecordHealthCheck.evaluate(
  rhc.RecordHealthCheckRequest.forCheck(
    checkApiName,
    accountId
  )
);
```

A Check created by an administrator in your org normally does not start with `rhc__`. Copy the
exact value from **Setup → Custom Metadata Types → Record Health Check → Manage Records**.

## Step 3: Handle every relevant status

The first example collects only `FAIL` records to keep the code short. Production code should make
an intentional decision for every status it can receive:

| Status | Meaning | Typical Apex action |
| --- | --- | --- |
| `PASS` | The record met the condition. | Continue. |
| `FAIL` | The record did not meet the business condition. | Start approved follow-up or show guidance. |
| `SKIPPED` | The Check did not apply. | Continue or report separately. |
| `UNABLE_TO_EVALUATE` | Access, data, or configuration prevented a reliable answer. | Inspect `reasonCode` and correct the cause. |
| `ERROR` | The Framework contained an evaluator or system problem as result data. | Send non-sensitive context to monitoring. |

Exceptions remain a separate channel. Authorization, invalid requests, Framework failures, and
fatal plugin side effects can prevent a normal response and should follow the caller's fault or
monitoring path.

## Request inputs

`rhc.RecordHealthCheckRequest` requires exactly one selection and a non-null list of record
IDs. The factories are:

| Factory | Selection |
| --- | --- |
| `forCheckSet(qualifiedApiName, recordId)` | One Check Set and one record |
| `forCheckSet(qualifiedApiName, recordIds)` | One Check Set and several records |
| `forCheck(qualifiedApiName, recordId)` | One Check and one record |
| `forCheck(qualifiedApiName, recordIds)` | One Check and several records |

Options are applied with chainable methods:

| Method | Default | Purpose |
| --- | --- | --- |
| `withResultMode(...)` | `EVALUATION` | Choose `EVALUATION`, `EVALUATION_WITH_DISPLAY`, or `SUMMARY` |
| `withEventPublication(...)` | `NONE` | Choose `NONE`, `ACTIONABLE`, or `ALL` publication |
| `withRunId(...)` | Generated when blank | Supply text that connects this call with related jobs or results |
| `withExecutionOrigin(...)` | `APEX_API` | Record whether Apex, Batch, Queueable, Scheduled, Future, Agent, or a Record Health Check class started the work |

An Apex request publishes nothing unless the code explicitly selects a publication mode. Metadata
fields still decide whether a requested event is enabled.
Execution origin reports where the request started. It does not grant or prove access. Record
Health Check Flow actions and Lightning components set their own origin automatically.

> [!TIP]
> Start with the default `EVALUATION` result mode and `NONE` publication mode. Add display data or
> Platform Events only when another automation has a defined use for them.

Result modes control response content:

| Mode | `results` content | Use it when… |
| --- | --- | --- |
| `EVALUATION` | Every selected result with machine-readable evaluation data | Code needs every outcome without display text |
| `EVALUATION_WITH_DISPLAY` | Every selected result with evaluation and authorized display data | Apex must display Record Health Check messages, values, or actions |
| `SUMMARY` | Counts plus `FAIL`, `UNABLE_TO_EVALUATE`, and `ERROR` results | Apex needs totals and only records requiring attention |

## Response contract

This section explains the values returned by Record Health Check.

Every call returns `rhc.RecordHealthCheckResponse` with:

| Field | Meaning |
| --- | --- |
| `runId` | Text used to connect this evaluation with related jobs or results |
| `recordIds` | Record IDs after nulls and repeated IDs are removed |
| `checkQualifiedApiNames` | Ordered Checks selected for the run |
| `results` | Ordered `rhc.RecordHealthCheckResultItem` entries |
| `summary` | Final counts for each status; it does not contain one combined `status` field |

Each item always has `evaluation`. It has `display` only when the request uses
`EVALUATION_WITH_DISPLAY`. Machine values use `rhc.RecordHealthCheckValue`, so callers do not
receive untyped `Object` values.

`evaluation` contains `recordId`, `checkQualifiedApiName`, `status`, `severity`, `reasonCode`,
`found`, `comparisonOperator`, and `expected`. The `summary` fields are `passed`, `failed`,
`skipped`, `unable`, and `systemError`; `summary.total()` returns their sum. Derive a business
decision from those explicit counts rather than expecting `summary.status`.

`found` and `expected` identify their value type as `STRING`, `BOOLEAN`, `NUMBER`, `DATE`,
`DATETIME`, `ID`, `COUNT`, or `LIST`. Use the matching typed value field instead of parsing display
text.

### Example: Use summary counts

```apex
rhc.RecordHealthCheckResponse response =
  rhc.RecordHealthCheck.evaluate(request);

if (response.summary.systemError > 0 || response.summary.unable > 0) {
  // Send approved, non-sensitive run information to operational monitoring.
}
```

The summary does not have one combined `status`. Read `passed`, `failed`, `skipped`, `unable`, and
`systemError` separately so the caller does not treat a business failure as a system failure.

### Apex types used by the API

These are the `global` types used by the request and response. Most code creates only a request and
reads a response. Record Health Check creates the result types inside the response.

| Type | Caller responsibility |
| --- | --- |
| `RecordHealthCheck` | Call `evaluate(request)` |
| `RecordHealthCheckRequest` | Select a Check or Check Set and the records to check |
| `RecordHealthCheckSelection` | Read the selected Check or Check Set Qualified API Name |
| `RecordHealthCheckOptions` | Read-only result, publication, Run ID, and origin choices copied by `with...` methods |
| `RecordHealthCheckResultMode` | Select `EVALUATION`, `EVALUATION_WITH_DISPLAY`, or `SUMMARY` |
| `RecordHealthCheckEventPublication` | Select `NONE`, `ACTIONABLE`, or `ALL` Platform Events |
| `RecordHealthCheckExecutionOrigin` | Attribute monitoring output to the actual caller context |
| `RecordHealthCheckResponse` | Read the Run ID, record IDs, ordered results, and summary |
| `RecordHealthCheckResultItem` | Read one evaluation and its optional display data |
| `RecordHealthCheckEvaluationResult` | Read machine status, reason, severity, and typed values |
| `RecordHealthCheckResultDisplay` | Render authorized messages, formatted values, and action information |
| `RecordHealthCheckAdminDetail` | Read authorized configuration/resolution diagnostics when present |
| `RecordHealthCheckRunSummary` | Read explicit status counts and `total()` |
| `RecordHealthCheckStatus` | Compare results with shared status constants and `isActionable(...)` |
| `RecordHealthCheckValue` | Read typed machine values without parsing display text |

The Apex Check extension types (`RecordHealthCheckPlugin`, `RecordHealthCheckScope`, and
`RecordHealthCheckOutcome`) are documented separately in the
[Apex Check contract](../reference/evaluation/apex-check-contract.md). Background-job entry
points are documented in [Queueable](queueable.md), [Batch](batch.md), and
[Scheduled](scheduled.md).

## Understand returned results and exceptions

| Situation | What Apex receives | What to do |
| --- | --- | --- |
| A record does not meet a Check | A `FAIL` result | Handle it as a business result. Do not treat it as an exception. |
| Record access, field access, data, or configuration prevents an answer | An `UNABLE_TO_EVALUATE` result when Record Health Check can identify the affected record or Check | Read `reasonCode` and correct the access, data, or configuration problem. |
| A Check encounters a contained evaluator problem | An `ERROR` result | Send approved, non-sensitive details to monitoring. |
| The user lacks the Record Health Check Run Custom Permission | `AuthorizationException` | Assign the required Permission Set or stop the process. |
| The request is invalid or Record Health Check cannot create a response | An Apex exception | Catch only exceptions the Apex process can recover from. Let unknown exceptions reach normal monitoring. |
| An Apex Check attempts a forbidden write, callout, email, event, or background job | An exception and rolled-back transaction | Correct the Apex Check. Do not convert this failure to `FAIL`. |

## Publish Platform Events

Requests do not publish Platform Events unless you enable publication. Add
`withEventPublication(rhc.RecordHealthCheckEventPublication.ACTIONABLE)` to publish actionable results,
or use `ALL` when an integration needs every result.

This option controls Platform Events only. It does not filter the normal Apex response. With the
default `EVALUATION` result mode, `response.results` still contains `PASS` and every other returned
status.

```apex
// Copy the exact Check Set Qualified API Name from Setup.
String checkSetApiName = 'My_Account_Checks';

rhc.RecordHealthCheckRequest request =
  // Use ACTIONABLE to publish only FAIL, UNABLE_TO_EVALUATE, and ERROR.
  // Use ALL to publish every result, including PASS and SKIPPED.
  // Use NONE when this Apex code reads response.results directly.
  rhc.RecordHealthCheckRequest.forCheckSet(
    checkSetApiName,
    accountIds
  ).withEventPublication(
    rhc.RecordHealthCheckEventPublication.ACTIONABLE
  );
```

Publishing is not the same as saving. A Flow, Apex trigger, or external integration must receive
and process the Platform Events if the organization needs permanent history or follow-on action.

## Limits and access

- Every public execution entry point requires **Custom Permission label:** Record Health Check Run
  (**API name:** `rhc__Record_Health_Check_Run`).
- One request accepts at most 200 records. The package keeps its internal implementation value
  private; code in an org where the package is installed must use 200 as the supported limit.
- Query, compare-query, and conforming Apex Checks run once for all records in the request.
- Formula Checks use one platform Formula evaluation per expression and record, so the
  request may need fewer records.
- Record and query access runs in user mode. Apex Checks created in the org must enforce their own
  user-mode access and should extend `rhc.RecordHealthCheckContractTest`.
- `MaxQueryRows__c` limits query rows for one request.

## Test the caller

Test with representative records and the effective access used in production. Include:

- one `PASS` and one business `FAIL`;
- `SKIPPED` when the Check can be inapplicable;
- an `UNABLE_TO_EVALUATE` access or configuration case;
- contained `ERROR` handling;
- an invalid request or unauthorized caller that throws; and
- Platform Event behavior when publication is enabled.

Assert machine-readable status, reason code, and typed values. Do not make business logic depend on
formatted display text.

## Troubleshooting

| Symptom | Check first |
| --- | --- |
| `AuthorizationException` is thrown | The running user's **Record Health Check Run** Custom Permission and Apex class access |
| No Check is selected | The qualified API name, including the package prefix returned by Salesforce |
| A record returns `UNABLE_TO_EVALUATE` | `reasonCode`, record visibility, field access, and Check configuration |
| The response has no display text | Use `EVALUATION_WITH_DISPLAY` and confirm the user is authorized for that display data |
| No Platform Event appears | Request publication mode, Check metadata event setting, and the Flow, Apex trigger, or integration that should receive it |
| A request over 200 records fails | Split the records or use Batch Apex |

## Related

- [API examples](README.md)
- [Apex plugin contract](../reference/evaluation/apex-check-contract.md)
- [Apex class catalog](../reference/apex/README.md)
- [Flow API](flow.md)
- [Upgrade guide](../installation/upgrading.md)
