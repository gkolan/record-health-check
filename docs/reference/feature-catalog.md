# Feature catalog

> [!NOTE]
> Use this catalog to find setup instructions and supported behavior. It describes this checkout;
> [version availability](../install/choose-a-package-version.md#documentation-and-installed-version)
> identifies additions that are not yet in the published package.

Record Health Check is a read-only evaluation framework. It explains record health; it does not
change business records, block saves, or keep a permanent result history by itself.

## Configure Check Sets and Checks

| Capability | Supported behavior | Detailed guide |
| --- | --- | --- |
| Custom Metadata configuration | Check Sets define one record-page review; Checks define the questions in that review. Configuration can move through normal Salesforce metadata processes. | [Configure Check Sets and Checks](../build-checks/configure-check-sets-and-checks.md) |
| Record-object matching | A Check Set names one Salesforce object. The App Builder picker shows active Check Sets matching the record page's object. | [Configure the component](../lightning-record-page/configure-the-component.md) |
| Automatic and Manual runs | Automatic (`RUN_ON_LOAD`) cards evaluate after loading. Manual (`RUN_ON_REQUEST`) cards wait for Run and preserve that boundary until the first completed run. | [Choose how Checks run](../start-here/choose-how-checks-run.md) |
| Card presentation | Configure title, subtitle, summary, all-at-once or one-by-one reveal, passed and skipped visibility, Found/Expected disclosure, and Run/Rerun button labels, icon, and visibility. | [Check Set fields](./custom-metadata/check-set-fields.md) |
| Ordered Checks and categories | Evaluation Order controls stable execution order. Category groups summaries without changing the outcome. | [Check fields](./custom-metadata/check-fields.md) |
| Applicability | A Formula, count Query, both, or neither can decide whether a Check applies. A non-applicable Check is `SKIPPED`, not `PASS`. | [Configure Checks](../build-checks/configure-check-sets-and-checks.md#step-6-decide-when-a-check-should-run) |
| Prerequisites | A Check can wait for another Check and skip when the required result does not permit evaluation. Dependency cycles are rejected. | [Check fields: Prerequisite Check](./custom-metadata/check-fields.md#prerequisite-check-prerequisitecheck__c) |
| Stop after a system error | A Check Set can stop launching later Checks after a system error while preserving results already completed. | [Check Set fields](./custom-metadata/check-set-fields.md#stop-after-a-system-error-stoponsystemerror__c) |
| Configuration validation action | **Validate Record Health Check Configuration** audits Check and Check Set metadata and returns error, warning, and JSON report outputs. | [Flow action inputs and outputs](../flow-guides/action-inputs-and-outputs.md#validate-record-health-check-configuration) |

## Evaluate record health

| Evaluation Type | Supported behavior | Detailed guide |
| --- | --- | --- |
| Formula (`FORMULA`) | Evaluate current-record and supported relationship fields with Salesforce FormulaEval. Declare the result type, decide the Pass condition, and optionally calculate separate display values. | [Formula reference](./evaluation/formula.md) |
| Query (`QUERY`) | Run bounded user-mode SOQL for one value, any-row, all-rows, list membership, or list comparison behavior. Configure no-row, empty-value, and maximum-row outcomes explicitly. | [Query reference](./evaluation/query.md) |
| Compare two queries (`COMPARE_TWO_QUERIES`) | Compare two counts, scalar values, or lists, including overlap, contains-all, and exact-list behavior. | [Compare two queries](./evaluation/compare-two-queries.md) |
| Apex plugin (`APEX`) | Run reviewed bulk Apex implementing `RecordHealthCheckPlugin`, returning exactly one typed outcome for every requested record ID. | [Write an Apex Check](../developer-guides/write-an-apex-check.md) |
| Plugin contract verification | Extend the packaged contract-test support class to verify bulk query growth, complete scope coverage, permission behavior, and prohibited side effects. | [Verify an Apex Check](../developer-guides/verify-an-apex-check.md) |
| Bulk query planning | Formula, Query, and Apex paths share bounded loading and evaluation across as many as 200 requested records. | [Bulk-query grammar](./evaluation/bulk-query-grammar.md) |

## Explain and display results

| Capability | Supported behavior | Detailed guide |
| --- | --- | --- |
| Honest outcomes | Results distinguish `PASS`, `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, and `ERROR`. Failed, Warning, and Info are severity presentations of `FAIL`. | [Statuses and labels](./results/statuses-and-labels.md) |
| Stable Reason Codes | Programmatic reasons distinguish business outcomes from access, configuration, data, and framework problems. | [Reason Codes](./results/reason-codes.md) |
| Found and Expected values | Show raw evaluation evidence or administrator-authored display formulas/text without changing the verdict. | [Display Found and Expected](./configuration/display-found-and-expected.md) |
| Display formats | Auto, Number, Currency, Percent, Ratio as Percent, Checkbox, Date, Date/Time, Text, and Raw formats follow the running user's locale where applicable. | [Display formats](./configuration/display-found-and-expected.md#choosing-a-format) |
| Lists and multiple currencies | List previews are bounded. Each value retains its own available currency identity; formatting does not convert currencies. | [List previews](./configuration/display-found-and-expected.md#list-previews) |
| Guidance and actions | Failure, unable, applicability, and fix messages support safe merge tokens. Optional Action Label and Action URL provide a read-only next step. | [Configure action links](../build-checks/add-fix-link.md) |
| Merge tokens | Record, result, Check, Check Set, and run values can be inserted into messages and safe links with typed formatting and explicit fallbacks. | [Merge syntax](./merge-syntax/README.md) |
| Diagnostics | Authorized viewers can see restricted diagnostic evidence and produce a redacted support report. Ordinary users receive safe guidance without internal details. | [Browser diagnostics](../diagnostics/browser-console.md) |
| Localization and accessibility | Labels can use Salesforce translations; values follow locale and timezone rules. The card supports keyboard use, responsive layout, SLDS 1, SLDS 2, and the active Salesforce theme. | [Languages and locales](./platform/languages-and-locales.md), [theme and accessibility](../lightning-record-page/theme-and-accessibility.md) |

## Run from Salesforce and integrations

| Entry point | Supported behavior | Detailed guide |
| --- | --- | --- |
| Lightning record page | One component runs the selected Check Set for the current record. It is intentionally unavailable on App and Home pages because those pages have no record context. | [Lightning record page](../lightning-record-page/README.md) |
| Save and `RefreshView` refresh | Automatic cards refresh after a standard record save or refresh notification. Manual cards refresh only after their first completed Run. Stale and overlapping runs cannot replace newer results. | [Record-save refresh](../lightning-record-page/configure-the-component.md#record-save-refresh) |
| Flow | Separate actions run one Check or one Check Set and return stable status, count, reason, and JSON outputs. A third action validates configuration. | [Flow guides](../flow-guides/README.md) |
| Synchronous Apex | `RecordHealthCheck.evaluate` accepts a typed request for one Check or Check Set. Result modes provide complete evaluation (`EVALUATION`), evaluation with display (`EVALUATION_WITH_DISPLAY`), or summary plus actionable results (`SUMMARY`). | [Run from Apex](../developer-guides/run-from-apex.md) |
| Queueable Apex | Submit up to 200 known record IDs for later execution and monitor the Apex job ID. | [Queueable](../developer-guides/async-apex/queueable.md) |
| Batch Apex | Evaluate larger record selections in bounded scopes, with query and explicit-ID submission options. | [Batch](../developer-guides/async-apex/batch.md) |
| Scheduled Apex | Start reviewed Queueable or Batch work on a Salesforce schedule. There is no direct Future-method API; existing Future callers should move to Queueable. | [Scheduled](../developer-guides/async-apex/scheduled.md), [replace Future](../developer-guides/async-apex/replace-future-with-queueable.md) |
| Agentforce | Packaged agent actions run one Check or Check Set and return the versioned diagnostic contract without exposing restricted record details. | [Agentforce actions](../developer-guides/agentforce-and-mcp/agentforce-actions.md) |
| REST agent tool | A versioned REST adapter exposes Check and Check Set operations for authorized integration users. | [Agent tool REST API](../developer-guides/agentforce-and-mcp/agent-tool-rest-api.md) |
| MCP service | The companion Node service maps MCP tools to the versioned REST contract, with documented authorization, timeouts, and deployment checks. | [Deploy the MCP service](../developer-guides/agentforce-and-mcp/deploy-mcp-service.md) |
| Versioning and correlation | Contract versions protect long-lived consumers. Run IDs, correlation IDs, and execution origins connect work and diagnostics across transaction boundaries. | [Contracts](./contracts/README.md), [integration options](../developer-guides/integration-options.md) |

## Publish and receive results

| Capability | Supported behavior | Detailed guide |
| --- | --- | --- |
| Event publication modes | `NONE`, `ACTIONABLE`, and `ALL` decide whether no Check Result events, only results needing attention, or every result is published. | [Choose where results go](../start-here/choose-where-results-go.md) |
| Check Result event (`Record_Health_Check_Result__e`) | Publishes one selected Check outcome with versioned identity, status, evidence, and diagnostic fields. | [Check Result metadata](./platform-event-metadata/check-result.md) |
| Check Set Run event (`Record_Health_Check_Set_Run__e`) | Publishes run lifecycle and summary counts, including the completion heartbeat used with actionable-only publication. | [Check Set Run metadata](./platform-event-metadata/check-set-run.md) |
| Error Log event (`Record_Health_Check_Log__e`) | Publishes restricted operational incidents only when enabled and authorized. | [Error Log metadata](./platform-event-metadata/error-log.md) |
| Flow, Apex, and Pub/Sub consumers | Subscribers can route events to approved storage, automation, or external systems. Events are not permanent storage themselves. | [Save results](../save-results/README.md), [Pub/Sub](../developer-guides/receive-events-with-pub-sub.md) |

## Security and safety

| Capability | Supported behavior | Detailed guide |
| --- | --- | --- |
| User-context access | Business-record reads use user mode, and Apex plugins run with sharing. The package does not grant access to subscriber business objects or fields. | [Security and data access](../architecture/security-and-data-access.md) |
| Purpose-specific access | **Record Health Check Card User**, **Record Health Check User**, **Record Health Check Admin**, **Record Health Check MCP Integration**, **Record Health Check Diagnostics Viewer**, and **Record Health Check Error Log Publisher** separate card, automation, administration, integration, diagnostic-viewing, and restricted logging duties. | [Permission Sets](./permission-sets.md) |
| Run and diagnostic permissions | Record Health Check Run authorizes execution. Record Health Check View Diagnostics authorizes restricted diagnostic detail when the Check Set also enables it. | [Custom Permissions](./custom-permissions.md) |
| Plugin side-effect protection | Plugin dispatch rejects detected record writes, callouts, email, Queueable, and Future work. Platform Event, Batch, and Scheduled prohibitions also require contract tests, static analysis, and review because Apex exposes no complete transaction counter for them. | [Verify an Apex Check](../developer-guides/verify-an-apex-check.md) |
| Safe templates and links | Query templates, merge tokens, and Action URLs are validated and bounded. Unsupported or inaccessible inputs fail closed instead of producing a guessed verdict. | [Merge syntax](./merge-syntax/README.md), [bulk-query grammar](./evaluation/bulk-query-grammar.md) |
| Namespaced configuration | Qualified API names and foreign-package field namespaces are preserved exactly across package and subscriber metadata. | [Names and API identities](./configuration/names-and-api-identities.md) |
| Request and field limits | Record, Check, query-row, FormulaEval, token, field-size, and output limits are documented and enforced. | [Field limits](./configuration/field-limits.md) |

## Package, examples, and operations

| Capability | Supported behavior | Detailed guide |
| --- | --- | --- |
| Immutable 2GP package versions | Install a specific `04t` version and test that same version in a sandbox before upgrading production. | [Choose a package version](../install/choose-a-package-version.md) |
| Install, upgrade, and uninstall | Guides cover sandbox-first installation, permission assignment, configuration backup, N-1 upgrade rehearsal, and safe uninstall preparation. | [Install](../install/README.md) |
| Packaged examples | Four active Example Check Sets contain 50 Checks across Account, Contact, and Opportunity. Matching docs explain Formula, Query, Compare two queries, Apex, applicability, display, and remediation patterns. | [Explore installed examples](../install/explore-installed-examples.md), [examples library](../examples/README.md) |
| Production operations | Back up subscriber-owned Custom Metadata, monitor events and jobs, test least-privilege users, and preserve evidence for support. | [Production operations](../production-operations/README.md) |

## Explicit boundaries and non-features

| Boundary | Current behavior | Detailed guide |
| --- | --- | --- |
| No record mutation or enforcement | The framework advises. Use Validation Rules, Flow, or Apex when Salesforce must block or perform an action. | [When to use Record Health Check](../start-here/when-to-use-record-health-check.md) |
| No automatic history store | API responses and optional Platform Events are transient until an approved subscriber saves them. | [When to use Platform Events](../save-results/when-to-use-platform-events.md) |
| No generic freshness evaluator | Express freshness through Formula, Query, Compare two queries, or reviewed Apex using explicit timestamps or provenance. | [Derived values and freshness](./platform/limitations.md#derived-values-snapshots-and-freshness) |
| Formula globals | `$User`, `$Profile`, `$Setup`, `$Permission`, and `$CustomMetadata` are not treated as checked-record fields and are not supported in a Pass Condition. | [Formula limitations](./platform/limitations.md#formula-planning-and-evaluation) |
| Polymorphic owners | User-only owner formulas cannot reliably evaluate Queue or Group owners and return unable instead of guessing. | [Polymorphic relationships](./platform/limitations.md#polymorphic-relationships) |
| Account activity example | The packaged Apex example counts only completed Tasks and Events whose `WhatId` is the Account. It does not count Contact `WhoId` activity or shared relations. | [Activity limitations](./platform/limitations.md#activities-what-who-and-shared-relations) |
| Person Accounts | Generic Contact-count examples can count the underlying PersonContact. Use explicit Person Account applicability and fields. | [Person Accounts](./platform/limitations.md#person-accounts) |
| Currency conversion | Display preserves available currency identity but does not perform corporate, dated, or Advanced Currency Management conversion. | [Currency limitations](./platform/limitations.md#currency-dates-and-display) |
| Save refresh events | Browser save refresh uses the non-publishing lifecycle; it does not publish Check Result or Check Set Run events unless a normal configured run requests publication. | [Record-save refresh](../lightning-record-page/configure-the-component.md#record-save-refresh) |
| Unsupported query shapes | Unsafe or unsupported SOQL shapes, inaccessible schema, row-cap overflow, and unprovable values return unable rather than a partial verdict. | [Platform limitations](./platform/limitations.md#query-and-data-model-boundaries) |

## Related

- [Documentation home](../README.md)
- [Build Checks](../build-checks/README.md)
- [Developer guides](../developer-guides/README.md)
- [Reference](./README.md)
- [Platform limitations](./platform/limitations.md)
