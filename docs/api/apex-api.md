# Apex API

> [!NOTE]
> Use this page to build requests for the synchronous Record Health Check Apex entry
> point. A request selects one qualified Check Set or Rule and supplies the complete record scope.

## Basic Apex pattern

Evaluate a Check Set for several records:

```apex
RecordHealthCheckRequest request = RecordHealthCheckRequest.forCheckSet(
  'Account_Data_Quality',
  accountIds
).withRunId('nightly-' + Date.today());

RecordHealthCheckResponse response = RecordHealthCheck.evaluate(request);
Set<Id> recordsNeedingAttention = new Set<Id>();
for (RecordHealthCheckResultItem item : response.results) {
  if (item.evaluation.status == RecordHealthCheckStatus.FAIL) {
    recordsNeedingAttention.add(item.evaluation.recordId);
  }
}
```

The example collects business failures for the caller to handle. In production, pass that set to
the approved notification, persistence, or orchestration service for your use case. Do not write
record details to a debug log.

Evaluate one Rule by its Custom Metadata `QualifiedApiName`:

```apex
RecordHealthCheckResponse response = RecordHealthCheck.evaluate(
  RecordHealthCheckRequest.forRule('Customer_Contact_Required', accountId)
);
```

In a namespaced install, use the identity Salesforce returns, such as
`rhc__Customer_Contact_Required`. Subscriber-owned records remain unprefixed.

## Request contract

`RecordHealthCheckRequest` requires exactly one selection and a non-null list of record
IDs. The factories are:

| Factory | Selection |
| --- | --- |
| `forCheckSet(qualifiedApiName, recordId)` | One Check Set and one record |
| `forCheckSet(qualifiedApiName, recordIds)` | One Check Set and a record scope |
| `forRule(qualifiedApiName, recordId)` | One Rule and one record |
| `forRule(qualifiedApiName, recordIds)` | One Rule and a record scope |

Options are applied with fluent methods:

| Method | Default | Purpose |
| --- | --- | --- |
| `withResultMode(...)` | `EVALUATION` | Choose machine results only or evaluation plus display data |
| `withEventPublication(...)` | `NONE` | Choose `NONE`, `ACTIONABLE`, or `ALL` publication |
| `withRunId(...)` | Generated when blank | Supply caller correlation |
| `withExecutionOrigin(...)` | `APEX_API` | Attribute published events to Apex, Batch, Queueable, Scheduled, Future, Agent, or a Record Health Check adapter |

Programmatic evaluation publishes nothing unless the caller explicitly selects a
publication mode. Metadata fields still decide whether a user-requested event is enabled.
Execution origin is caller-supplied attribution, not a security assertion. Record Health Check Flow
and LWC adapters set their own origin automatically.

## Response contract

Every call returns `RecordHealthCheckResponse` with:

| Field | Meaning |
| --- | --- |
| `runId` | Correlation ID for this evaluation |
| `recordIds` | Normalized record scope |
| `ruleQualifiedApiNames` | Ordered Rules selected for the run |
| `results` | Ordered `RecordHealthCheckResultItem` entries |
| `summary` | Counts and aggregate run status |

Each item always has `evaluation`. It has `display` only when the request uses
`EVALUATION_WITH_DISPLAY`. Machine values use `RecordHealthCheckValue`, so callers do not
receive untyped `Object` values.

## Failure contract

| Category | Public Apex | Controller | Flow | Async adapters |
| --- | --- | --- | --- | --- |
| Authorization | Throws `AuthorizationException` | Stable `NOT_AUTHORIZED` Aura error | Aligned `AUTHORIZATION` output | Submission/execution fails before work |
| Invalid request or configuration | Throws a stable contract exception | Sanitized configuration or load error | Aligned validation/evaluation output | Job fails and is platform-visible |
| Record visibility or field access | Contained per-record or per-Rule result | Same contained result | Same contained result | Same contained result within the scope |
| Evaluator defect | Contained stable error where attributable | Sanitized stable error item | Aligned evaluation output | Scope follows the adapter failure channel |
| Plugin side effect | Fatal; mutation is rolled back | Fatal | Fatal | Job/scope fails |

The public facade deliberately does not promise that every failure becomes result data. Fatal
plugin-side-effect violations and request/framework failures assigned to the caller remain thrown.
Queueable Finalizers flush `QUEUEABLE_FAILED`; Batch scopes flush `BATCH_SCOPE_FAILED` and rethrow.

## Publish lifecycle events

Requests do not publish lifecycle events unless you enable publication. Add
`withEventPublication(RecordHealthCheckEventPublication.ACTIONABLE)` to publish actionable results,
or use `ALL` when an integration needs every result.

## Limits and access

- Every public execution entry point requires the `Record_Health_Check_Run` custom permission.
- One request accepts at most `RecordHealthCheckConstants.MAX_RECORDS_PER_SCOPE` records.
- Query, compare-query, and conforming Apex Rules run once for the complete scope.
- Formula Rules use one platform Formula evaluation per expression and record, so the
  request planner may require a smaller scope.
- Record and query access runs in user mode. Subscriber Apex plugins must enforce
  their own user-mode access and should extend `RecordHealthCheckRuleContractTest`.
- `MaxQueryRows__c` is a per-scope budget.

## Flow adapters

The Rule and Check Set Flow actions are thin adapters over the same request API. Their
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
- [Apex plugin contract](../reference/evaluation/apex-rule-contract.md)
- [Apex class catalog](../reference/apex/README.md)
- [Flow API](flow.md)
- [Upgrade guide](../installation/04-upgrading.md)
