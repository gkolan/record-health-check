# Release runtime matrix

This is the minimum release contract for Record Health Check. It applies to every package release,
including patch builds. A missing, skipped, timed-out, inconclusive, or stale result is a failure.
Static analysis and unit tests do not substitute for a live Salesforce result.

The machine-readable dimensions are in
[`config/release-runtime-matrix.json`](../../config/release-runtime-matrix.json). The CI guard
`npm run check:release-runtime-matrix` rejects missing dimensions, missing evidence files, weakened
workflow wiring, or incomplete package-install verification.

## Version identity

The package version is `major.minor.patch.build`. This corrective release is `2.0.7.1`, upgrading
from the stable `2.0.6.2` package. A package candidate is identified by its exact `04t` version ID and Git commit SHA.
Evidence from another build, branch head, pull-request merge commit, or package ID cannot satisfy a
candidate's gate.

## Gate sequence

| Stage | Required result | Failure behavior |
| --- | --- | --- |
| Pull request and committed source | Every tracked check in `.github/workflows/ci.yml` passes | Do not merge or call the source CI-ready |
| Hosted source validation | Namespaced and no-namespace jobs pass for the exact commit | Do not create a package version |
| Package creation | Code coverage, artifact membership, version identity, and dependency checks pass | Do not publish a candidate for subscriber testing |
| Clean subscriber installation | Exact candidate installs and all installed-surface gates pass | Do not promote |
| Subscriber upgrade | `2.0.6.2` upgrades to the exact candidate; customer-owned configuration survives; all installed-surface gates pass again | Do not promote |
| Promotion | Exact-commit source workflow and exact-candidate subscriber workflow are both successful | Promotion command must fail closed |
| Release publication | Release registry, changelog, install links, tag, and rollback information identify the promoted `04t` | Do not announce the release |

Package creation and promotion require a clean Git worktree and verify hosted GitHub Actions
evidence before invoking a Salesforce create or promote mutation. A locally green run is useful
diagnostic evidence, but it cannot replace the hosted jobs. Every required artifact upload uses
`if-no-files-found: error`; a successful test without its retained evidence is a failed release gate.

## Salesforce environment matrix

Source validation must cover all four combinations:

| Namespace topology | Lightning security mode | Browser engines |
| --- | --- | --- |
| `rhc` namespaced | Lightning Web Security | Chromium and Firefox |
| `rhc` namespaced | Lightning Locker | Chromium and Firefox |
| No namespace | Lightning Web Security | Chromium and Firefox |
| No namespace | Lightning Locker | Chromium and Firefox |

Each org must be newly created from the tracked scratch definition. The workflow records the org
shape, deploy result, test result, and browser artifacts. Reusing an org is not evidence for the
hosted release gate.

## Evaluation and entry-point matrix

Every entry point must execute a Check Set containing all four evaluation types:

- Formula
- Query
- Compare Two Queries
- Apex

The required entry points are:

| Entry point | Required live proof |
| --- | --- |
| Lightning Web Component, manual | Component renders without a page-level or component spinner, Run completes, and all four types return results |
| Lightning Web Component, run on load | Initial shell remains quiet, deferred run completes, and no manual Run button is shown |
| Apex API | Public Apex API returns all four evaluation types |
| Flow | A real Flow interview invokes the packaged action and returns all four types |
| REST/MCP | Authenticated REST request and MCP contract return all four types in both namespace shapes |
| Native Agentforce actions | The packaged Check Set action crosses the invocable boundary and accounts for every Check in the four-type set |
| Platform Events | `ALL` publication emits one Check Result per executed Check and one Set Run event, and subscriber-owned triggers receive them |
| Queueable | Job completes and its Check Set covers all four types |
| Batch | Job completes and its Check Set covers all four types |
| Scheduled | Scheduled adapter launches the work, it completes, and its Check Set covers all four types |

An Apex unit test that calls the shared service directly does not replace the Flow, REST, browser,
or asynchronous adapter test. Every adapter must cross its real platform boundary.

## Lightning lifecycle matrix

Browser validation must reject uncaught JavaScript errors, Salesforce component error dialogs, the
reported `Invalid contextElement` failure, incomplete runs, and persistent spinners. It covers:

- a configured component in Lightning App Builder;
- a component with no selected Check Set in App Builder;
- a saved record page in normal view mode;
- manual and run-on-load components on the same page;
- initial load without a page-level loading overlay;
- RefreshView registration and refresh execution;
- record-to-record navigation without a full browser reload;
- component disconnect/reconnect without stale handlers or duplicate work;
- LWS and Locker in both namespace shapes;
- Chromium and Firefox;
- administrator and restricted-permission personas;
- post-install and post-upgrade rendering.

The builder canvas must remain inert: it may show configuration guidance, but it must not run a
record check, show an operational spinner, register an invalid RefreshView context, or require a
record ID. At runtime, the component renders its shell first and defers on-load work; it does not
put a loading overlay on the record page.

## Apex and server-side gates

Both namespace shapes run two explicit, reconciled inventories: package-only tests before fixtures,
then the final package-plus-integration identity set after the harness is deployed.
`npm run test:apex:exact` inventories every repository class with a real class-level `@IsTest`
annotation, passes every discovered class explicitly to Salesforce, and reconciles the returned
methods and class names against that inventory. A missing, unexpected, skipped, failing, or
unreported class fails the gate.

The raw Salesforce result and reconciliation verdict are kept for 90 days as four artifacts:
namespaced package, namespaced full, no-namespace package, and no-namespace full. The 18 test
identities intentionally overlaid by fixture-aware integration variants are pinned in
`config/apex-test-overlays.json`; the package variant runs in the first phase and the integration
variant runs in the second. Any new duplicate identity or missing side of an approved overlay fails
before Salesforce is called. The gate includes:

- CRUD, field-level security, sharing, and restricted-user behavior;
- injection-resistant dynamic SOQL and merge-token validation;
- bulk input and governor-limit behavior;
- all public Apex entry points and invocable actions;
- Queueable, Batch, Scheduled, REST, and platform-event behavior;
- positive, negative, null, malformed, unauthorized, and partial-failure paths;
- package namespace resolution and no-namespace portability;
- blocking Code Analyzer `AppExchange`, `Recommended:Security`, and every Flow Scanner rule for
  package, integration, and subscriber-harness source, plus an all-rules advisory report;
- exact package test coverage, with no coverage bypass.

The installed-package tests repeat the public API, Flow interview, four evaluation types,
REST/MCP, Queueable, Batch, Scheduled, and LWC gates after both a clean installation and the
upgrade. The matrix remains blocked unless the subscriber-owned Flow and its Apex interview test
exist; an Apex-only substitute does not satisfy the Flow entry-point gate.

## Security release contract

Security is checked at source, deployed-source, clean-install, and upgrade boundaries. A scanner
result is not accepted if its engine logs contain a processing exception, even when the scanner
returns exit code zero and reports zero violations.

### Apex execution and data access

- Runtime service and adapter classes declare `with sharing`; packaged invocable classes, methods,
  request types, response types, and variables are `global` so the exact subscriber-namespace
  boundary is compiled and exercised rather than assumed.
- Every execution surface requires the packaged Run custom permission. Restricted-user tests must
  prove denial through the Apex API, Flow action, REST/MCP adapter, Agentforce action, Queueable,
  Batch, and Scheduled submission, with no record-health detail in the denial response.
- Customer-record queries use `WITH USER_MODE` or `AccessLevel.USER_MODE`, Schema-derived object and
  field identifiers, and bind variables. Admin-authored query templates cannot request
  `WITH SYSTEM_MODE`, add executable syntax through merge tokens, or access an undisclosed field.
- The single system-mode query is limited to reading this package's public Custom Metadata
  definitions in `RecordHealthCheckScopePlanner`; it does not read customer records. Any additional
  `SYSTEM_MODE` use requires a reviewed source-policy change and new restricted-user evidence.
- Formula, relationship, currency, polymorphic, aggregate, grouped, dual-query, and plugin paths
  enforce object access, field access, sharing, type compatibility, bounded scope, query-row, query,
  CPU, heap, serialization, and response-size ceilings. Tests cover bulk, null, malformed, inaccessible,
  partial-failure, and exception paths.
- The package does not grant object or field access to customer business objects. The executing
  user's permissions remain in control, and subscriber plugin code runs in its declared sharing
  context.

### LWC, browser, and Lightning security

- Shipped LWC source is checked by Salesforce's LWC lint rules, the Locker security rules, the
  release compatibility scanner, ESLint Recommended, RetireJS Recommended, Jest, SLDS 1/2 linting,
  and real browsers in both Lightning Web Security and Lightning Locker.
- Shipped code cannot use page-owned `document` DOM, `innerHTML`, `outerHTML`, `shadowRoot`, dynamic
  code evaluation, browser storage, worker escape APIs, Aura globals, manual DOM, or executable URL
  schemes. Guided-action URLs accept only an in-app absolute path or explicit HTTPS URL.
- RefreshView must retain both supported registration protocols: the LWS component form first and
  the Locker host-plus-bound-handler fallback. Registration failure is fail-open for rendering, and
  disconnect unregisters the accepted handler.
- Initial configuration and run-on-load work is deferred until after the shell renders. No
  component spinner or page-level loading overlay is permitted on initial load, in App Builder, or
  during automatic execution. Progress after a deliberate user click stays inside the clicked
  action control.
- App Builder previews are server-inert even when Salesforce supplies a sample record ID: configured and unconfigured
  previews make no `RecordHealthCheckController` request, load no definitions, evaluate no Check,
  and render no runtime action.
- Browser tests fail on any uncaught page error, Salesforce component-error dialog, incomplete
  result count, persistent spinner, duplicate automatic run, stale handler, full reload during
  record navigation, or the reported `Invalid contextElement` signature.

### REST, MCP, Agentforce, Flow, async, and events

- REST accepts only authenticated callers with the Run custom permission, JSON content type, a
  bounded request body, an approved operation, one syntactically valid record ID, exact qualified
  metadata identity, and a bounded safe correlation ID. It returns versioned, redacted validation,
  authorization, limit, or execution envelopes rather than raw exceptions.
- MCP and Agentforce inputs use the same exact qualified identity contract. Agentforce/MCP-backed
  invocable methods are global, run as the authenticated user, use sharing, and return aligned,
  bounded output. Flow tests must use a real Flow interview; a direct Apex call is supplemental.
- Queueable, Batch, and Scheduled adapters recheck authorization at both submission and execution
  boundaries, defensively copy and bound explicit record populations, and publish no event unless
  the caller requests an allowed publication mode. Their release tests capture every result event,
  resolve each event's exact Check identity back to Custom Metadata, and require the resulting set
  to contain `APEX`, `COMPARE_TWO_QUERIES`, `FORMULA`, and `QUERY`; job completion or event counts
  alone are insufficient evidence.
- Platform Events contain stable IDs, counts, status, reason code, source, and record identity but no
  raw exception or restricted diagnostic detail. Publication is chunked, publish failures are
  inspected, subscriber triggers are exercised, and recursion is suppressed.

### Static-analysis and exception integrity

- The blocking Apex/XML profile runs Salesforce Code Analyzer's `AppExchange`,
  `Recommended:Security`, and `flow:all` selectors. Shipped JavaScript runs `eslint:Recommended`
  and `retire-js:Recommended`; the all-rules reports remain retained advisory evidence.
- Analyzer JSON must be complete and every analyzer log must be free of engine processing errors and
  null-pointer failures. This prevents a scanner crash from becoming a false green release result.
- `code-analyzer.yml` has an exact approved list of four file-scoped `ProtectSensitiveData` false
  positives. Each permits one finding and carries a specific reason. A new path, a second finding,
  a widened limit, or globally disabling that security rule fails CI and release preflight.
- Inline Apex suppressions remain visible beside the guarded statement and are reviewed with the
  code. Hosted reports, scanner versions, configurations, logs, and HTML/JSON results are retained
  for 90 days against the exact commit.

## Upgrade and data-preservation gates

The upgrade org starts with the promoted `2.0.6.2` package. Before upgrading, the workflow creates
subscriber-owned Check Sets and Checks and records their identities and values. It then:

1. deploys only the subscriber-owned preservation fixture and proves the stable `2.0.6.2` global
   Apex API can execute it;
2. installs the exact `2.0.7.1` candidate using the tracked upgrade mode;
3. verifies the installed package version ID;
4. proves the subscriber-owned metadata is unchanged;
5. reassigns and verifies permissions;
6. deploys the candidate-only subscriber harness, then runs Apex, asynchronous, REST/MCP, Flow,
   Agentforce, Platform Event, App Builder, restricted-user, and browser gates under both LWS and
   Locker;
7. retains install requests, test output, browser traces, and the exact before/after Custom
   Metadata preservation snapshot for 90 days.

A clean install cannot satisfy the upgrade gate. An upgrade that succeeds but loses configuration
or fails an entry point is a failed release.

## Supply-chain, metadata, and documentation gates

The release also requires:

- pinned Node, Salesforce CLI, Java, Python, and Code Analyzer policy versions;
- production and development dependency audits with no known vulnerabilities; the patched
  `@babel/core` transitive override is lockfile-pinned and must remain compatible with the Salesforce
  LWC compiler and Jest suite;
- package-boundary, manifest, converted-artifact, permission, namespace-token, API-surface, query,
  field-limit, XML, formatting, lint, SLDS, JavaScript, and documentation checks;
- every intended Custom Metadata record in both the manifest and physical package artifact;
- permanent regression tests for every escaped defect;
- release notes that describe user-visible behavior, upgrade impact, and rollback steps;
- retained evidence tied to the exact commit and `04t` candidate.

Secrets, unavailable scratch capacity, browser installation failures, missing Flow-generation
capability, unavailable hosted validation, and rate limits are blockers. Workflows must not convert
those conditions into warnings or skipped success.

## Evidence and exceptions

Evidence belongs in hosted workflow logs and retained artifacts for the exact source revision.
Record deploy IDs, Apex run IDs, org shape, security mode, browser traces, package install request
IDs, before/after metadata snapshots, candidate ID, and workflow URL.

There is no informal release exception. Reducing supported scope or waiving a gate requires a
reviewed source change to this contract and the machine-readable matrix before a candidate exists;
it must not be done to make a failing candidate pass.

## Related

- [Package testing and upgrades](./package-testing-and-upgrades.md)
- [Platform conformance](./platform-conformance.md)
- [Releasing](../../.github/RELEASING.md)
