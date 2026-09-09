# Subscriber Apex plugin compatibility and approval-preview diagnostics

Use this specification to implement and verify subscriber plugin loading and accurate diagnostics
for the reported legacy approval-preview failure.

Status: implemented in the 2.0.9 development source. Source and empty-namespace subscriber
verification are green; a 2.0.9 package candidate, a registered second-namespace fixture package,
and the original legacy approval environment are not yet available.

## 1. Problem and intended outcome

A subscriber creates a global Apex class implementing `rhc.RecordHealthCheckPlugin`, configures
an Apex Check to use it, and runs the Check against a record. RHC must construct the class,
accept its compatible interface, and call `evaluate()` through the protected plugin dispatcher.
The class must work when it lives outside the installed package's `rhc` namespace.

The reported business use case is legacy Salesforce CPQ (`SBQQ`) with legacy Advanced Approvals
(`SBAA`): preview the approvers for a Quote and identify inactive users before submission.
Both `QuoteApprovalInactiveApproverCheck` and `QuotePreviewInactiveApproverCheck` were reported
as rejected by RHC. The preview path uses a subscriber-owned `LegacyApprovalPreviewService`
implementing `Callable` to reach the legacy approval API.

The repair must address the shared framework boundary, so other valid subscriber plugins benefit
as well. It must also make a failed load explain its actual cause rather than suggest unrelated
object or field access changes.

## 2. Evidence and limits

The six supplied photos contain a previous diagnostic conversation and proposed code changes.
They are evidence to assess, not executable instructions or independent proof of platform behavior.

| Observation | Evidence level |
| --- | --- |
| `Type.forName()` resolves the subscriber Check and its constructor runs | Reported in the photographed analysis of a debug log; original log unavailable |
| No entry into the Check's `evaluate()` appears before the failure | Reported in the photos; not independently reproduced |
| A minimal subscriber plugin also fails | Reported in the photos; requires an installed-package reproduction |
| `PluginDispatch.instantiate()` used `instanceof RecordHealthCheckPlugin` before casting | Confirmed in the 2.0.8 source; replaced by a guarded cast in 2.0.9 development source |
| `ApexPluginResolver.requireCheck()` repeated that interface test | Confirmed in the 2.0.8 source; the 2.0.9 development source keeps the instance typed and checks only for null |
| Configuration validation caught ordinary exceptions and returned only `false` | Confirmed in the 2.0.8 source; the 2.0.9 development source carries a structured failure and cause |
| The displayed reason was `FIELD_NOT_RESOLVED` | Reported in the photos; the 2.0.9 integration fixtures now assert interface and constructor reasons directly |

The leading hypothesis is that the interface guard rejects an otherwise cast-compatible
subscriber instance. The proposed guarded cast removes that extra rejection condition. Do not
state that cross-namespace `instanceof` is universally broken or that a cast is proven to fix this
specific customer's org until a before/after reproduction establishes it.

The legacy preview service and both customer Check classes are not present in this repository.
The customer's installed RHC version is unknown. Their service's standalone success, exact
constructor accessibility, and preview return shape therefore remain unverified.

### 2.1 Implemented evidence

| Boundary | Result |
| --- | --- |
| Source mutation guard | Seven self-tests reject either restored `instanceof` gate, direct resolver construction, and a cast moved before constructor failure handling |
| Namespaced source | 58 focused methods passed in run `707RL00001g1UAG`, including exact interface/constructor reasons and the four-outcome compatibility Set |
| Existing installed package plus empty-namespace plugin | The focused four-outcome subscriber validation passed against RHC 2.0.6.2 in deployment `0Afdh000009zYKXCA2`; this does not reproduce the reported defect |
| Foreign installed namespace lookup | `SBQQ.ServiceRouter` resolved in an existing `rhc` source org and was correctly classified at construction; it does not implement the RHC interface and therefore is not NS-03 success evidence |
| Static analysis | Salesforce Code Analyzer Recommended scan found zero violations in the package, integration, subscriber, and partner fixture Apex workspaces |

The source repository now includes `RHC_Plugin_Compatibility`, the subscriber outcome matrix, and
`namespace-fixture/`. The last is package-ready source, but NS-03 remains unverified until a release
owner supplies a registered second namespace and authorizes creation of both candidate artifacts.

### 2.2 Traceability to all six photos

This table maps the substantive points visible in each supplied photo. Repeated content is mapped
once to the same requirement; photographed recommendations remain proposals until verified.

| Photo | Visible claim or recommendation | Required coverage in this specification |
| --- | --- | --- |
| IMG_5601.JPEG | Constructor succeeds, evaluate is not entered; both approval Checks affected; field error misleading; use instantiate-and-cast, avoid inspecting plugin dependencies, retain exception details, install corrected package and recompile/redeploy subscriber classes | Sections 4–7 and 11.1; both named customer Checks remain in the conditional integration matrix |
| IMG_5602.JPEG | Global plugin class/method and exact signature; public same-namespace Callable service; implicit no-argument constructor; subscriber service lookup; failure precedes service invocation, SBAA preview, and user/group queries | Sections 5.4 and 8 distinguish the two caller boundaries and forbid attributing a pre-evaluate failure to downstream work |
| IMG_5603.JPEG | PREVIEW_SERVICE_NOT_FOUND and PREVIEW_FAILED differ from RHC's FIELD_NOT_RESOLVED; correction to blanket constructor advice; MinimalRhcPlugin isolates dispatch without fields or external logic | Sections 5.4, 6, 8, and 10; minimal subscriber fixture must prove evaluate entry independently of SBAA |
| IMG_5604.JPEG | Replace the instanceof branch with a cast in a narrow TypeException catch after constructionFailure propagation; fix the second occurrence | Sections 5.1–5.2; mutation guards must protect each occurrence independently |
| IMG_5606.JPEG | Validator.apexFindings calls isValidApexPlugin; null becomes invalid; package-local valid/invalid tests are insufficient for a subscriber boundary | Sections 6 and 9–10; full validation-to-execution regression and actual installed-package evidence |
| IMG_5607.JPEG | Valid/invalid cast tests; namespace-free subscriber installation smoke test; PLUGIN_INTERFACE_INVALID or APEX_CLASS_INVALID rather than a field error; minimal plugin first, real preview Check next | Sections 6 and 9–11; progressive verification and separate evidence categories |

The photos do not establish that every possible defect has been identified. Coverage here means
every visible substantive point has an explicit requirement or an explicitly recorded uncertainty.

## 3. Scope

Included:

- Interface acceptance during protected construction and subsequent resolution.
- Equivalent behavior for cached and newly constructed plugin instances.
- Accurate failure classification in runtime configuration validation, definition loading,
  metadata audits, and direct Apex evaluation.
- Authorized diagnostics that retain the original exception context.
- Package-local tests, integration Check/Check Set fixtures, and subscriber-package tests.
- A concrete legacy CPQ preview verification contract, conditional on that environment existing.

Excluded:

- Changes to the global plugin method signature or automatic conversion of incompatible classes.
- Adding SBQQ or SBAA dependencies to the core RHC package.
- Implementing a general approval engine, submitting/approving/recalling Quotes, or sending email.
- Replacing legacy CPQ with Revenue Management approvals.
- Relaxing sharing, CRUD/FLS, diagnostics access, or the plugin side-effect contract.
- Repairing unrelated Quote Document code to install packages, or acquiring discontinued packages.

## 4. Required execution sequence

For an eligible record scope with valid Apex configuration:

1. Load current Check configuration and validate its identity, parameters, and applicable fields.
2. Resolve the configured Apex type using the existing namespace rules.
3. Construct the instance once for this validation-to-execution handoff, inside the existing
   savepoint and resource-counter protection.
4. After constructor safety checks succeed, directly cast the instance to the global plugin
   interface. A failed interface cast rejects the class; a successful cast accepts it.
5. Cache the typed instance for that exact Check configuration when validation precedes execution.
6. Consume that instance once during resolution. If no instance is cached, use the same protected
   construction path. Neither path may repeat the problematic interface predicate.
7. Invoke `RecordHealthCheckPluginDispatch.run(plugin, scope)` once for the eligible scope.
8. Enforce side-effect, returned-key, completeness, and outcome validation before shaping results.
9. Return each record's status and reason, with technical diagnostics only where authorized.

Configuration and metadata audits may construct a plugin to validate it, but must never call its
`evaluate()` method. Framework applicability and prerequisite decisions may skip execution as
they do today; a skipped Check must not be presented as a successful plugin invocation.

## 5. Construction and interface acceptance

### 5.1 Change the dispatcher after the existing constructor fence

In `RecordHealthCheckPluginDispatch.instantiate(Type)`, retain the null-Type behavior, savepoint,
counter snapshots, `finally`, rollback/release logic, and constructor-exception propagation.
Replace only the final interface predicate with this candidate implementation:

```apex
if (constructionFailure != null) {
  throw constructionFailure;
}
try {
  return (RecordHealthCheckPlugin) instance;
} catch (TypeException ex) {
  return null;
}
```

This is a proposed code fragment, not a compiled artifact. The cast's `try` block must contain
only the cast. A `TypeException` thrown by a constructor must remain a constructor failure;
it must not be caught here and misclassified as an interface mismatch.

Contract:

- Null input Type: return null, with no construction or savepoint allocation.
- Compatible instance: return a typed plugin, regardless of the implementation namespace.
- Incompatible instance: return null; the caller reports `PLUGIN_INTERFACE_INVALID`.
- Ordinary constructor exception: propagate the original exception for classification.
- Detected constructor side effect: preserve the fatal side-effect exception, with its existing
  precedence over a constructor exception or any other result.

Do not move the cast before the fence finishes or bypass the fence for known classes.

### 5.2 Remove the second predicate in the resolver

`RecordHealthCheckApexPluginResolver` currently widens typed instances to `Object` and then uses
`instanceof` again in `requireCheck()`. Prefer keeping the value typed as
`RecordHealthCheckPlugin` through `resolve()`, `instantiatePlugin()`, and the cache handoff.
The final requirement check then needs only an explicit null check that raises
`PLUGIN_INTERFACE_INVALID`.

If an Object-valued boundary must remain, use an explicit null check and a guarded direct cast
there as well. Catch only `TypeException` around that cast. Do not rely on `instanceof` as a
prerequisite for accepting a subscriber implementation at either boundary.

Audit similar dynamically loaded extension paths. Change only predicates that gate this plugin
interface; JSON collection checks and package-local exception classification are different
contracts and must not be removed indiscriminately.

### 5.3 Preserve type resolution and cache identity

Keep the current class-name behavior:

- Trim surrounding whitespace.
- Resolve a qualified name through `Type.forName(namespace, className)`.
- For an unqualified name, preserve the existing lookup precedence and explicit empty-namespace
  fallback. Do not silently change which class wins when names collide.
- Do not fall back to a different class after a resolved class fails construction or its cast.

The cache remains transaction-local, keyed by Check identity, configured class, and parameters.
Two Checks using one class with different parameters must not share a consumed instance. Later
validation rejection must discard the cached success. Failed validation must not leave a stale
success for the same key. No static cache may carry this state across requests.

### 5.4 Separate plugin compatibility from service compatibility

The outer subscriber class must implement the package's actual global contract:
`Map<Id, rhc.RecordHealthCheckOutcome> evaluate(rhc.RecordHealthCheckScope scope)`, with
cross-namespace visibility sufficient for the package caller. A class with a similar method name,
wrong parameter/return types, or only a Callable implementation is not an RHC plugin.

The inner service uses the separate Callable contract:
`Object call(String action, Map<String, Object> args)`. The photos show a public service invoked
by code in the same subscriber namespace. Do not prescribe changing every service and constructor
to global. Verify accessibility at each actual caller boundary, including an implicit no-argument
constructor when no constructor is declared. Add explicit-constructor, implicit-constructor,
parameterized-only, abstract/non-instantiable, and inaccessible-class cases to the loading tests
where those states can be represented in the validation environment.

The dispatcher must not infer interface compatibility from the plugin's fields, symbol graph,
referenced packages, or internal service dependencies. A minimal field-free plugin must be enough
to exercise acceptance. This does not remove ordinary validation of configured record fields,
merge tokens, or the existing static security review of plugin source.

If construction, cast, and evaluate-entry markers pass but the service fails, classify the failure
at that downstream boundary. Test missing service, a class that does not implement Callable,
unsupported action, thrown service exception, null response, malformed response, and partially
resolved approvers. Null/malformed responses must not masquerade as a valid empty preview.

## 6. Validation must preserve the reason

The Boolean `isValidApexPlugin()` result is insufficient for diagnostic callers. Introduce an
internal structured validation result, produced once per validation attempt, containing:

- Validity and the successfully typed instance, if any.
- Stable reason code and phase for a failure.
- Configured class name and resolved type identity when available.
- The original ordinary constructor exception for the authorized diagnostic pipeline.

Keep existing Boolean helpers as wrappers where required for compatibility. Diagnostic callers
must consume the structured result directly. Do not re-run constructors merely to discover a
reason while mapping a finding.

Extend the shared Finding model or introduce distinct finding codes so both runtime and metadata
mapping receive the same classification. Update all exhaustive mapping tests. The old generic
`APEX_CLASS_INVALID` fallback, when no richer cause exists, must say `APEX_CLASS_INVALID`; it
must not claim a class is missing or a field failed to resolve.

| Actual condition | Runtime status | Reason code | Phase |
| --- | --- | --- | --- |
| Blank or unresolvable class name | UNABLE_TO_EVALUATE | APEX_CLASS_NOT_FOUND | PLUGIN_RESOLVE |
| Class constructs but cannot cast to the plugin interface | UNABLE_TO_EVALUATE | PLUGIN_INTERFACE_INVALID | PLUGIN_RESOLVE |
| Constructor throws or cannot be invoked | UNABLE_TO_EVALUATE | PLUGIN_CONSTRUCTOR_FAILED | PLUGIN_CONSTRUCT |
| Malformed or non-object parameters | UNABLE_TO_EVALUATE | INVALID_APEX_PARAMETERS | PLUGIN_PARAMETERS |
| Plugin throws during evaluation without a detected side effect | ERROR | PLUGIN_THREW | Existing execution phase |
| Constructor or evaluation performs a detected prohibited effect | Fatal exception; no ordinary result conversion | PLUGIN_SIDE_EFFECT_DETECTED | Actual construction/execution phase |
| Field resolution genuinely fails on a field-dependent path | Existing field-failure behavior | Existing field-specific reason | Actual field phase |

Metadata audits return issues rather than runtime result rows, but must use the corresponding
reason and attribute plugin configuration errors to `ApexClass__c` or `ApexParametersJson__c`.
Use the actual interface name `RecordHealthCheckPlugin` in guidance; current generic mapper
messages incorrectly say `RecordHealthCheck`.

Reason-code changes are observable to API consumers. Document the correction from the former
generic reason to the specific plugin reason in release notes and update expected-result fixtures.
Do not alter PASS/FAIL outcomes or field-error mappings to achieve this correction.

## 7. Diagnostic and security contract

Ordinary users receive a safe explanation, for example: "This custom Apex Check could not be
loaded. Contact your administrator." Preserve configured Unable messages where applicable.
Do not label a load failure an exception from the approval preview method.

Authorized diagnostics should include the Check/Set identities, run/diagnostic identifier,
configured class, phase, reason, affected scope, and original exception type, sanitized message,
line, and stack/top frame where Salesforce exposes them. Missing managed-package frames must be
reported as unavailable, never fabricated. Do not replace the original constructor failure with
the wrapper's stack as the only evidence.

Use the existing diagnostic factory, sanitizer, access checks, and response shaping. Do not add
raw messages or stack traces to normal results, metadata reports available to broader audiences,
or browser console output. Do not log full parameters, Quote content, or tokens simply to diagnose
a type mismatch. Test authorized and unauthorized callers explicitly.

Constructor and evaluation safety is unchanged: detected DML must roll back within the existing
boundary; side-effect exceptions must survive every adapter catch. Preserve the documented limits
of runtime counters for events and asynchronous operations rather than claim complete detection.

## 8. Legacy CPQ preview behavior

This section defines the acceptance contract for the subscriber example to be built. It is
separate from the framework repair. The outcome policies below are selected requirements for
that example; the actual SBAA API and schema still require environment verification.

```text
RHC Check on an SBQQ Quote
  -> subscriber QuotePreviewInactiveApproverCheck.evaluate(scope)
  -> subscriber LegacyApprovalPreviewService.call(action, arguments)
  -> SBAA.ApprovalAPI.preview(...)
  -> resolve predicted approvers and inspect User.IsActive
  -> return one RHC outcome per requested Quote
```

The exact preview overload, return structure, action name, and Approval-to-Quote lookup must come
from the installed schema/API and actual service source. Do not assume the customer's custom
lookup name exists in another org. The example must not query historical approvals and present
them as the result of a fresh preview.

Proposed outcome contract:

| Preview scenario | Expected result |
| --- | --- |
| Nonempty complete preview; all resolved approvers are active | PASS; inactive count 0 |
| Complete preview; at least one resolved approver is inactive | FAIL; distinct inactive-user count greater than 0 |
| Successfully evaluated preview has no required approvers | SKIPPED / PREVIEW_NO_APPROVERS; never interpret an absent or malformed response as this case |
| Service class is unavailable | UNABLE_TO_EVALUATE / PREVIEW_SERVICE_NOT_FOUND |
| Service invocation or preview fails | UNABLE_TO_EVALUATE / PREVIEW_FAILED |
| Approver identity cannot be resolved, or required user/group data is inaccessible | UNABLE_TO_EVALUATE with a specific documented resolution/access reason |
| Record is outside the configured applicability or a prerequisite prevents execution | Existing SKIPPED result; do not invoke preview |

For this example, incomplete evidence takes precedence over PASS or FAIL; diagnostics may retain
known inactive counts but must not imply the full preview was inspected. These defaults require
no further requirements decision to implement; changing them later is a separate behavior change.

Group, nested-group, delegated, and dynamic approver types must be explicitly supported or return
an unable result. Define expansion semantics from the actual approval configuration; do not treat
an unresolved group as zero inactive users. Deduplicate a user reached through multiple paths.
Bound group traversal and preview work. If the legacy preview API cannot support the framework's
maximum scope within limits, document and enforce a safe bound rather than silently omit Quotes.

Test an inactive predicted user even when an active delegate or another active group member exists.
The example flags every inactive user in the complete predicted set; it does not claim that one
inactive member prevents approval, or that an active delegate erases that finding. If the API cannot
resolve the effective predicted set, return an unable outcome. Do not silently filter inactive users.
Preview-to-submission races remain possible: this Check reports the state at preview time and
does not guarantee that users or approval rules remain unchanged until submission.

The health check must not submit an approval, create approvals, change a user, or send messages.
If the preview API itself performs prohibited writes, report that incompatibility; do not weaken
RHC's protections. Class visibility must be sufficient for the actual caller boundary. Moving the
service behind Callable or changing its visibility does not repair rejection of the outer plugin.

## 9. Regression scenario matrix

Write and run the relevant guards before production edits. Follow
[Check and Check Set outcome verification](../quality-gates/check-outcome-verification.md).

| Area | Scenarios and required assertion |
| --- | --- |
| Interface compatibility | Valid package-local, empty-namespace subscriber, and qualified subscriber types reach evaluate; unrelated concrete type is rejected |
| Loading boundaries | Validation then cached execution, direct uncached resolution, definition loading, metadata audit; identical classifications |
| Null/invalid configuration | Null Type, blank/missing class, wrong type, missing accessible no-argument constructor, malformed/scalar/array/null parameter JSON; existing empty-parameter behavior preserved |
| Constructor failures | Ordinary exception and constructor TypeException classified as constructor failures; original cause retained |
| Side effects | Constructor/evaluation DML with and without a subsequent throw; rollback and fatal precedence unchanged |
| Cache isolation | Different Check identities and parameters, consumed cache, discarded cache, failed revalidation; no instance leaks or duplicate construction in a successful handoff |
| Ordinary outcomes | Plugin-controlled PASS, FAIL, SKIPPED, and UNABLE_TO_EVALUATE preserved; thrown evaluation error classified separately |
| Result contract | Null map, missing record entry, unknown returned ID, invalid outcome; existing dispatcher behavior preserved |
| Bulk/limits | Single record and maximum supported scope, one evaluate call per scope, more than five sequential constructions; no savepoint accumulation |
| Namespace variants | Package-local source, namespaced source, installed package with subscriber-owned class; namespace collisions retain documented precedence |
| Security | Runner without diagnostic access, authorized diagnostic viewer, inaccessible data, missing run permission; no new exposure or elevated execution |
| Runtime variants | LWS and Locker display safe reasons when browser verification is available; no loader/rendering change required |
| Data variations | Currency, locale, and time zone cannot affect interface acceptance or reason classification; verify the dispatch fixture has no dependence on them |
| Legacy integration | Active/inactive/no approvers, service failure, unresolved groups, duplicate users, permissions, supported bulk bound; conditional on actual SBQQ/SBAA availability |

Existing starting points include `RecordHealthCheckPluginDispatchTest`,
`RecordHealthCheckApexAdapterTest`, `RecordHealthCheckConfigValidationTest`,
`RecordHealthCheckConfigFindingMapperTest`, diagnostic tests, and
`RHCSubscriberSmokeTest.unmanagedSubscriberPluginResolvesAcrossNamespaceBoundary()`.
Audit their actual assertions; test names or nonblank-reason checks alone are insufficient.

Package-local tests may pass before and after the cast change. Do not present those as a red
reproduction of the namespace defect. The decisive test uses an installed RHC package and a
subscriber-owned class. If that environment is unavailable, mark the runtime hypothesis unverified.
An executable source guard must additionally reject reintroduction of the plugin-interface
predicate, with self-tests showing it fails on the old source, but is not platform proof.

For this repair, that source guard is required as a durable complement to Apex tests. Register it
in the existing source-gate declaration so ordinary CI runs it. Scan the relevant production
plugin-loading boundary for both the old acceptance predicate and new paths that bypass protected
construction. Its self-tests must distinguish prohibited plugin guards from legitimate JSON and
exception predicates, and must fail when either original occurrence is restored independently.
Use the repository's existing source-analysis conventions; do not depend on a single exact line
of formatting or reject explanatory comments as executable code.

### 9.1 Entry-point and failure-path coverage

Use the shared Check fixtures through each public surface that can reach the Apex evaluator:

| Surface | Required observable checks |
| --- | --- |
| Record card, including definition loading and rerun | Valid subscriber plugin runs; load failures name the plugin phase; rerun reads changed class/parameters; no header-only or stuck-loading state |
| Public Apex single Check and Check Set requests | Exact result count, identity, status, reason, and evaluate-entry marker for cached and uncached paths |
| Flow Check/Set actions and agent Check/Set actions | Adapter output retains the specific plugin failure, identity, and safe diagnostics; side-effect failures cannot become ordinary results |
| Agent REST and any supported MCP bridge into these APIs | No generic field error or diagnostic leakage introduced by serialization or error translation |
| Queueable, Batch, and Scheduled adapters | Scope processing and permitted lifecycle output preserve failure meaning; no false successful completion or swallowed fatal side effect |
| Metadata validation action and definition service | No evaluate call; correct class/parameter issue, no repeated construction to recover a diagnostic |
| Plugin-author contract test harness | Compatible typed instance reaches protected run; result and side-effect guarantees remain enforced |

Exercise the lowest shared layer thoroughly and add adapter assertions at each meaningful
translation boundary; duplicating all permutations at every adapter is unnecessary. Record the
concrete test name for every row. A claimed not-applicable surface requires evidence that it cannot
reach the changed path. Keep the existing
[record-page card contract](../architecture/record-page-card-contract.md) intact.

Do not blanket-catch all Apex failures and report UNABLE_TO_EVALUATE. Preserve the existing fatal
handling of side effects and the platform behavior of uncatchable governor-limit exceptions.
Test catchable failure precedence without promising recovery from an exhausted transaction.

Demonstrate diagnostic red tests against the current generic mapping. After implementation,
revert each relevant change independently to show the guard detects its recurrence. Save actual
red/green output, rather than inferred expected failures.

## 10. Fixtures and administrator verification

Under `packages/record-health-check/integration-tests`, add a proposed
`RHC_Plugin_Compatibility` Check Set on Account with Checks backed by controlled plugins for
PASS, FAIL, SKIPPED, and UNABLE_TO_EVALUATE. Organize malformed-class and constructor-error Checks
in a separate diagnostic Set with explicit deployment and audit expectations. Wire every
fixture to an automated test and an exact manual procedure.

A separate Set alone does not exclude its Checks from an org-wide metadata audit. Deploy the
valid fixture subset and run the zero-error audit first, then deploy the deliberately invalid
fixtures for diagnostic tests, or explicitly assert their exact expected audit issues. Ensure the
chosen ordering works in reused orgs as well as clean installs. Never suppress all audit errors
to accommodate a negative fixture. Match the existing subscriber smoke test's zero-error audit
expectation with its deployment subset.

Keep the minimal subscriber fixture independent of SBQQ/SBAA, record-field queries, and Callable.
It returns one marker PASS per requested record. Pair it with a non-plugin class that constructs
successfully, a throwing constructor, and controlled evaluation-result fixtures. Capture
constructor and evaluate invocation counts in test-visible subscriber state so a marker result
cannot be confused with a framework-generated fallback. Validation must leave evaluate count zero.

Under `subscriber-app`, reuse the existing `Subscriber_Smoke_Extension` Set and
`RHCSubscriberPlugin`, extending the subscriber tests as needed. Those classes must remain
subscriber-owned and reference the global `rhc` API; they must not be moved into package source
or call private framework helpers. Add subscriber fixtures for the additional externally visible
paths rather than relying solely on package-local injected caches.

Administrator procedure in a suitable existing validation org:

1. Record org identity, installed package ID/version, source commit, and relevant permissions.
2. Deploy the fixture classes and Check/Check Set metadata; create the named Account fixture.
3. Run the compatibility Set through the public API and the record card; compare every Check's
   exact expected status/reason and confirm no unresolved display tokens.
4. Run diagnostic fixtures separately; inspect class/interface/constructor guidance as an
   authorized user, and verify safe output as a user without diagnostic access.
5. Repeat against the installed package using the subscriber-owned fixture. Assert the minimal
   plugin's marker result, such as `SUBSCRIBER_PLUGIN_PASS`, proving its method actually ran.
6. When a legacy environment exists, prepare named Quotes with active, inactive, and no predicted
   approvers. Compare direct preview results with the RHC Check, including scope limits and errors.
7. Save expected/actual results and record IDs for repeatable manual inspection.

A local Callable fixture may simulate preview success and failure to verify delegation, but must
be labeled a simulation. It cannot prove SBAA preview semantics or SBQQ schema compatibility.

## 11. Implementation order and completion criteria

1. Record the scenario matrix and add failing diagnostic/source guards plus executable Apex and
   subscriber fixtures. Capture whatever runtime red evidence is actually available.
2. Apply the guarded cast and remove the resolver's redundant Object/interface predicate.
3. Preserve structured validation failures and update runtime/metadata/diagnostic consumers.
4. Run focused tests and mutation checks; update administrator instructions and reason-code docs.
5. Run applicable source gates, followed by `npm run ci:gates` and the CI Code Analyzer checks.
   Preserve ignored evidence if the output-path gate requires a clean-checkout verification.
6. Validate deployment and run Apex tests in an authorized existing org. For an owner-approved
   package candidate, run subscriber tests against its exact installed `04t`.
7. Record legacy preview verification separately when the required packages are available.

Report completion in separate categories:

- **Implementation complete:** code, accurate mappings, tests, fixtures, docs, and source gates pass.
- **Managed-package compatibility verified:** exact installed-package subscriber tests pass;
  before/after or mutation evidence supports the reported regression claim.
- **Legacy preview verified:** actual SBQQ/SBAA scenarios return the documented outcomes.

Do not collapse these categories into "fixed and verified" when later evidence is unavailable.
An absent legacy environment does not block authoring the core fix or testing its generic
subscriber interface. It does block claims that the customer's preview integration works.

This specification authorizes no org creation, workflow dispatch, package creation, or promotion.
Those actions retain the repository's explicit release-owner and scratch-org authorization rules.
Hosted scratch-org validation remains optional release evidence under the working agreement.

### 11.1 Upgrade, repeatability, and release evidence

An implementation of this specification must test clean installation and upgrade from the
reported affected RHC package when it becomes available. Record the exact package ID and Apex
API/package version settings used by subscriber classes. At minimum, exercise the previous
supported release to the candidate; do not call that a reproduction of an unknown customer version.

On upgrade, first rerun the existing subscriber class without edits to measure compatibility.
If recompilation or redeployment is required, use that as a documented recovery step, then rerun
the same assertions. Do not silently change the plugin's business logic or delete/recreate
subscriber-owned Checks to make the upgrade pass. Preserve their class names, parameters, and
qualified metadata identities. A new installed package is necessary to deliver a managed-source
repair; editing this repository does not patch an already installed managed package.

Each implementation/release evidence record must name the source commit, package version,
namespace topology, entry point, scenario, fixture, expected and actual status/reason, invocation
counts where applicable, test run/job ID, and verification date. Separate unavailable/blocked
scenarios from passing ones. Update the traceability table when implementation moves a boundary.

Future changes to dispatch, resolver, validator, findings, diagnostics, caching, or adapter error
translation must rerun their affected regressions and the ordinary source gates. Installed-package
subscriber compatibility remains a required evidence category for claims about that boundary;
when it cannot run, disclose the gap rather than treat a package-local pass as equivalent.

## 12. Current environment constraints

The original customer org is unavailable. The selected `gkcpq-dev-ed` org has SBQQ 240.5.0.1.
The attempted RHC 2.0.8.1 install there was rejected because unrelated existing
`QuoteDocumentTableDefinitionDefaultsTest` calls a missing method. SBAA is not installed and its
old installer is unavailable. These are environment blockers, not evidence about the plugin fix.
Do not remove unrelated tests or modify quote-document behavior as part of this specification.

SBQQ 240.5.0.1 was successfully installed in the existing `rhc-demo-20260820` subscriber org and
`rhc-208-ns-20260906` source org. The empty-namespace subscriber plugin passed in the former, and
qualified `SBQQ.ServiceRouter` lookup reached constructor classification in the latter. Neither
result proves a compatible plugin owned by the SBQQ namespace or legacy SBAA preview semantics.

## 13. General namespace and Apex compatibility contract

This section closes the requirements beyond the two photographed occurrences. It applies to all
RHC Apex plugins, including future plugins unrelated to approvals. These are implementation
requirements, not a claim that current source already satisfies them.

### 13.1 Supported namespace topologies

| ID | Topology | Required outcome and evidence |
| --- | --- | --- |
| NS-01 | Unnamespaced RHC source and local plugin | Valid plugin constructs and evaluates; development baseline only |
| NS-02 | Installed `rhc` package and subscriber-owned class in the empty namespace | Unqualified local class resolves through the documented fallback and evaluates; installed-package test |
| NS-03 | Installed `rhc` package and compatible global plugin in a different namespace | Explicit `othernamespace.PluginClass` resolves and evaluates; real second-namespace test, not a dotted name on a local test double |
| NS-04 | Plugin distributed separately under the same `rhc` namespace | Explicit global contract remains usable; package dependencies and exposed surface verified with the actual package topology |
| NS-05 | Plugin in another namespace calling its own helper or another package | RHC accepts the outer plugin; helper accessibility/failure is attributed to construction or evaluation where it occurs |
| NS-06 | Same simple class name in package and subscriber namespaces | Existing lookup precedence is stable; explicitly qualified names select only the requested namespace |
| NS-07 | Check metadata namespace differs from implementation namespace | `ApexClass__c` determines implementation resolution; neither Set nor Check namespace is automatically prepended |
| NS-08 | Requested namespace/package absent, inaccessible, or incompatible | Specific bounded failure; no fallback to a similarly named class in another namespace |

NS-03 is essential to a claim that RHC works with other namespaces. NS-02 alone is insufficient.
Provide a minimal partner-package fixture source and deployment/install instructions independent
of SBQQ/SBAA. Do not create or publish that package or create orgs without the required owner
authorization. When the fixture cannot be installed, retain the scenario as unverified, not passed.

The global contract includes the interface, scope, outcome, value types, and every member a plugin
must call. Add a consumer-compilation test in the external namespace; testing the interface name
alone does not catch a DTO method losing visibility. Audit package dependencies and prevent any
core-to-partner dependency cycle. Same-namespace accessibility annotations are not a substitute
for a deliberately global cross-namespace extension API; see Salesforce's
[namespace-based visibility reference](https://developer.salesforce.com/docs/platform/pkg2-dev/guide/sfdx-dev-dev2gp-namespace-visibility.html).

### 13.2 Class-name selection is deterministic

Supported metadata syntax is a top-level simple Apex class name or exactly
`namespace.ClassName`. Trim only surrounding whitespace. Preserve Apex/platform case resolution;
retain the platform's resolved name for diagnostics rather than deriving a namespace by arbitrary
string replacement. Respect the configured field's length limit.

Reject malformed syntax before reflection: embedded whitespace, empty namespace/class segments,
extra dots, generic type syntax, paths, and appended code. Use APEX_CLASS_INVALID for these cases.
Do not reinterpret `namespace__ClassName` as a namespace separator; it is a literal simple name
if valid as an identifier. Inner-class addressing and a new empty-namespace selector syntax are
outside this repair's public configuration contract. Do not invent either silently.

For an unqualified class, retain the current package-context lookup followed by the explicit
empty-namespace fallback only when the first lookup returns no type. An inaccessible class can
look absent to reflection; describe that limitation honestly. If a name collides, document the
winning implementation and use a distinct subscriber class name where the existing syntax cannot
select it unambiguously. Do not execute multiple constructors to find whichever one casts.

After resolution, preserve the resolved Type and successful typed instance through that attempt.
Do not resolve the class a second time to build a diagnostic or consume an already validated
instance. Audit any proposed change to lookup order as a separate compatibility change.

### 13.3 Complete Apex failure taxonomy

Every reachable load/evaluate failure must fit a documented category. Extend section 6 as follows:

| Condition | Required behavior |
| --- | --- |
| Invalid class-name syntax | UNABLE_TO_EVALUATE / APEX_CLASS_INVALID; no reflection or constructor |
| Lookup returns no Type | UNABLE_TO_EVALUATE / APEX_CLASS_NOT_FOUND; guidance says missing or not visible to this caller, not conclusively deleted |
| Reflection itself throws a catchable exception | UNABLE_TO_EVALUATE / APEX_CLASS_LOAD_FAILED, an additive reason; PLUGIN_RESOLVE phase, original cause retained |
| Interface type, abstract class, or inaccessible/parameterized-only constructor resolves but cannot construct | UNABLE_TO_EVALUATE / PLUGIN_CONSTRUCTOR_FAILED; do not report interface mismatch without a constructed object |
| Constructed class has the wrong interface, including a same-named unrelated interface | UNABLE_TO_EVALUATE / PLUGIN_INTERFACE_INVALID |
| Concrete subclass inherits a compatible plugin implementation | Accept when Salesforce permits construction and cast; no requirement to redeclare implements on the concrete class |
| Static initialization or nested helper fails during construction | PLUGIN_CONSTRUCTOR_FAILED with original cause; nested stack does not change the phase |
| Missing dependency, license, or package-version incompatibility surfaces during construction/evaluation | Classify by the observed phase and preserve available evidence; do not infer a license failure from all TypeExceptions |
| Interface signature or dependency cannot compile at deployment/install time | Deployment/package error, not a fabricated runtime result; save exact component and compiler error |
| Missing/malformed returned outcome data | Existing PLUGIN_RESULT/STATUS/VALUES/DISPLAY reason and scope-impact contract; never treat as PASS |
| No safe catchable classification exists | Existing FRAMEWORK_UNEXPECTED diagnostic path; no default FIELD_NOT_RESOLVED and no swallowed fatal error |

Only add APEX_CLASS_LOAD_FAILED to the published reason contract with synchronized constants,
diagnostic classification/guidance, mapper coverage, API/adapter assertions, and documentation.
Preserve older reason literals in historical evidence. Do not use exception-message substring
matching as the authoritative classifier or claim reflection reveals every visibility distinction.

Differentiate Apex class access, the framework run permission, package license access, and record
CRUD/FLS in troubleshooting. They are not interchangeable repairs. RHC does not automatically
grant access, elevate sharing, activate users, or bypass a package license to make a plugin pass.

### 13.4 Parameters, freshness, and isolation

Validate the JSON shape and existing parameter-size limits before running a constructor for an
already-invalid Check. Blank parameters produce an empty map; JSON object values are accepted;
JSON null, scalar, array, malformed, or over-limit input fails with INVALID_APEX_PARAMETERS.
Do not turn invalid parameters into an empty map. Preserve nested values and the existing detached
scope copies so a plugin cannot change another Check's input by mutating a shared object.

Failure precedence is deterministic: missing run access/record prerequisites retain their existing
guards; malformed configuration is rejected before construction; protected loading then determines
resolve/construct/interface failures; a detected side effect during executable work remains fatal.
If multiple configuration findings exist, use one documented stable order in every mapper, with
class-name presence/syntax before parameter syntax. No diagnostic pass reruns executable Apex.

Test two sequential runs in the same transaction as well as separate requests. A valid result
followed by changed class/parameters must not consume the prior instance or failure. Limit any
failure cache to the same exact configuration and attempt; clear retained exception references
when the attempt completes. Keep the public scope deeply detached and preserve run/record/Check
identities when two namespace plugins run in the same Set.

Verify that class identity and parameters are sufficient for the existing per-attempt cache key,
and include any additional configuration used during construction if implementation introduces it.
Do not cache a verdict about a user's data or permissions as a verdict about the class itself.

### 13.5 Bounded execution and graceful failure

Dispatch remains once per eligible scope. Measure constructor, savepoint, query, CPU, and heap
overhead against the existing maximum Check/scope limits. Do not assume per-package governor
accounting creates an unlimited combined budget. Guard known oversized input before invoking
the plugin; retain platform-fatal behavior for limits that cannot be safely caught.

Do not automatically retry a throwing constructor or evaluate method: either may have attempted
effects, and retries can duplicate work or exhaust limits. An explicit new user run is a new
attempt. Test failure cleanup so ordinary failures do not leave active savepoints or stale caches.

An ordinary configuration/evaluation failure must retain one terminal result for each affected
record without converting unrelated Checks to PASS or dropping them. Preserve prerequisite and
existing run-control semantics; test a Set containing both a healthy plugin and a failing plugin.
A fatal side effect still stops the applicable transaction. Preserve intentional business FAIL
and plugin-reported UNABLE_TO_EVALUATE as distinct from framework contract ERROR.

### 13.6 Deliverables and decision closure

The following deliverables are mandatory for the implementation, not optional follow-up ideas:

| Deliverable | Owner in the codebase / acceptance |
| --- | --- |
| Safe interface acceptance | PluginDispatch and ApexPluginResolver; both old predicates removed, independently guarded |
| Structured validation | ConfigValidator and Validator; no loss of cause, no constructor rerun, stable failure order |
| Consistent diagnostics | ConfigFindingMapper, MetadataIssueMapper, DiagnosticFactory/Guidance and consumers; every taxonomy row covered |
| Public contract compatibility | Global plugin/DTO surface consumer compilation and existing API surface gate; no accidental breaking signature/visibility changes |
| CI prevention | Named source guard registered in scripts/lib/release-gates.mjs, self-tests and mutation evidence |
| Namespace proof | NS-01 through NS-08 mapped to exact tests and environment evidence; real foreign-namespace consumer |
| Reusable user fixtures | Valid, invalid, constructor, result, and mixed-Set cases wired to tests and admin procedures |
| Release handoff | Exact candidate and previous-version evidence, corrected reason-code notes, blocked scenarios disclosed |

Core loading and failure classification requirements are closed by this specification. No further
business input is needed to implement them. Legacy example defaults are also selected: complete
all-active preview passes; complete preview containing an inactive predicted user fails; a valid
empty preview skips; incomplete/malformed/inaccessible preview is unable. The preview adapter must
recognize each returned approver shape or report it as unsupported, never silently ignore it.

Remaining unknowns are evidence and environment inputs: the actual legacy API shape, customer
package version/log, and available installed-package test topology. Their absence does not reopen
the generic contract or justify guessing platform behavior. It limits the claims that can be made
after implementation. Unforeseen Salesforce constraints must be recorded as concrete findings with
a test and a bounded compatibility decision, not silently worked around.

## 14. Red, edge, and war-room execution plan

A negative scenario and a red test are different. A test that correctly rejects an invalid class
should pass. A red regression test fails against the defective implementation because the expected
behavior is absent. Evidence must identify which kind was run; a suite containing "Red" in a name
is not proof that a defect was reproduced.

### 14.1 Environment matrix

An org has at most one development namespace, but can contain installed packages from multiple
namespaces. "Multiple namespace org" here means those packages coexist and call across their
boundaries. An org with no development namespace can still contain an installed `rhc` package;
that differs from deploying all RHC source without a namespace.

| Environment | Required fixture composition | What it proves |
| --- | --- | --- |
| E-01: no namespace source org | Unnamespaced RHC source and local plugin fixtures | Local source behavior and negative cases |
| E-02: namespaced source org | RHC source in `rhc`, package-local fixtures | Namespaced compilation and internal paths; not subscriber-package proof |
| E-03: no development namespace, installed RHC | Exact managed `rhc` candidate plus empty-namespace subscriber fixtures | Actual package-to-subscriber construction, validation, and execution |
| E-04: multiple installed namespaces | Exact `rhc` candidate, two distinct external namespace fixtures, and an empty-namespace fixture | Isolation across multiple plugins; same simple names select the intended class; package-to-package and package-to-subscriber calls coexist |
| E-05: separate packages sharing a namespace | RHC and compatible separately distributed same-namespace fixture | Package visibility/dependency boundaries distinct from namespace identity |
| E-06: upgrade topology | Previous RHC release plus existing external fixtures, upgraded to exact candidate | Existing subscriber implementations/configuration survive upgrade |
| E-07: legacy integration | SBQQ, SBAA, RHC, and subscriber preview adapter | Actual approval API semantics; conditional environment evidence |

E-01 through E-06 are the required general compatibility evidence plan. E-04 must use actual
distinct namespaces, not strings, mocks, or renamed local classes. E-07 is additional evidence for
the legacy integration claim. Record unsupported/unavailable topology and its impact explicitly.
No requirement here authorizes creating orgs or packages. Do not conflate a missing environment
with a failing runtime test or a pass.

### 14.2 Required red demonstrations

| ID | Defect or mutation | Required failing assertion |
| --- | --- | --- |
| RED-01 | Original dispatcher predicate in an affected installed-package environment | Compatible subscriber plugin does not reach its required marker result; if the old runtime passes, record hypothesis not reproduced |
| RED-02 | Restore dispatcher predicate after the repair | Source guard fails independently; runtime regression must fail where the platform reproduces the problem |
| RED-03 | Restore resolver predicate only | Independent source guard fails; cached and uncached consumer tests protect the second boundary |
| RED-04 | Collapse invalid interface/constructor/load failures into a missing-class or field error | Exact reason and phase assertions fail in runtime and metadata mapping |
| RED-05 | Drop original exception context or expose it to ordinary callers | Authorized-detail or unauthorized-redaction assertion fails |
| RED-06 | Reuse a plugin under the wrong Check/parameters or retain it after failure | Identity, invocation count, or parameter-isolation assertion fails |
| RED-07 | Swallow a side-effect exception or remove rollback | Fatal-propagation or fixture-state assertion fails in an isolated test transaction |
| RED-08 | Make a required global DTO member inaccessible or change the plugin signature | External consumer compilation fails |

Mutation runs belong in isolated local copies or disposable test transactions. Never deploy
deliberately weakened safety code to a customer org. Restore the implementation and rerun the same
assertions to record green evidence. Source mutation proof complements, rather than replaces,
installed-package runtime evidence.

### 14.3 Combined failures and hostile plugin scenarios

| ID | War-room scenario | Required outcome |
| --- | --- | --- |
| WAR-01 | One Set contains local, namespace A, namespace B, invalid-interface, and throwing plugins | Correct per-Check identity/results; recoverable failures remain attributable; no namespace or instance bleed |
| WAR-02 | Same class names across namespaces; explicitly selected type fails to construct | Do not switch to a working lookalike; retain configured/resolved identity and actual error |
| WAR-03 | Constructor performs DML then throws TypeException | Roll back plugin work and propagate the side-effect failure, not interface invalidity |
| WAR-04 | Caller made legitimate changes before a plugin mutates and fails | Plugin boundary rollback does not itself erase pre-boundary caller work; an uncaught fatal exception may still cause Salesforce to roll back the whole transaction |
| WAR-05 | Plugin attempts to alter scope parameters/record IDs and returns extra, missing, or malformed results | Detached scope and existing completeness/identity validation hold; no fabricated healthy result |
| WAR-06 | Maximum supported Check and record scope with repeated construction/failure cycles | Bounded overhead and released savepoints; no hidden per-record construction or automatic retries |
| WAR-07 | Two requests/users run the same configuration with different data visibility | No cross-request cache or diagnostic leakage; permissions evaluated for the actual caller |
| WAR-08 | Check metadata changes between card runs or an external package changes between transactions | New attempt reads current configuration/type; no persistent stale acceptance or result |
| WAR-09 | Invalid class name and invalid parameters occur together | Stable configuration-failure precedence, no constructor invocation |
| WAR-10 | Helper/dependency throws while the outer plugin is constructing versus evaluating | Distinct constructor/evaluation phases, original cause retained; no guessed field-access diagnosis |
| WAR-11 | Plugin returns a very large result/message, or throws sensitive text | Existing size bounds and sanitization hold across JSON/API/card diagnostics; no raw data leakage |
| WAR-12 | Healthy plugin follows an ordinary failed plugin and a prerequisite depends on the failed one | Healthy independent path remains correct; prerequisite behavior stays explicit; failed Check does not become PASS |
| WAR-13 | Nested/cyclic group membership, inactive member plus active delegate, partial preview response | Bounded traversal/deduplication; no false zero-inactive verdict; incomplete evidence is unable |
| WAR-14 | Preview or plugin approaches a governor limit or attempts prohibited asynchronous work | Existing prevention/detection limits and fatal behavior preserved; no claim that all platform effects are catchable |

Pair each applicable row with null/empty, one-element, supported maximum, and one-over-limit
inputs at the relevant boundary. Derive maxima from the existing constants/schema instead of
inventing new limits. Evaluate concurrency in separate requests; Apex unit-test sequencing alone
does not prove simultaneous-request behavior. Exercise LWS/Locker presentation and representative
currency/locale/time-zone settings without changing plugin acceptance based on those settings.

### 14.4 Runner integration and evidence checklist

Wire package-local/integration negative cases into the existing negative-conformance suite and
`scripts/contributor/war-room.mjs` where applicable. Keep installed-package external consumer tests
in the subscriber runner; the current war-room runner is not by itself proof of external namespaces.
Inspect its permission assignment and fixture setup behavior before using it for a restricted-user
scenario. Test restricted users explicitly rather than asserting restrictions as the admin runner.

Maintain an executable scenario manifest that maps NS, RED, and WAR IDs to the exact test method
or verification script, environment, expected status/reason, and required permissions. CI must
reject missing mappings, duplicate IDs, orphaned fixtures, or claimed automated coverage without
an executable target. At run time, the harness must verify required packages/namespaces, report
each scenario's actual outcome, and distinguish passed, failed, blocked, and not applicable.
An expected negative business result is a passed test when it matches the contract; a blocked
scenario is never included in the passed count.

Implementation handoff must include the manifest, actual red/green logs, independent mutation
results, installed-package consumer evidence, and every environment gap. A statement such as
"all tests passed" without those mappings does not satisfy this specification.

## Related

- [Contributor guide](./README.md)
- [Write an Apex Check](../developer-guides/write-an-apex-check.md)
- [Check outcome verification](../quality-gates/check-outcome-verification.md)
- [Package testing and upgrades](../quality-gates/package-testing-and-upgrades.md)
