# Reference: Apex classes

> [!NOTE]
> On this page, choose the layer-specific Apex class guide for Record Health Check. Use this
> when reading source or extending the Framework. Writing an Apex Rule plugin? Start with
> [Apex Rule contract](../evaluation/apex-rule-contract.md), not this folder.

This guide covers every **production** class under `force-app/main/default/classes/` (excluding
`*Test` classes and coverage helpers). Shipped and integration-test example plugins are listed in
[Results, definitions, and plugins](results-and-plugins.md).

Unless noted otherwise, Framework service classes are `public with sharing`. Result and definition
data holders, the plugin interface, merge-token helpers, and a few other types are plain `public`
classes (no sharing keyword) because they hold data or interfaces rather than query Salesforce
records.

## Choose a layer guide

| Layer | Page |
| --- | --- |
| L5 Entry points | [Entry points](entry-points.md) |
| L4 Scope orchestration | [Scope orchestration](scope-orchestration.md) |
| L3 Evaluators | [Evaluators](evaluators.md) |
| L2 Configuration and validation | [Configuration and validation](configuration-and-validation.md) |
| L2 Shared evaluation services | [Shared services](shared-services.md) |
| L2 Merge-token classes | [Merge-token classes](merge-token-classes.md) |
| L1 Results, definitions, and plugins | [Results and plugins](results-and-plugins.md) |
| Plugin verification harness | [Plugin verification](plugin-verification.md) |
| Test-seam / architecture policy (contributors) | [Contributor policy: Apex test seams](test-seams.md) |

## How to use this guide

| You want to… | Start here |
| --- | --- |
| Scan classes by layer | [Class index by level](#class-index-by-level) |
| Understand who calls whom | [Layers at a glance](#layers-at-a-glance) |
| Read a detailed description | The layer sections below |
| Call the Framework from Apex or Flow | Entry points, then [Apex API](../../api/apex-api.md) / [Flow actions](../../integration/flow-actions.md) |
| Implement `RecordHealthCheckRule` | Plugin interface classes, then [Apex reference](../evaluation/apex-rule-contract.md) |

Every class entry below follows the same order, so you can find any given fact in the same place
every time: **Role** (what it is, read in under three seconds) → **Type** (declared sharing mode or
data holder / interface / exception) → what it does → **Key members** (the constants/methods/fields
worth knowing) → **Notable behavior** (gotchas, rationale, or a concrete example grounded in the
code) → **See also**. A class skips a slot only when there's genuinely nothing to put there - the
order never changes.

## Layers at a glance

Higher levels call lower levels. Lower levels never call back up. This matches
[Reference: Architecture § 5. Layers](../framework/architecture.md#5-layers); the sections below use
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
| L5 | [`RecordHealthCheck`](entry-points.md#recordhealthcheck) | Public Apex `evaluate(request)` API |
| L5 | [`RecordHealthCheckController`](entry-points.md#recordhealthcheckcontroller) | Aura-enabled API for the Lightning card |
| L5 | [`RecordHealthCheckRunRuleFlowAction`](entry-points.md#recordhealthcheckrunruleflowaction) | Packaged Flow action "Run Record Health Check Rule" |
| L5 | [`RecordHealthCheckRunSetFlowAction`](entry-points.md#recordhealthcheckrunsetflowaction) | Packaged Flow action "Run Record Health Check Set" |
| L5 | `RecordHealthCheckQueueable` | Packaged asynchronous adapter for one bounded Check Set scope |
| L5 | `RecordHealthCheckBatch` | Packaged adapter that splits an explicit ID population into safe transactions |
| L5 | `RecordHealthCheckScheduled` | Lightweight scheduler that launches `RecordHealthCheckBatch` |
| L5 | `RecordHealthCheckAsyncSupport` | Shared validation and request construction for asynchronous adapters |
| L5 | `RecordHealthCheckFlowSupport` | Shared Flow input normalization, result alignment, and summary status logic |
| L5 | `RecordHealthCheckFlowGroupExecutor` | Shared normalized grouping and engine execution for both Flow actions |
| L5 | [`RecordHealthCheckLifecyclePublisher`](entry-points.md#recordhealthchecklifecyclepublisher) | Optional Set Run and Rule Result platform events |
| L5 | [`RecordHealthCheckRunContext`](entry-points.md#recordhealthcheckruncontext) | Run id, source, and timing for one evaluation |
| L5 | [`RecordHealthCheckSetPicklist`](entry-points.md#recordhealthchecksetpicklist) | App Builder dynamic picklist for Check Set Developer Name |

### L4 - Engine

| Level | Class | One-line purpose |
| --- | --- | --- |
| L4 | [`RecordHealthCheckScopePipeline`](scope-orchestration.md#recordhealthcheckscopepipeline) | Resolves a selection and evaluates the complete ordered record scope |
| L4 | [`RecordHealthCheckEvaluatorRegistry`](scope-orchestration.md#recordhealthcheckevaluatorregistry) | Maps Evaluation Type values to a common scope evaluator contract |
| L4 | [`RecordHealthCheckFieldPlanner`](scope-orchestration.md#recordhealthcheckfieldplanner) | Safe record-field planning for scope evaluation |
| L4 | [`RecordHealthCheckBulkQuerySupport`](scope-orchestration.md#recordhealthcheckbulkquerysupport) | Executes supported query templates once for a complete scope |
| L4 | [`RecordHealthCheckBulkQueryRewriter`](scope-orchestration.md#recordhealthcheckbulkqueryrewriter) | Rewrites validated query templates for scope-wide execution |
| L4 | [`RecordHealthCheckScopePlanner`](scope-orchestration.md#recordhealthcheckscopeplanner) | Resolves selections, applicability, prerequisites, and request budgets |
| L4 | [`RecordHealthCheckScopeResultSupport`](scope-orchestration.md#recordhealthcheckscoperesultsupport) | Converts internal outcomes, diagnostics, display text, and safe URLs |

### L3 - Evaluators

| Level | Class | One-line purpose |
| --- | --- | --- |
| L3 | [`RecordHealthCheckFormulaEvaluator`](evaluators.md#recordhealthcheckformulaevaluator) | Formula Evaluation Type and shared formula resolution |
| L3 | [`RecordHealthCheckSoqlEvaluator`](evaluators.md#recordhealthchecksoqlevaluator) | Single-query Evaluation Type |
| L3 | [`RecordHealthCheckCompareQueriesEvaluator`](evaluators.md#recordhealthcheckcomparequeriesevaluator) | Compare-two-queries Evaluation Type |
| L3 | [`RecordHealthCheckApexEvaluator`](evaluators.md#recordhealthcheckapexevaluator) | Loads and runs a `RecordHealthCheckRule` plugin |
| L3 | [`RecordHealthCheckQueryEvaluatorSupport`](evaluators.md#recordhealthcheckqueryevaluatorsupport) | Shared query execution and empty-result handling |
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
| L2 | [`RecordHealthCheckConfigService`](configuration-and-validation.md#recordhealthcheckconfigservice) | Load Check Sets/Rules; definitions; runtime validation adapter |
| L2 | [`RecordHealthCheckRuleValidator`](configuration-and-validation.md#recordhealthcheckrulevalidator) | Shared per-Evaluation-Type Rule field validation |
| L2 | [`RecordHealthCheckMetadataValidator`](configuration-and-validation.md#recordhealthcheckmetadatavalidator) | Deploy-time / CI audit of Custom Metadata |
| L2 | [`RecordHealthCheckConfigValidator`](configuration-and-validation.md#recordhealthcheckconfigvalidator) | Shared validation helpers (object names, plugins, JSON, tokens) |
| L2 | [`RecordHealthCheckConstants`](configuration-and-validation.md#recordhealthcheckconstants) | Allowed values and numeric limits (single source of truth) |
| L2 | [`RecordHealthCheckReasonCodes`](configuration-and-validation.md#recordhealthcheckreasoncodes) | Selected stable reason-code helpers |
| L2 | [`RecordHealthCheckSetAvailability`](configuration-and-validation.md#recordhealthchecksetavailability) | Whether an object has active/inactive Check Sets |
| L2 | [`RecordHealthCheckComparisonEngine`](shared-services.md#recordhealthcheckcomparisonengine) | Operators, equality, empty/null behavior |
| L2 | [`RecordHealthCheckDisplayFormat`](shared-services.md#recordhealthcheckdisplayformat) | Renders Found and Expected values for the card chips |
| L2 | [`RecordHealthCheckSoqlTemplate`](shared-services.md#recordhealthchecksoqltemplate) | Safe SOQL preparation (`WITH USER_MODE`, row limit, keyword rejection) |
| L2 | [`RecordHealthCheckValueResolver`](shared-services.md#recordhealthcheckvalueresolver) | Extract, convert, and compare query values |
| L2 | [`RecordHealthCheckDescribeCache`](shared-services.md#recordhealthcheckdescribecache) | Schema describe cache for the current transaction |
| L2 | [`RecordHealthCheckEvaluatorException`](shared-services.md#recordhealthcheckevaluatorexception) | Evaluator failure carrying a reason code |
| L2 | [`RecordHealthCheckAccess`](shared-services.md#recordhealthcheckaccess) | Diagnostics Custom Permission check |
| L2 | [`RecordHealthCheckLogger`](shared-services.md#recordhealthchecklogger) | `[RHC]` debug lines and ERROR log platform events |
| L2 | `RecordHealthCheckDiagnosticTrace` | Builds authorized Rule configuration and resolution snapshots for browser diagnostics |
| L2 | `RecordHealthCheckSettingsProvider` | Resolves lifecycle and diagnostic publication settings |
| L2 | [`RecordHealthCheckTemplateService`](merge-token-classes.md#recordhealthchecktemplateservice) | Parse, validate, and resolve namespaced merge tokens and their optional fallback text |
| L2 | `RecordHealthCheckTemplateValueResolver` | Resolves namespace-specific values from the runtime merge context |
| L2 | [`RecordHealthCheckTokenRegistry`](merge-token-classes.md#recordhealthchecktokenregistry) | Allowed token namespaces and properties |
| L2 | [`RecordHealthCheckToken`](merge-token-classes.md#recordhealthchecktoken) | One parsed merge token |
| L2 | [`RecordHealthCheckTokenIssue`](merge-token-classes.md#recordhealthchecktokenissue) | One token validation failure |
| L2 | [`RecordHealthCheckMergeContext`](merge-token-classes.md#recordhealthcheckmergecontext) | Values available while resolving merge tokens |
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

| L1 | [`RecordHealthCheckDefinition`](results-and-plugins.md#recordhealthcheckdefinition--recordhealthcheckdefinitionresponse) | One Rule row in the Lightning definition response |
| L1 | [`RecordHealthCheckDefinitionResponse`](results-and-plugins.md#recordhealthcheckdefinition--recordhealthcheckdefinitionresponse) | Check Set display settings + ordered Rule definitions |
| L1 | [`RecordHealthCheckAdminDetail`](results-and-plugins.md#recordhealthcheckadmindetail) | Structured diagnostics detail on a Rule result |
| L1 | [`RecordHealthCheckValueSource`](results-and-plugins.md#recordhealthcheckvaluesource) | Structured Found/Expected diagnostic detail |
| L1 | [`RecordHealthCheckRule`](results-and-plugins.md#recordhealthcheckrule-interface) | Interface every Apex evaluator plugin implements |

### Example plugins

| Level | Class | One-line purpose |
| --- | --- | --- |
| Example | [`AccountHasRecentActivityCheck`](results-and-plugins.md#accounthasrecentactivitycheck) | Shipped Apex Rule: recent Task/Event activity on an Account |

---


## Related

- [Architecture](../framework/architecture.md)
- [Apex Rule contract](../evaluation/apex-rule-contract.md)
- [Apex API](../../api/apex-api.md)
- [Flow actions](../../integration/flow-actions.md)
