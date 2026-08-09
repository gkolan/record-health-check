# Reference: Apex runtime support classes (L2-L5)

> [!NOTE]
> This page covers supporting classes behind the documented entry points. A top-level `public`
> class is package-internal across a managed-package namespace; only types marked `global` are
> subscriber-callable.

Start with [Entry points](entry-points.md) when choosing an API to call.

## Asynchronous execution and Flow support

### `RecordHealthCheckAsyncSupport`

Normalizes asynchronous ID scopes and constructs the shared request state. It removes null and
duplicate IDs while retaining deterministic order and validates the supported async origin.

### `RecordHealthCheckBatch`

**Type:** `global with sharing`; implements `Database.Batchable<Id>`

Runs a Check or Check Set over a detached ID scope. `run(...)` submits the batch; `start`, `execute`,
and `finish` implement its lifecycle. See [Batch API](../../api/batch.md).

### `RecordHealthCheckQueueable`

**Type:** `global with sharing`; implements `Queueable` and `Finalizer`

`enqueue(...)` submits a detached request. The Queueable evaluates it and the Finalizer records
completion independently of the worker transaction. See [Queueable API](../../api/queueable.md).

### `RecordHealthCheckScheduled`

**Type:** `global with sharing`; implements `Schedulable`

`scheduleDaily(...)` creates a daily schedule and `execute` dispatches the configured evaluation.
See [Scheduled API](../../api/scheduled.md).

### `RecordHealthCheckFlowSupport`

Owns Flow response-size budgeting, per-record result construction, publication-policy parsing, and
overall-summary status. Its exceptions distinguish invalid input from an oversized response.

### `RecordHealthCheckFlowGroupExecutor`

Groups compatible Flow requests by qualified identity and publication policy, enforces the group
ceiling before work begins, and maps evaluation responses back to invocable requests.

### `RecordHealthCheckEventPublication`

**Type:** `global enum`

Programmatic event policy: `NONE` (default), `ACTIONABLE` (Fail, Unable, and Error), or `ALL`. It is
explicit caller intent and does not inherit record-page publication settings.

### `RecordHealthCheckExecutionOrigin`

**Type:** `global enum`

Caller attribution: `APEX_API`, `FLOW`, `USER_INITIATED`, `RUN_ON_LOAD`, `BATCH`, `QUEUEABLE`,
`SCHEDULED`, `FUTURE`, or `AGENT`.

## Evaluation helpers

### `RecordHealthCheckApexPluginResolver`

Resolves an Apex Check class with namespace-aware lookup and validates interface conformance.
Invalid or unavailable configuration raises `PluginConfigurationException`.

### `RecordHealthCheckApexResultFinalizer`

Converts a typed plugin outcome into the Framework's internal result, renders typed values, and
applies the final status, reason, and display contract.

### `RecordHealthCheckCompareQuerySupport`

Implements scalar and list mechanics for Compare Two Queries, including single-value resolution,
list normalization, and duplicate-sensitive frequency equality.

### `RecordHealthCheckFormulaDisplay`

Applies display fields after Formula evaluation, keeping presentation out of verdict logic.

### `RecordHealthCheckFormulaSyntax`

Owns Formula token and syntax-word recognition used during validation and preparation.

### `RecordHealthCheckSoqlEvaluation`

Coordinates prepared-query execution, found/expected resolution, comparison, and internal result
construction for Query checks.

### `RecordHealthCheckSoqlTokenBinder`

Binds supported record tokens into SOQL, escapes literals, rejects disallowed keywords, and builds
multi-select-picklist `INCLUDES` expressions.

### `RecordHealthCheckSoqlBindValueResolver`

Resolves relationship field paths and coerces fallback text to the terminal Salesforce field type,
including date/time and multi-select-picklist handling.

## Configuration and validation helpers

### `RHCMetadataDependencyValidator`

Validates prerequisite relationships among Check metadata records and returns deploy-time
`ValidationIssue` values for invalid dependencies.

### `RecordHealthCheckConfigFindingMapper`

Maps the first shared validator finding into the runtime `UNABLE_TO_EVALUATE` result.
`buildUnableResult` supplies the consistent safe failure shape.

### `RecordHealthCheckDefinitionLoader`

Loads the Lightning card definition, validates its Check Set and active Checks, applies the Check
limit, reports inactive Checks, and selects the executable subset.

### `RecordHealthCheckMetadataIssueMapper`

Converts shared validation findings into deploy-time `ValidationIssue` rows.

### `RecordHealthCheckMetadataSetValidator`

Validates Check Set-level card behavior and publication settings separately from per-Check
evaluation configuration.

### `RecordHealthCheckSettingsProvider`

Package-internal organization-settings reader. It intentionally has no subscriber-callable API.

## Display, diagnostics, and identity helpers

### `RecordHealthCheckComparisonDisplay`

Builds operator labels and human-readable expected/found text for scalar and list comparisons.

### `RecordHealthCheckDiagnosticTrace`

Populates authorized diagnostic detail without changing the evaluation verdict.

### `RecordHealthCheckDisplayCurrencyRenderer`

Renders currency using the requested format, scale, and resolved ISO currency.

### `RecordHealthCheckDisplayCurrencyResolver`

Resolves row, field-path, record, or corporate currency and detects multi-currency organizations.

### `RecordHealthCheckDisplayFieldResolver`

Describes a query field and resolves its display format and multi-select representation.

### `RecordHealthCheckDisplayNumberRenderer`

Normalizes numeric input and renders general or fixed-scale numbers.

### `RecordHealthCheckDisplayTextRenderer`

Renders Boolean, Date, Datetime, Time, and multi-select values into stable display text.

### `RecordHealthCheckQualifiedIdentity`

Normalizes and validates a Check or Check Set `QualifiedApiName`, rejecting labels and ambiguous
bare metadata names.

## Merge-token helpers

### `RecordHealthCheckTemplateParser`

Parses literal/token segments, validates supported surfaces and attributes, reports token issues,
and extracts referenced record paths.

### `RecordHealthCheckTemplateValueResolver`

Resolves tokens from record fields, Check/Check Set metadata, result data, and run context.

## Request, response, and plugin contract types

### `RecordHealthCheckContractTestData`

**Type:** `global abstract`

Provides subscriber-visible fixtures for managed-package contract verification, including
`PermissionFixture`. It is test support, not a runtime entry point.

### `RecordHealthCheckInternalResult`

Package-internal mutable result used while evaluators, diagnostics, and display services assemble
an outcome. Public response DTOs are built from it.

### `RecordHealthCheckOptions`

**Type:** `global`; immutable builder

Carries result mode, event publication, optional normalized run ID, and execution origin.
`defaults()` requests evaluation results, publishes nothing, and uses `APEX_API`; each `with...`
method returns a copy.

### `RecordHealthCheckOutcome`

**Type:** `global`

Typed Apex-plugin outcome. Factories create Pass, Fail, Unable, Skipped, or Error; `withFound`,
`withComparison`, and `withExpected` attach typed values.

### `RecordHealthCheckPluginDispatch`

Invokes an Apex Check plugin while enforcing exact record-key coverage, supported statuses, and no
subscriber side effects. Contract and side-effect failures are distinct.

### `RecordHealthCheckRequest`

**Type:** `global`; immutable builder

Creates single- or multi-record requests with `forCheckSet(...)` or `forCheck(...)`. Record IDs are
returned defensively, and every `with...` method returns a new request.

### `RecordHealthCheckResultMode`

**Type:** `global enum`

Response content: `EVALUATION`, `EVALUATION_WITH_DISPLAY`, or `SUMMARY`. It never changes the
response type or evaluation semantics.

### `RecordHealthCheckRunSummary`

**Type:** `global`

Counts Pass, Fail, Skipped, Unable, and system-error results. `total()` sums them; no aggregate
business verdict is invented.

### `RecordHealthCheckSelection`

**Type:** `global`; immutable value object

Represents exactly one qualified Check Set or one qualified Check and rejects blank or malformed
identities.

### `RecordHealthCheckStatus`

**Type:** `global abstract` constants holder

Defines `PASS`, `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, and `ERROR`. `isActionable` is true only for
Fail, Unable, and Error.

### `RecordHealthCheckValue`

**Type:** `global`

Typed plugin value with factories for String, Boolean, Number, Date, Datetime, Id, Count, and List.

---

## Related

- [Apex class reference](README.md)
- [Apex API](../../api/apex-api.md)
- [Apex Check contract](../evaluation/apex-check-contract.md)
