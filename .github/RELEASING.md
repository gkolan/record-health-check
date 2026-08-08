# Release Record Health Check

Record Health Check ships primarily as the namespaced unlocked package `Record Health Check`.
Source deployment is a contributor workflow and is not the supported subscriber installation path.

## Version model

The Framework follows Semantic Versioning. `package.json` carries the Framework version and
`packages/record-health-check/sfdx-project.json` carries the Salesforce package version as
`MAJOR.MINOR.PATCH.NEXT`. Each package build uses `MAJOR.MINOR.PATCH.BUILD`; later build numbers are
immutable candidates for the same semantic release.

## Single source of truth for subscriber installs

All subscriber-facing install URLs, CLI scripts, and CI gates read from
[`config/package-releases.json`](../config/package-releases.json).

Checks:

1. `stable.subscriberPackageVersionId` must always refer to a **promoted** version.
2. Never update `stable` merely because package-version creation produced a new candidate `04t`.
3. Move the current stable `04t` into `previous` before replacing `stable`.
4. Refresh `installUrl.production` and `installUrl.sandbox` when `stable` changes.
5. Do not duplicate the stable `04t` across README badges, docs, and scripts. Update
   `package-releases.json` first, then run doc checks.

## Required evidence

Before creating a release candidate:

1. Run every local gate, including docs, query shapes, permissions, formatting, lint, and Jest.
2. Run Code Analyzer and resolve every unsuppressed release finding.
3. Run the package-source org gate in CI (`salesforce-validate.yml`).
4. After both namespaced and no-namespace source tests complete, run
   `npm run check:apex-coverage -- <org-alias>` for each org and retain the lower Framework result.
   Run `npm run test:unit:coverage`, update `config/quality-metrics.json` and the README, then run
   `npm run check:quality-metrics -- --apex-org <org-alias>` against both orgs. Published coverage
   must describe the candidate being released, not a prior package.

After creating the single candidate and before promotion:

1. Run `npm run package:verify` against its explicit `04t`.
2. Confirm the retrieved server artifact passes the physical-file audit.
3. Confirm clean install, N-1 upgrade, and subscriber-owned Custom Metadata preservation gates.

Never discard deploy, test, package, or install output. Archive JSON results with the release.

Before any Salesforce operation, run `npm run check:toolchain`. Before creating scratch orgs or a
package candidate, the repository scripts check the authoritative Dev Hub limits and stop rather
than consume the last required capacity. Package verification deletes only the orgs it created; use
`--keep-org` solely for an intentional, time-bounded investigation and delete that org afterward.
See [Salesforce operations standard](SALESFORCE_OPERATIONS.md) for the mandatory lifecycle checks and
the redacted migration record.

## Create a package candidate

Package creation is manual and happens once, at the end of release-branch preparation. Do not create
a package version for every commit and do not add creation to ordinary pull-request CI. Commit the
exact release source first; the command refuses a dirty worktree, `main`, a detached HEAD, or a
missing explicit release-ready acknowledgement. The command runs the complete local release
preflight before consuming package-version capacity. That preflight converts the package to
Metadata API format and proves that every Custom Metadata member named in `package.xml` has a
physical file, including exactly four Check Sets and 21 Checks.

The command permits only one candidate attempt in a Dev Hub package-create limit window by default.
If any package-create capacity has already been consumed, wait for the limit to reset. An additional
attempt requires both `--allow-additional-candidate` and a reviewed `--override-reason` of at least
20 characters. This exception is for an externally time-critical release with evidence of a fixed
cause; it is not a retry mechanism for package debugging.

```bash
npm run package:create -- --dev-hub <dev-hub> --release-ready
```

The Node entry points work on Windows, macOS, and Linux. Pass `--dev-hub` explicitly; do not rely
on the bash-only `VAR=value command` prefix.

Or manually from the nested package project:

```bash
cd packages/record-health-check

sf package version create \
  --package 0Hoak0000004kKPCAY \
  --definition-file config/project-scratch-def.json \
  --code-coverage \
  --generate-pkg-zip \
  --installation-key-bypass \
  --wait 120 \
  --target-dev-hub <dev-hub>
```

Record the resulting `04t` ID. Verify the immutable candidate, attach the redacted evidence to the
pull request, and do not promote it until subscriber verification gates pass.

## Verify before promote

```bash
npm run package:verify -- --dev-hub <dev-hub> --package <candidate-04t>
```

This runs:

- Retrieval of the immutable server-generated package artifact
- Refusal to continue unless all 25 Custom Metadata records exist in both its manifest and files
- Clean no-namespace install of the candidate
- Subscriber harness deploy and `RHCSubscriberSmokeTest`
- Previous-to-candidate upgrade rehearsal when `previous` is a promoted `04t`

## Promote and publish

```bash
npm run package:promote -- --dev-hub <dev-hub> --package <candidate-04t>
```

Then update `config/package-releases.json`:

1. Move the current stable entry to `previous`.
2. Set `stable.subscriberPackageVersionId` to the promoted `04t`.
3. Refresh `installUrl` values.
4. Update `CHANGELOG.md` and create the GitHub release.

Also commit the exact source used to create the package, create the matching semantic-version tag,
and configure the public install redirect (`recordhealthcheck.com/install`) to the new stable `04t`.

Current promoted subscriber package version ID: see `config/package-releases.json`.

## Demo Example Check Sets and Checks

The 25 `Example_` Check Sets and Checks ship **inside** the package, from
`packages/record-health-check/force-app/main/default/customMetadata`. A subscriber gets four Demo
Check Sets and 21 Checks on install, with no extra step. `check:package-boundary` enforces that they
stay there and stay byte-identical to their `integration-tests` copies.

Do not move them to an unpackaged directory and do not add `unpackagedMetadata` to
`sfdx-project.json`; that flag deploys metadata to the build org for testing and then deliberately
excludes it from the package, which is how `2.0.0.6` came to install with zero Example records.

Demo _data_ is different. The Acme Accounts and related records the demo org uses are subscriber
owned, come from `scripts/subscriber/data`, and must never be packaged.

Package artifact evidence is retained locally under
`packages/record-health-check/.package-artifacts/<04t>/`. Verification never overwrites an existing
artifact directory. If retrieval is interrupted, inspect and move or delete the incomplete directory
before retrying. The Dev Hub user must have Salesforce's package-zip download permission; a missing
permission blocks verification before a scratch org is created.

## Rollback

Salesforce package versions are immutable. Roll forward with a corrected package version when a
schema or installed metadata change cannot be safely reversed. For an application-only regression,
install the previously supported version only when Salesforce package ancestry and upgrade checks
permit it. Document data or configuration remediation separately.
