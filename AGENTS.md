# Repository working agreement

Before handing off a pull request, run the checks from the `ci` job in
`.github/workflows/ci.yml`. Do not describe the branch as CI-ready until every
tracked-source check passes. Also confirm that the hosted Salesforce validation
jobs pass after the branch is pushed when the release owner explicitly authorizes
scratch-org creation for that validation. Hosted scratch-org validation is optional
release evidence; it is not a prerequisite for package creation or promotion.

Never create a scratch org, or dispatch a workflow that can create one, without the
user's explicit authorization for that specific creation or workflow run. A request to
test, validate, release, or create a package is not scratch-org authorization. Before
an authorized scratch-org operation, read the
[scratch org lifecycle and release plan](docs/quality-gates/scratch-org-lifecycle.md). Check the
Dev Hub inventory first, reuse a matching project org, use the documented lifetime and ownership
rules, and delete disposable orgs after saving evidence. A new agent or terminal is not a reason to
create another org. Never delete an unfamiliar org without confirming its owner and purpose.

Each product release may retain only one LWS and one Locker subscriber scratch org. Keep at most
the current and immediately preceding release pairs; delete release `N` before creating the `N+2`
pair. Clean installation and the previous-release upgrade reuse the same two orgs through the
guarded uninstall/reset path. `config/release-org-policy.json` is the executable policy.

Package creation and promotion are release-owner decisions. When the user explicitly asks for
them, run the guarded local quality checks and Salesforce's package commands without inventing an
additional hosted-workflow or scratch-org approval requirement.

`npm run check:code-analyzer-output-paths` scans the working directory, including
ignored files. Local, ignored Code Analyzer evidence under `reports/` can make
that check fail even though a clean CI checkout passes. Preserve those local
files and verify the check from a clean archive or checkout instead of deleting
user evidence.

Keep pull request titles and descriptions concise, specific, and written in
plain human language. Explain the user-visible outcome, the important safety or
quality improvements, and how the change was verified.

## Agentforce and MCP contract

Treat `contracts/agent-tool/1`, the Apex REST adapter, the native Agentforce
actions, and the MCP server as one versioned boundary. A change to any request,
response, status, diagnosis field, or limit must update every applicable surface,
its public documentation, and `check:agent-tool-contract` in the same change.

For MCP changes, preserve Streamable HTTP behavior, OAuth protected-resource
discovery, the dedicated integration user's least privilege, strict input and output
schemas, and model-facing status semantics. Run `npm run check:mcp`,
`npm run check:agent-tool-contract`, and `npm run check:docs` while iterating.

For Agentforce changes, distinguish the native invocable-action path from the REST
and MCP paths. Keep the Agent Spec draft until a human approves it, specify the test
runner explicitly, and never describe a template as executable until its structural
validator passes. Publishing, activating, or previewing against a Salesforce org
requires the user's explicit authorization and an identified target org.

## Specification authoring contract

Before creating or substantively revising any feature specification, read
[Specification authoring standard](specs/spec-authoring-standard.md) completely and follow it.
For implementation-ready depth, apply its depth gate, research-accounting and verification sections.
Use `specs/merge-syntax-and-inline-links` as a precision benchmark, not only a folder template.
Resolve material API/payload/storage choices, map exact assertions to feature-specific fixtures and
test cases, and visibly supersede earlier alternatives. Do not call matching headings or generic
scenario lists equivalent depth. A locked design is not a verified implementation; keep platform,
installed-package and browser evidence explicitly pending until executed. Check ignored spec files
explicitly so a formatter or gate that skipped them cannot be reported as verification.
Create each feature under `specs/<feature-name>/` with independently verifiable Markdown steps,
not in `docs/contributing/`. Inspect current APIs and contracts, distinguish confirmed requirements
from proposals, and resolve material choices before describing a spec as locked. Include ordinary,
admin-error, edge, adversarial and recovery scenarios; paired PASS/FAIL Check and Check Set fixtures;
red-before-green tests; and requirement-to-evidence traceability. Use the standard's justified
non-Check fixture exception for repository-only work. Never describe planned fixtures or tests as
created or verified. Keep feature specs untracked under existing policy. This shared `AGENTS.md` and
its Claude, Gemini, Copilot, and Cursor pointers are public repository guidance and must stay tracked.

## Regression-first development contract

Read [Check and Check Set outcome verification](docs/quality-gates/check-outcome-verification.md)
before changing Check behavior or packaged examples. It is the tracked, reusable authority for
expected Salesforce outcomes in new functionality and every release.

Every bug fix and new product behavior must leave an executable guard that makes a recurrence
detectable. A code change without the corresponding tests and user-verification fixtures is
incomplete.

### Bug fixes

1. Before changing production code, add or identify a test that reproduces the reported behavior.
   Run it against the broken implementation and confirm that it fails for the expected reason.
2. Preserve that test as a regression test. It must assert the observable contract, fail again if
   the fix is reverted, and cover every affected sibling path, not only the first caller where the
   bug was found.
3. Add the relevant ordinary-use, boundary, empty/null, error, permission/security, bulk/limit,
   namespace, and platform-variation cases. Mark a category not applicable only when its behavior
   genuinely cannot affect the change.
4. For behavior that users can exercise through Record Health Check configuration, add or update
   integration-test `Record_Health_Check_Set` and `Record_Health_Check` Custom Metadata fixtures.
   The Check Set and Checks must reproduce the regression and give an administrator a concrete
   sandbox verification path. Connect every fixture to an automated test or documented verification
   procedure; do not add orphaned sample metadata.
5. Record the red result, the green result, and the exact automated and manual verification paths in
   the pull request or release evidence.

### New functionality

1. Before implementation, write down a scenario matrix covering the everyday user journey,
   expected success and failure outcomes, boundary and empty states, invalid input, permissions and
   security, bulk/governor limits, namespaces, and relevant runtime variations such as LWS versus
   Locker, multicurrency, locale, and time zone.
2. Create the automated tests first and confirm that they are red because the behavior does not yet
   exist. Then implement the smallest change that makes them green. Tests added only after the
   implementation do not satisfy this contract unless the red state is demonstrated by reverting or
   disabling the implementation.
3. Test at the lowest useful layer and at every important boundary the feature crosses: Apex unit,
   LWC/Jest, metadata validation, integration, browser, packaging, or hosted Salesforce validation.
4. Add a representative integration-test Check Set and Checks for each user-visible configuration
   path, including expected PASS, FAIL, SKIPPED, or UNABLE_TO_EVALUATE results where applicable.
   Document the setup, record data, action, and expected result so a user can verify the feature in a
   sandbox without reading the implementation.
5. A feature is not complete until the scenario matrix, automated tests, Check/Check Set fixtures,
   user-verification instructions, and required CI and hosted Salesforce validations are all green.

If a change cannot meaningfully be represented by a Record Health Check Check and Check Set (for
example, repository-only documentation or release tooling), add the equivalent executable fixture or
self-test and state the specific reason Custom Metadata is not applicable. Do not use this exception
merely to avoid creating user-verification coverage.

## Record-page card contract

Two behaviors of the `recordHealthCheck` LWC are easy to remove by accident, because both look
like redundant work when you read the component on its own:

1. Every card-initiated run goes through `_loadDefinitions`, so a run never evaluates against
   configuration it did not just read. Do not reuse `this.checks` and call `_runner.run` directly,
   and do not mark `getCheckDefinitions` as `cacheable=true`.
2. `showEmptyBodyNotice` renders when no other body block does, so the card cannot collapse to a
   header-only strip. Adding a body block means adding it to that condition. Adding an `await` to
   the load path means giving that window a loading state.

[Record-page card contract](docs/architecture/record-page-card-contract.md) owns the full
reasoning, the verified state table, and the steps to confirm the guarding tests still fail when
the behavior is removed. Read it before changing the component's loading, rendering, or run path.

## Where things live

Read this before grepping. Paths are repo-relative.

| Looking for                                                    | Go to                                                                                          |
| -------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| How to author or revise a feature specification                | `specs/spec-authoring-standard.md` (required reading); one feature per `specs/<feature-name>/` |
| The list of source gates                                       | `scripts/lib/release-gates.mjs` (single declaration; run all with `npm run ci:gates`)          |
| Gates a release runs that a PR does not                        | `releaseGates` in `scripts/lib/release-gates.mjs` (run with `npm run release:preflight`)       |
| A gate's implementation                                        | `scripts/release/check_*.mjs` and `check_*.py`                                                 |
| A package Apex class, by concern                               | `docs/architecture/apex-implementation/README.md`                                              |
| Package Apex/LWC source                                        | `packages/record-health-check/force-app`                                                       |
| Check / Check Set fixtures                                     | `packages/record-health-check/integration-tests`                                               |
| Prebuilt inventories (don't regenerate to read them)           | `scripts/release/generated/`                                                                   |
| What CI runs without an org                                    | `.github/workflows/ci.yml`                                                                     |
| Scratch-org ownership, reuse, verification, and release budget | `docs/quality-gates/scratch-org-lifecycle.md`                                                  |
| What hosted source validation does in scratch orgs             | `.github/workflows/salesforce-validate.yml`                                                    |
| Architecture and data model                                    | `docs/architecture/README.md`                                                                  |
| Local, machine-only notes                                      | `internal/` (untracked)                                                                        |

## Which gate for which change

Run the likely gates while iterating, then `npm run ci:gates` before handing off. The
full run is the authority, this table is only to shorten the loop.

| Changed                                                    | Likely gates                                                                                                                                                      |
| ---------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Anything                                                   | `prettier:verify`                                                                                                                                                 |
| LWC / JS                                                   | `lint`, `lint:slds`, `test:unit:coverage`                                                                                                                         |
| `scripts/**/*.mjs`, `tests/**/*.mjs`                       | `lint` (covers them now, not only LWC)                                                                                                                            |
| Python gate scripts                                        | `lint:python`                                                                                                                                                     |
| `.github/workflows/*.yml`                                  | `lint:workflows`, `check:release-runtime-matrix`                                                                                                                  |
| Apex                                                       | `check:apex-architecture`, `check:apex-surface`, `check:plugin-sharing`, `check:test-data-factory`                                                                |
| Check / Check Set metadata                                 | `check:field-limits`, `check:check-set-comprehension`, `check:fixture-value-coverage`, `check:demo-outcome-coverage`, `check:configuration-identity`, `check:xml` |
| `scripts/lib`                                              | `test:scripts`                                                                                                                                                    |
| One gate at a time                                         | `npm run ci:gates -- --only <exact names>`; `--list` prints them                                                                                                  |
| Docs                                                       | `check:docs`                                                                                                                                                      |
| `docs/build-checks/draft-with-ai/**`, `tests/ai-drafts/**` | `check:ai-prompts`                                                                                                                                                |
| Version bump                                               | `check:version-sync`, `check:product-version-language`                                                                                                            |

Gates never catch org-side deploy failures. A green `ci:gates` is not a deployable branch;
dry-run the deploy before calling a branch ready.

`npm run ci:gates` is the pull-request list. `npm run release:preflight` runs that list plus any
deterministic release-only gates. Editing a prompt under `docs/build-checks/draft-with-ai` fails
`check:ai-prompts` until the provider-neutral reference fixture under `tests/ai-drafts` matches the
edited prompt and metadata contract. This validation is entirely offline and must not require a
provider credential, SDK, paid account, or live model call.

## Skills to use

Skill names vary across coding agents. When the named skill is available, invoke it
before starting the work; otherwise follow the same repository contract and current
official Salesforce guidance rather than guessing.

| Work                                  | Skill                                                        |
| ------------------------------------- | ------------------------------------------------------------ |
| Writing or changing package Apex      | `sf-apex`, then `platform-apex-generate`                     |
| Adding Apex tests                     | `platform-apex-test-generate`                                |
| Running Apex tests / reading failures | `platform-apex-test-run`, `dx-devops-test-failures-analyze`  |
| Debugging an Apex failure in an org   | `sf-debug`, `platform-apex-logs-debug`                       |
| The `recordHealthCheck` LWC           | `sf-lwc`; read the record-page card contract first           |
| LWC styling (the `lint:slds` gate)    | `design-systems-slds-apply`, `design-systems-slds-validate`  |
| Custom Metadata, objects, fields      | `sf-metadata`                                                |
| Deploying to the scratch pair         | `sf-deploy`, `dx-org-manage`                                 |
| SOQL and the query-shape gate         | `sf-soql`, `platform-soql-query`                             |
| Permission sets and access            | `sf-permissions`                                             |
| Code Analyzer runs and suppressions   | `dx-code-analyzer-run`                                       |
| Looking up Salesforce behavior        | `sf-docs`, `platform-docs-get`                               |
| Reviewing a finished change           | `code-review`, `security-review`, `ponytail:ponytail-review` |

Do not hand-roll what a skill covers. `dx-code-analyzer-run` replaces reconstructing
analyzer invocations from `.github/workflows/salesforce-validate.yml`.

## Keeping notes current

`internal/agent-notes.md` holds durable, machine-local project facts that every agent
reads. Claude's own memory directory is Claude-only, so project facts belong here, not
there.

Before ending a turn, append a note when the turn established a fact that a future
session would otherwise re-derive: a decision the user made and the reason, an
environment or org fact not visible in the code, an expected failure that is not a
regression, a scope boundary, or a correction to something in this file. One fact per
entry, dated, with why it matters and how to apply it.

Do not record what the repo already says, such as code structure, git history, or anything in
this file. Do not record session scratch. If a note turns out to be wrong, delete it in
the same turn you discover that; a stale note costs more than a missing one.
