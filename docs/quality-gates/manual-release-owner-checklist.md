# Manual release-owner checklist

Use this checklist when an authorized maintainer turns a green release pull request into one
promoted Record Health Check package. It is the manual companion to the
[release runtime matrix](./release-runtime-matrix.md) and the complete
[release runbook](../../.github/RELEASING.md).

The release owner performs GitHub authentication, pushes, merges, workflow dispatches, package
creation, and promotion. A contributor or automation assistant may prepare source, commits, local
validation, and instructions, but must not use or request the release owner's GitHub credentials.

## Values to record

Record these values in the pull request or retained release evidence before starting:

| Value | Example or source |
| --- | --- |
| Semantic release | `MAJOR.MINOR.PATCH` from `package.json` |
| Exact package version | `MAJOR.MINOR.PATCH.BUILD` from `config/release-runtime-matrix.json` |
| Release branch | The pull-request head branch |
| Release commit | Full output of `git rev-parse HEAD` |
| Upgrade base | `upgradeFromVersion` from `config/release-runtime-matrix.json` |
| Candidate package ID | The new `04t` returned by package creation |
| Hosted source workflow | URL of the successful manually dispatched run |
| Subscriber workflow | URL of the successful run for the exact `04t` |

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
   sf org display --target-org <dev-hub-alias> --verbose
   ```

2. In GitHub, open **Settings → Secrets and variables → Actions**.
3. Create or replace the repository secret named `SFDX_AUTH_URL`.
4. Paste the **Sfdx Auth Url** directly into the secret value.

Treat this value like a password. Never paste it into an issue, pull request, chat, terminal log, or
tracked file.

## 3. Dispatch hosted source validation

1. Open **Actions → Salesforce release gate**.
2. Select **Run workflow**.
3. Select the release branch, not `main` and not a stale branch.
4. Run the workflow.
5. Open the completed run and confirm that all of these jobs executed and passed:
   - `require-dev-hub-secret`
   - `package-source-tests`
   - `portable-source-tests`
   - `locker-browser-tests`
6. Confirm the run's head SHA is the recorded release commit.
7. Retain the workflow URL and uploaded evidence.

Stop if any job is skipped, cancelled, timed out, pending, inconclusive, or failing. The green
wrapper result from a credential-skipped pull-request run does not qualify. Package creation accepts
only a successful `workflow_dispatch` run for the exact commit.

## 4. Create exactly one package candidate

Return to the same clean local release branch and run:

```bash
npm run package:create -- --dev-hub <dev-hub-alias> --release-ready
```

The guarded command repeats release preflight, verifies the successful hosted source workflow,
checks Dev Hub capacity, and creates only the exact four-part version declared in the runtime
matrix. Record the returned `04t` package-version ID and preserve the ignored creation-evidence file
under `packages/record-health-check/.package-evidence/`.

Do not create another candidate because validation failed. Correct the cause first; an additional
candidate requires the documented reviewed override and is not a normal retry mechanism.

## 5. Dispatch installed-package validation

1. Open **Actions → Subscriber validation**.
2. Select **Run workflow**.
3. Select the unchanged release branch.
4. Enter the exact candidate `04t` in `package_version_id`.
5. Run the workflow.
6. Confirm all four matrix jobs execute and pass:
   - clean install under Lightning Web Security;
   - clean install under Lightning Locker;
   - upgrade from the tracked stable version under Lightning Web Security;
   - upgrade from the tracked stable version under Lightning Locker.
7. Confirm the workflow title identifies the exact candidate and the run's head SHA is the release
   commit.
8. Retain install requests, Apex results, browser traces, and upgrade-preservation snapshots.

Successful source deployment or clean installation cannot replace the upgrade gate. Successful job
completion without the required retained artifacts is also a failure.

## 6. Promote the exact candidate

From the same working copy, unchanged branch, and exact creation commit, run:

```bash
npm run package:promote -- --dev-hub <dev-hub-alias> --package <candidate-04t>
```

Promotion fails unless the worktree is clean, local creation evidence binds the `04t` to the current
commit, hosted source validation passed for that commit, and subscriber validation passed for that
commit and candidate. Never bypass or rewrite this evidence.

Record the production and sandbox installation URLs printed by the promotion command.

## 7. Publish the promoted release

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

## Stop conditions

Stop the release immediately when any of these conditions occurs:

- source or subscriber Salesforce jobs are skipped;
- the workflow commit differs from the release commit;
- the subscriber workflow names a different `04t`;
- the local branch advances after package creation and before promotion;
- the worktree is dirty;
- scratch-org or package-version capacity is unavailable;
- a browser, analyzer, Flow, Apex, security, clean-install, upgrade, or evidence-upload gate fails;
- subscriber-owned configuration changes or disappears during upgrade;
- version metadata, package report, registry, install links, or release notes disagree.

Fix the cause and repeat the affected gates. Never reinterpret a skipped or partial result as a
pass.

## Related

- [Release runtime matrix](./release-runtime-matrix.md)
- [Package testing and upgrades](./package-testing-and-upgrades.md)
- [Complete release runbook](../../.github/RELEASING.md)
