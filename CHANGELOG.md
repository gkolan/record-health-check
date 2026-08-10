# Release notes

Record Health Check follows [Semantic Versioning](https://semver.org/) for package artifacts. This
page describes the Framework a new installer receives. It intentionally avoids historical
interfaces and product-generation terminology.

## Current release

**Subscriber install:** promoted unlocked package `Record Health Check@2.0.1-11`. Stable `04t` and
install URLs are recorded in [`config/package-releases.json`](config/package-releases.json).

- Production and Sandbox install links: see `installUrl` in `config/package-releases.json`
- Current released candidate: `Record Health Check@2.0.1-11`.

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
- Plugin dispatch rejects DML, callouts, email, event publication, and asynchronous work.
- Public results protect access details; authorized Show Diagnostics viewers can investigate the
  specific restricted reason.
- Merge tokens use explicit namespaces, typed fallbacks, bounded resolution, and safe Action URL
  handling.
- Checks per run, records per request, query rows, FormulaEval work, token count, and completed text
  all have documented limits.

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
