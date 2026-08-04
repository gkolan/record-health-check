# Revalidate an installation

> [!NOTE]
> Use this page when Record Health Check is already installed and you need to deploy the current
> repository safely. You will preserve the org's configuration, validate the deployment in a
> representative environment, and retain a tested rollback path.

Do not treat an existing installation like a new sandbox. Its Custom Metadata, Lightning page
activation, permission assignments, Apex callers, Flow integrations, and Platform Event
subscribers may support active business processes.

## Before you start

You need an authenticated Salesforce CLI target, permission to deploy Apex and metadata, and a
sandbox or scratch org that represents the destination org. Identify a release owner who can stop
the deployment if verification differs from the expected result.

Capture these items before changing metadata:

1. Export every `Record_Health_Check_Set__mdt` and `Record_Health_Check_Rule__mdt` record.
2. Retain the source or package artifact currently installed in the org.
3. Record the active Lightning record pages and their selected Check Sets.
4. Export assignments for `Record_Health_Check_User` and `Record_Health_Check_Admin`.
5. List Apex, Flow, and Platform Event integrations that call or subscribe to Record Health Check.
6. Record one passing and one failing business scenario for each active Check Set.

Store the backup where the release owner can restore it. A backup that has never been restored in
a test org is not sufficient rollback evidence.

## Public surfaces to re-check after deployment

This page is a revalidation procedure, not a migration guide between product generations. When the org
already calls or configures Record Health Check, confirm these current contracts after deployment:

| Surface | Confirm |
| --- | --- |
| Synchronous Apex | Callers use `RecordHealthCheck.evaluate(RecordHealthCheckRequest)` with qualified Check Set or Rule API names |
| Apex plugins | Plugins implement bulk `RecordHealthCheckRule.evaluate(RecordHealthCheckScope)` and return one outcome per requested record ID |
| Merge tokens | Templates use namespaced tokens and attribute fallbacks such as `{!record.Name fallback="this record"}` |
| Diagnostics access | Troubleshooters hold `Record_Health_Check_View_Diagnostics` (via `Record_Health_Check_Admin`) and the Check Set enables **Show Diagnostics** only while investigating |
| Run entitlement | Executable surfaces require `Record_Health_Check_Run` (included in the User and Admin Permission Sets) |
| Card outcomes | Lightning verification expects Pass, Fail (Failed / Warning / Info), Skipped, Unable to Check, and System Error |

Do not teach or restore retired entry points. If an existing caller still uses an older shape, update
the caller to the contracts above before treating the org as verified.

## Step 1: Validate the repository locally

From the repository root, install the locked dependencies and run the release gates:

```bash
npm ci
npm run prettier:verify
npm run lint
npm run check:docs
npm run check:product-version-language
npm run check:test-data-factory
npm test
```

Every command must exit successfully. Resolve a failing gate in source before starting an org
deployment.

## Step 2: Run a deployment validation

Validate the same manifest you intend to deploy:

```bash
sf project deploy start \
  --dry-run \
  --manifest manifest/package.xml \
  --test-level RunLocalTests \
  --target-org <validation-org> \
  --wait 30
```

Replace `<validation-org>` with the alias of the representative sandbox or scratch org. Success
means Salesforce compiled the metadata and completed the required Apex tests without changing the
org.

## Step 3: Deploy to the validation org

After the dry run succeeds, deploy the same manifest:

```bash
sf project deploy start \
  --manifest manifest/package.xml \
  --test-level RunLocalTests \
  --target-org <validation-org> \
  --wait 30
```

Do not deploy `integration-tests/` to a subscriber org. That directory contains CI and benchmark
fixtures rather than installable product metadata.

## Step 4: Verify configuration and access

Run the metadata validator:

```bash
sf apex run \
  --file scripts/apex/validateMetadata.apex \
  --target-org <validation-org>
```

Then verify the installation as the people who use it:

| Verification | Expected result |
| --- | --- |
| Open each active Lightning record page | The intended Check Set appears on the Record Health Check card |
| Run the retained passing record | The expected Rules pass without exposing diagnostic detail |
| Run the retained failing record | The expected guidance, severity, Found/Expected values, and action appear |
| Run as a standard user | The card respects record, object, and field access |
| Run as an authorized troubleshooter | Diagnostic detail appears only when **Show Diagnostics** is enabled |
| Exercise each Apex or Flow caller | The caller handles every returned status and preserves its correlation ID |
| Exercise each event subscriber | Publication intent, duplicate handling, replay behavior, and data retention match the approved design |

Compare the deployed Custom Metadata with the export captured before deployment. Investigate an
unexpected deletion, blank value, changed relationship, or inactive record before continuing.

## Step 5: Prepare production deployment

Repeat the dry run against production with the same manifest and test level. Schedule the change
only after the release owner approves the validation-org evidence, production dry run, backup, and
rollback rehearsal.

During the change, record the deployment job ID and the person who performed each verification.

## Roll back when verification fails

Rollback restores a known installation; it does not ask production users to tolerate a mixed
state.

1. Disable lifecycle publication when subscribers could act on unverified results.
2. Restore the retained source or package artifact.
3. Restore the exported Custom Metadata records.
4. Restore Lightning page activation and permission assignments.
5. Run the retained Apex tests and business scenarios.
6. Preserve deployment, validation, and subscriber logs for root-cause analysis.

Do not resume the release until the restored org produces the retained passing and failing results.

## If verification fails

| Failure | What to inspect |
| --- | --- |
| Deployment validation fails | The first component or Apex test failure, missing dependencies, and target-org feature settings |
| A Check Set is missing | Custom Metadata deployment, **Active**, **Object**, and Lightning component selection |
| A Rule changes status | Referenced data, running-user access, applicability, prerequisite order, and Evaluation Type configuration |
| An integration fails | Qualified metadata names, request limits, status handling, publication mode, and subscriber permissions |
| Rollback does not restore behavior | The retained artifact, Custom Metadata export, page activation, permission assignments, and external subscriber state |

## Next steps

- [Install and verify](02-install-and-verify.md)
- [Configuration review checklist](../guides/configure-check-sets-and-rules.md#14-review-checklist)
- [Integration overview](../integration/README.md)
- [Reason Codes](../reference/reference-reason-codes.md)
