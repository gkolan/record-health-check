# Release notes

Record Health Check follows [Semantic Versioning](https://semver.org/) for package artifacts. This
page describes the Framework a new installer receives. It intentionally avoids historical
interfaces and product-generation terminology.

## Current release

### Evaluation and integration

- Formula, Query, Compare two queries, and bulk Apex Rule plugins use one bounded evaluation
  pipeline for Lightning, Apex, and Flow.
- `RecordHealthCheck.evaluate(RecordHealthCheckRequest)` returns ordered, typed evaluation results
  with optional display content.
- Apex plugins implement `RecordHealthCheckRule`, receive one `RecordHealthCheckScope`, and return
  one `RecordHealthCheckOutcome` per requested record ID.
- Flow actions expose Rule and Check Set evaluation without requiring custom Apex.
- Optional Set Run, Rule Result, and Error Log Platform Events carry independent machine-readable
  contract versions.

### Trust and safety

- Business-record SOQL runs in user mode. Administrator-authored templates reject unsafe query
  shapes and system-mode execution.
- Plugin dispatch rejects DML, callouts, email, event publication, and asynchronous work.
- Public results protect access details; authorized Show Diagnostics viewers can investigate the
  specific restricted reason.
- Merge tokens use explicit namespaces, typed fallbacks, bounded resolution, and safe Action URL
  handling.
- Rules per run, records per request, query rows, FormulaEval work, token count, and completed text
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
  The Framework package itself ships without business-policy Check Sets or Rules; optional starter
  metadata lives in RecordHealthCheck-Examples and integration fixtures.

### Engineering gates

- The package manifest and Permission Sets are checked against shipped metadata.
- Apex tests use the shared TestDataFactory for Salesforce record creation.
- Salesforce Code Analyzer, ESLint, the SLDS linter, formatting, documentation structure, links,
  field limits, query shapes, product language, Apex coverage, and deployment validation are release
  gates.

For installation and verification, start with
[Install and verify](docs/installation/02-install-and-verify.md). For the public contracts, use the
[Apex API](docs/api/apex-api.md), [Flow actions](docs/integration/flow-actions.md), and
[Apex Rule plugin reference](docs/reference/reference-apex.md).
