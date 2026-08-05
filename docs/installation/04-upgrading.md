# Revalidate or upgrade an installation

> [!NOTE]
> Use this page when Record Health Check is already installed and you need to upgrade the unlocked
> package or redeploy Framework source safely. You will preserve the org's configuration, verify
> the result in a representative environment, and retain a tested rollback path.

Do not treat an existing installation like a new sandbox. Its Custom Metadata, Lightning page
activation, permission assignments, Apex callers, Flow integrations, and Platform Event
subscribers may support active business processes.

## Before you start

Capture these items before changing metadata:

1. Export every `Record_Health_Check_Set__mdt` and `Record_Health_Check_Rule__mdt` record.
2. Retain the source or package artifact currently installed in the org (including the installed
   package version ID when the org uses the unlocked package).
3. Record the active Lightning record pages and their selected Check Sets.
4. Export assignments for `Record_Health_Check_User` and `Record_Health_Check_Admin`.
5. List Apex, Flow, and Platform Event integrations that call or subscribe to Record Health Check.
6. Record one passing and one failing business scenario for each active Check Set.

Store the backup where the release owner can restore it. A backup that has never been restored in
a test org is not sufficient rollback evidence.

## Choose an upgrade path

| Path | Use when |
| --- | --- |
| [Option A: Upgrade the unlocked package](#option-a-upgrade-the-unlocked-package) | The org installed **Record Health Check** (`rhc`) from a package version |
| [Option B: Source-deploy revalidation](#option-b-source-deploy-revalidation) | The org was installed from this repository, or you are validating a contributor change |

Both paths share the same [verification checklist](#verification) and
[rollback](#roll-back-when-verification-fails) steps.

## Public surfaces to re-check after upgrade

When the org already calls or configures Record Health Check, confirm these current contracts after
the upgrade:

| Surface | Confirm |
| --- | --- |
| Synchronous Apex | Callers use `RecordHealthCheck.evaluate(RecordHealthCheckRequest)` with qualified Check Set or Rule API names |
| Apex plugins | Plugins implement bulk `RecordHealthCheckRule.evaluate(RecordHealthCheckScope)` and return one outcome per requested record ID |
| Merge tokens | Templates use namespaced tokens and attribute fallbacks such as `{!record.Name fallback="this record"}` |
| Diagnostics access | Troubleshooters hold `Record_Health_Check_View_Diagnostics` (via `Record_Health_Check_Admin`) and the Check Set enables **Show Diagnostics** only while investigating |
| Run access | Executable surfaces require `Record_Health_Check_Run` (included in the User and Admin Permission Sets) |
| Card outcomes | Lightning verification expects Pass, Fail (Failed / Warning / Info), Skipped, Unable to Check, and System Error |

Do not teach or restore retired entry points. If an existing caller still uses an older shape, update
the caller to the contracts above before treating the org as verified.

## Option A: Upgrade the unlocked package

Use a sandbox that mirrors production before upgrading production.

1. Confirm the currently installed package version (Setup → Installed Packages, or
   `sf package installed list --target-org <validation-org>`).
2. Install the newer promoted **Record Health Check** package version into the validation org
   (AppExchange / package install URL from the release notes, or
   `sf package install --package <04t…> --target-org <validation-org> --wait 30`).
3. Keep subscriber-owned Check Sets and Rules. Package upgrades should not replace org-authored
   Custom Metadata; investigate any unexpected change against your pre-upgrade export.
4. Run the [verification checklist](#verification).
5. Repeat the package install against production only after the release owner approves the
   validation evidence, backup, and rollback rehearsal.

## Option B: Source-deploy revalidation

You need an authenticated Salesforce CLI target, permission to deploy Apex and metadata, and a
sandbox or scratch org that represents the destination org.

### B1. Validate the repository locally

```bash
npm ci
npm run prettier:verify
npm run lint
npm run check:docs
npm run check:product-version-language
npm run check:test-data-factory
npm test
```

Every command must exit successfully before an org deployment.

### B2. Dry-run, then deploy

```bash
sf project deploy start \
  --dry-run \
  --manifest manifest/package.xml \
  --test-level RunLocalTests \
  --target-org <validation-org> \
  --wait 30

sf project deploy start \
  --manifest manifest/package.xml \
  --test-level RunLocalTests \
  --target-org <validation-org> \
  --wait 30
```

Do not deploy `integration-tests/` to a subscriber org.

### B3. Run the metadata validator

```bash
sf apex run \
  --file scripts/apex/validateMetadata.apex \
  --target-org <validation-org>
```

Then continue with the [verification checklist](#verification).

### B4. Prepare production

Repeat the dry run against production with the same manifest and test level. Schedule the change
only after the release owner approves the validation-org evidence, production dry run, backup, and
rollback rehearsal. Record the deployment job ID during the change.

## Verification

| Verification | Expected result |
| --- | --- |
| Open each active Lightning record page | The intended Check Set appears on the Record Health Check card |
| Run the retained passing record | The expected Rules pass without exposing diagnostic detail |
| Run the retained failing record | The expected guidance, severity, Found/Expected values, and action appear |
| Run as a standard user | The card respects record, object, and field access |
| Run as an authorized troubleshooter | Diagnostic detail appears only when **Show Diagnostics** is enabled |
| Exercise each Apex or Flow caller | The caller handles every returned status and preserves its correlation ID |
| Exercise each event subscriber | Publication intent, duplicate handling, replay behavior, and data retention match the approved design |

Compare deployed Custom Metadata with the export captured before the upgrade. Investigate an
unexpected deletion, blank value, changed relationship, or inactive record before continuing.

## Roll back when verification fails

1. Disable lifecycle publication when subscribers could act on unverified results.
2. Restore the retained package version or source artifact.
3. Restore the exported Custom Metadata records.
4. Restore Lightning page activation and permission assignments.
5. Run the retained Apex tests and business scenarios.
6. Preserve deployment, validation, and subscriber logs for root-cause analysis.

Do not resume the release until the restored org produces the retained passing and failing results.

## If verification fails

| Failure | What to inspect |
| --- | --- |
| Package install or deployment validation fails | The first component or Apex test failure, missing dependencies, and target-org feature settings |
| A Check Set is missing | Custom Metadata deployment, **Active**, **Object**, and Lightning component selection |
| A Rule changes status | Referenced data, running-user access, applicability, prerequisite order, and Evaluation Type configuration |
| An integration fails | Qualified metadata names, request limits, status handling, publication mode, and subscriber permissions |
| Rollback does not restore behavior | The retained artifact, Custom Metadata export, page activation, permission assignments, and external subscriber state |

## Next steps

- [Install and verify](02-install-and-verify.md)
- [Uninstall and rollback](06-uninstall-and-rollback.md)
- [Operate in production](../guides/08-operate-in-production.md)
- [Configuration review checklist](../guides/03-configure-check-sets-and-rules.md#14-review-checklist)
- [Integration overview](../integration/README.md)
- [Reason Codes](../reference/contracts/01-reason-codes.md)
