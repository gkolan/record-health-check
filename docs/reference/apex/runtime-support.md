# Supporting Apex classes (L2-L5)

> [!NOTE]
> Use this page to identify supporting package classes referenced in an error, debug log, or code
> review. To call Record Health Check from custom Apex, use a documented `global` class instead of
> these internal classes.

Start with [Entry points](entry-points.md) when choosing an API to call.

## Batch, Queueable, Scheduled, and Flow support

### `RecordHealthCheckAsyncSupport`

Prepares record IDs for Batch, Queueable, and Scheduled Apex. It removes null and repeated IDs,
keeps the remaining IDs in a predictable order, and confirms that the request came from Batch,
Queueable, or Scheduled Apex.

### `RecordHealthCheckBatch`

**Type:** `global with sharing`; implements `Database.Batchable<Id>`

Runs a Check or Check Set when Apex already has the record IDs. `run(...)` starts the Batch with the
default 100 records per transaction or a caller-selected number from 1 through 200. See
[Batch Apex](../../api/batch.md) for examples and guidance on choosing that number.

### `RecordHealthCheckQueueable`

**Type:** `global with sharing`; implements `Queueable` and `Finalizer`

`enqueue(...)` makes a copy of the request and starts Queueable Apex. The Queueable runs the health
check. Its Finalizer records whether the Queueable completed even when the Queueable transaction
fails. See [Queueable Apex](../../api/queueable.md).

### `RecordHealthCheckScheduled`

**Type:** `global with sharing`; implements `Schedulable`

`scheduleDaily(...)` creates a schedule that runs every day. Salesforce calls `execute` at the
scheduled time to start the configured health check. See [Scheduled Apex](../../api/scheduled.md).

### `RecordHealthCheckFlowSupport`

Keeps the JSON returned to Flow within the package limit, builds one Flow response per input record,
reads `NONE`, `ACTIONABLE`, or `ALL`, and calculates the overall Status. It reports invalid input
separately from a response that is too large.

### `RecordHealthCheckFlowGroupExecutor`

Combines Flow inputs that use the same Check or Check Set Qualified API Name and the same Platform
Event choice. It checks the maximum number of groups before work begins, then returns each result to
the matching Flow input.

### `RecordHealthCheckEventPublication`

**Type:** `global enum`

Controls Platform Events for Apex, Flow, Batch, Queueable, and Scheduled runs: `NONE` publishes no
results, `ACTIONABLE` publishes FAIL, UNABLE_TO_EVALUATE, and ERROR, and `ALL` publishes every
result. Programmatic requests default to `NONE`. These choices do not use the Lightning card's
publication settings.

### `RecordHealthCheckExecutionOrigin`

**Type:** `global enum`

Identifies how the health check started: `APEX_API`, `FLOW`, `USER_INITIATED`, `RUN_ON_LOAD`,
`BATCH`, `QUEUEABLE`, `SCHEDULED`, `FUTURE`, or `AGENT`.

## Evaluation helpers

### `RecordHealthCheckApexPluginResolver`

Finds the class named by an Apex Check, including a namespace prefix when present, and confirms that
the class implements `RecordHealthCheckPlugin`. A missing class, invalid JSON parameters, or wrong
class type raises `PluginConfigurationException`.

### `RecordHealthCheckApexResultFinalizer`

Converts a custom Apex Check outcome into the package's internal result. It formats Found and
Expected values and applies the final Status, Reason Code, and display text.

### `RecordHealthCheckCompareQuerySupport`

Supports Compare two queries Checks. It resolves one value from each query or cleans up two lists
before applying list operators. **Lists Match Exactly** also checks repeated values, so `[A, A]` does
not equal `[A]`.

### `RecordHealthCheckFormulaDisplay`

Adds formatted values and messages after a Formula Check has already determined its Status.

### `RecordHealthCheckFormulaSyntax`

Recognizes supported Formula tokens and formula keywords while validating and preparing a Formula
Check.

### `RecordHealthCheckSoqlEvaluation`

Runs the prepared SOQL for a Query Check, determines Found and Expected values, compares them, and
builds the internal result.

### `RecordHealthCheckSoqlTokenBinder`

Replaces supported `record.*` tokens in SOQL, escapes text safely, rejects disallowed SOQL keywords,
and builds `INCLUDES` values for multi-select picklists.

### `RecordHealthCheckSoqlBindValueResolver`

Reads fields through Salesforce relationships and converts token fallback text to the selected
field's data type, including Date, Datetime, Time, and multi-select picklist values.

## Configuration and validation helpers

### `RHCMetadataDependencyValidator`

Checks `PrerequisiteCheck__c` relationships and returns `ValidationIssue` entries when a dependency
is missing, invalid, or cannot run in the selected order.

### `RecordHealthCheckConfigFindingMapper`

Converts the first Check configuration problem into an `UNABLE_TO_EVALUATE` result.
`buildUnableResult` supplies the same safe result format for each problem.

### `RecordHealthCheckDefinitionLoader`

Loads the Lightning card definition, validates its Check Set and active Checks, applies the Check
limit, reports inactive Checks, and selects the executable subset.

### `RecordHealthCheckMetadataIssueMapper`

Converts Check configuration findings into the `ValidationIssue` entries returned by the package's
metadata audit.

### `RecordHealthCheckMetadataSetValidator`

Validates Check Set-level card behavior and publication settings separately from per-Check
evaluation configuration.

### `RecordHealthCheckSettingsProvider`

Reads package settings used internally for Platform Event publication. Custom Apex in an org that
installs the package should not call this class.

## Display, diagnostics, and identity helpers

### `RecordHealthCheckComparisonDisplay`

Builds readable operator labels and Found and Expected text for single-value and list comparisons.

### `RecordHealthCheckDiagnosticTrace`

Adds troubleshooting details when the running user is allowed to view diagnostics. It does not
change the health result.

### `RecordHealthCheckDisplayCurrencyRenderer`

Formats a currency value using the requested Value Format, decimal places, and ISO currency code.

### `RecordHealthCheckDisplayCurrencyResolver`

Determines whether to use the currency from a query row, related field path, checked record, or the
org's corporate currency. It also detects whether multiple currencies are enabled.

### `RecordHealthCheckDisplayFieldResolver`

Reads a query field's Salesforce type and determines its display format, including multi-select
picklist values.

### `RecordHealthCheckDisplayNumberRenderer`

Converts supported numeric values to a consistent type and formats them with either automatic or
fixed decimal places.

### `RecordHealthCheckDisplayTextRenderer`

Formats Boolean, Date, Datetime, Time, and multi-select picklist values for messages and the
Lightning card.

### `RecordHealthCheckQualifiedIdentity`

Validates a Check or Check Set Qualified API Name. It rejects a label and rejects a name that is
ambiguous because its required namespace prefix is missing.

## Merge-token helpers

### `RecordHealthCheckTemplateParser`

Separates ordinary text from merge tokens, validates where each token is allowed and which settings
it uses, reports invalid tokens, and lists the Salesforce record fields referenced by the template.

### `RecordHealthCheckTemplateValueResolver`

Replaces tokens with values from Salesforce fields, Check and Check Set Custom Metadata, completed
results, and run details.

## Request, response, and custom Apex Check types

### `RecordHealthCheckContractTestData`

**Type:** `global abstract`

Provides test data for `RecordHealthCheckContractTest`, including the optional `PermissionFixture`
used to verify behavior for a user with limited access. A custom Apex Check test can extend this
class; production automation should not call it.

### `RecordHealthCheckInternalResult`

Stores a result while package classes evaluate a Check, add diagnostics, and create display text.
The package converts it to the `global` response types before returning it to custom Apex.

### `RecordHealthCheckOptions`

**Type:** `global`; each method returns a new object instead of changing the existing one

Stores the requested response content, Platform Event choice, optional run ID, and how the request
started. `defaults()` returns evaluation results, publishes no events, and uses `APEX_API`. Each
`with...` method returns a new options object instead of changing the existing one.

### `RecordHealthCheckOutcome`

**Type:** `global`

Result returned by a custom Apex Check. Factory methods create PASS, FAIL, UNABLE_TO_EVALUATE,
SKIPPED, or ERROR. `withFound`, `withComparison`, and `withExpected` add values while preserving
their Salesforce data types.

### `RecordHealthCheckPluginDispatch`

Calls a custom Apex Check and verifies that it returns exactly the requested record IDs and supported
Statuses. It also rejects record changes, callouts, queued work, future calls, and email. An invalid
result and a prohibited action use different errors.

### `RecordHealthCheckRequest`

**Type:** `global`; each method returns a new request instead of changing the existing one

Creates requests for one or more records with `forCheckSet(...)` or `forCheck(...)`. Its `recordIds`
getter returns a copy, and every `with...` method returns a new request instead of changing the
existing one.

### `RecordHealthCheckResultMode`

**Type:** `global enum`

Controls how much information the response contains: `EVALUATION`, `EVALUATION_WITH_DISPLAY`, or
`SUMMARY`. It does not change which Checks run or how their Status is calculated.

### `RecordHealthCheckRunSummary`

**Type:** `global`

Counts PASS, FAIL, SKIPPED, UNABLE_TO_EVALUATE, and ERROR results. `total()` adds those counts. The
class does not convert them to a separate pass-or-fail decision for the entire request.

### `RecordHealthCheckSelection`

**Type:** `global`; cannot be changed after creation

Identifies exactly one Check Set or one Check by its Qualified API Name. It rejects a blank or
invalid name.

### `RecordHealthCheckStatus`

**Type:** `global abstract` constants holder

Defines `PASS`, `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, and `ERROR`. `isActionable` returns `true`
only for FAIL, UNABLE_TO_EVALUATE, and ERROR.

### `RecordHealthCheckValue`

**Type:** `global`

Value returned by a custom Apex Check. Factory methods preserve String, Boolean, Number, Date,
Datetime, ID, Count, and List types.

---

## Related

- [Apex class reference](README.md)
- [Apex API](../../api/apex-api.md)
- [Apex Check contract](../evaluation/apex-check-contract.md)
