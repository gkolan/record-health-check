# Reference: Apex classes

> [!NOTE]
> On this page, look up what each Record Health Check Apex class owns, when to use it, and how it
> fits the runtime layers. Use this as a class-by-class reference while reading source or extending
> the Framework.
>
> **Reference**
>
> - For the full architecture story (layers, runtime path, security, limits), use
> [Reference: Architecture](reference-architecture.md).
> - For calling health checks from your code, use [Reference: Apex API](../api/apex-api.md).
> - For writing a custom evaluator plugin, use [Reference: Apex](reference-apex.md).

This guide covers every **production** class under `force-app/main/default/classes/` (excluding
`*Test` classes and coverage helpers). Shipped and integration-test example plugins are listed at
the end.

Unless noted otherwise, Framework service classes are `public with sharing`. Result and definition
data holders, the plugin interface, merge-token helpers, and a few other types are plain `public`
classes (no sharing keyword) because they hold data or interfaces rather than query Salesforce
records. Exceptions and interfaces are called out in their entries when that distinction matters.

## How to use this guide

| You want to… | Start here |
| --- | --- |
| Scan classes by layer | [Class index by level](#class-index-by-level) |
| Understand who calls whom | [Layers at a glance](#layers-at-a-glance) |
| Read a detailed description | The layer sections below |
| Call the Framework from Apex or Flow | Entry points, then [Apex API](../api/apex-api.md) / [Flow actions](../integration/flow-actions.md) |
| Implement `RecordHealthCheckRule` | Plugin interface classes, then [Apex reference](reference-apex.md) |

Every class entry below follows the same order, so you can find any given fact in the same place
every time: **Role** (what it is, read in under three seconds) → **Type** (declared sharing mode or
data holder / interface / exception) → what it does → **Key members** (the constants/methods/fields
worth knowing) → **Notable behavior** (gotchas, rationale, or a concrete example grounded in the
code) → **See also**. A class skips a slot only when there's genuinely nothing to put there - the
order never changes.

## Layers at a glance

Higher levels call lower levels. Lower levels never call back up. This matches
[Reference: Architecture § 5. Layers](reference-architecture.md#5-layers); the sections below use
the same L5→L1 numbering so you can move between the two pages without re-deriving the mapping.

| Level | Layer | Classes (summary) |
| --- | --- | --- |
| L5 | Entry points | `RecordHealthCheck`, Flow actions, `RecordHealthCheckController`, plus lifecycle publication and run context |
| L4 | Scope orchestration | `RecordHealthCheckScopePipeline`, `RecordHealthCheckFieldPlanner` |
| L3 | Evaluators | Formula, Query, Compare two queries, Apex evaluators + query support |
| L2 | Shared services | Config, validation, SOQL templates, comparison, values, merge tokens, describe cache, logger, access, constants |
| L1 | Results and definitions | Result data holders, definition responses, plugin interface and context |

Configuration, shared evaluation services, and merge tokens each get their own H2 section below for
readability, but all three live at **L2** in the architecture layer diagram.

## Class index by level

### L5 - Entry points

| Level | Class | One-line purpose |
| --- | --- | --- |
| L5 | [`RecordHealthCheck`](#recordhealthcheck) | Public Apex `evaluate(request)` API |
| L5 | [`RecordHealthCheckController`](#recordhealthcheckcontroller) | Aura-enabled API for the Lightning card |
| L5 | [`RecordHealthCheckRunRuleFlowAction`](#recordhealthcheckrunruleflowaction) | Packaged Flow action "Run Record Health Check Rule" |
| L5 | [`RecordHealthCheckRunSetFlowAction`](#recordhealthcheckrunsetflowaction) | Packaged Flow action "Run Record Health Check Set" |
| L5 | `RecordHealthCheckQueueable` | Packaged asynchronous adapter for one bounded Check Set scope |
| L5 | `RecordHealthCheckBatch` | Packaged adapter that splits an explicit ID population into safe transactions |
| L5 | `RecordHealthCheckScheduled` | Lightweight scheduler that launches `RecordHealthCheckBatch` |
| L5 | `RecordHealthCheckAsyncSupport` | Shared validation and request construction for asynchronous adapters |
| L5 | `RecordHealthCheckFlowSupport` | Shared Flow input normalization, result alignment, and summary status logic |
| L5 | `RecordHealthCheckFlowGroupExecutor` | Shared normalized grouping and engine execution for both Flow actions |
| L5 | [`RecordHealthCheckLifecyclePublisher`](#recordhealthchecklifecyclepublisher) | Optional Set Run and Rule Result platform events |
| L5 | [`RecordHealthCheckRunContext`](#recordhealthcheckruncontext) | Run id, source, and timing for one evaluation |
| L5 | [`RecordHealthCheckSetPicklist`](#recordhealthchecksetpicklist) | App Builder dynamic picklist for Check Set Developer Name |

### L4 - Engine

| Level | Class | One-line purpose |
| --- | --- | --- |
| L4 | `RecordHealthCheckScopePipeline` | Resolves a selection and evaluates the complete ordered record scope |
| L4 | `RecordHealthCheckEvaluatorRegistry` | Maps Evaluation Type values to a common scope evaluator contract |
| L4 | [`RecordHealthCheckFieldPlanner`](#recordhealthcheckfieldplanner) | Safe record-field planning for scope evaluation |
| L4 | `RecordHealthCheckBulkQuerySupport` | Executes supported query templates once for a complete scope |
| L4 | `RecordHealthCheckBulkQueryRewriter` | Rewrites validated query templates for scope-wide execution |
| L4 | `RecordHealthCheckScopePlanner` | Resolves selections, applicability, prerequisites, and request budgets |
| L4 | `RecordHealthCheckScopeResultSupport` | Converts internal outcomes, diagnostics, display text, and safe URLs |

### L3 - Evaluators

| Level | Class | One-line purpose |
| --- | --- | --- |
| L3 | [`RecordHealthCheckFormulaEvaluator`](#recordhealthcheckformulaevaluator) | Formula Evaluation Type and shared formula resolution |
| L3 | [`RecordHealthCheckSoqlEvaluator`](#recordhealthchecksoqlevaluator) | Single-query Evaluation Type |
| L3 | [`RecordHealthCheckCompareQueriesEvaluator`](#recordhealthcheckcomparequeriesevaluator) | Compare-two-queries Evaluation Type |
| L3 | [`RecordHealthCheckApexEvaluator`](#recordhealthcheckapexevaluator) | Loads and runs a `RecordHealthCheckRule` plugin |
| L3 | [`RecordHealthCheckQueryEvaluatorSupport`](#recordhealthcheckqueryevaluatorsupport) | Shared query execution and empty-result handling |
| L3 | `RecordHealthCheckApexResultFinalizer` | Finalizes plugin outcomes without mixing result shaping into dispatch |
| L3 | `RecordHealthCheckApexPluginResolver` | Resolves validated plugin instances and bounded parameter objects |
| L3 | `RecordHealthCheckCompareQuerySupport` | Owns compare-query row reduction and side-specific handling |
| L3 | `RecordHealthCheckFormulaDisplay` | Shapes formula evaluator Found and Expected display values |
| L3 | `RecordHealthCheckFormulaSyntax` | Parses and validates formula-specific syntax |
| L3 | `RecordHealthCheckSoqlEvaluation` | Owns the SOQL evaluator's query-to-result decision path |
| L3 | `RecordHealthCheckSoqlTokenBinder` | Performs safe lexical substitution in validated SOQL templates |
| L3 | `RecordHealthCheckSoqlBindValueResolver` | Resolves described field paths and coerces typed token fallbacks |

### L2 - Shared services

| Level | Class | One-line purpose |
| --- | --- | --- |
| L2 | [`RecordHealthCheckConfigService`](#recordhealthcheckconfigservice) | Load Check Sets/Rules; definitions; runtime validation adapter |
| L2 | [`RecordHealthCheckRuleValidator`](#recordhealthcheckrulevalidator) | Shared per-Evaluation-Type Rule field validation |
| L2 | [`RecordHealthCheckMetadataValidator`](#recordhealthcheckmetadatavalidator) | Deploy-time / CI audit of Custom Metadata |
| L2 | [`RecordHealthCheckConfigValidator`](#recordhealthcheckconfigvalidator) | Shared validation helpers (object names, plugins, JSON, tokens) |
| L2 | [`RecordHealthCheckConstants`](#recordhealthcheckconstants) | Allowed values and numeric limits (single source of truth) |
| L2 | [`RecordHealthCheckReasonCodes`](#recordhealthcheckreasoncodes) | Selected stable reason-code helpers |
| L2 | [`RecordHealthCheckSetAvailability`](#recordhealthchecksetavailability) | Whether an object has active/inactive Check Sets |
| L2 | [`RecordHealthCheckComparisonEngine`](#recordhealthcheckcomparisonengine) | Operators, equality, empty/null behavior |
| L2 | [`RecordHealthCheckDisplayFormat`](#recordhealthcheckdisplayformat) | Renders Found and Expected values for the card chips |
| L2 | [`RecordHealthCheckSoqlTemplate`](#recordhealthchecksoqltemplate) | Safe SOQL preparation (`WITH USER_MODE`, row limit, keyword rejection) |
| L2 | [`RecordHealthCheckValueResolver`](#recordhealthcheckvalueresolver) | Extract, convert, and compare query values |
| L2 | [`RecordHealthCheckDescribeCache`](#recordhealthcheckdescribecache) | Schema describe cache for the current transaction |
| L2 | [`RecordHealthCheckEvaluatorException`](#recordhealthcheckevaluatorexception) | Evaluator failure carrying a reason code |
| L2 | [`RecordHealthCheckAccess`](#recordhealthcheckaccess) | Diagnostics Custom Permission check |
| L2 | [`RecordHealthCheckLogger`](#recordhealthchecklogger) | `[RHC]` debug lines and ERROR log platform events |
| L2 | `RecordHealthCheckDiagnosticTrace` | Builds authorized Rule configuration and resolution snapshots for browser diagnostics |
| L2 | `RecordHealthCheckSettingsProvider` | Resolves lifecycle and diagnostic publication settings |
| L2 | [`RecordHealthCheckTemplateService`](#recordhealthchecktemplateservice) | Parse, validate, and resolve namespaced merge tokens and their optional fallback text |
| L2 | `RecordHealthCheckTemplateValueResolver` | Resolves namespace-specific values from the runtime merge context |
| L2 | [`RecordHealthCheckTokenRegistry`](#recordhealthchecktokenregistry) | Allowed token namespaces and properties |
| L2 | [`RecordHealthCheckToken`](#recordhealthchecktoken) | One parsed merge token |
| L2 | [`RecordHealthCheckTokenIssue`](#recordhealthchecktokenissue) | One token validation failure |
| L2 | [`RecordHealthCheckMergeContext`](#recordhealthcheckmergecontext) | Values available while resolving merge tokens |
| L2 | `RecordHealthCheckComparisonDisplay` | Converts comparison operands into stable display content |
| L2 | `RecordHealthCheckConfigFindingMapper` | Maps validation findings to runtime configuration results |
| L2 | `RecordHealthCheckDefinitionLoader` | Loads and validates Lightning definition metadata |
| L2 | `RecordHealthCheckDisplayCurrencyRenderer` | Renders currency symbols and minor units |
| L2 | `RecordHealthCheckDisplayCurrencyResolver` | Resolves row and corporate currency context with transaction caching |
| L2 | `RecordHealthCheckDisplayFieldResolver` | Extracts display values from described field paths |
| L2 | `RecordHealthCheckDisplayNumberRenderer` | Renders numeric and percentage display formats |
| L2 | `RecordHealthCheckDisplayTextRenderer` | Renders textual and blank display values |
| L2 | `RHCMetadataDependencyValidator` | Validates prerequisite references and dependency cycles |
| L2 | `RecordHealthCheckMetadataIssueMapper` | Maps validator findings to deploy-time issues |
| L2 | `RecordHealthCheckMetadataSetValidator` | Validates Check Set identity and set-level fields |
| L2 | `RecordHealthCheckTemplateParser` | Parses namespaced merge tokens independently of resolution |

### L1 - Results and definitions

| Level | Class | One-line purpose |
| --- | --- | --- |
| L1 | `RecordHealthCheckScope` | The records a custom Rule is asked about, plus its parameters. Read-only |
| L1 | `RecordHealthCheckOutcome` | What a custom Rule returns for one record: a verdict and its values |
| L1 | `RecordHealthCheckValue` | A typed Found or Expected value with one stored format per data type |
| L1 | `RecordHealthCheckEvaluationResult` | Machine-readable status, identity, reason, and typed values |
| L1 | `RecordHealthCheckResultDisplay` | Optional human-facing rendering derived from evaluation data |
| L1 | `RecordHealthCheckResultItem` | Evaluation data plus optional display content |
| Internal | `RecordHealthCheckInternalResult` | Package-only evaluator handoff used before the public result split |
| L1 | `RecordHealthCheckSelection` | Qualified Rule or Check Set selection with XOR construction |
| L1 | `RecordHealthCheckQualifiedIdentity` | Shared trim and length validation for qualified metadata identities |
| L1 | `RecordHealthCheckOptions` | Result, publication, and run correlation options |
| L1 | `RecordHealthCheckExecutionOrigin` | Typed caller attribution for lifecycle events |
| L1 | `RecordHealthCheckRequest` | Qualified selection and detached record scope |
| L1 | `RecordHealthCheckResponse` | Shared Rule and Check Set response envelope |
| L1 | `RecordHealthCheckRunSummary` | Terminal status counts for one response |
| L1 | `RecordHealthCheckRuleContractTest` | Extensible plugin verification harness for bulk growth and prohibited effects |
| L1 | `RecordHealthCheckRuleContractTestData` | Plugin-author supplied scopes and controlled permission fixture |
| L1 | `RecordHealthCheckStatus` | The status vocabulary: PASS, FAIL, SKIPPED, UNABLE_TO_EVALUATE, ERROR |
| L1 | `RecordHealthCheckResultMode` | Selects how much data a result carries |
| L1 | `RecordHealthCheckEventPublication` | Whether a programmatic run publishes lifecycle Platform Events |
| L1 | `RecordHealthCheckPluginDispatch` | Runs a custom Rule and holds it to its contract, including the side-effect fence |

| L1 | [`RecordHealthCheckDefinition`](#recordhealthcheckdefinition--recordhealthcheckdefinitionresponse) | One Rule row in the Lightning definition response |
| L1 | [`RecordHealthCheckDefinitionResponse`](#recordhealthcheckdefinition--recordhealthcheckdefinitionresponse) | Check Set display settings + ordered Rule definitions |
| L1 | [`RecordHealthCheckAdminDetail`](#recordhealthcheckadmindetail) | Structured diagnostics detail on a Rule result |
| L1 | [`RecordHealthCheckValueSource`](#recordhealthcheckvaluesource) | Structured Found/Expected diagnostic detail |
| L1 | [`RecordHealthCheckRule`](#recordhealthcheckrule-interface) | Interface every Apex evaluator plugin implements |

### Example plugins

| Level | Class | One-line purpose |
| --- | --- | --- |
| Example | [`AccountHasRecentActivityCheck`](#accounthasrecentactivitycheck) | Shipped Apex Rule: recent Task/Event activity on an Account |

---

## Entry points (L5)

### `RecordHealthCheck`

**Role:** Single public Apex request API.
**Type:** Service class · `global with sharing`

Runs one qualified Rule or Check Set selection over a detached record scope. The request carries its
result mode, event-publication choice, and optional correlation id explicitly.

**Key members:**

| Member | Purpose |
| --- | --- |
| `evaluate(RecordHealthCheckRequest)` | Evaluate one qualified selection and return the common response envelope |

**Notable behavior:**
- **When to use it:** any Apex process that needs typed results for one Rule or every active Rule in
  one Check Set.
- **Gotcha:** selection identities are Custom Metadata `QualifiedApiName` values, not labels or bare
  names chosen with `LIMIT 1`.

**See also:** [Reference: Apex API](../api/apex-api.md)

### `RecordHealthCheckController`

**Role:** Aura-enabled API for the Lightning card.
**Type:** Service class · `public with sharing`

Exposes four card operations and nothing else. It does not contain evaluation logic; it cleans up
inputs, supplies Lightning lifecycle sources, and delegates to `RecordHealthCheckConfigService` and
`RecordHealthCheckScopePipeline`.

**Key members:**

| Member | Purpose |
| --- | --- |
| `getCheckSetAvailabilityForRecord(recordId)` | Active/inactive Check Sets for the record's object (setup banner) |
| `getCheckDefinitions(checkSetQualifiedApiName, recordId, runId)` | Display settings and ordered Rule definitions for the card |
| `evaluateCheck(checkSetQualifiedApiName, ruleQualifiedApiName, recordId, runId, source)` | One Rule evaluation (one Apex transaction per Rule from the card) |
| `completeRun(checkSetQualifiedApiName, runId, source, recordId, resultsJson)` | After a user-initiated run: re-evaluates server-side and publishes the Set completed event |

**Notable behavior:**
- **Source behavior:** the browser may request only Lightning-allowed source values. Unknown values
 fall back to non-publishable `RUN_ON_LOAD` behavior (as documented in architecture).
- **Gotcha:** `getCheckDefinitions` distinguishes a caught `ConfigException` (logged at `DEBUG`,
 reason code passed through as-is) from any other exception (logged at `ERROR`, always rethrown as
 `LOAD_FAILED`) so a real governor-limit or NPE failure is never mistaken by the card for a genuine
 missing-Check-Set condition. `completeRun` also ignores any Rule results the browser tried to pass
 in - it always re-evaluates server-side before publishing, since a lifecycle event must reflect
 server-side counts.

**See also:** [Lightning component](../integration/lightning-component.md)

### `RecordHealthCheckRunRuleFlowAction`

**Role:** Packaged Flow action "Run Record Health Check Rule".
**Type:** Invocable Flow action · `public with sharing`

Invocable wrapper around the scope pipeline for one qualified Rule per request. It returns the common
evaluation fields and JSON response for advanced consumers.

**Notable behavior:**
- **Gotcha:** the action validates the complete request list before evaluation and uses the shared
  scope ceiling from `RecordHealthCheckConstants`.

### `RecordHealthCheckRunSetFlowAction`

**Role:** Packaged Flow action "Run Record Health Check Set".
**Type:** Invocable Flow action · `public with sharing`

Invocable wrapper around the scope pipeline for one qualified Check Set per request. It returns the
shared summary counts and JSON response.

**Notable behavior:**
- **Gotcha:** the action validates request shape and scope size before dispatch, so malformed bulk
  input fails before partial work.

**See also:** [Flow actions](../integration/flow-actions.md)

### `RecordHealthCheckLifecyclePublisher`

**Role:** Optional Set Run and Rule Result platform events.
**Type:** Service class · `public with sharing`

Publishes only for deliberate, publishable sources (`APEX_API`, `FLOW`, `USER_INITIATED`,
`SCHEDULED`, `BATCH`). Honors Check Set `PublishUserRunEvent__c` and Rule `PublishUserResultEvent__c`.
Publishes in batches of 100, never fails the health-check run when publish fails, and blocks
publication in subscriber context to prevent loops.

**Key members:**

| Member | Purpose |
| --- | --- |
| `CONTRACT_VERSION`, `FRAMEWORK_VERSION`, `SOURCE_*`, `PUBLISH_CHUNK_SIZE` | Event contract, product version, publishable-source values, and the 100-row publish batch size |
| `publishCompletedSet(...)` | Publish the Set Run event after a deliberate run |
| `publishRuleResults(...)` | Publish per-Rule Result events for Rules that enable publication |
| `isRunPublicationEnabled(...)` | Whether the Check Set's `PublishUserRunEvent__c` allows publication |
| `canPublish(...)` | Whether the source is publishable and the call isn't inside subscriber context |

**Notable behavior:**
- **Gotcha:** `newEventId` builds a unique key from the run id, a suffix (`SET` or the Rule
 Developer Name), and 8 hex characters from a freshly generated AES key - truncating the run id to
 50 characters and the suffix to 20 so a caller-supplied run id can never exceed the platform
 event's `EventId__c` field. `canPublish` checks both `PUBLISHABLE_SOURCES` and a
 `subscriberContextOverride` flag so a subscriber reacting to one of these events cannot trigger
 republication and loop.

**See also:** [Lifecycle events](../integration/lifecycle-events.md)

### `RecordHealthCheckRunContext`

**Role:** Run id, source, and timing for one evaluation.
**Type:** Data holder · `public` (no sharing keyword)

Holds `runId`, `source`, `startedAt`, `completedAt`, and `durationMs`. Created at the start of an
evaluation path; `complete()` stamps end time. Exposed to merge tokens (`rhcRun.*`) and used when
building lifecycle events.

**Notable behavior:**
- **Gotcha:** `complete()` is safe to call more than once - it only stamps `completedAt`/`durationMs`
 when `completedAt` is still `null`, so calling it again along a call chain cannot overwrite the
 original duration with a later, longer one.

### `RecordHealthCheckSetPicklist`

**Role:** App Builder dynamic picklist for Check Set Developer Name.
**Type:** Service class · `public with sharing`, extends `VisualEditor.DynamicPickList`

Lists active Check Set Developer Names for the page's object
(`DesignTimePageContext.entityName`). Both label and stored value are the Developer Name. When
exactly one active Check Set matches, it becomes the default so a first drop onto the page needs no
extra click.

**Notable behavior:**
- **Why it exists:** DeveloperName, not MasterLabel, is used for both the picklist label and value
 because MasterLabels are not guaranteed unique across Check Sets while the DeveloperName is. This
 also avoids configuration mistakes caused by free-text entry. When
 `entityName` is blank (for example, a template being edited outside a record page), `getValues()`
 falls back to listing every active Check Set rather than none.

---

## Scope orchestration (L4)

### `RecordHealthCheckFieldPlanner`

**Role:** Internal field-planning support used by the scope pipeline.
**Type:** Service class · `public with sharing`

Builds the approved set of readable record fields needed by a Rule before
`RecordHealthCheckScopePipeline` performs its scope-wide user-mode load. Public callers use
`RecordHealthCheck.evaluate(request)` and do not call the planner directly.

**Key members:**

| Member | Purpose |
| --- | --- |
| `collectRecordFields(...)` | Plan the record fields needed by a Rule before the scope-wide user-mode load |

**Notable behavior:**
- **Gotcha:** candidate fields are resolved through describe metadata before entering dynamic SOQL;
  malformed, unavailable, and unreadable paths are ignored.

**See also:** [Architecture § How one Rule is evaluated](reference-architecture.md#6-how-one-rule-is-evaluated)

---

## Evaluators (L3)

Each evaluator implements the same shape: build an empty result, run Evaluation Type logic, catch
failures into `UNABLE_TO_EVALUATE` / `ERROR` with a reason code, and set `durationMs` /
`evaluatorType`.

### `RecordHealthCheckFormulaEvaluator`

**Role:** Formula Evaluation Type (`FORMULA`).
**Type:** Evaluator · `public with sharing`

Evaluates `PassConditionFormula__c` against the loaded record via Salesforce `FormulaEval`. Also
used by other paths for applicability formulas, expected-record formulas, and list-membership
primary values (`FindInListFormula__c`).

**Key members:**

| Member | Purpose |
| --- | --- |
| `evaluate(rule, recordId, record)` | Main entry point for a Formula Rule |
| `resolveFormulaSingleValue(...)` | Shared formula resolution used by other paths |
| Governor safety | Tracks FormulaEval calls for the whole transaction (platform limit 100) with a safety margin; caches resolved return types so bulk callers do not retry every record |

**Notable behavior:**
- **Gotcha:** a formula that resolves to `null` (e.g. a null relationship traversal) is treated as
 `UNABLE_TO_EVALUATE`/`INVALID_FORMULA`, not `FAIL` - the class comments explain that letting null
 count as false would produce false failures. `evaluateFormulaAnyType` tries the admin-declared
 `FormulaResultType__c` or a cached previously-resolved return type first, and only falls back to
 trying all eight `formulaeval.FormulaReturnType` values (in a fixed cheapest-first order:
 `BOOLEAN`, `DECIMAL`, `DATE`, `DATETIME`, `STRING`, `DOUBLE`, `INTEGER`, `LONG`) when that preferred
 type fails, since every failed attempt still uses one of the 100 FormulaEval calls for the
 transaction. `FORMULA_EVAL_SAFETY_MARGIN` is `5`, so calls stop being attempted once
 `formulaEvalCallCount` reaches 95, leaving spare room for later checks' applicability checks in
 the same transaction.

**See also:** [Reference: Formula](reference-formula.md)

### `RecordHealthCheckSoqlEvaluator`

**Role:** Query Evaluation Type (`QUERY`).
**Type:** Evaluator · `public with sharing`

Binds merge tokens in `SourceQuery__c`, runs the query through
`RecordHealthCheckQueryEvaluatorSupport` / `RecordHealthCheckSoqlTemplate`, extracts Found values,
resolves Expected from fixed value / record formula / comparison query, and applies operators via
`RecordHealthCheckComparisonEngine`. Supports one-result, multi-row, list-membership, and unary
operators according to Rule configuration.

**Notable behavior:**
- **Gotcha:** an indeterminate operator result is split into two distinct causes that must not be
 handled the same way: a genuine zero-row query is governed by `NoRowsResult__c`, while a present
 row whose field value is null is governed by `EmptyValueHandling__c` and resolves to `SKIPPED` - 
 collapsing the two would let "null value + no rows" wrongly resolve to `FAIL`. `bindTokens` also
  resolves each `{!record.FieldApiName}` token (with an optional quoted `fallback` attribute) in both a quoted and unquoted form, since a multi-select
 picklist token expands differently depending on whether it appears inside quotes (raw `'A;B;C'`
 value) or unquoted (an `INCLUDES (...)` list).

**See also:** [Reference: Query](reference-query.md)

### `RecordHealthCheckCompareQueriesEvaluator`

**Role:** Compare two queries Evaluation Type (`COMPARE_TWO_QUERIES`).
**Type:** Evaluator · `public with sharing`

Runs `SourceQuery__c` and `ComparisonQuery__c`, then compares either one value per side
(`ONE_RESULT`) or two lists (`COMPARE_AS_LISTS`) with list set operators. Empty-query handling
follows `NoRowsResult__c`, consistent with the single-query evaluator.

**Key members:**

| Member | Purpose |
| --- | --- |
| `LISTS_OVERLAP`, `LISTS_CONTAIN_ALL`, `LISTS_MATCH_EXACTLY` | Supported list operators (the last compares how often each cleaned-up value appears, so duplicate counts must match, not just shared values) |

**Notable behavior:**
- **Gotcha:** under `AS_NO_MATCH` empty-value handling, a missing list value is not converted to an
 empty string (which would let two nulls wrongly "match" as blanks) - it is replaced with a unique
 placeholder, `' __rhc_missing__:' + side + ':' + index`, so a null on one side matches nothing, not
 even another null.

**See also:** [Reference: Compare two queries](reference-compare-two-queries.md)

### `RecordHealthCheckApexEvaluator`

**Role:** Apex Evaluation Type (`APEX`).
**Type:** Evaluator · `public with sharing`

Resolves `ApexClass__c` with `Type.forName`, confirms the instance implements
`RecordHealthCheckRule`, parses `ApexParametersJson__c` into `scope.parameters`, and invokes the
plugin once with the complete record scope. The dispatcher validates exact record-key coverage,
supported statuses, and prohibited side effects before the Framework derives display content.

**Key members:**

| Member | Purpose |
| --- | --- |
| `APEX_CLASS_NOT_FOUND`, `INVALID_APEX_PARAMETERS`, `APEX_EVALUATOR_ERROR` | Typical failure reason codes |

**Notable behavior:**
- **Gotcha:** the scope dispatcher requires exactly one outcome for every requested record ID and
 no outcomes for unknown IDs. Missing or extra keys, prohibited side effects, and malformed plugin
 responses become `ERROR` results with stable plugin-contract reason codes. Configuration or data
 conditions that prevent a safe verdict become `UNABLE_TO_EVALUATE` instead.

**See also:** [Reference: Apex](reference-apex.md)

### `RecordHealthCheckQueryEvaluatorSupport`

**Role:** Shared query execution for both SOQL evaluators.
**Type:** Shared helper · `public with sharing`

`runQuery` prepares SOQL (row limit +1 so it can detect too many rows), executes `Database.query`,
maps template and query exceptions to evaluator exceptions, and rejects results over the row limit
with `GOVERNOR_LIMIT_RISK`. Also provides shared `buildEmptyResult` / `buildNullIndeterminateResult`
and the safe "cannot evaluate" message helper.

**Key members:**

| Member | Purpose |
| --- | --- |
| `runQuery(...)` | Shared, limited query execution for both SOQL evaluators |
| `buildEmptyResult(...)` | Shared zero-row result shape, based on `NoRowsResult__c` |
| `buildNullIndeterminateResult(...)` | Shared null-value result shape |

**Notable behavior:**
- **Gotcha:** `runQuery` asks `RecordHealthCheckSoqlTemplate.prepareForExecution` for `maxRows + 1`
 rows rather than `maxRows` - fetching one extra row is how it distinguishes "exactly at the limit"
 from "over the limit" and raises `GOVERNOR_LIMIT_RISK` only in the latter case, without needing a
 separate `COUNT()` query. `buildEmptyResult`'s four-way branch on `NoRowsResult__c` (`PASS`, `FAIL`,
 `UNABLE_TO_EVALUATE`, or the default `SKIPPED`/`APPLICABILITY_NOT_MET`) is shared exactly by both
 SOQL evaluators so a zero-row query behaves identically regardless of Evaluation Type.

---

## Configuration and validation (L2)

### `RecordHealthCheckConfigService`

**Role:** Load Check Sets/Rules and runtime validation adapter.
**Type:** Service class · `public with sharing`

Queries Check Set and Rule Custom Metadata, builds Lightning definition responses (including
truncation at `FRAMEWORK_MAX_CHECKS`), reports Check Set availability for an object, resolves a
Rule's parent Check Set, loads Rules for evaluation, and maps the first
`RecordHealthCheckRuleValidator` finding into an `UNABLE_TO_EVALUATE` / `INVALID_CONFIG` result.

**Key members:**

| Member | Purpose |
| --- | --- |
| `ConfigException` (nested) | Exception carrying `reasonCode` |
| `RC_*` | Reason-code string aliases used across load paths - the single source of truth callers compare against, rather than a literal (e.g. `RC_CONFIG_INACTIVE`, `RC_OBJECT_MISMATCH`, `RC_NO_ACTIVE_CHECKS`) |
| `findCheckSetDeveloperName(...)` | Resolve a Rule's parent Check Set |
| `getCheckSetAvailabilityForObject(...)` | Active/inactive Check Sets for an object |
| `getDefinitionResponse(...)` | Build the Lightning definition response |
| `validateRuleForEvaluation(...)` | Map the first validator finding to a result |
| `loadRule(...)` | Load a Rule for evaluation |
| `cachedRulePublicationSettings(...)` | Transaction-cached publication flags |

**Notable behavior:**
- **Gotcha:** `getDefinitionResponse` rejects a blank `CardTitle__c` with `INVALID_CONFIG`; it does
 not substitute Master Label or Developer Name for administrator-authored card text. When active
 Rules for a Check Set exceed `FRAMEWORK_MAX_CHECKS` (25), it logs a `WARN` server-side
 in addition to the truncation metadata the LWC shows as its "First 25 of N shown" badge, so the
 excess is visible in logs too, not only in the UI.

### `RecordHealthCheckRuleValidator`

**Role:** Shared Rule-field validation for every Evaluation Type.
**Type:** Shared validator · `public with sharing`

Returns ordered `Finding` values (`FindingCode` enum) once. Runtime (`ConfigService`) takes the first
finding; deploy-time (`MetadataValidator`) collects all findings. Keeps the decision logic in one
place so the two validators cannot disagree on *what* is invalid - only on how findings are mapped to
messages and field names.

**Notable behavior:**
- **Gotcha:** `MaxQueryRows__c` and `EmptyValueHandling__c` / `NoRowsResult__c` are deliberately
 *excluded* from `queryFindings`/`compareQueriesFindings` - callers run `maxRowsFindings` and
 `nullEmptyFindings` separately, since `ConfigService` applies them only to Query/CompareTwoQueries
 checks while `MetadataValidator` runs them once at the top level for every Evaluation Type; folding
 them into the per-type producers would double-count findings for the collect-all caller. Mutually
 exclusive conditions (operator, `QueryResultHandling__c`, comparison-value source) use `if`/`else
 if` chains for the same reason - so at most one `Finding` is returned per field even by the
 collect-everything path.

### `RecordHealthCheckMetadataValidator`

**Role:** Deploy-time / CI Custom Metadata audit.
**Type:** Service class · `public with sharing`

Validates all active Check Sets and Rules in the org and returns `ValidationIssue` rows (`ERROR` /
`WARNING`) with component name, field, message, and reason code. An empty list means the audit
passed. Use before promoting configuration between orgs.

**Key members:**

| Member | Purpose |
| --- | --- |
| `validate()` | Validate every active Check Set and Rule in the org |
| `validateRecords(...)` | Validate a supplied set of records |

**Notable behavior:**
- **Gotcha:** `validateRecords` treats a Check Set with more active Rules than
 `RecordHealthCheckConstants.FRAMEWORK_MAX_CHECKS` (25) as `WARNING`/`CHECK_LIMIT_EXCEEDED`, not
 `ERROR` - the excess Rules still deploy and are still valid, they simply will not run. It then
 checks whether any *included* Rule's `PrerequisiteRule__c` points outside that first-25 execution
 window and adds a second `WARNING`/`DEPENDENCY_NOT_IN_RUN` for each affected Rule. At runtime,
 Apex and the Lightning component skip a Rule whose Prerequisite Rule was not included.

### `RecordHealthCheckConfigValidator`

**Role:** Shared validation helpers.
**Type:** Shared helper · `public with sharing`

First template token issue, object API name checks, Apex plugin class validation / creation helpers
(`isValidApexPlugin`, `takeValidatedPlugin`), and JSON-object shape checks. Used by both runtime and
deploy-time paths.

**Notable behavior:**
- **Gotcha:** `isValidApexPlugin` creates an instance of the class while validating it, then caches
 that instance in `validatedPluginInstances` by class name; `takeValidatedPlugin` retrieves and
 removes it so `RecordHealthCheckApexEvaluator` can reuse the already-built plugin instead of
 calling `newInstance()` a second time. `isJsonObject` treats a blank string as valid (returns
 `true`) since `ApexParametersJson__c` is optional - only a non-blank value that fails to parse as a
 JSON object is rejected.

### `RecordHealthCheckConstants`

**Role:** Allowed values and numeric limits (single source of truth).
**Type:** Constants holder · `public with sharing`

Owns `FRAMEWORK_MAX_CHECKS` (25), `FRAMEWORK_MAX_ROWS` (2000), and Set accessors that return a copy
for display modes, trigger/reveal modes, Evaluation Types, operators, null/empty behaviors,
severities, applicability modes, and related allowed-value lists. Runtime and deploy-time validators
both read from here so they cannot get out of sync.

**Notable behavior:**
- **Why it exists:** runtime and metadata validation need one approved vocabulary. Every
 `public static Set<String>` accessor here returns a `new Set<String>(...)` copy,
 not the internal set itself, so a caller changing the returned set can never overwrite the
 Framework's official values. The class also owns the Apex-to-LWC value translation
 (`toLwcTriggerMode`, `toLwcSeverity`, `toLwcEvaluatorType`, etc.) that maps metadata API values
 (for example `CRITICAL`) to the card's presentation vocabulary (for example `Error`).

### `RecordHealthCheckReasonCodes`

**Role:** Selected stable reason-code helpers.
**Type:** Constants holder · `public` (no sharing keyword - data-only)

Declares commonly referenced codes (for example applicability and access) and marks which codes are
diagnostics-only (`isDiagnosticsOnly`). Full outcome list lives in
[Reference: Reason Codes](reference-reason-codes.md).

**Key members:**

| Member | Purpose |
| --- | --- |
| `isDiagnosticsOnly(reasonCode)` | Whether a reason code should be treated as diagnostics-only |

**Notable behavior:**
- **Example:** `DIAGNOSTICS_ONLY` contains exactly `FIELD_NOT_ACCESSIBLE` and
 `RECORD_NOT_ACCESSIBLE` - the two reason codes that reveal FLS/sharing details an unauthorized
 viewer should not see; `isDiagnosticsOnly(reasonCode)` simply checks whether the code is in that
 pair.

### `RecordHealthCheckSetAvailability`

**Role:** Check Set availability data for setup messaging.
**Type:** Data holder · `public` (no sharing keyword)

Used when the Lightning card has no Check Set selected.

**Key members:**

| Member | Purpose |
| --- | --- |
| `hasActive` | Whether the object has any active Check Sets |
| `hasInactive` | Whether the object has any inactive Check Sets |

**Notable behavior:**
- **Gotcha:** the no-arg constructor sets both `@AuraEnabled` booleans to `false`, so a caller that
 returns early before filling them in (for example `RecordHealthCheckController` on a `null`
 `recordId`) still returns a valid, non-null shape to the LWC.

---

## Shared evaluation services (L2)

### `RecordHealthCheckComparisonEngine`

**Role:** Shared comparison operators for Query evaluators.
**Type:** Shared service · `public with sharing`

Implements Equals / NotEquals / Contains / ordered operators, unary blank checks, list operators,
and `EmptyValueHandling__c` / `NoRowsResult__c` resolution. Throws
`RecordHealthCheckEvaluatorException` so both SOQL evaluators map the same reason codes.

**Key members:**

| Member | Purpose |
| --- | --- |
| `applySingleValueComparison(...)` | One-value operator comparison |
| `applySingleComparison(...)` | Single-row operator comparison |
| `applyUnaryComparison(...)` | Blank-check style operators |
| `valuesEqual(...)` | Typed equality |
| `resolveEmptyBehavior(...)` | `EmptyValueHandling__c` / `NoRowsResult__c` resolution |
| `formatValue(...)` / `formatList(...)` | Human-readable display formatting |
| `valueForDisplay(...)` / `valuesForDisplay(...)` | Resolve display-only picklist labels from a queried field while leaving comparison values untouched |
| `describeExpected(...)` / `describeExpectedForActual(...)` | Operator phrase plus the formatted operand |

**Notable behavior:**
- Each display method has an overload that takes the Rule's `DisplayValueFormat__c`. The no-format
 overloads render on `Auto`. The rendering itself lives in
 [`RecordHealthCheckDisplayFormat`](#recordhealthcheckdisplayformat); this class owns the operator
 phrasing and the list preview cap.
- **Example:** `formatList` limits the rendered preview to `LIST_PREVIEW_CAP` (`10`) entries and
 appends `… (N total)` beyond that, so a large query result stays readable in the UI. Full
 contract: [Reference: Display value format](reference-display-value-format.md).

### `RecordHealthCheckDisplayFormat`

**Role:** Renders Found and Expected values as the text shown on the card chips.
**Type:** Shared service · `public with sharing`

Applies the Rule's **Display: Value Format** (`DisplayValueFormat__c`). On `Auto` a value is
humanized from its Apex type; a named format such as `Currency` or `Raw` overrides that. Formatting
is display only - `RecordHealthCheckComparisonEngine` decides pass and fail from the raw typed
values, so no format can move a check between pass and fail.

**Key members:**

| Member | Purpose |
| --- | --- |
| `render(value, format, isoCode)` | One value rendered for the chosen format and currency |
| `isFormatApiName(format)` | Whether a name is one of the ten official, uppercase format API values |
| `isDisplayedNumberOne(value)` | Whether locale-formatted display text represents exactly one, used when a rendered count needs singular or plural wording |
| `formatForField(...)` / `formatForRow(...)` | The format a field's Setup definition suggests, used when the Rule is on Auto |
| `valueForDisplay(...)` / `valuesForDisplay(...)` | Picklist labels or raw typed values prepared for one value or a list |
| `currencyIsoCodeFrom(row)` | The currency a row's amounts belong to, in an org with more than one |
| `currencyIsoCodeFor(row, record, fieldPath)` | The same, walking a relationship path when needed and falling back to the card record when the query read that record without selecting `CurrencyIsoCode` |
| `currencyIsoCodesFor(rows, record, fieldPath)` | One currency per row, including related rows, so a list preview labels each entry with its own |
| `alignExpectedToFound(...)` | Keeps a fixed text operand in the same units as a numeric Found value |
| `FORMAT_*` constants | The `DisplayValueFormat__c` API values |

**Notable behavior:**
- Numbers are grouped for the running user's locale: `70000.0` reads `70,000` for an English (US)
 user and `70.000` for a German (Germany) one. The digits are laid out by the class rather than by
 `Decimal.format()`, which keeps only three decimal places; a chip shows up to six, rounded for
 display only.
- An aggregate row such as `SUM(Amount)` is labelled with the org's corporate currency, which is
 what Salesforce converts an aggregate into.
- Each side of a comparison keeps its own currency: a Compare two queries Rule, and a Query Rule
 whose Expected value comes from a comparison query, read a currency per side rather than sharing
 the Found side's.
- ISO date text that names an impossible date, such as `2026-02-30`, keeps its original spelling.
 `Date.newInstance` rolls out-of-range parts over instead of rejecting them, so the parts are
 checked by round-tripping before the value is treated as a date.
- Aligning an Expected operand to a numeric Found value keeps the leading-zero guard, so `00100`
 stays `00100`.
- A `Time` reads on a 24-hour clock (`17:30`), because Apex can format a time of day only as part of
 a date.
- A named format that cannot apply to a value returns the value with its original spelling rather
 than raising an error - `Currency` on a Salesforce Id stays the Id.
- A `Date` is tested before a `Datetime` everywhere, because Apex reports a `Date` as an instance of
 `Datetime`; checking the other way round would shift a date by the user's time-zone offset.
- An org with more than one currency renders ISO-first (`USD 70,000.00`); a single-currency org uses
 the symbol. `RecordHealthCheckFieldPlanner` loads `CurrencyIsoCode` on the record in a multi-currency org
 so an amount can be shown in the currency its own record uses.
- Full contract: [Reference: Display value format](reference-display-value-format.md).

### `RecordHealthCheckSoqlTemplate`

**Role:** Safe preparation of administrator-authored SOQL.
**Type:** Shared service · `public with sharing`

Cleans up admin-authored SOQL with awareness of parenthesis depth: rejects DML keywords and
`WITH SYSTEM_MODE`, requires a single outer SELECT, rewrites bare `COUNT()`, enforces the outer row
limit, and injects `WITH USER_MODE` in a legal clause position. Ignores keywords inside string
literals and nested subqueries so false positives and misplaced injection are avoided.

**Key members:**

| Member | Purpose |
| --- | --- |
| `prepareForExecution(soql, maxRows)` | Main entry point; cleans up and limits admin-authored SOQL |
| `TemplateException` (nested) | Exception carrying `reasonCode` |

**Notable behavior:**
- **Gotcha:** `maskStringLiterals` replaces every character inside a single-quoted literal with a
 space (preserving length and position) rather than stripping it, so later regex match indices
 computed against the masked copy still map back onto the original SOQL string unchanged.
 `injectUserMode` only inserts `WITH USER_MODE` when no outer `WITH` clause already exists, and
 walks `TAIL_CLAUSE_PATTERNS` to find the earliest legal tail-clause position (`GROUP BY`/`ORDER
 BY`/`LIMIT`/etc.) to insert before - an admin query already ending in a tail clause never gets
 `WITH USER_MODE` appended after it, which would be invalid SOQL. `WITH SYSTEM_MODE` is rejected
 outright rather than merely ignored, since it would let an admin-authored query bypass the
 sharing/FLS enforcement the framework guarantees.

### `RecordHealthCheckValueResolver`

**Role:** Value extraction, conversion, and comparison.
**Type:** Shared service · `public with sharing`

Reads fields from rows and `AggregateResult`s (including relationship paths), classifies
`QueryException` messages into access vs template reason codes, and compares numeric / datetime /
string values consistently for both Query evaluators.

**Key members:**

| Member | Purpose |
| --- | --- |
| `traverse(...)` | Read a (possibly relationship-dotted) field path off a row |
| `classifyQueryException(...)` | Map a `QueryException` message to a reason code |
| `ResolverException` (nested) | Exception carrying `reasonCode` |

**Notable behavior:**
- **Gotcha:** `traverse` returns `null` (not an exception) when an intermediate relationship in a
 dotted field path (e.g. `Account.Name`) is itself null, so a broken relationship chain becomes a
 null value rather than an error. `classifyQueryException` inspects the exception message text
 for `access`, `permission`, or `insufficient privileges` to decide `FIELD_NOT_ACCESSIBLE` vs.
 `INVALID_SOQL_TEMPLATE` - it accepts the base `Exception` type specifically because
 `System.QueryException` cannot be constructed with a custom message in a test, so only the message
 is ever inspected, not the exception's runtime type.

### `RecordHealthCheckDescribeCache`

**Role:** Schema describe cache for the current transaction.
**Type:** Shared service · `public with sharing`

Caches global describe, SObject describes, field maps, and field describes so a busy card or bulk
run does not rebuild metadata repeatedly. Production describe lookups should go through this class
rather than calling Schema APIs directly elsewhere in the Framework.

**Key members:**

| Member | Purpose |
| --- | --- |
| `containsObject(...)` | Whether an object exists in the global describe |
| `resolveSObjectType(...)` | Resolve an object API name to its `SObjectType` |
| `getGlobalDescribe(...)` | Cached global describe map |
| `objectApiName(...)` | Cached object API name lookup |
| `describeSObject(...)` | Cached `DescribeSObjectResult` |
| `fieldMap(...)` | Cached field map for an object |
| `describeField(...)` | Cached `DescribeFieldResult` for one field |

**Notable behavior:**
- **Gotcha:** `describeField` keys its cache on the `Schema.SObjectField` token itself, not on
 `String.valueOf(field)` - a comment notes that `String.valueOf` returns only the unqualified field
 name, so two same-named fields reached from different objects (for example `Account.Name` vs.
 `Contact.Name` via a relationship traversal) would otherwise collide in the cache and return the
 wrong describe, including a wrong `isAccessible()` result.

### `RecordHealthCheckEvaluatorException`

**Role:** Evaluator exception with a reason code.
**Type:** Custom exception · `public`, extends `Exception`

Thrown by comparison, SOQL template, and value-resolution paths. Evaluators catch it and map
`reasonCode` onto `UNABLE_TO_EVALUATE` results instead of leaking stack traces to users.

**Notable behavior:**
- **Why it exists:** one top-level exception lets shared comparison and query services carry a
 stable reason code that both SOQL evaluators recognize and convert into safe results.

### `RecordHealthCheckAccess`

**Role:** Diagnostics Custom Permission check.
**Type:** Shared service · `public with sharing`

`canViewDetails()` returns whether the running user holds `Record_Health_Check_View_Diagnostics`.
Check Set `ShowDiagnostics__c` still controls *when* troubleshooting fields are attached; this class
only answers *who* may see them.

**Key members:**

| Member | Purpose |
| --- | --- |
| `canViewDetails()` | Whether the running user holds the diagnostics Custom Permission |

**Notable behavior:**
- **Gotcha:** `canViewDetails()` only honors the `@TestVisible` `viewDetailsPermissionOverride` when
 `Test.isRunningTest()` is true - a test override left set can never leak into a non-test
 `FeatureManagement.checkPermission` call, so production behavior always reflects the real Custom
 Permission assignment.

### `RecordHealthCheckLogger`

**Role:** Single logging destination for the Framework.
**Type:** Shared service · `public with sharing`

Every Framework log line goes through this class as structured `[RHC]` output with run id and
running user. Levels: `ERROR`, `WARN`, `INFO`, `DEBUG`. ERROR lines are also held as
`Record_Health_Check_Log__e` and published by `flush()` at the transaction boundary (default on,
opt-out per Check Set through `PublishErrorLogEvent__c`, and subscriber-context guarded). Entry
points call `flush()` so ERROR platform events are not lost when
`System.debug` is off.

**Key members:**

| Member | Purpose |
| --- | --- |
| `normalizeIdentifier(...)` | Length-limited API names used in logs and lookups |
| `flush()` | Publish held `ERROR` events at the transaction boundary |
| `enterSubscriberContext()` | Loop guard for subscriber-context log handling |

**Notable behavior:**
- **Gotcha:** `captureErrorEvent` deliberately never carries field values (actual/expected) into the
 `Record_Health_Check_Log__e` event - only identifying context (run id, Check Set/Rule
 names, record id, exception type/message/stack) - because those raw values belong to Debug Mode's
 admin detail channel, not a platform event any subscriber with object access could read.
 `enterSubscriberContext()` is a one-way loop guard a subscriber processing this same event must
 call first, so an error raised while handling a log event cannot republish onto the same event bus.

**See also:** [Log event metadata](../metadata/event-log.md)

---

## Merge tokens (L2)

### `RecordHealthCheckTemplateService`

**Role:** Parse, validate, and resolve merge tokens.
**Type:** Shared service · `public` (no sharing keyword)

Handles namespaced tokens such as `{!record.Name}`, with optional quoted attributes such as
`{!record.Amount format="CURRENCY" fallback="Not available"}`, for display messages, URLs, and SOQL
text.
Enforces max 100 tokens and 20,000 characters of resolved text. Unknown namespaces, unknown
properties, unsupported flat tokens, and stray braces become structured `RecordHealthCheckTokenIssue`s.

**Key members:**

| Member | Purpose |
| --- | --- |
| `SURFACE_DISPLAY`, `SURFACE_URL`, `SURFACE_SOQL` | The three contexts tokens can resolve for |
| `resolveFieldPath(...)` | Resolve a dotted `record.*` token to a field value |
| `applyFoundExpectedText(...)` | Apply administrator Found and Expected wording after evaluator values are formatted |

**Notable behavior:**
- **Gotcha:** `resolveFieldPath` rejects a dotted record token whose relationship depth exceeds 5
 hops (`parts.size() > 6`) with `TOKEN_NOT_AVAILABLE_IN_PHASE`, so a runaway relationship chain in an
 admin-authored template fails immediately rather than describing arbitrarily deep schema. On
 `SURFACE_URL`, a token that resolves blank and has no `fallback` attribute throws `MISSING_TOKEN_VALUE`
 instead of silently substituting an empty string - a blank display value is harmless, but a blank
 URL segment could produce a broken or unintended link. `rhcResult` tokens can only be resolved once
 `context.resultFinalized` is true, since a result's Found/Expected values are not meaningful until
 the evaluator has finished.

**See also:** [Reference: Merge tokens](reference-merge-tokens.md)

### `RecordHealthCheckTokenRegistry`

**Role:** Allowed list of merge-token namespaces and properties.
**Type:** Constants holder · `public` (no sharing keyword)

Record properties are any non-blank field path; other namespaces use fixed property sets (Developer
Name, status, run id, and so on).

**Key members:**

| Member | Purpose |
| --- | --- |
| `record`, `rhcRule`, `rhcSet`, `rhcResult`, `rhcRun` | The five allowed token namespaces |
| `RESULT_PROPERTIES` | Fixed property set for the `rhcResult` namespace |

**Notable behavior:**
- **Example:** `RESULT_PROPERTIES` is exactly `{status, foundValue, foundValuePluralSuffix,
 expectedValue, failedRecordCount, totalRecordCount, reasonCode}` - `foundValuePluralSuffix` in
 particular exists so a multi-row summary message can render "1 Contact" vs "2 Contacts" without the
 admin hand-authoring a conditional.

### `RecordHealthCheckToken`

**Role:** One parsed merge token.
**Type:** Data holder · `public` (no sharing keyword)

**Key members:**

| Member | Purpose |
| --- | --- |
| `expression` | The full raw token text |
| `namespaceName` | The token's namespace (e.g. `record`, `rhcRule`) |
| `propertyPath` | The property or field path within that namespace |
| `formatName` | Optional official uppercase Display: Value Format API name |
| `fallbackValue` | Optional text from the quoted `fallback` attribute; `null` when omitted |
| `attributeError` | Parser error for unknown, duplicate, unquoted, or otherwise invalid attributes |
| `startIndex` / `endIndex` | Start and end position of the token within the template string |

**Notable behavior:**
- **Note:** a convenience constructor omits `fallbackValue` (defaults to `null`) for callers that
 only need the namespace/property/span.

### `RecordHealthCheckTokenIssue`

**Role:** One merge-token validation failure.
**Type:** Data holder · `public` (no sharing keyword)

**Key members:**

| Member | Purpose |
| --- | --- |
| `RecordHealthCheckTokenIssue(String reasonCode, String token, String message)` | Constructor, for example `('UNSUPPORTED_TOKEN_NAMESPACE', '{!foo.bar}', 'Unsupported token namespace "foo".')` <!-- rejected-token-fixture --> |

### `RecordHealthCheckMergeContext`

**Role:** Values available while resolving merge tokens.
**Type:** Chainable builder · `public` (no sharing keyword)

Chainable `withRecord` / `withRule` / `withResult` / `withRun` builders supply the record, Rule (and
parent Check Set), result, and run context used by token resolution. Also carries optional
failed/total record counts for plural-aware result tokens.

**Key members:**

| Member | Purpose |
| --- | --- |
| `withRecord(...)` | Supply the record for `record.*` tokens |
| `withRule(...)` | Supply the Rule (and derive its parent Check Set) for `rhcRule.*` / `rhcSet.*` tokens |
| `withResult(value, finalized)` | Supply the result for `rhcResult.*` tokens; only usable when `finalized` is true |
| `withRun(...)` | Supply the run context for `rhcRun.*` tokens |

**Notable behavior:**
- **Gotcha:** `withRule` also derives `checkSet` by calling
 `value.getSObject('Record_Health_Check_Set__r')` on the passed-in Rule record - callers never set
 `checkSet` directly, so a Rule query that omits the `Record_Health_Check_Set__r` relationship will
 silently leave `rhcSet.*` tokens unresolved. `resultFinalized` defaults to `false` and is only
 ever set `true` through `withResult(value, finalized)`, which controls when `rhcResult.*` tokens
 become available.
- **Attributes:** raw `record.*` tokens may carry `format="API_NAME"` and `fallback="text"` in
 either order. Values must be double-quoted. Unknown, duplicate, or unquoted attributes produce a
 token issue; result tokens cannot be formatted again because they already contain display text.

---

## Results, definitions, and plugin interface (L1)

### `RecordHealthCheckEvaluationResult` / `RecordHealthCheckResultDisplay`

**Role:** Separate stable machine data from optional human-facing rendering.
**Type:** Global data holders

`RecordHealthCheckEvaluationResult` carries status, qualified Rule identity, reason code, severity,
and typed Found/Expected values. `RecordHealthCheckResultDisplay` carries labels, messages, links,
and formatted values only when the selected result mode requests display content.

### `RecordHealthCheckResponse` / `RecordHealthCheckResultItem`

**Role:** Common response shape for both Rule and Check Set requests.
**Type:** Global data holders

The response preserves the detached input record order and selected Rule order. Each result item
contains one evaluation plus optional display content; the summary holds terminal status totals.

**See also:** [Apex API response contract](../api/apex-api.md#response-contract)

### `RecordHealthCheckDefinition` / `RecordHealthCheckDefinitionResponse`

**Role:** Lightning definition response (not evaluation results).
**Type:** Data holders (`@AuraEnabled`) · `public` (no sharing keyword)

**Key members:**

| Member | Purpose |
| --- | --- |
| `RecordHealthCheckDefinition.developerName` / `label` / `description` / `priority` | One Rule's identity and display fields |
| `RecordHealthCheckDefinition.dependsOnRuleDeveloperName` | `null` when the Rule has no `PrerequisiteRule__c` dependency |
| `RecordHealthCheckDefinitionResponse` title/trigger/reveal/display fields | Check Set card settings (title, trigger/reveal modes, passed/skipped/comparison display, stop-on-first-error) |
| `RecordHealthCheckDefinitionResponse.checksOmittedByLimit` | Truncation metadata for the "First 25 of N shown" badge |
| `RecordHealthCheckDefinitionResponse.inactiveRuleLabels` | Diagnostics-only detail behind `inactiveRuleCount` |
| `RecordHealthCheckDefinitionResponse.showDiagnostics` / `checks` | Diagnostics visibility flag and the ordered Rule definitions |

**Notable behavior:**
- **Note:** `inactiveRuleLabels` - the list of names, not just the count - is only meaningful to an
 admin auditing why a Rule did not run.

### `RecordHealthCheckAdminDetail`

**Role:** Structured diagnostics for authorized Show Diagnostics viewers.
**Type:** Data holder (`@AuraEnabled`) · `public` (no sharing keyword)

Left blank on a normal business response.

**Key members:**

| Member | Purpose |
| --- | --- |
| `containsRestrictedDetail` | Whether restricted detail is present; read by `RecordHealthCheckLifecyclePublisher` to set `ContainsRestrictedDetail__c` on the outgoing event |
| `reasonCode` | Diagnostics reason code |
| `message` | Diagnostics message text |

**Notable behavior:**
- **Note:** all three fields are `@AuraEnabled` with no constructor - callers set them field by
 field.

### `RecordHealthCheckValueSource`

**Role:** Structured Found/Expected diagnostic detail.
**Type:** Data holder · `public` (no sharing keyword)

**Key members:**

| Member | Purpose |
| --- | --- |
| `Detail` (nested: `sourceLabel`, `rawValueLabel`, `coercionLabel`) | Structured pieces of one diagnostic note |
| `render(Detail)` | Turns a `Detail` into the single human-readable note shown as `actualValueDetail` / `expectedValueDetail` |
| `rowCount(...)` | Formats pluralized row counts |

**Notable behavior:**
- **Gotcha:** `render` returns `null` - not an empty string - when every part of the `Detail` is
 blank, so the engine can leave the public `*Detail` string `null` rather than showing an empty
 parenthetical note. `rowCount` exists solely so a value-source note never reads "1 row(s)": it
 special-cases `n == 1` to `"1 row"` and treats a `null` count as `0`.

### `RecordHealthCheckRule` (interface)

**Role:** Plugin interface for Apex Evaluation Type.
**Type:** Interface · `global`

```apex
global interface RecordHealthCheckRule {
  Map<Id, RecordHealthCheckOutcome> evaluate(RecordHealthCheckScope scope);
}
```

Implementations are bulk by contract: query once for the complete scope, seed every requested Id,
overlay returned facts, and isolate record-specific conversion errors inside the record loop.

**Notable behavior:**
- **Gotcha:** the signature cannot prove query growth or access mode. The dispatcher validates exact
  key coverage and prohibited effects; the supplied contract harness measures behavior across scope
  sizes and can use a controlled least-privilege fixture as evidence.

### `RecordHealthCheckScope`

**Role:** Input to `RecordHealthCheckRule.evaluate`.
**Type:** Read-only global data holder

**Key members:**

| Member | Purpose |
| --- | --- |
| `objectApiName` | Object API name (for example `Account`) |
| `recordIds` | Detached copy of every record Id in the request scope |
| `parameters` | Detached parsed `ApexParametersJson__c` map |
| `ruleQualifiedApiName` | Qualified Rule identity |
| `checkSetQualifiedApiName` | Qualified parent Check Set identity |
| `runId` | Correlation id for the request |

**Notable behavior:**
- **Gotcha:** getters return detached collections. A plugin cannot mutate the pipeline's record Ids
  or parameter map through the scope object.

**See also:** [Reference: Apex](reference-apex.md)

---

## Example Apex plugins

These classes implement `RecordHealthCheckRule`. They are examples and fixtures, not required for
the engine to run Formula or Query Rules.

### `AccountHasRecentActivityCheck`

**Role:** Shipped Apex Rule for recent Account Task/Event activity.
**Type:** Example plugin (implements `RecordHealthCheckRule`) · `global with sharing`

Ships with Record Health Check in `force-app`. Passes when the Account has at least one completed Task or Event in
a look-back window. Tunable with `ApexParametersJson__c`: `{"daysBack": 90}` (default 30, bounds
1–3650). Sets Found/Expected and value-source detail; label, severity, and failure message come from
metadata.

**Key members:**

| Member | Purpose |
| --- | --- |
| `DEFAULT_DAYS_BACK` (`30`) | Look-back window only when `daysBack` is omitted |
| `MIN_DAYS_BACK` / `MAX_DAYS_BACK` (`1` / `3650`) | Valid bounds for `daysBack` |
| `resolveDaysBack(...)` | Parses and bounds-checks the `daysBack` parameter |

**Notable behavior:**
- **Gotcha:** an omitted `daysBack` uses `DEFAULT_DAYS_BACK`; a supplied value that is nonnumeric or
 outside `MIN_DAYS_BACK`/`MAX_DAYS_BACK` returns `UNABLE_TO_EVALUATE` with `INVALID_CONFIG`. Both queries run
 `WITH USER_MODE` and use `SELECT COUNT()`, so Task/Event visibility follows the running user's
 sharing and FLS like every other Framework query.

**See also:** [Recent Account activity example](../examples/apex/01-recent-activity.md)

### Integration-test plugins

These live under `integration-tests/main/default/classes/` and accompany the examples library. They
are not part of Record Health Check unless you deploy that folder.

| Class | What it checks | Typical JSON parameters |
| --- | --- | --- |
| `AccountOpenOpportunityHealthCheck` | Open Opportunities that are stale, missing Next Step, and not closing this quarter | `{"staleDays": 30}` |
| `AccountStrategicReadinessCheck` | Weighted readiness score (contacts, pipeline, activity, billing) | `{"minScore": 80, "activityDaysBack": 60}` |
| `ApprovalInactiveApproverCheck` | Pending approval steps assigned to inactive users (dynamic object/field names for Advanced Approvals) | Object/field/status overrides; returns `UNABLE_TO_EVALUATE` when the approval object is absent |

**See also:** [Apex examples](../examples/apex/README.md)

---

## Test helpers (not runtime)

| Class | Note |
| --- | --- |
| `RecordHealthCheckTestDataFactory` | `@isTest` factory for Accounts/Contacts and related coverage data; not used at runtime |
| `*Test.cls` / coverage classes | Unit and coverage tests; not part of the product API |

---

## Related

- [Reference: Architecture](reference-architecture.md) - layers, runtime path, ownership map
- [Reference: Apex API](../api/apex-api.md) - public `evaluate(request)` contract
- [Reference: Apex](reference-apex.md) - writing a `RecordHealthCheckRule` plugin
- [Reference: Reason Codes](reference-reason-codes.md) - status and reason codes
- [Reference: Merge tokens](reference-merge-tokens.md) - token namespaces and limits
- [Technical references index](README.md)
