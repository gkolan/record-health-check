# Apex API

> [!NOTE]
> On this page, build a request for the synchronous Record Health Check Apex entry point, select
> one qualified Check Set or Check, and supply a bounded record scope.

The examples assume the supported subscriber installation and therefore use the package's `rhc.`
namespace. Contributor source inside the package refers to the same classes without that prefix.

## Basic Apex pattern

Evaluate a Check Set for several records:

```apex
rhc.RecordHealthCheckRequest request = rhc.RecordHealthCheckRequest.forCheckSet(
  'Account_Data_Quality',
  accountIds
).withRunId('nightly-' + Date.today());

rhc.RecordHealthCheckResponse response = rhc.RecordHealthCheck.evaluate(request);
Set<Id> recordsNeedingAttention = new Set<Id>();
for (rhc.RecordHealthCheckResultItem item : response.results) {
  if (item.evaluation.status == rhc.RecordHealthCheckStatus.FAIL) {
    recordsNeedingAttention.add(item.evaluation.recordId);
  }
}
```

The example collects business failures for the caller to handle. In production, pass that set to
the approved notification, persistence, or coordinating service for your use case. Do not write
record details to a debug log.

Evaluate one Check by its Custom Metadata `QualifiedApiName`:

```apex
rhc.RecordHealthCheckResponse response = rhc.RecordHealthCheck.evaluate(
  rhc.RecordHealthCheckRequest.forCheck(
    'Customer_Contact_Required',
    accountId
  )
);
```

In a namespaced install, use the identity Salesforce returns, such as
`rhc__Customer_Contact_Required`. Subscriber-owned records remain unprefixed.

## Request contract

`rhc.RecordHealthCheckRequest` requires exactly one selection and a non-null list of record
IDs. The factories are:

| Factory | Selection |
| --- | --- |
| `forCheckSet(qualifiedApiName, recordId)` | One Check Set and one record |
| `forCheckSet(qualifiedApiName, recordIds)` | One Check Set and a record scope |
| `forCheck(qualifiedApiName, recordId)` | One Check and one record |
| `forCheck(qualifiedApiName, recordIds)` | One Check and a record scope |

Options are applied with chainable methods:

| Method | Default | Purpose |
| --- | --- | --- |
| `withResultMode(...)` | `EVALUATION` | Choose `EVALUATION`, `EVALUATION_WITH_DISPLAY`, or `SUMMARY` |
| `withEventPublication(...)` | `NONE` | Choose `NONE`, `ACTIONABLE`, or `ALL` publication |
| `withRunId(...)` | Generated when blank | Supply caller correlation |
| `withExecutionOrigin(...)` | `APEX_API` | Attribute published events to Apex, Batch, Queueable, Scheduled, Future, Agent, or a Record Health Check adapter |

Programmatic evaluation publishes nothing unless the caller explicitly selects a
publication mode. Metadata fields still decide whether a user-requested event is enabled.
Execution origin is caller-supplied attribution, not a security assertion. Record Health Check Flow
and LWC adapters set their own origin automatically.

Result modes control response content:

| Mode | `results` content | Use it when… |
| --- | --- | --- |
| `EVALUATION` | Every selected result with machine-readable evaluation data | Code needs every outcome without display text |
| `EVALUATION_WITH_DISPLAY` | Every selected result with evaluation and authorized display data | A caller must render Framework messages, values, or actions |
| `SUMMARY` | Counts plus actionable `FAIL`, `UNABLE_TO_EVALUATE`, and `ERROR` results | A bulk caller needs totals and only records requiring attention |

## Response contract

Every call returns `rhc.RecordHealthCheckResponse` with:

| Field | Meaning |
| --- | --- |
| `runId` | Correlation ID for this evaluation |
| `recordIds` | Normalized record scope |
| `checkQualifiedApiNames` | Ordered Checks selected for the run |
| `results` | Ordered `rhc.RecordHealthCheckResultItem` entries |
| `summary` | Terminal-result counts; it does not contain an aggregate `status` field |

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

### Public Apex type map

These are the `global` types that make up the synchronous request and response contract. Most
callers construct only a request and inspect a response; the Framework constructs the nested result
types.

| Type | Caller responsibility |
| --- | --- |
| `RecordHealthCheck` | Call `evaluate(request)` |
| `RecordHealthCheckRequest` | Select a Check/Check Set and detached record scope |
| `RecordHealthCheckSelection` | Immutable qualified Check or Check Set identity created by the request factories |
| `RecordHealthCheckOptions` | Immutable result, publication, run-ID, and origin options copied by `with...` methods |
| `RecordHealthCheckResultMode` | Select `EVALUATION`, `EVALUATION_WITH_DISPLAY`, or `SUMMARY` |
| `RecordHealthCheckEventPublication` | Select `NONE`, `ACTIONABLE`, or `ALL` lifecycle events |
| `RecordHealthCheckExecutionOrigin` | Attribute monitoring output to the actual caller context |
| `RecordHealthCheckResponse` | Read run identity, normalized scope, ordered results, and summary |
| `RecordHealthCheckResultItem` | Read one evaluation and its optional display data |
| `RecordHealthCheckEvaluationResult` | Read machine status, reason, severity, and typed values |
| `RecordHealthCheckResultDisplay` | Render authorized messages, formatted values, and action information |
| `RecordHealthCheckAdminDetail` | Read authorized configuration/resolution diagnostics when present |
| `RecordHealthCheckRunSummary` | Read explicit status counts and `total()` |
| `RecordHealthCheckStatus` | Compare results with shared status constants and `isActionable(...)` |
| `RecordHealthCheckValue` | Read typed machine values without parsing display text |

The Apex Check extension types (`RecordHealthCheckPlugin`, `RecordHealthCheckScope`, and
`RecordHealthCheckOutcome`) are documented separately in the
[Apex Check contract](../reference/evaluation/apex-check-contract.md). Asynchronous global entry
points are documented in [Queueable](queueable.md), [Batch](batch.md), and
[Scheduled](scheduled.md).

## Failure contract

| Category | Public Apex | Controller | Flow | Async adapters |
| --- | --- | --- | --- | --- |
| Authorization | Throws `AuthorizationException` | Stable `NOT_AUTHORIZED` Aura error | Aligned `AUTHORIZATION` output | Submission/execution fails before work |
| Invalid request or configuration | Throws a stable contract exception | Safe configuration or load error | Aligned validation/evaluation output | Job fails and is platform-visible |
| Record visibility or field access | Contained per-record or per-Check result | Same contained result | Same contained result | Same contained result within the scope |
| Evaluator defect | Contained stable error where attributable | Safe stable error item | Aligned evaluation output | Scope follows the adapter failure channel |
| Forbidden plugin write (DML, callout, email, event, or async work) | Fatal; mutation is rolled back | Fatal | Fatal | Job/scope fails |

The public facade deliberately does not promise that every failure becomes result data. Fatal
plugin write violations (`PLUGIN_SIDE_EFFECT_DETECTED`) and request/framework failures assigned to
the caller remain thrown. Catch only exceptions your application can recover from; allow unknown
Framework exceptions to reach the caller's fault and monitoring path instead of converting them to
`FAIL`.
Queueable Finalizers flush `QUEUEABLE_FAILED`; Batch scopes flush `BATCH_SCOPE_FAILED` and rethrow.

## Publish lifecycle events

Requests do not publish lifecycle events unless you enable publication. Add
`withEventPublication(rhc.RecordHealthCheckEventPublication.ACTIONABLE)` to publish actionable results,
or use `ALL` when an integration needs every result.

## Limits and access

- Every public execution entry point requires the **Record Health Check Run** (`rhc__Record_Health_Check_Run`) Custom Permission.
- One request accepts at most 200 records. The package keeps its implementation constant internal;
  subscribers should treat the documented number as the public limit.
- Query, compare-query, and conforming Apex Checks run once for the complete scope.
- Formula Checks use one platform Formula evaluation per expression and record, so the
  request planner may require a smaller scope.
- Record and query access runs in user mode. Subscriber Apex plugins must enforce
  their own user-mode access and should extend `rhc.RecordHealthCheckContractTest`.
- `MaxQueryRows__c` is a per-scope budget.

## Flow adapters

The Check and Check Set Flow actions are thin adapters over the same request API. Their
publication input defaults to `NONE`; set it explicitly when the Flow is intended to
publish lifecycle events.

One Flow call accepts at most 200 input rows, at most 10 distinct selection/publication groups,
and at most 2,000,000 aggregate serialized-result characters. A group-limit rejection happens
before evaluation and returns aligned `LIMIT` outputs; a response-limit rejection affects the row
that would cross the ceiling without corrupting prior aligned outputs. Bulk automation should
reuse the same Check Set and publication mode wherever possible instead of creating per-row
selection fan-out.

## Related

- [API examples](README.md)
- [Apex plugin contract](../reference/evaluation/apex-check-contract.md)
- [Apex class catalog](../reference/apex/README.md)
- [Flow API](flow.md)
- [Upgrade guide](../installation/upgrading.md)
