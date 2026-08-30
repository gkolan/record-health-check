# Package Apex implementation reference

Use this reference to locate the production Apex class responsible for a package behavior while
changing or reviewing the repository source. These classes are implementation details, not public
Apex APIs for subscriber code.

This folder is only for developers changing the package source.

> [!IMPORTANT]
> **Audience: package maintainers and Salesforce developers.** This class-level reference is not a
> Setup or Flow walkthrough. Administrators should use the Flow, configuration, and evaluation
> guides; subscriber developers should use the public Apex API or Apex Check contract.

> [!NOTE]
> On this page, find the production Apex class responsible for an internal Record Health Check
> behavior. Use this while reading or changing the package source. Writing a custom Apex Check? Start with
> [Apex Check contract](../../developer-guides/write-an-apex-check.md), not this folder.

This guide covers every production class under
`packages/record-health-check/force-app/main/default/classes/` (excluding
`*Test` classes and coverage helpers). The Apex Check installed with the package and the examples
used only by repository integration tests are identified separately in
[Results, definitions, and plugins](./results-and-plugins.md).

This is an internal package-maintenance catalog. It is not a list of Apex APIs available to custom
code in your org. After installing the namespaced unlocked package, a top-level `public` class can
be used only by other classes inside the package. Apex created in your org can call only the
`global` types documented by the [Apex API](../../developer-guides/run-from-apex.md) and
[Apex Check contract](../../developer-guides/write-an-apex-check.md).

Unless noted otherwise, Record Health Check service classes are `public with sharing`. Result and definition
data holders, the plugin interface, merge-token helpers, and a few other types are plain `public`
classes (no sharing keyword) because they hold data or interfaces rather than query Salesforce
records.

## Codebase size and verification

The current source contains 223 packaged Apex classes, including 114 test classes. Tests and contract
support cover dynamic SOQL, formulas, metadata validation, security boundaries, bulk execution,
asynchronous entry points, integrations, and failure diagnostics; those classes are verification
surface rather than ordinary health-check runtime behavior.

The class and test counts are checked automatically by `npm run check:docs`. Physical line counts
are intentionally omitted because they change with implementation and documentation comments and
are not a supported package contract.

## Recommended path

The L5 through L1 labels describe which internal classes can call which other classes. L5 receives
requests from Lightning, Flow, or Apex and calls lower layers. L1 holds results, requests, and
public contracts and does not call back into the higher layers. These labels are not package
versions or steps an administrator must learn.

| Step | Layer | Page |
| ---: | --- | --- |
| 1 | L5 Entry points | [Entry points](./entry-points.md) |
| 2 | L4 Scope orchestration | [Scope orchestration](./scope-orchestration.md) |
| 3 | L3 Evaluators | [Evaluators](./evaluators.md) |
| 4 | L2 Configuration and validation | [Configuration and validation](./configuration-and-validation.md) |
| 5 | L2 Shared evaluation services | [Shared services](./shared-services.md) |
| 6 | L2 Merge-token classes | [Merge-token classes](./merge-token-classes.md) |
| 7 | L2-L5 Supporting classes used while a Check runs | [Run-support classes](./runtime-support.md) |
| 8 | L1 Results, definitions, and plugins | [Results and plugins](./results-and-plugins.md) |
| 9 | Plugin verification test | [Plugin verification](../../developer-guides/verify-an-apex-check.md) |
| 10 | Test-only access / architecture policy | [Contributor policy: Apex test-only access](../../quality-gates/apex-test-only-access.md) |

## How to use this guide

| You want to… | Start here |
| --- | --- |
| Scan classes by layer | [Class index by level](#class-index-by-level) |
| Understand who calls whom | [Layers at a glance](#layers-at-a-glance) |
| Read a detailed description | The layer sections below |
| Call Record Health Check from Apex or Flow | [Apex API](../../developer-guides/run-from-apex.md) or [Flow actions](../../flow-guides/action-inputs-and-outputs.md); do not call internal classes from this folder |
| Implement `RecordHealthCheckPlugin` | Plugin interface classes, then [Apex reference](../../developer-guides/write-an-apex-check.md) |

Each detailed class entry uses the same order: its job, Apex type and sharing mode, behavior, key
methods or fields, important limits, and related classes. This makes it easier to compare the
documentation with the source.

## Layers at a glance

Higher levels call lower levels. Lower levels never call back up. This matches
[Reference: Architecture § 5. Layers](../framework.md#5-layers); the sections below use
the same L5→L1 numbering so you can move between the two pages without re-deriving the mapping.

| Level | Layer | Classes (summary) |
| --- | --- | --- |
| L5 | Entry points | `RecordHealthCheck`, Flow actions, `RecordHealthCheckController`, plus lifecycle publication and run context |
| L4 | Scope orchestration | `RecordHealthCheckScopePipeline`, `RecordHealthCheckFieldPlanner`, `RecordHealthCheckFormulaFieldScanner` |
| L3 | Evaluators | Formula, Query, Compare two queries, Apex evaluators + query support |
| L2 | Shared services | Config, validation, SOQL templates, comparison, values, merge tokens, describe cache, logger, access, constants |
| L1 | Results and definitions | Result data holders, definition responses, plugin interface and context |

Configuration, shared evaluation services, and merge tokens each get their own H2 section below for
readability, but all three live at **L2** in the architecture layer diagram.

## Class index by level

### L5 - Entry points

| Level | Class | One-line purpose |
| --- | --- | --- |
| L5 | [`RecordHealthCheck`](./entry-points.md#recordhealthcheck) | Public Apex `evaluate(request)` API |
| L5 | [`RecordHealthCheckController`](./entry-points.md#recordhealthcheckcontroller) | Aura-enabled API for the Lightning card |
| L5 | [`RecordHealthCheckRunCheckFlowAction`](./entry-points.md#recordhealthcheckruncheckflowaction) | Packaged Flow action "Run Record Health Check" |
| L5 | [`RecordHealthCheckRunSetFlowAction`](./entry-points.md#recordhealthcheckrunsetflowaction) | Packaged Flow action "Run Record Health Check Set" |
| L5 | [`RecordHealthCheckRunCheckAgentAction`](./entry-points.md#recordhealthcheckruncheckagentaction) | Native Agentforce action for one exact Check and record |
| L5 | [`RecordHealthCheckRunSetAgentAction`](./entry-points.md#recordhealthcheckrunsetagentaction) | Native Agentforce action for one exact Check Set and record |
| L5 | [`RecordHealthCheckAgentRestResource`](./entry-points.md#recordhealthcheckagentrestresource) | Versioned read-only REST boundary for approved agent tools |
| L5 | `RecordHealthCheckQueueable` | Runs one bounded Check Set group in the background; results are not saved unless the caller publishes events or custom code saves them |
| L5 | `RecordHealthCheckBatch` | Splits an explicit list of 1–2,000 IDs into scopes of 1–200 records that share the Batch job Run ID; defaults to 100 |
| L5 | `RecordHealthCheckScheduled` | Runs the same saved list of IDs daily by launching `RecordHealthCheckBatch` |
| L5 | `RecordHealthCheckAsyncSupport` | Shared validation and request construction for asynchronous adapters |
| L5 | `RecordHealthCheckFlowSupport` | Shared Flow input normalization, result alignment, and summary status logic |
| L5 | `RecordHealthCheckFlowGroupExecutor` | Shared normalized grouping and engine execution for both Flow actions |
| L5 | [`RecordHealthCheckLifecyclePublisher`](./entry-points.md#recordhealthchecklifecyclepublisher) | Optional Set Run and Check Result platform events |
| L5 | [`RecordHealthCheckEventId`](./entry-points.md#recordhealthcheckeventid) | Unique, bounded lifecycle-event identifier generation |
| L5 | [`RecordHealthCheckValidateMetadataAction`](./entry-points.md#recordhealthcheckvalidatemetadataaction) | Administrator Flow action for configuration validation |
| L5 | [`RecordHealthCheckRunContext`](./entry-points.md#recordhealthcheckruncontext) | Run id, source, and timing for one evaluation |
| L5 | [`RecordHealthCheckSetPicklist`](./entry-points.md#recordhealthchecksetpicklist) | App Builder dynamic picklist for Check Set Developer Name |

### L4 - Run coordination

| Level | Class | One-line purpose |
| --- | --- | --- |
| L4 | [`RecordHealthCheckScopePipeline`](./scope-orchestration.md#recordhealthcheckscopepipeline) | Resolves a selection and evaluates the complete ordered record scope |
| L4 | [`RecordHealthCheckEvaluatorRegistry`](./scope-orchestration.md#recordhealthcheckevaluatorregistry) | Maps Evaluation Type values to a common scope evaluator contract |
| L4 | [`RecordHealthCheckFieldPlanner`](./scope-orchestration.md#recordhealthcheckfieldplanner) | Safe record-field planning for scope evaluation |
| L4 | [`RecordHealthCheckFormulaFieldScanner`](./scope-orchestration.md#recordhealthcheckformulafieldscanner) | Extracts selectable record paths from formula expressions |
| L4 | [`RecordHealthCheckBulkQuerySupport`](./scope-orchestration.md#recordhealthcheckbulkquerysupport) | Executes supported query templates once for a complete scope |
| L4 | [`RecordHealthCheckBulkQueryRewriter`](./scope-orchestration.md#recordhealthcheckbulkqueryrewriter) | Rewrites validated query templates for scope-wide execution |
| L4 | [`RecordHealthCheckScopePlanner`](./scope-orchestration.md#recordhealthcheckscopeplanner) | Resolves selections, applicability, prerequisites, and request budgets |
| L4 | [`RecordHealthCheckScopeResultSupport`](./scope-orchestration.md#recordhealthcheckscoperesultsupport) | Converts internal outcomes, diagnostics, display text, and safe URLs |

### L3 - Evaluators

| Level | Class | One-line purpose |
| --- | --- | --- |
| L3 | [`RecordHealthCheckFormulaEvaluator`](./evaluators.md#recordhealthcheckformulaevaluator) | Formula Evaluation Type and shared formula resolution |
| L3 | [`RecordHealthCheckSoqlEvaluator`](./evaluators.md#recordhealthchecksoqlevaluator) | Single-query Evaluation Type |
| L3 | [`RecordHealthCheckCompareQueriesEvaluator`](./evaluators.md#recordhealthcheckcomparequeriesevaluator) | Compare-two-queries Evaluation Type |
| L3 | [`RecordHealthCheckApexEvaluator`](./evaluators.md#recordhealthcheckapexevaluator) | Loads and runs a `RecordHealthCheckPlugin` |
| L3 | [`RecordHealthCheckQueryEvaluatorSupport`](./evaluators.md#recordhealthcheckqueryevaluatorsupport) | Shared query execution and empty-result handling |
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
| L2 | [`RecordHealthCheckConfigService`](./configuration-and-validation.md#recordhealthcheckconfigservice) | Loads Check Sets and Checks, builds definitions, and reports configuration problems found while a Check runs |
| L2 | [`RecordHealthCheckValidator`](./configuration-and-validation.md#recordhealthcheckvalidator) | Shared per-Evaluation-Type Check field validation |
| L2 | [`RecordHealthCheckMetadataValidator`](./configuration-and-validation.md#recordhealthcheckmetadatavalidator) | Deploy-time / CI audit of Custom Metadata |
| L2 | [`RecordHealthCheckConfigValidator`](./configuration-and-validation.md#recordhealthcheckconfigvalidator) | Shared validation helpers (object names, plugins, JSON, tokens) |
| L2 | [`RecordHealthCheckConstants`](./configuration-and-validation.md#recordhealthcheckconstants) | Allowed values and numeric limits (single source of truth) |
| L2 | [`RecordHealthCheckReasonCodes`](./configuration-and-validation.md#recordhealthcheckreasoncodes) | Selected stable reason-code helpers |
| L2 | [`RecordHealthCheckSetAvailability`](./configuration-and-validation.md#recordhealthchecksetavailability) | Whether an object has active/inactive Check Sets |
| L2 | [`RecordHealthCheckComparisonEngine`](./shared-services.md#recordhealthcheckcomparisonengine) | Operators, equality, empty/null behavior |
| L2 | [`RecordHealthCheckDisplayFormat`](./shared-services.md#recordhealthcheckdisplayformat) | Renders Found and Expected values for the card chips |
| L2 | [`RecordHealthCheckSoqlTemplate`](./shared-services.md#recordhealthchecksoqltemplate) | Safe SOQL preparation (`WITH USER_MODE`, row limit, keyword rejection) |
| L2 | [`RecordHealthCheckValueResolver`](./shared-services.md#recordhealthcheckvalueresolver) | Extract, convert, and compare query values |
| L2 | [`RecordHealthCheckDescribeCache`](./shared-services.md#recordhealthcheckdescribecache) | Schema describe cache for the current transaction |
| L2 | [`RecordHealthCheckEvaluatorException`](./shared-services.md#recordhealthcheckevaluatorexception) | Evaluator failure carrying a reason code |
| L2 | [`RecordHealthCheckAccess`](./shared-services.md#recordhealthcheckaccess) | Diagnostics Custom Permission check |
| L2 | [`RecordHealthCheckLogger`](./shared-services.md#recordhealthchecklogger) | `[RHC]` debug lines and ERROR log platform events |
| L2 | `RecordHealthCheckDiagnosticTrace` | Builds authorized Check configuration and resolution snapshots for browser diagnostics |
| L2 | `RecordHealthCheckSettingsProvider` | Resolves lifecycle and diagnostic publication settings |
| L2 | [`RecordHealthCheckTemplateService`](./merge-token-classes.md#recordhealthchecktemplateservice) | Parse, validate, and resolve namespaced merge tokens and their optional fallback text |
| L2 | `RecordHealthCheckTemplateValueResolver` | Resolves namespace-specific values available while merge text is built |
| L2 | [`RecordHealthCheckTokenRegistry`](./merge-token-classes.md#recordhealthchecktokenregistry) | Allowed token namespaces and properties |
| L2 | [`RecordHealthCheckToken`](./merge-token-classes.md#recordhealthchecktoken) | One parsed merge token |
| L2 | [`RecordHealthCheckTokenIssue`](./merge-token-classes.md#recordhealthchecktokenissue) | One token validation failure |
| L2 | [`RecordHealthCheckMergeContext`](./merge-token-classes.md#recordhealthcheckmergecontext) | Values available while resolving merge tokens |
| L2 | `RecordHealthCheckComparisonDisplay` | Converts comparison operands into stable display content |
| L2 | `RecordHealthCheckConfigFindingMapper` | Converts validation findings into configuration results returned during a run |
| L2 | `RecordHealthCheckDefinitionLoader` | Loads and validates Lightning definition metadata |
| L2 | `RHCDefinitionDependencyIdentity` | Resolves prerequisite identity without namespace collisions |
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
| L1 | `RecordHealthCheckScope` | The records a custom Check is asked about, plus its parameters. Read-only |
| L1 | `RecordHealthCheckOutcome` | What a custom Check returns for one record: a verdict and its values |
| L1 | `RecordHealthCheckValue` | A typed Found or Expected value with one stored format per data type |
| L1 | `RecordHealthCheckEvaluationResult` | Machine-readable status, identity, reason, and typed values |
| L1 | `RecordHealthCheckResultDisplay` | Optional human-facing rendering derived from evaluation data |
| L1 | `RecordHealthCheckResultItem` | Evaluation data plus optional display content |
| Internal | `RecordHealthCheckInternalResult` | Package-only evaluator handoff used before the public result split |
| L1 | `RecordHealthCheckSelection` | Requires exactly one qualified Check name or one qualified Check Set name |
| L1 | `RecordHealthCheckQualifiedIdentity` | Shared trim and length validation for qualified metadata identities |
| L1 | `RecordHealthCheckOptions` | Result, publication, and run correlation options |
| L1 | `RecordHealthCheckExecutionOrigin` | Typed caller attribution for lifecycle events |
| L1 | `RecordHealthCheckRequest` | Qualified selection and detached record scope |
| L1 | `RecordHealthCheckResponse` | Shared Check and Check Set response envelope |
| L1 | `RecordHealthCheckRunSummary` | Terminal status counts for one response |
| L1 | `RecordHealthCheckContractTest` | Extensible plugin verification test for bulk growth and forbidden writes |
| L1 | `RecordHealthCheckContractTestData` | Plugin-author supplied scopes and controlled least-privilege test data |
| L1 | `RecordHealthCheckStatus` | The status values: PASS, FAIL, SKIPPED, UNABLE_TO_EVALUATE, ERROR |
| L1 | `RecordHealthCheckResultMode` | Selects how much data a result carries |
| L1 | `RecordHealthCheckEventPublication` | Whether a programmatic run publishes lifecycle Platform Events |
| L1 | `RecordHealthCheckPluginDispatch` | Runs a custom Check and verifies that it did not change Salesforce records, make callouts, send email, publish events, or start asynchronous work |

| L1 | [`RecordHealthCheckDefinition`](./results-and-plugins.md#recordhealthcheckdefinition--recordhealthcheckdefinitionresponse) | One Check row in the Lightning definition response |
| L1 | [`RecordHealthCheckDefinitionResponse`](./results-and-plugins.md#recordhealthcheckdefinition--recordhealthcheckdefinitionresponse) | Check Set display settings + ordered Check definitions |
| L1 | [`RecordHealthCheckAdminDetail`](./results-and-plugins.md#recordhealthcheckadmindetail) | Structured diagnostics detail on a Check result |
| L1 | [`RecordHealthCheckValueSource`](./results-and-plugins.md#recordhealthcheckvaluesource) | Structured Found/Expected diagnostic detail |
| L1 | [`RecordHealthCheckPlugin`](./results-and-plugins.md#recordhealthcheckplugin-interface) | Interface every Apex evaluator plugin implements |

### Example plugins

| Level | Class | One-line purpose |
| --- | --- | --- |
| Example | [`AccountHasRecentActivityCheck`](./results-and-plugins.md#accounthasrecentactivitycheck) | Shipped Apex Check: recent Task/Event activity on an Account |

---


## Related

- [Architecture](../framework.md)
- [Apex Check contract](../../developer-guides/write-an-apex-check.md)
- [Apex API](../../developer-guides/run-from-apex.md)
- [Flow actions](../../flow-guides/action-inputs-and-outputs.md)
