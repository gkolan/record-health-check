# Revalidate or upgrade an installation

> [!NOTE]
> Use this page when Record Health Check is already installed and you need to upgrade the unlocked
> package safely. You will preserve the org's configuration, verify the result in a representative
> environment, and retain a tested rollback path.

Do not treat an existing installation like a new sandbox. Its Custom Metadata, Lightning page
activation, permission assignments, Apex callers, Flow integrations, and Platform Event
subscribers may support active business processes.

## Before you start

Capture these items before changing metadata:

1. Export every **Record Health Check Set** (`Record_Health_Check_Set__mdt`) and **Record Health Check Rule** (`Record_Health_Check_Rule__mdt`) record.
2. Retain the installed package version ID from Setup → Installed Packages or
   `sf package installed list --target-org <validation-org>`.
3. Record the active Lightning record pages and their selected Check Sets.
4. Export assignments for **Record Health Check User** (`Record_Health_Check_User`) and **Record Health Check Admin** (`Record_Health_Check_Admin`).
5. List Apex, Flow, and Platform Event integrations that call or subscribe to Record Health Check.
6. Record one passing and one failing business scenario for each active Check Set.

Store the backup where the release owner can restore it. A backup that has never been restored in
a test org is not sufficient rollback evidence.

## Upgrade the unlocked package

Use a sandbox that mirrors production before upgrading production.

1. Confirm the currently installed package version (Setup → Installed Packages, or
   `sf package installed list --target-org <validation-org>`).
2. Install the newer promoted **Record Health Check** package version into the validation org.
   The current stable subscriber package version ID is recorded in
   [`config/package-releases.json`](../../config/package-releases.json).

   | Org type | Install |
   | --- | --- |
   | Production / Developer Edition | Use the `installUrl.production` value from `config/package-releases.json` |
   | Sandbox | Use the `installUrl.sandbox` value from `config/package-releases.json` |

   ```bash
   sf package install \
     --package <04t-from-package-releases.json> \
     --target-org <validation-org> \
     --upgrade-type DeprecateOnly \
     --wait 30 \
     --publish-wait 10
   ```

   Or run the maintained upgrade helper against a scratch org:

   ```bash
   npm run subscriber:upgrade -- --alias <org-alias>
   ```

   Use `DeprecateOnly` while the project is young; see
   [Package testing and upgrades](../reference/framework/07-package-testing-and-upgrades.md).

3. Keep subscriber-owned Check Sets and Rules. Package upgrades should not replace org-authored
   Custom Metadata; investigate any unexpected change against your pre-upgrade export.
4. Run the [verification checklist](#verification).
5. Repeat the package install against production only after the release owner approves the
   validation evidence, backup, and rollback rehearsal.

## Public surfaces to re-check after upgrade

When the org already calls or configures Record Health Check, confirm these current contracts after
the upgrade:

| Surface | Confirm |
| --- | --- |
| Synchronous Apex | Callers use `RecordHealthCheck.evaluate(RecordHealthCheckRequest)` with qualified Check Set or Rule API names |
| Apex plugins | Plugins implement bulk `RecordHealthCheckRule.evaluate(RecordHealthCheckScope)` and return one outcome per requested record ID |
| Merge tokens | Templates use namespaced tokens and attribute fallbacks such as `{!record.Name fallback="this record"}` |
| Diagnostics access | Troubleshooters hold **Record Health Check View Diagnostics** (`Record_Health_Check_View_Diagnostics`) (via **Record Health Check Admin** (`Record_Health_Check_Admin`)) and the Check Set enables **Show Diagnostics** only while investigating |
| Run access | Executable surfaces require **Record Health Check Run** (`Record_Health_Check_Run`) (included in the User and Admin Permission Sets) |
| Card outcomes | Lightning verification expects Pass, Fail (Failed / Warning / Info), Skipped, Unable to Check, and System Error |

Do not teach or restore retired entry points. If an existing caller still uses an older shape, update
the caller to the contracts above before treating the org as verified.

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
2. Restore the retained package version.
3. Restore the exported Custom Metadata records.
4. Restore Lightning page activation and permission assignments.
5. Run the retained business scenarios.
6. Preserve deployment, validation, and subscriber logs for root-cause analysis.

Do not resume the release until the restored org produces the retained passing and failing results.

## If verification fails

| Failure | What to inspect |
| --- | --- |
| Package install fails | The first component failure, missing dependencies, and target-org feature settings |
| A Check Set is missing | Custom Metadata deployment, **Active**, **Object**, and Lightning component selection |
| A Rule changes status | Referenced data, running-user access, applicability, prerequisite order, and Evaluation Type configuration |
| An integration fails | Qualified metadata names, request limits, status handling, publication mode, and subscriber permissions |
| Rollback does not restore behavior | The retained package version, Custom Metadata export, page activation, permission assignments, and external subscriber state |

## Contributor revalidation

If you are validating Framework source changes rather than upgrading a subscriber org, use the
contributor workflow in [Source development](../contributing/source-development.md). That path
deploys unpackaged package source into a development org and is not a supported subscriber
installation method.

## Next steps

- [Install and verify](02-install-and-verify.md)
- [Uninstall and rollback](06-uninstall-and-rollback.md)
- [Operate in production](../guides/08-operate-in-production.md)
- [Configuration review checklist](../guides/03-configure-check-sets-and-rules.md#14-review-checklist)
- [Integration overview](../integration/README.md)
- [Reason Codes](../reference/contracts/01-reason-codes.md)
