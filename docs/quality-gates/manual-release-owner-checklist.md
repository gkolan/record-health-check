# Manual release-owner checklist

Use this checklist when an authorized maintainer turns a green release pull request into one
promoted Record Health Check package. It is the manual companion to the
[release runtime matrix](./release-runtime-matrix.md) and the complete
[release runbook](../../.github/RELEASING.md).

The release owner decides when to create and promote a package and when scratch-org testing is
worth its quota. An automation assistant may perform those actions when the owner explicitly asks.

## Quota policy: Creation is the final validation phase

The release owner's daily scratch-org allowance is five. Do not create scratch orgs to investigate
an error or test a workflow edit. Use local checks and already authorized, suitable existing orgs
for diagnosis. A check-only deployment does not require a new org. New orgs are reserved for the
final fresh-environment release evidence after known failures are resolved.

Pull-request and push CI must consume no scratch-org or package-version creation quota. Both
Salesforce workflows are manual-only and require the complete no-org preflight before checking
capacity. The source workflow also completes Code Analyzer before any org is created. Source
runtime stages execute namespaced LWS, then namespaced Locker. The Locker stage and each subscriber
stage run one org at a time and stop queued work on failure. A no-namespace source deployment is an
optional contributor check, not a second package shape or a release requirement. Capacity checks
are not reservations and cannot protect against unrelated Dev Hub activity.

Never repeatedly rerun an org-consuming workflow while its first failure is unexplained. Inspect
the original error and existing evidence, correct the cause, and repeat no-org validation first.
Scratch-org workflows are optional release evidence. They are never implied by a release request:
the owner must explicitly authorize each local creation or workflow run before it starts.

Package creation is an owner-run final build after local validation passes, not a debugging tool.
No GitHub workflow creates or promotes a package. Optional clean-install, upgrade, and sandbox tests
may follow creation when the owner authorizes their environments.

## Values to record

Record these values in the pull request or retained release evidence before starting:

| Value | Example or source |
| --- | --- |
| Semantic release | `MAJOR.MINOR.PATCH` from `package.json` |
| Exact package version | `MAJOR.MINOR.PATCH.BUILD` from `config/release-runtime-matrix.json` |
| Release branch | The pull-request head branch |
| Release commit | Full output of `git rev-parse HEAD` |
| Upgrade bases | Every entry in `upgradeBases` in `config/release-runtime-matrix.json` |
| Candidate package ID | The new `04t` returned by package creation |
| Optional hosted evidence | Workflow URLs only when the owner authorized those scratch-org runs |

Do not reuse evidence from another commit, pull-request merge commit, branch head, package build, or
`04t`.

## 1. Prepare the release branch

1. In GitHub Desktop, fetch the origin and switch to the release branch.
2. Confirm every intended release change is committed and pushed.
3. Keep the pull request open and do not delete or advance the release branch until package
   promotion is complete.
4. Confirm the pull request's required static checks pass on the exact release commit.
5. In a terminal opened at the repository root, run:

   ```bash
   git status --short
   git rev-parse HEAD
   npm run check:version-sync
   npm run release:preflight
   ```

6. Stop if the worktree is not clean. Preserve local test and analyzer evidence under its approved
   ignored evidence directory; do not delete evidence merely to satisfy the clean-worktree gate.

A green pull request summary is source evidence only. A pull-request run in which Salesforce jobs
were skipped is not hosted release evidence.

## 2. Configure the hosted credential

The repository Actions secret `SFDX_AUTH_URL` must contain the Dev Hub SFDX authorization URL. Only
the release owner may create or replace this secret.

1. Obtain the value locally:

   ```bash
   sf org display --target-org <dev-hub-alias> --json
   SF_DISABLE_LOG_FILE=true sf org auth show-sfdx-auth-url \
     --target-org <dev-hub-alias> \
     --json | jq -r '.result.sfdxAuthUrl' | pbcopy
   ```

   Continue only when `sf org display` returns `"status": 0`. The second command copies the actual
   `force://` credential directly to the macOS clipboard. The redacted `Sfdx Auth Url` row from
   `sf org display` is a safety notice, not a usable credential.

2. In GitHub, open **Settings → Secrets and variables → Actions**.
3. Create or replace the repository secret named `SFDX_AUTH_URL`.
4. Paste the clipboard value directly into the secret. Do not print or inspect it.

The secret-presence job proves only that the value is nonempty. The `Authenticate Dev Hub` step
must also pass. Hosted workflows use a mode-`600` temporary file because pinned CLI versions can
change stdin-flag parsing; a tracked structural gate rejects the previously broken stdin/alias
command shape.

Treat this value like a password. Never paste it into an issue, pull request, chat, terminal log, or
tracked file.

## 3. Optionally dispatch hosted source validation

Do not perform this section unless the release owner explicitly authorizes scratch-org creation for
the run.

1. Open **Actions → Salesforce release gate**.
2. Select **Run workflow**.
3. Select the release branch, not `main` and not a stale branch.
4. Set `authorize_scratch_org_creation` to `true`, then run the workflow.
5. Confirm `offline-preflight` passes, then confirm `Check release-matrix scratch-org capacity`
   passes with two daily and active slots available. The complete source matrix creates two scratch orgs. Deleting an org
   restores an active slot but does not restore a daily creation. Do not run unrelated scratch-org
   creation concurrently with the release gate.
6. Open the completed run and confirm that all of these jobs executed and passed:
   - `offline-preflight`
   - `require-dev-hub-secret`
   - `package-source-tests`
   - `locker-browser-tests (namespaced)`
7. Confirm the run's head SHA is the recorded release commit.
8. Retain the workflow URL and uploaded evidence.

After any workflow-source fix, commit and push it and start a new workflow run. Rerunning an older
run keeps the older commit and workflow definition, so it cannot validate the fix.

Treat incomplete results as failed optional evidence. They do not block package creation.

## 4. Create exactly one package candidate

Return to the same clean local release branch and run:

```bash
npm run package:create -- --dev-hub <dev-hub-alias> --release-ready
```

The guarded command repeats release preflight, checks package-version capacity, and creates only the
exact four-part version declared in the runtime matrix. Record the returned `04t` package-version ID
and preserve the ignored creation-evidence file
under `packages/record-health-check/.package-evidence/`.

Do not create another candidate because validation failed. Correct the cause first; an additional
candidate requires the documented reviewed override and is not a normal retry mechanism.

## 5. Optionally dispatch installed-package validation

Do not perform this section unless the release owner explicitly authorizes scratch-org creation for
each run.

1. Open **Actions → Subscriber validation**.
2. Select **Run workflow**.
3. Select the unchanged release branch.
4. Enter the exact candidate `04t` in `package_version_id`.
5. Choose `validation_stage: clean-install`, set `authorize_scratch_org_creation` to `true`, and run the workflow.
6. Confirm `offline-preflight` passes. Then confirm
   `Check subscriber-stage scratch-org capacity` passes before the two selected jobs run sequentially.
7. Require both selected jobs to execute and pass, one under Lightning Web Security and one under
   Lightning Locker. Repeat the dispatch for `upgrade-2.0.6.2`, then `upgrade-2.0.4.2`, always using
   the same candidate and unchanged release branch when that additional evidence is desired.
8. Confirm the workflow title identifies the exact candidate and the run's head SHA is the release
   commit.
9. Retain install requests, the complete subscriber Apex inventory (including
   `RHCSubscriberFlowSmokeTest`), browser evidence, and both upgrade-preservation snapshots.

Each subscriber dispatch creates two fresh orgs. Check daily and active capacity before each
authorized stage. Workflow concurrency serializes these
release workflows but does not reserve capacity against other tools or people. Deleting scratch orgs
does not refund daily creations.

The unselected clean/upgrade job is intentionally skipped in each staged dispatch. If the run is
retained as optional evidence, require each selected security-mode job and its artifacts to pass.

A successful source deployment does not prove upgrade behavior. Record each optional result for what
it actually tested.

## 6. Optionally verify a representative sandbox

When the release owner requests human acceptance, install or upgrade the exact candidate in an
approved representative sandbox with the affected CPQ Quote page and customer-owned configuration.
Coordinate access with its owner; never
use production as the test environment. Record the org, persona, expected/actual outcome, and a safe
evidence reference for each scenario below. Do not include credentials or customer record contents.

| Scenario | Acceptance evidence required |
| --- | --- |
| `cpq-quote-lifecycle` | The affected Quote page loads, runs manually and on load, saves, refreshes, and navigates without the reported error, duplicate execution, or an RHC loading overlay. Builder and configuration previews remain quiet. |
| `existing-page-and-access-preservation` | Existing page placements and customer Check Sets survive the upgrade. Admin, Card User, User, and a user without Run permission behave as documented; diagnostics require the separate entitlement. |
| `four-type-business-outcomes` | Representative Formula, Query, Compare Two Queries, and Apex Checks return the expected outcomes, including failure, no-data, and restricted-data cases. A successful transaction alone is insufficient. |
| `existing-automation` | Existing Flow, Apex, REST/MCP, and asynchronous consumers still return their expected results and publish only requested events. Existing validation rules, triggers, and flows remain enabled. |
| `configuration-recovery` | Customer metadata and page-placement backups exist, the documented restore procedure is rehearsed in the sandbox, and a forward-fix/rollout-stop plan is recorded. Do not assume an in-place package downgrade. |

Copy [`config/release-acceptance-template.json`](../../config/release-acceptance-template.json) to
`packages/record-health-check/.package-evidence/<candidate-04t>-acceptance.json`. Fill in the exact
candidate ID, full creation commit, reviewer, ISO verification timestamp, and each scenario's result
and evidence reference. Leave untested scenarios pending. The file stays ignored and local; retain a
redacted copy with the release evidence. This remains useful human evidence, but promotion does not
require the local acceptance file.

## 7. Promote the exact candidate

From the same working copy, unchanged branch, and exact creation commit, run:

```bash
npm run package:promote -- --dev-hub <dev-hub-alias> --package <candidate-04t>
```

Promotion fails unless the worktree is clean, local creation evidence binds the `04t` to the current
commit, and the Dev Hub reports the configured package and exact version. Hosted and sandbox
evidence may be retained when it was explicitly authorized, but it is not a promotion prerequisite.

Record the production and sandbox installation URLs printed by the promotion command.

## 8. Publish the promoted release

After promotion:

1. Update `config/package-releases.json`:
   - move the former `stable` entry to `previous`;
   - set `stable.subscriberPackageVersionId` to the promoted `04t`;
   - update the production and sandbox installation URLs.
2. Update `CHANGELOG.md` with the promoted version, exact `04t`, user-visible behavior, upgrade
   impact, and rollback guidance.
3. Update public install redirects to the promoted `04t` and verify both destinations.
4. Commit and push the publication changes with GitHub Desktop.
5. Wait for the pull request's complete CI workflow to pass again.
6. Merge the pull request into `main`.
7. Create the matching semantic-version tag and GitHub release.
8. Verify the release page, registry, changelog, tag, and both install links all identify the same
   promoted `04t`.

Do not announce a candidate as released before promotion and publication are complete.

The release registry, changelog, package chooser, and public production/sandbox redirects must name
the same promoted `04t`. An emergency redirect to an older release is a documented rollback action,
not a package downgrade: existing subscribers cannot install an older unlocked-package version over
a newer installed version.

## Stop conditions

Stop the release immediately when any required package or publication condition occurs:

- the local branch advances after package creation and before promotion;
- the worktree is dirty;
- package-version capacity is unavailable;
- a required local source gate or Salesforce package build fails;
- version metadata, package report, registry, install links, or release notes disagree.

Fix the cause and repeat the affected gates. Never reinterpret a skipped or partial result as a
pass.

## Lessons retained for every release

- A passing mock cannot prove Salesforce lifecycle compatibility. Keep the exact RefreshView
  regression, and use real browser gates when the owner authorizes their orgs.
- Discover and reconcile every Apex test, including real subscriber Flow interviews; never maintain
  a one-class smoke list that silently omits a new test.
- Prove all four Check types actually execute in manual and on-load fixtures. A fixture's label or
  a completed job is not evidence of type coverage or correct business outcomes.
- Keep each browser run's evidence separate and reject skipped or flaky results. Never let
  a later browser run overwrite an earlier failure's evidence.
- Treat restricted-user first login as a tested prerequisite: wait for the password form or
  Lightning Home rather than checking visibility once after a redirect. Locate password inputs
  by label, and require the actual Home path after submission. A Home return URL, a hidden
  heading, or a login/error page is not success. Keep delayed-form and failure-path regressions
  runnable without consuming scratch-org quota; hosted browser validation remains optional.
- When upgrade rehearsal is authorized, use every supported public distribution base and record
  whether customer configuration was preserved.
- Pin and verify the CLI/authentication command, enforce dependency and coverage checks, and record
  quota limits before dispatch. Fix the cause instead of lowering the gate.
- Authentication success does not prove that a default Dev Hub is configured. Every workflow
  scratch-creation command must explicitly select the authenticated `devhub` alias with
  `--target-dev-hub devhub`. The offline regression gate rejects missing or incorrect Hub targets
  before any creation attempt; do not rely on a runner's saved defaults.
- Run the actual Code Analyzer commands locally before handing off hosted validation; passing
  configuration, suppression-inventory, and source checks does not mean the analyzer passed.
  Test-only Flows need fault connectors too. Fault paths must return explicit failure outputs,
  not silently continue. Check description findings against the Metadata API schema: action
  parameters do not support descriptions, so adding invalid XML is not a valid remediation.
- Inspect converted object metadata, not only source-file/manifest parity. A Setup list view
  under `objects/CustomPermission` causes a non-customizable `CustomObject` entry during 2GP
  packaging. Keep real custom permissions in `customPermissions/`; the artifact gate rejects
  this unsupported object/list-view representation before another package build is attempted.
- Bind every release decision to the same commit and immutable package ID. A green PR, old artifact,
  or source deployment is not proof that the package is ready.

These controls reduce regression risk; they cannot promise that an unknown defect will never occur.

## Related

- [Release runtime matrix](./release-runtime-matrix.md)
- [Package testing and upgrades](./package-testing-and-upgrades.md)
- [Complete release runbook](../../.github/RELEASING.md)
