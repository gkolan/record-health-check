# Release notes

Record Health Check follows [Semantic Versioning](https://semver.org/) for package artifacts. This
page describes the Framework a new installer receives. It intentionally avoids historical
interfaces and product-generation terminology.

## Current release

**Subscriber install:** promoted unlocked package `Record Health Check@2.0.3-1`. Stable `04t` and
install URLs are recorded in [`config/package-releases.json`](config/package-releases.json).

- Production and Sandbox install links: see `installUrl` in `config/package-releases.json`
- Current released candidate: `Record Health Check@2.0.3-1`.

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

- Record-page placements declare **When Checks Run** in App Builder. Manual cards perform no
  Salesforce server work until Run; Automatic cards defer definition loading and evaluation until
  browser idle. The component fails closed if the App Builder mode and Check Set mode differ.

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
[Install and verify](docs/installation/install-and-verify.md). For the public contracts, use the
[Apex API](docs/api/apex-api.md), [Flow actions](docs/integration/flow-actions.md), and
[Apex Check plugin reference](docs/reference/evaluation/apex-check-contract.md).

## Unreleased

Target package version: **2.0.4**.

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
- [Support](SUPPORT.md) map for Issues, Discussions, Slack, and security advisories.

### Changed

- Install documentation states the namespaced unlocked package as the supported subscriber path,
  with concrete Production and Sandbox install URLs for promoted `04tak000000ZXVlAAO`, and source
  deploy reserved for contribution and scratch-org workflows.
- Configuration identity guidance lives under
  [Configuration identity](docs/reference/framework/configuration-identity.md).
- Technical references are grouped under `docs/reference/{framework,evaluation,contracts,apex}/`
  instead of a flat `reference-*.md` list. Old GitHub blob URLs to the previous filenames will not
  redirect.

Earlier package builds under `2.0.0-*` candidates are listed in `sfdx-project.json` package
aliases. Dated section history starts with this release notes format.
