# Write code with verifiable outcomes

This standard is for contributors implementing and reviewing Record Health Check behavior. Use it
with [Check outcome verification](./check-outcome-verification.md) and the repository regression-first
contract. It captures reusable lessons from source review, Salesforce execution and browser testing.
It does not authorize deployment, package creation, new orgs or destructive cleanup.

## Specify the answer before writing the implementation

Every scenario must say what data and configuration mean, independently of what the current code
returns. Do not use the production helper under test to calculate its own expected result, copy a
captured response into an unexplained oracle, or use a serializer round trip as proof of wire behavior.

Use this scenario record in feature specifications and regression evidence:

| Field                | Required content                                                                            |
| -------------------- | ------------------------------------------------------------------------------------------- |
| Identity             | Stable requirement and scenario IDs; exact Check and Check Set identities                   |
| Initial state        | Record fields, related rows, metadata values, active flags and relevant defaults            |
| Context              | Actor and permissions, caller, namespace, runtime, fresh or warmed state                    |
| Action               | Exact request or data/configuration change; input order and scope                           |
| Business expectation | Exact status, reason, result identity, displayed values and summary counts                  |
| Evidence expectation | Row/column types, null positions, completeness and omitted/total counts                     |
| Forbidden work       | Queries, hooks, formulas, rendering, publication or retries that must not occur             |
| Test expectation     | Assertion that passes for correct behavior; precise defect that makes it red                |
| Proof                | Named test method, metadata fixture, administrator procedure, red/green evidence and source |
| Recovery             | Corrected input, rerun expectation, original values and owned-record cleanup procedure      |

Mark irrelevant fields with a specific reason. Keep unexecuted tests and browser procedures planned;
a detailed expected result is not proof that it happened.

## Business FAIL is a passing test

Consider an illustrative rule: an applicable Account passes when its related open Opportunity count
is zero. These rows specify a business contract, not new packaged fixture names or executable Apex.

| Case                   | Data/configuration                                                | Expected Check result                                           | Expected automated test result                                     |
| ---------------------- | ----------------------------------------------------------------- | --------------------------------------------------------------- | ------------------------------------------------------------------ |
| Healthy                | Zero open Opportunities                                           | PASS                                                            | Pass when the assertion finds PASS                                 |
| Needs review           | One open Opportunity                                              | FAIL                                                            | Pass when the assertion finds FAIL                                 |
| Recovery               | Close that same Opportunity; rerun the same Check                 | PASS                                                            | Pass when the assertion finds PASS                                 |
| Outside applicability  | Make the configured applicability predicate false                 | SKIPPED, if this is the selected contract                       | Pass when SKIPPED and zero forbidden evaluation calls are verified |
| Missing operand        | Required comparison value is absent                               | UNABLE_TO_EVALUATE, if this is the selected contract            | Pass when the exact status and reason are verified                 |
| Invalid configuration  | Required rule configuration is invalid                            | The exact configuration-error outcome specified for this caller | Pass when that outcome and failure precedence are verified         |
| Optional display fault | Keep the one open Opportunity; corrupt only optional presentation | Preserve FAIL with the specified display fallback               | Pass when FAIL survives and unsafe content is absent               |

A red regression would be the needs-review assertion expecting FAIL while the broken implementation
returns PASS. An expected business ERROR is also a passing test when that is the specified result.
Do not treat every invalid configuration as the same status: inspect the public adapter's mapping,
including internal reasons versus public statuses. Assertion failure, Apex job failure, business
failure and incomplete evidence are separate concepts.

## Write the test class before the fix

1. Use the existing test data factory and the smallest deterministic setup that reproduces the
   contract. Name test methods by observable behavior. Keep setup, invocation and assertions clear;
   use shared helpers only when their parameters and assertions remain understandable.
2. Assert exact identities and semantic values with useful failure messages. Assert forbidden keys,
   leaked values and calls are absent. Avoid empty test methods, unconditional assertions and
   coverage-only invocations. An exception test must fail if no exception occurs and verify the
   expected exception contract if it does.
3. Run the focused case against the broken behavior before editing production code. Save the command,
   source, named assertion and expected cause. Compile errors, missing fields, invalid fixture DML,
   missing permissions needed by setup and CLI failures are not behavioral red evidence. Repair setup
   and rerun. A new API may need a minimal compile-only skeleton before its behavior can be red.
4. Add sibling-path, boundary and negative controls, then implement the smallest coherent fix. Preserve
   authorization, ordering and the public contract in shared entry points instead of copying logic
   into another adapter. Keep evaluation, optional display and transport responsibilities explicit.
5. Run green tests. For an important guard, revert only the relevant behavior in an isolated copy and
   show the assertion becomes red again; restore and rerun. Do not disturb unrelated working changes.
6. Connect configurable behavior to integration Check/Check Set metadata, deterministic data and an
   administrator procedure. Repository-only behavior needs an equivalent executable self-test and
   the specific reason Custom Metadata cannot exercise it.

Clone Custom Metadata returned by `getInstance()` before modifying a detached test definition; those
returned records are read-only. Do not mistake that setup exception for the production defect.
Keep `@TestSetup` prerequisites deterministic and permission tests explicit about the actor who runs
setup versus the actor who invokes the product. Do not assume a stage label, locale or record type
has the same meaning in every org; set or discover the required semantic value.

## Challenge isolation, mixtures and recovery

A successful Check Set can hide a broken single Check: a valid sibling may load a relationship that
an invalid Check should never read. Run important cases alone, alongside a valid sibling and with the
sibling removed or reordered. Compare the same record and permissions across affected single-Check,
Check Set, typed controller, JSON, Preview, Flow and bulk boundaries. State intentional differences.

Include fresh transactions versus warmed caches; separate requests versus shared request budgets;
valid and invalid definitions in one scope; missing and denied records beside authorized records;
empty/null inputs; duplicate or reordered identities; and correction followed by rerun. Use targeted
combinations where risks interact, rather than claiming a homogeneous batch proves mixed behavior.

Assert the exact callback record IDs and output ordering. A preflight or permission failure must
prevent forbidden downstream queries, formulas, plugin hooks and field-dependent rendering. A final
error status alone cannot prove that sensitive or expensive work was avoided. Preserve valid siblings
at the specified failure scope and test which earlier failure takes precedence.

The record-page card makes independent Check requests. Two rows or cards do not prove a shared
Check Set response budget. Test that budget through an entry point that actually shares it.

## Verify the wire and the consumer

Typed Apex results, JSON text, Aura delivery, REST/MCP payloads and browser DOM are distinct test
boundaries. Test the actual path used by the consumer, then its strict validator and visible result.
Apex serialization alone cannot prove Aura preserves null array elements.

Include absent object properties, explicit null properties, empty arrays, `rows: [[null]]`, null
group keys, wrong row widths and wrong cell types. Verify authorized typed nulls render the intended
empty-value marker. Keep malformed data rejected; do not pad missing cells or weaken a strict schema
to conceal transport loss. Test PASS and FAIL results with the same evidence shape.

Prefer explicit client field allowlists at transport boundaries. Verify internal operands, hidden
values and storage-only fields are absent, not merely that expected fields are present. Delegating to
a validated entry point must preserve its authorization, membership and source checks. Test text-only
nodes separately from links so an unwanted null property cannot invalidate otherwise valid content.

For evidence, distinguish valid typed nulls, malformed payloads and permission redaction. Specify
completeness and total/omitted counts for each; unknown information must not become a fabricated zero.
Test authorized records in the selected scope and exclusion of records outside it.

## Measure the right limit

For each bound, specify units, owner and scope: field, envelope, Check, record, batch or request.
Test limit minus one, exact limit and limit plus one using actual UTF-8 serialized bytes, including
multibyte characters, escaping, final identity fields and completeness metadata. Character counts
are not serialized byte counts.

Exercise multiple individually valid fields whose combined size exceeds one field's limit. Test the
producer before the shared allocator as well as the final public response: a later truncation can
mask an oversized producer. Specify atomicity and fallback per field/item, with bounded redacted
diagnostics. Optional presentation failure must preserve evaluation truth when the contract requires
it; fatal transaction/security failures require their own precedence tests.

## Preserve trustworthy execution evidence

- Record exact source identity, manifests, test overlays, target org/runtime, commands, job IDs,
  exits and limitations. A duplicate test class in an integration overlay does not prove the packaged
  variant ran. Validate each intended variant through its documented deployment phase.
- Reconcile requested versus executed class and method identities, missing/duplicate/unexpected rows
  and setup results separately. A mistyped requested class can be omitted despite zero reported test
  failures. Summary counters and coverage percentages are supporting evidence, not completeness proof.
- A result file that says passed does not override a process abort or nonzero exit. Preserve the
  original failure and recover the same run through successful independent reporting; reconcile its
  identities before using it. Do not rerun an entire suite solely to recover a report. Follow
  [Apex result collection](./release-runtime-matrix.md#apex-result-collection).
- Green source gates do not establish deployability, browser behavior, restricted-user behavior,
  Locker behavior or an installed package. Label each boundary verified or pending. A live Preview
  API call does not prove the Preview UI journey.
- A fresh browser tab does not guarantee fresh Salesforce LWC assets. Confirm deployed source and
  account for caching before diagnosing a regression or redeploying. Remove temporary diagnostic
  instrumentation, restore original page/data values and record any remaining cleanup limitation.
- Preserve ignored reports and validate source gates from a clean Git-derived copy when local
  evidence affects a gate. Explicitly validate ignored specs; a skipped file is not a checked file.

## Review findings without weakening the contract

Treat analyzer findings as hypotheses. Inspect the exact source and engine logs even when the tool
exits zero; parser exceptions mean incomplete engine coverage. Separate generated assets from intended
source targets while retaining the original report. Record exact finding identity, source hash,
rationale, disposition and regression evidence.

Distinguish false measurements from accurate measurements retained for a justified design, such as an
explicit mapping table protected by exhaustive cases. Do not raise limits, weaken assertions, add
blanket suppressions or fragment readable code solely to reduce a finding count. For large mechanical
refactors, verify preservation of behavior, member coverage, meaningful assertions and fixture purpose.

Keep historical evidence immutable and label superseded conclusions. Put reusable rules in this
standard and AGENTS.md, environment facts in local agent notes, and feature-specific choices in specs.
Update public claims when behavior changes; formatting and link checks cannot establish accuracy.
Use [the documentation standard](./documentation-standard.md) for that review.

## Existing regression examples

These source links are concrete patterns to inspect, not a claim that a future checkout or org has
run them successfully:

- [RHCInvalidDisplayIsolationTest](../../packages/record-health-check/integration-tests/main/default/classes/RHCInvalidDisplayIsolationTest.cls): isolated public, typed and JSON callers, and planning failures that must not read unplanned relationships.
- [RHCControllerEvidenceTransportTest](../../packages/record-health-check/integration-tests/main/default/classes/RHCControllerEvidenceTransportTest.cls): PASS/FAIL typed-null evidence, runner access and omitted null object properties.
- [Record-page card contract](../architecture/record-page-card-contract.md): fresh definitions, visible body states and card transport invariants.

For each new fix, add its exact method-level mapping and red/green evidence to the feature or release
record. These examples do not replace feature-specific assertions and administrator fixtures.

## Related

- [Check outcome verification](./check-outcome-verification.md)
- [Source development](../contributing/source-development.md)
- [Documentation standard](./documentation-standard.md)
