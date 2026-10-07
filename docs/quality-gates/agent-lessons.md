# Agent lessons and verification handoff

This guide is required reading for coding agents and useful for maintainers updating Record Health
Check. Administrators configuring Checks can return to the [documentation home](../README.md).
Read it at the start of each session, as directed by [AGENTS.md](../../AGENTS.md).

These lessons came from source review, failed Salesforce runs, deployment drift, authorization tests
and real browser verification during 2.0.11 work. They explain how to avoid repeating those failures.
They are maintained guidance, not a certificate that the current checkout passes. Exact run IDs,
local org identities and machine-specific workarounds belong in local evidence and agent notes.

## Start each session with current context

1. Read AGENTS.md and this guide completely. Read `internal/agent-notes.md` when present.
   That file is deliberately ignored and may not exist on another machine.
2. Give a brief acknowledgment naming the lessons that matter to the current task. A useful example:
   “I read the shared guidance and local notes; this change needs error-precedence, permission and
   browser recovery coverage.” Do not paste the whole checklist into every response.
3. Check the branch, working-tree changes and untracked files. Preserve work belonging to the user.
   Establish what source the previous evidence actually tested before relying on it.
4. Identify the applicable skills and read them before the work they govern. Skill availability is
   session-specific. If a named skill is unavailable, use the repository's documented fallback;
   never claim to have run a skill that was not loaded.
5. Read the owning standards for the task: the
   [regression testing standard](./regression-testing-standard.md) for implementation tests,
   [Check outcome verification](./check-outcome-verification.md) for configurable behavior, and
   [record-page card contract](../architecture/record-page-card-contract.md) for the LWC's loading,
   rendering or run path.
6. Resolve the target environment and existing authorization before any org operation. A request to
   validate does not itself authorize scratch-org creation. Follow the
   [scratch-org lifecycle](./scratch-org-lifecycle.md).
7. After compaction or another agent's handoff, preserve completed work and the user's decisions.
   Reopen guidance or evidence whose details are missing or changed; do not repeat expensive checks
   merely because the conversation was summarized.

Shared instructions are carried by AGENTS.md and the Claude, Gemini, Copilot and Cursor entry files.
The documentation gate checks that the reading pointers remain present and are not ignored.
There is no mechanism that proves an agent understood the text. The acknowledgment makes compliance
visible; executable regressions provide the stronger protection for product behavior.

## Keep decisions, lessons and evidence in the right place

| Information                                            | Durable owner                         | How future sessions use it                               |
| ------------------------------------------------------ | ------------------------------------- | -------------------------------------------------------- |
| Shared startup and authorization rules                 | AGENTS.md                             | Read before task work; apply to the current request      |
| Reusable testing rules                                 | Regression testing standard           | Read before writing or changing implementation tests     |
| Feature behavior and rationale                         | Owning architecture or reference page | Verify the current contract before changing its callers  |
| Cross-cutting failure lessons                          | This guide                            | Follow the relevant prevention and verification paths    |
| Local org ownership, paths and environment limitations | Internal agent notes                  | Recheck facts that can expire or change                  |
| Exact commands, source state, run IDs and results      | Retained release or local evidence    | Establish what was executed and which boundary it proves |
| Published artifact behavior                            | Release record and changelog          | Preserve historical accuracy when source moves ahead     |

Promote reusable lessons out of ignored files. Keep credentials, frontdoor URLs, session IDs,
passwords and access tokens out of documentation and uploaded evidence. Local notes must not become
a second product specification or a chronological transcript.

When a note becomes stale, replace its current-status instruction or explicitly supersede it.
For example, a note saying “Apex tests have not run” must not remain actionable after successful
org execution. Keep the old failure in historical evidence if it explains the regression.

## Lesson 1: A regression must fail because of the reported defect

A hidden-heading test appeared meaningful while another invalid field, a missing Card Title, could
produce the same INVALID_CONFIG reason. Removing the intended validation would still leave the
test green. Another test expected a heading error even though the hidden-button rule failed first.

Prevention:

- Start from an otherwise valid fixture. Change only the setting necessary to trigger the defect.
- Specify the expected reason, relevant message or rejected field, and forbidden downstream work.
- Test configurations with multiple invalid settings separately and preserve deliberate first-error
  precedence. Do not assume all paths reaching the same reason code are interchangeable.
- Confirm the broken implementation produces the intended behavioral red result. A setup,
  compiler, permission or CLI failure does not count.
- Where practical, disable only the fix in an isolated copy and show the guard becomes red again.

The concrete regressions live in `RecordHealthCheckConfigValidationTest`,
`RecordHealthCheckDefinitionLoaderTest` and `RHCCardHeadingTest`. The shared authority is the
[regression testing standard](./regression-testing-standard.md). Static source checks help preserve
the tests' presence; they cannot replace executing Apex in Salesforce.

## Lesson 2: Permission tests must control the relevant permission

The original ordinary-user error test ran as a principal who held Admin and Diagnostics Viewer
permission sets. Its expected denial depended on who launched the test.

A denial test must deliberately establish denial or inability to verify access. Use the existing
narrow test seam when appropriate and restore it after the test. Test the authorized path separately.
Do not weaken production authorization, assume that a test runner lacks privileges, or create users
in unlocked-package tests merely to work around the package-build context.

For configuration errors, the server must redact restricted detail before serialization. Hiding it
in the rendered card does not remove it from the network response. Assert the generic payload,
absence of rejected identities, and false detail entitlement for denial. Assert the exact bounded
message only for an authorized actor.

`RecordHealthCheckControllerErrorTest`, access tests and LWC tests guard these paths. The
[service-owned data and package-build rules](./regression-testing-standard.md#service-owned-data-and-package-build-principals)
explain why source-org success does not establish package-version test success.

## Lesson 3: A presentation change can alter whether an action is reachable

Hiding the card heading also removes its Run/Rerun control. That affects configuration validity and
whether user-initiated event publication is reachable.

The user chose a day-one 2.0.11 contract: a hidden heading is valid for page-load execution and invalid
for manual execution. Do not reintroduce a body Run row to support prior-release behavior unless the
user explicitly changes that decision. Preserve accurate historical documentation of released
artifacts without importing their behavior into the new source contract.

When changing presentation, review all dependent surfaces:

- Definition validation and metadata validation must agree on validity and administrator guidance.
- Client-side defense must reject the same malformed definition combinations.
- Publication warnings must consider whether any user-run action is reachable, including when the
  button's own setting is visible but its containing heading is hidden.
- Field descriptions, inline help, reason-code explanations and user verification steps must agree.
- Heading changes must preserve independent PASS and FAIL outcomes for valid configurations.
- The card must retain its accessible name, useful empty body and recovery path.

The [card contract](../architecture/record-page-card-contract.md) owns the behavior.
`check:configuration-identity`, heading-fixture tests, Apex validator tests and LWC tests supply
complementary guards. Manual sandbox fixtures remain part of verification.

## Lesson 4: Preserve authorized detail through client validation and recovery

An otherwise authorized definition response may fail a client-side size or shape check before normal
state assignment. If detail entitlement is assigned only after those checks, the administrator loses
the explanation needed to fix the configuration.

Read the server-provided Boolean entitlement before relevant client validations and preserve the
fail-closed default when it is absent or malformed. Never infer entitlement from a message or the
user's apparent role. Structured configuration errors carry server-verified entitlement because a
rejected definition cannot return its normal DTO.

Test malformed and over-limit definitions with entitled and unentitled callers. Test Try Again after
correcting configuration, and verify that each run rereads definitions. Assert that recovery does not
double-run or evaluate stale checks. LWC tests and the live card-contract browser suite cover
different parts of this path.

## Lesson 5: Source deletion does not remove metadata from an existing org

Three classes deleted in earlier repository changes remained in the source org. They referenced
removed factory methods and caused compilation failures in full local test runs.

Before blaming current source:

1. Reconcile the full failure list, including compile failures, against the deployed and local class
   inventories.
2. Check source history and references for any org-only class. Establish ownership and purpose.
3. Do not restore obsolete factory methods merely to satisfy a class intentionally removed earlier.
4. If cleanup is authorized, prepare exact destructive members and validate the complete resulting
   deployment. Preserve the evidence and recovery source.
5. Confirm that Salesforce deleted only the intended members and that current tests still pass.

This is an operational lesson. Offline CI does not inspect an existing org for stale classes.
A full deployment dry-run and Salesforce test run remain necessary. Never translate this lesson into
automatic deletion of unfamiliar metadata or orgs.

## Lesson 6: Verify identities and process results, not just passing counts

A Salesforce test-run record ID is not necessarily the asynchronous job ID expected by a CLI command.
Identify the record type and expected input; query the run record directly when that is the evidence
available. Do not guess by substituting IDs until a command accepts one.

Use `npm run test:apex:exact` for the intended source scope. Its inventory verification detects
missing or unexpected classes, failing results, inconsistent counts and command failures.
Account for Salesforce's separate TestSetup counting. Inspect compile failures as well as method
assertion failures.

For every retained run, record:

- Exact source state, including relevant uncommitted or untracked files.
- Target org, namespace, execution scope and source variant.
- Requested test inventory, executed result identities and process exit.
- Run or deployment ID with its meaning, evidence paths and final outcome.
- Any environment or prerequisite failure separately from behavioral results.

A source-org test run, deployment validation, installed-package test and browser test are different
evidence boundaries. Passing one must never be described as passing all four.

## Lesson 7: Toolchain and analyzer failures can masquerade as clean scans

Different shells can resolve different Salesforce CLI installations. A version recorded in one
terminal does not establish what an elevated command actually executed. Check the executable path,
CLI version and plugin version in the same environment used for the scan.

Use [toolchain policy](../../config/toolchain.json) as the current version authority; do not copy
old version pins from agent notes. Update applicable workflow pins together when intentionally
updating the toolchain. The toolchain gates check policy, while execution evidence establishes the
actual installed tools.

Follow the Code Analyzer skill and repository CI scan definitions. Inspect every required report and
engine log. Zero findings or exit zero are insufficient when an engine failed to process source.
The analyzer integrity guard rejects incomplete reports and known processing-error signatures.

Keep suppressions narrow, reviewed and bounded by the repository allowlist. Do not disable a rule or
engine just to get green output. Preserve ignored analyzer evidence when a path-policy check objects
to it; use the documented clean-checkout method rather than deleting the evidence.

## Lesson 8: A baseline update needs an independent expected result

Query-verdict parity exposed missing fixtures in the baseline. Refreshing the file alone would have
hidden whether the difference was an intended fixture addition or a product regression.

For each difference, identify the fixture, input, applicability and expected outcome from the
contract and tests. Explain why the old baseline is incomplete or wrong. Only then update it and
rerun the comparison without rewriting the baseline again.

`check:query-shapes` covers static query shape. `check:query-verdicts` compares live Salesforce
outcomes. They are distinct commands; the offline source gate does not execute live parity.
Likewise, a uniqueness assertion must inspect candidate identifiers, not the constant list of
expected identifiers. Preserve a duplicate-input negative test for that guard.

## Lesson 9: Browser prerequisites and failures must be classified accurately

The main Salesforce browser gate and the URL-story runner are separate entry points. Running the
main gate alone does not execute the URL-story browser assertions.

The [integration guide](../../packages/record-health-check/integration-tests/README.md) owns fixture
setup. URL-story verification needs its dedicated records and an active Account page containing the
URL-story Check Set. The main release browser page has a different card inventory.

Before executing a browser suite, verify its records, permissions, active page and selected runtime.
When temporarily changing an integration page, save the original, scope the change, restore it
afterward even if a test fails, and verify the restoration. Resolve exact records and ownership
before running any setup script that deletes matching names.

Distinguish these outcomes:

| Observation                                      | Meaning and next action                                                      |
| ------------------------------------------------ | ---------------------------------------------------------------------------- |
| Browser process cannot create a page             | Investigate local browser/platform setup before claiming a component failure |
| Expected record or card is absent                | Correct the documented integration prerequisites and rerun                   |
| Product assertion fails with valid prerequisites | Diagnose the product or test expectation from independent evidence           |
| Salesforce shell emits an error                  | Identify its origin; do not broadly suppress page errors                     |
| Test skipped, flaky or report missing            | Do not count it as completed passing browser evidence                        |

A local Firefox workaround can be selected through `RHC_FIREFOX_EXECUTABLE_PATH`; its temporary
binary and wrapper are machine-specific, not a portable repository dependency. Reverify the need
before applying it on a future machine.

Salesforce can show a Scheduled Maintenance notice to either the administrator or restricted
user before the expected page. The browser runner initializes both sessions through the shared
first-login helper, acknowledges only that notice, and still requires Lightning Home. Detached
frames during the redirect can be retried; other errors remain failures. Sanitize generated
content-door `sid` and `lm` parameters as well as known credentials, including failure-context
Markdown, before retaining or publishing browser evidence. Retained-org runtime settings retrieval
follows the [scratch-org lifecycle](./scratch-org-lifecycle.md#rolling-two-release-org-window).

The App Builder test recognizes a narrowly specified Firefox Salesforce-shell error shape and
attaches the errors as evidence. Do not expand that exception to arbitrary errors, missing stacks or
component failures. Successful Chromium execution does not establish Firefox or Locker behavior.
The browser evidence helper rejects empty, skipped, flaky and failed reports and redacts secrets.

For record-save lifecycle verification, wait for fresh evaluation responses from both populated
cards before navigating away. Previous completed totals and generic Aura request counts can pass
while the save-triggered refresh is still running. Destroying that page early can also raise a
Salesforce wire-refresh error in Firefox. Keep the actual response assertion and strict page-error
check; do not suppress that error or count stale totals as a refreshed run.

## Lesson 10: Preserve release truth and include new guards in the handoff

A branch name does not prove the package version was bumped or that a candidate exists. Consult
package configuration and release records. Current source evidence must not overwrite the history
of an already promoted package or satisfy a new candidate's installed-package requirement.

Inspect `git status --short` before handoff. New test classes, their metadata files, script tests and
fixture contracts can make local checks pass while remaining absent from the next commit. Make
their inclusion explicit when committing is authorized. A documentation gate can reject ignored
guidance, but cannot make an untracked file appear in a remote checkout.

Use the single [gate declaration](../../scripts/lib/release-gates.mjs) rather than maintaining a
separate remembered list. Run applicable focused checks while iterating, then the required full
checks before handoff. Do not rerun unrelated expensive suites solely for a documentation change
when no runtime claim has changed; state exactly what was checked.

Package creation, promotion, new scratch orgs and optional hosted workflows retain their own
authorization rules. A successful local preflight does not create those artifacts or evidence.

## What is automated and what still requires execution

| Boundary                        | Existing guard or command                              | Important limit                                                    |
| ------------------------------- | ------------------------------------------------------ | ------------------------------------------------------------------ |
| Startup documentation           | `check:docs`                                           | Protects guide and pointers, not actual reading or comprehension   |
| Shared source checks            | `ci:gates`, `release:preflight`                        | Do not deploy or run every live integration entry point            |
| Test/fixture presence and shape | Configuration identity, fixture coverage, script tests | Static checks do not establish Salesforce behavior                 |
| UI behavior                     | Jest and Salesforce browser suites                     | Mocked UI and actual runtime evidence remain separate              |
| Apex execution                  | Exact Apex inventory runner                            | Requires the correct deployed source and an authorized org         |
| Security analysis               | CI analyzer scans and integrity guard                  | Requires complete reports and functioning engines                  |
| Query outcomes                  | Live query-verdict comparison                          | Requires independent expectations before baseline changes          |
| Examples and URL story          | Demo verifier, URL-story outcome and browser verifiers | Require documented records, metadata and page setup                |
| Org metadata drift              | Deployment dry-run and full tests                      | No automatic org-only metadata deletion or offline drift guarantee |
| Package and runtime variants    | Candidate installation and relevant LWS/Locker checks  | Source success does not close the installed-package boundary       |

## End each session with a usable handoff

Record what changed, why, the exact checks run, and the evidence boundaries still pending. Say
whether changes are committed, untracked or only local. Include external-state changes and cleanup
results, especially temporary pages, records or test users.

Update local notes only with durable facts a future session cannot recover easily from source.
Include the date, scope, reason and how to apply the fact. Mark verification as historical to its
tested source; do not write “current source passes” without a source boundary that can be recovered.

When adding a lesson, record the observed failure, independent expected behavior, prevention,
named guard, evidence required to verify it, and any limitation. Update the owning standard first
when the rule belongs there, and link it here. Do not substitute a new paragraph for a missing
behavioral regression test.

## Related

- [Regression testing standard](./regression-testing-standard.md)
- [Check and Check Set outcome verification](./check-outcome-verification.md)
- [Record-page card contract](../architecture/record-page-card-contract.md)
- [Documentation standard](./documentation-standard.md)
- [Manual release-owner checklist](./manual-release-owner-checklist.md)
