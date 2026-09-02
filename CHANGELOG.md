# Release notes

Record Health Check follows [Semantic Versioning](https://semver.org/) for package artifacts. This
page describes the Framework a new installer receives. It intentionally avoids historical
interfaces and product-generation terminology.

## Current release

**Subscriber install:** promoted unlocked package `Record Health Check@2.0.6-2`. Stable `04t` and
install URLs are recorded in [`config/package-releases.json`](./config/package-releases.json).

> **Known issue:** unlocked `2.0.0-*` package tests can fail when they are selected explicitly,
> included in Run All Tests, or source-deployed into a customized org and subscriber validation
> rules, triggers, or flows reject Framework fixture DML. Ordinary subscriber `RunLocalTests` skips
> the installed package's namespaced tests. Confirm the failing stack before changing automation;
> version 2.0.6 removes business-object DML from packaged tests.

- Production and Sandbox install links: see `installUrl` in `config/package-releases.json`
- Current stable release: `Record Health Check@2.0.6-2` (`04tak000000eM53AAE`).
- Previous stable release: `Record Health Check@2.0.5-1` (`04tak000000eIO1AAM`).

### Evaluation and integration

- Formula, Query, Compare two queries, and bulk Apex Check plugins use one bounded evaluation
  pipeline for Lightning, Apex, and Flow.
- `RecordHealthCheck.evaluate(RecordHealthCheckRequest)` returns ordered, typed evaluation results
  with optional display content.
- Apex plugins implement `RecordHealthCheck`, receive one `RecordHealthCheckScope`, and return
  one `RecordHealthCheckOutcome` per requested record ID.
- Flow actions expose Check and Check Set evaluation without requiring custom Apex.
- Optional Set Run, Check Result, and Error Log Platform Events carry independent machine-readable
  contract versions.

### Trust and safety

- Business-record SOQL runs in user mode. Administrator-authored templates reject unsafe query
  shapes and system-mode execution.
- Plugin dispatch detects and rejects DML, callouts, email, Queueable, and Future work. Apex exposes
  no reliable counter for Platform Event publication, Batch, or Scheduled work, so those plugin
  prohibitions rely on contract tests, static analysis, and human review.
- Public results protect access details; authorized Show Diagnostics viewers can investigate the
  specific restricted reason.
- Merge tokens use explicit namespaces, typed fallbacks, bounded resolution, and safe Action URL
  handling.
- Checks per run, records per request, query rows, FormulaEval work, token count, and completed text
  all have documented limits.

### Lightning performance

- Superseded during 2.0.4 development: an earlier implementation declared **When Checks Run** in
  App Builder and failed closed on a mode mismatch. The current component uses the selected Check
  Set as the single source of truth and loads lightweight shell configuration on initial render.
  Manual cards defer definitions and evaluation until Run; Automatic cards defer those operations
  until browser idle.

### Administrator experience

- Lightning App Builder provides a Check Set picker filtered to the record-page object.
- The card distinguishes Pass, Fail (Failed / Warning / Info by severity), Skipped, Unable to Check,
  and System Error outcomes. Setup and API use Unable to Evaluate (`UNABLE_TO_EVALUATE`) and `ERROR`
  for the last two statuses.
- Found and Expected values support locale-aware Number, Currency, Percent, Ratio as Percent,
  Checkbox, Date, Date/Time, Text, and Raw display formats.
- Optional remediation text and safe links guide a user without changing Salesforce data.
- Teaching examples and deterministic demo data cover Account, Contact, and Opportunity scenarios.
  The Framework package ships four Example Check Sets (`Example_…`, card titles prefixed with
  `Example:`) plus matching integration fixtures.

### Engineering gates

- The package manifest and Permission Sets are checked against shipped metadata.
- Apex tests use the shared TestDataFactory for Salesforce record creation.
- Salesforce Code Analyzer, ESLint, the SLDS linter, formatting, documentation structure, links,
  field limits, query shapes, Framework version language, Apex coverage, and deployment validation are release
  gates.

For installation and verification, start with
[Install and verify](./docs/install/install-in-a-sandbox.md). For the public contracts, use the
[Apex API](./docs/developer-guides/run-from-apex.md), [Flow actions](./docs/flow-guides/action-inputs-and-outputs.md), and
[Apex Check plugin reference](./docs/developer-guides/write-an-apex-check.md).

## Version 2.0.6.3 hotfix

### Fixed

- Record Health Check now registers its save-driven RefreshView handler with the protocol required
  by either Lightning Web Security or Lightning Locker. A RefreshView registration failure no
  longer prevents the component from loading.

## Version 2.0.6

Released package version: **2.0.6.2** (`04tak000000eM53AAE`). Salesforce reports 99% package
coverage and no skipped validation. Use the [2.0.6.2 sandbox install
link](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tak000000eM53AAE) or the
[2.0.6.2 production install
link](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tak000000eM53AAE).

### Added

- Lightning record pages now reevaluate visible results after a standard record save or
  `RefreshView` notification. Automatic Check Sets refresh immediately; Manual Check Sets preserve
  their initial user-run boundary and refresh only after the first completed Run.
- Added a platform conformance gate for hierarchy paths, signed decimal and currency values, nulls,
  current-versus-snapshot behavior, timestamps, and mixed-record bulk evaluation.
- Added an isolated two-package conformance gate using the `rhc` and Salesforce CPQ `SBQQ`
  namespaces. It proves a foreign namespaced field through Formula, Query, and record merge-token
  evaluation without making CPQ a product dependency.

### Changed

- Packaged Apex tests no longer persist Account, Contact, Opportunity, Task, Event, or Case fixture
  records. Persistence-dependent coverage remains in the clean-org integration harness, preventing
  subscriber validation rules, triggers, and flows from breaking package installation or explicit
  packaged-test runs.
- Reviewed package upgrade commands now use Salesforce `Mixed` mode. Components that are safe to
  remove do not remain behind and break compilation, while components Salesforce cannot safely
  delete are deprecated.
- Save-driven Lightning refreshes use the non-publishing browser lifecycle. They coalesce bursts,
  replace stale in-flight results, and never publish Check Result or Check Set Run lifecycle events.

### Fixed

- A result from a superseded Lightning run can no longer overwrite results started after a record
  save or an in-place record change.

### Documentation

- Added an execution-context war room for differences between Lightning, Flow, Queueable, Batch,
  and Scheduled Apex, including access, identity, timezone, and asynchronous transaction evidence.
- Documented that fields owned by another installed package must retain their complete namespace
  prefix in formulas, SOQL, Source Query Field, and record merge tokens. Record Health Check does
  not infer or retry an unqualified API name.
- Clarified that derived-value freshness is an organization-specific policy expressed with existing
  Formula, Query, Compare Two Queries, or subscriber Apex evidence rather than a new core evaluator.
- Documented record-save refresh behavior, lifecycle-event boundaries, platform conformance
  evidence, and the separation between packaged tests and persistence-dependent integration tests.

### Verification

- Added regression coverage confirming that existing Formula-global masking keeps `$User`,
  `$Profile`, `$Setup`, `$Permission`, and other FormulaEval globals out of the checked-record field
  plan. Unsupported globals continue to fail closed with `UNABLE_TO_EVALUATE` and
  `INVALID_FORMULA`.
- The foreign-namespace gate passed all three focused Apex scenarios in a disposable namespaced
  scratch org with Record Health Check and Salesforce CPQ installed.
- The exact working-tree package source passed a check-only deployment to an `rhc` namespaced
  scratch org. All 695 local Apex tests passed with no component errors. The 2.0.6.2 candidate
  creation reported 99% package coverage, and the published Framework coverage gate reports 99.57%
  with every executable production class above 98%.
- Package-version creation completed without skipped validation. Salesforce reports 99% package
  coverage and confirms that the package is org independent.
- The immutable-package upgrade rehearsal installed stable 2.0.5.1 and then candidate 2.0.6.2 in a
  no-namespace subscriber scratch org. All six subscriber smoke tests passed, and the
  subscriber-owned Check Set and Check Custom Metadata records remained available after upgrade.
- The focused Code Analyzer scan reported zero violations. Local release checks cover package
  conversion, manifests, boundaries, query shapes, permissions, XML, documentation, LWC tests, MCP
  tests, and published quality metrics. Hosted Salesforce validation remains required after push.

## Version 2.0.5.1

Released package version: **2.0.5.1** (`04tak000000eIO1AAM`).

### Added

- Added MCP deployment and configuration safeguards, consistent Salesforce failure responses, and
  tests for simultaneous requests, timeouts, authorization, availability, and protocol behavior.

### Changed

- Browser diagnostics now keep a completely passing run concise and warning-free. Per-Check console
  groups exclude Pass results; ordinary business Fail and Skipped outcomes remain concise; full
  **Advanced diagnostics** and support-report bundles are reserved for Unable to Check and System
  Error outcomes.
- Show Diagnostics no longer overrides the Check Set's configured visibility for passed or skipped
  rows. Administrators do not see hidden healthy rows reappear as apparent problems merely because
  troubleshooting is enabled.
- Record Health Check now applies the same stricter request limits when it loads relationship
  fields, runs queries and Apex Checks, compares values, and handles multiple currencies across
  Lightning, Apex, Flow, background, Agentforce, REST, and MCP requests.
- Formula field planning now treats a relationship path as one field reference. A formula such as
  `Parent.Name = "Required Parent"` no longer fails field planning merely because `Parent` or `Name`
  was also misread as a root field; null relationships now reach normal Salesforce formula
  evaluation and can therefore produce the configured business verdict.
- Package, subscriber-validation, permission, manifest, API, documentation, and quality-metric
  gates now cover the new MCP and core-framework surfaces.

### Fixed

- Corrected the released version 1 agent-tool response schema so its strict validators accept the four
  diagnostic summary fields already returned by the Apex REST adapter since 2.0.4.2. The schema,
  examples, MCP validator, and disclosure guidance now describe the same response surface.
- Corrected diagnostics support guidance so expected business failures are not described as
  technical incidents or sources of full support bundles.

### Documentation

- Clarified the browser-console behavior for Pass, Fail, Skipped, Unable to Check, and System Error
  so administrators know which outcomes produce technical support evidence.

## Version 2.0.4.2

Released package version: **2.0.4.2**.

### Fixed

- Flow Check Set actions now fail closed when an aligned result is missing and preserve stable
  authorization, validation, and limit categories instead of flattening engine failures into a
  generic execution response.
- Compare Two Queries now applies the same pre-execution multi-currency safety checks as Query
  Checks, and aggregate queries that return multiple values require an explicit source-field alias.
- Error Log publication is now an explicit, default-off Check Set choice. Missing configuration
  fails closed, and publishers still require the separate Error Log Publisher Permission Set.
- Async adapters reject missing or object-less Check Set configuration, App Builder returns no
  unrelated Check Sets without a record-object context, and one rejected Lightning Check can no
  longer unlock a concurrent run while other evaluations remain active.
- Flow documentation now describes whole-request rejection above 25 active Checks and identifies
  Flow result JSON as evaluation-only rather than authorized display data.
- Lifecycle events now report framework version `2.0.4`; the release gate also verifies that the
  Apex event publisher stays synchronized with the package version.
- Scope-wide Query Check classification now ignores `LIMIT`, `ORDER BY`, and correlation-like text
  inside string literals or nested subqueries. Nested-only record correlation fails closed instead
  of rewriting the outer query from the wrong parenthesis depth.
- Transaction planning now reserves both SOQL executions for a Query Check whose expected value
  comes from `COMPARISON_QUERY`, preventing a late governor-limit failure after evaluation begins.
- Explicit per-Check metadata loading now includes `Category__c`, keeping the advertised complete
  Check object safe for presentation-token consumers without an unqueried-field exception.
- Finalized result merge tokens now preserve the literal text value `"null"`; only an actual Apex
  null resolves blank or activates a configured fallback.
- Apex tests no longer receive an implicit run-permission grant. Namespaced restricted-persona
  conformance now proves the actual Custom Permission boundary across Apex, Lightning, Flow, and
  asynchronous entry points.
- Query runtime now repeats multi-currency authoring safeguards before SOQL executes. Legacy or
  bypassed metadata cannot run an ungrouped Currency aggregate, rely on a semi-join-only ISO filter,
  or compare a Currency field with a fixed threshold that has no declared ISO basis.
- MCP concurrency exhaustion now returns the versioned structured `LIMIT` contract with safe retry
  guidance instead of an unclassified tool error.
- Lifecycle guidance now identifies `USER_INITIATED` card completion events as client-attested
  advisory notifications and requires server re-evaluation for compliance-sensitive actions.
- The packaged Account-owner example now uses a correlated Query Check against `User` instead of
  asking Formula evaluation to resolve User-only fields through polymorphic `Owner`; inactive,
  missing, and Queue owners fail closed. Its display guidance no longer reintroduces unsupported
  polymorphic `Owner.Name` or `Owner.Manager.Name` paths.
- The packaged Channel Partner Governance example now uses a correlated parent-count Query and a
  static display label, so non-applicable Accounts skip cleanly instead of becoming inconclusive
  while hydrating `ParentId` or `Parent.Name`.
- The Agent REST wire handler now sends its explicitly null-suppressed contract body instead of
  allowing Salesforce to auto-serialize unused Apex fields as `null`. The strict MCP adapter maps
  exhausted Salesforce authorization, request-limit, contract, and availability failures to safe
  structured outcomes.
- The MCP runtime now uses a digest-pinned, non-root distroless Node 22 image without package-manager
  layers. Its High/Critical artifact gate retains exact, documented reachability exceptions for four
  unreachable glibc/OpenSSL code paths; unmatched findings still fail the build. The production npm
  dependency audit is clear, and the exact built-image result remains a hosted gate after push.
- Authorized card diagnostics now render the nested admin-detail message returned by the public Apex
  display contract instead of leaving the troubleshooting panel empty.
- User-initiated Lightning runs now send completed results in the nested Apex result-item contract,
  so enabled Check Result and Check Set Run events contain the evaluated Checks and accurate counts.
- Text values beginning with `(` or `[` are now rendered as text instead of being mistaken for an
  Apex list and failing the Check during display formatting.
- Plain Base64/Blob fields selected by Query Checks are now refused during describe validation with
  `FIELD_TYPE_NOT_SUPPORTED`, before binary data can reach query comparison, result serialization,
  display, or diagnostics. Purpose-built Apex must retain user-mode visibility and return only a
  redacted business outcome.
- Checks whose required field or relationship path cannot be resolved now return
  `UNABLE_TO_EVALUATE` with `FIELD_NOT_RESOLVED` or `RELATIONSHIP_NOT_RESOLVED` instead of silently
  dropping the path from the record query. This is a visible reason-code behavior change for
  configurations that reference schema absent from the current org.
- Query failures no longer depend on English exception-message matching. Root objects and plain
  selected field paths in the documented flat-query subset are describe-validated before both
  single and bulk execution; other execution failures fall back to `INVALID_SOQL_TEMPLATE`.
- Query comparisons now refuse reachable mixed currency units with `MIXED_CURRENCY`. Fixed
  thresholds against Currency fields require a declared ISO basis, and metadata validation rejects
  Currency aggregates that discard unit evidence instead of claiming a runtime aggregate guard.
  The framework does not convert currencies; Formula and subscriber-plugin arithmetic remain
  explicitly outside this guard.
- Query row-cap outcomes now use `ROW_LIMIT_EXCEEDED` instead of `GOVERNOR_LIMIT_RISK`. This is an
  immediate public reason-code change: consumers matching the old literal must adopt the new code.
  `GOVERNOR_LIMIT_RISK` remains reserved for invalid or unsafe configuration/transaction pressure;
  no compatibility window emits both codes for one outcome.
- `NO_ROWS_RETURNED`, `VALUE_IS_EMPTY`, `APPLICABILITY_NOT_MET`, and `INVALID_SOQL_TEMPLATE` remain
  stable public literals and now have canonical declarations in `RecordHealthCheckReasonCodes`.

- Formula field planning now recognizes validated Salesforce polymorphic colon references such as
  `Owner:User.IsActive` and retains the explicitly selected relationship type during dependency
  expansion.
- Formula planning rejects type-specific polymorphic fields that flat SOQL cannot select without
  `TYPEOF`, preventing one invalid path from aborting the shared Check Set query.
- Formula globals such as `$User`, `$Profile`, `$Setup`, and `$Permission` no longer contribute
  bogus root-record fields to the generated query.

### Verification

- Added a repeatable, cross-transaction scratch-org gate for the reported active-User-owned Lead
  checkbox formula configuration. The integration fixture is excluded from subscriber packaging.
- Focused namespaced tests in a Person Account and multi-currency scratch org prove that reachable
  mixed units, unsafe aggregates, semi-join-only ISO filters, and fixed thresholds without an ISO
  basis fail closed. The framework still does not convert currencies. The complete packaged
  Person-versus-Business Account example matrix remains a separate live verification item.
- The exhaustive query-verdict gate now launches its fifth 50-Check page. Its reviewed namespaced
  baseline covers 114 query-bearing Checks and 173 query templates, including fail-closed diagnostic
  fixtures and the corrected owner and channel-partner examples.

## [2.0.3] - 2026-08-11

### Changed

- Prevented long Check Set titles and unbroken text from overlapping Run and Rerun controls across
  label, icon, hidden, and combined display modes.
- Improved Run/Rerun configuration labels, descriptions, help text, defaults, and list views.
- Removed Category values from packaged examples and clarified Category guidance.
- Added subscriber demo list views and tracked Production and Sandbox installation URLs.
- Updated the subscriber-facing package version name to `Version 2.0.3`.

## [2.0.2] - 2026-08-10

### Changed

- Improved the subscriber-facing package version name and description shown during installation.

## [2.0.1] - 2026-08-10

### Added

- Added Check Set and Lightning App Builder controls for labeled, label-only, compact icon-only, or
  hidden Run/Rerun actions. Hidden automatic actions release their header space; manual Check Sets
  cannot hide their only run action. Empty automatic Check Sets no longer show a decorative Rerun,
  and metadata validation warns when hidden automatic cards have lifecycle publication enabled but
  no in-card deliberate publication path.

## [2.0.0] - 2026-08-04

### Added

- Four Demo Check Sets (`Example_…`, card titles prefixed with `Demo:`) shipped with the Framework
  package for Account, Contact, and Opportunity teaching scenarios.
- Documentation surfaces for security and data access, glossary, compatibility, data model,
  localization, FAQ, native-Salesforce comparison, uninstall/rollback, and production operations.
- [Support](./SUPPORT.md) map for Issues, Discussions, Slack, and security advisories.

### Changed

- Install documentation states the namespaced unlocked package as the supported subscriber path,
  with concrete Production and Sandbox install URLs for promoted `04tak000000ZXVlAAO`, and source
  deploy reserved for contribution and scratch-org workflows.
- Configuration identity guidance lives under
  [Configuration identity](./docs/reference/configuration/names-and-api-identities.md).
- Technical references are grouped under `docs/reference/{framework,evaluation,contracts,apex}/`
  instead of a flat `reference-*.md` list. Old GitHub blob URLs to the previous filenames will not
  redirect.

Earlier package builds under `2.0.0-*` candidates are listed in `sfdx-project.json` package
aliases. Dated section history starts with this release notes format.
