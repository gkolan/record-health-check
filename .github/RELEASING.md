# Release Record Health Check

> [!NOTE]
> On this page, build, verify, promote, and publish one immutable Record Health Check package
> candidate using the repository release gates.

Record Health Check ships primarily as the namespaced unlocked package `Record Health Check`.
Source deployment is a contributor workflow and is not the supported subscriber installation path.

The authorized maintainer should follow the
[manual release-owner checklist](../docs/quality-gates/manual-release-owner-checklist.md) for the
exact GitHub Desktop, workflow-dispatch, package-creation, subscriber-validation, promotion, merge,
tag, and publication sequence. That checklist does not replace the detailed contracts on this page.

## Version model

The Framework follows Semantic Versioning. `package.json` carries the Framework version and
`packages/record-health-check/sfdx-project.json` carries the Salesforce package version as
`MAJOR.MINOR.PATCH.NEXT`. Each package build uses `MAJOR.MINOR.PATCH.BUILD`; later build numbers are
immutable candidates for the same semantic release. The package version name must be
`Version MAJOR.MINOR.PATCH` so Salesforce installation messages show the semantic version without
repeating the package name. Run `npm run check:version-sync`; CI and release preflight run the same
gate and fail when the three values do not match.

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
   `npm run check:quality-metrics -- --apex-org <org-alias>` against both orgs. The gate treats the
   published Apex value as the conservative cross-shape floor: both orgs must meet or exceed it.
   Published coverage must describe the candidate being released, not a prior package.

After creating the single candidate and before promotion:

1. Run `npm run package:verify` against its explicit `04t`.
2. Confirm clean install, N-1 upgrade, and subscriber-owned Custom Metadata preservation gates.
3. Run `npm run release:preflight` again from the final committed release source.
4. Confirm the pull request's complete GitHub Actions **CI** workflow is green. Do not promote while
   CI is absent, pending, cancelled, or failing.

Never discard deploy, test, package, or install output. Archive JSON results with the release.

Before any Salesforce operation, run `npm run check:toolchain`. Before creating scratch orgs or a
package candidate, the repository scripts check the Dev Hub limits and stop rather
than consume the last required capacity. Package verification deletes only the orgs it created; use
`--keep-org` solely for an intentional, time-bounded investigation and delete that org afterward.
See [source development](../docs/contributing/source-development.md) for the public contributor workflow and
scratch-org lifecycle checks.

## Create a package candidate

### Package source layout

Second-generation packaging builds from the local source directory declared in
`packages/record-health-check/sfdx-project.json`. The Dev Hub and namespace-registry org do not
supply missing package content. Every component intended for subscribers must therefore exist under
`packages/record-health-check/force-app` before package-version creation starts.

Custom Metadata types and Custom Metadata records use different filename conventions:

```text
packages/record-health-check/force-app/main/default/
├── objects/
│   ├── Record_Health_Check_Set__mdt/
│   │   └── Record_Health_Check_Set__mdt.object-meta.xml
│   └── Record_Health_Check__mdt/
│       └── Record_Health_Check__mdt.object-meta.xml
└── customMetadata/
    ├── Record_Health_Check_Set.Example_Account_Check_Builder_Guide.md-meta.xml
    └── Record_Health_Check.Example_Account_Billing_Address.md-meta.xml
```

The type directory and object definition retain the `__mdt` suffix. A record filename does **not**:

```text
<CustomMetadataTypeDeveloperName>.<RecordDeveloperName>.md-meta.xml
```

For example, use
`Record_Health_Check_Set.Example_Account_Check_Builder_Guide.md-meta.xml`, not
`Record_Health_Check_Set__mdt.Example_Account_Check_Builder_Guide.md-meta.xml`. The second segment is
the record's Developer Name, not its displayed Master Label. Package source also stays unprefixed;
Salesforce applies the package's `rhc` namespace while building the namespaced artifact.

The package manifest must identify records by the same metadata full name used by the physical
files. Do not add `rhc__` or `__mdt` to a Custom Metadata record member merely because Apex refers
to its SObject type as `rhc__Record_Health_Check_Set__mdt` after installation.

### Prove Custom Metadata round-trip before packaging

Before running the release preflight, deploy the exact package source to a namespaced `rhc` scratch
org, retrieve the Custom Metadata records into a clean temporary directory, and compare the
retrieved names and XML with the committed source. A successful deployment alone is insufficient:
Salesforce can accept a source name that is later normalized differently in the server-generated
package ZIP.

From the nested package project:

```bash
cd packages/record-health-check

sf project deploy start \
  --source-dir force-app/main/default/objects/Record_Health_Check_Set__mdt \
  --source-dir force-app/main/default/objects/Record_Health_Check__mdt \
  --source-dir force-app/main/default/customMetadata \
  --target-org <namespaced-scratch-org> \
  --wait 30

sf project retrieve start \
  --metadata CustomMetadata \
  --target-org <namespaced-scratch-org> \
  --target-metadata-dir <empty-directory> \
  --unzip \
  --wait 30
```

Use a new, empty directory outside the tracked package source so retrieval cannot silently overwrite
the files being audited. Confirm all of the following before continuing:

1. The retrieve returns 54 records: four Check Sets and 50 Checks.
2. Each manifest member has one physical record file with the same metadata full name.
3. Record filenames omit `__mdt` and the `rhc__` namespace.
4. Record XML field names remain unprefixed in package source.
5. No record exists only in the org or only in the repository.

Stop if deployment and retrieval produce different names. Correct the committed source and repeat
both org-shape gates before creating a candidate. Do not use another immutable package version to
diagnose a source-layout mismatch.

### Run the guarded package workflow

Package creation is manual and happens once, at the end of release-branch preparation. Do not create
a package version for every commit and do not add creation to ordinary pull-request CI. Commit the
exact release source first; the command refuses a dirty worktree, `main`, a detached HEAD, or a
missing explicit release-ready acknowledgement. The command runs the complete local release
preflight before consuming package-version capacity. That preflight converts the package to
Metadata API format and proves that every Custom Metadata member named in `package.xml` has a
physical file, including exactly four Check Sets and 50 Checks.

The command permits only one candidate attempt in a Dev Hub package-create limit window by default.
If any package-create capacity has already been consumed, wait for the limit to reset. An additional
attempt requires both `--allow-additional-candidate` and a reviewed `--override-reason` of at least
20 characters. This exception is for an externally time-critical release with evidence of a fixed
cause; it is not a retry mechanism for package debugging.

```bash
npm run package:create -- --dev-hub <dev-hub> --release-ready
```

The guarded workflow is:

```bash
npm ci
npm run check:toolchain
npm run check:toolchain-latest
npm run release:preflight
npm run package:create -- --dev-hub <dev-hub> --release-ready
npm run package:verify -- --dev-hub <dev-hub> --package <candidate-04t>
```

Run the commands from a clean, committed release branch. `package:create` repeats the release
preflight, checks Dev Hub capacity, requests code coverage, and records redacted creation evidence.
The Salesforce package-version Branch field records the stable Git release branch; it does not
include a commit suffix. Exact commit provenance lives in the ignored creation evidence, while 2GP
upgrade ancestry remains linear through `"ancestorVersion": "HIGHEST"` in `sfdx-project.json`.
`package:verify` treats installation into a clean subscriber org as the authoritative validation of
the immutable server artifact. ZIP retrieval can be retained as optional diagnostic evidence, but
Salesforce reporting a generated ZIP as unretrievable does not block install verification.

Preserve the ignored
`packages/record-health-check/.package-evidence/<04t>-create.json` file written by
`package:create`. The promotion command requires that local file and verifies that it binds the
candidate to the configured package and the current `HEAD`. Promote from the same working copy at
the exact creation commit; promotion intentionally fails after advancing or merging the branch, or
from another machine without the creation evidence.

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

- Clean no-namespace install of the candidate
- Verification that all packaged Custom Metadata types and records are installed
- Subscriber verification metadata deployment and `RHCSubscriberSmokeTest`
- Stable-to-candidate upgrade rehearsal when `stable` is a promoted `04t`

## Promote and publish

```bash
npm run package:promote -- --dev-hub <dev-hub> --package <candidate-04t>
```

The promotion command prints all four release-owner URLs. Copy the exact Salesforce Production and
Sandbox URLs into the release evidence, then verify that both tracked public URLs redirect to those
same destinations:

```text
Production: https://login.salesforce.com/packaging/installPackage.apexp?p0=<candidate-04t>
Sandbox: https://test.salesforce.com/packaging/installPackage.apexp?p0=<candidate-04t>
Tracked Production: https://recordhealthcheck.com/install/production
Tracked Sandbox: https://recordhealthcheck.com/install/sandbox
```

Then update `config/package-releases.json`:

1. Move the current stable entry to `previous`.
2. Set `stable.subscriberPackageVersionId` to the promoted `04t`.
3. Refresh `installUrl` values.
4. Update `CHANGELOG.md` and create the GitHub release.

Also commit the exact source used to create the package, create the matching semantic-version tag,
and configure both tracked public install redirects to the new stable `04t`.

Current promoted subscriber package version ID: see `config/package-releases.json`.

## Packaged Example Check Sets and Checks

The 54 `Example_` Check Sets and Checks ship **inside** the package, from
`packages/record-health-check/force-app/main/default/customMetadata`. A subscriber gets four Example
Check Sets and 50 Checks on install, with no extra step. `check:package-boundary` enforces that they
stay there and stay byte-identical to their `integration-tests` copies.

Do not move them to an unpackaged directory and do not add `unpackagedMetadata` to
`sfdx-project.json`; that flag deploys metadata to the build org for testing and then deliberately
excludes it from the package, which is how `2.0.0.6` came to install with zero Example records.

Demo _data_ is different. The Acme Accounts and related records the demo org uses are subscriber
owned, come from `scripts/subscriber/data`, and must never be packaged.

When Salesforce makes an optional package ZIP available, diagnostic artifact evidence can be
retained locally under `packages/record-health-check/.package-artifacts/<04t>/`. This evidence is
supplemental; clean installation and subscriber smoke tests remain the release gates.

## Rollback

Salesforce package versions are immutable. Roll forward with a corrected package version when a
schema or installed metadata change cannot be safely reversed. For an application-only regression,
install the previously supported version only when Salesforce package ancestry and upgrade checks
permit it. Document data or configuration remediation separately.
