# Choose a package version

Use this page to select an exact package version, verify the installed version, or
plan recovery. For a normal first installation, follow [Install and verify](./install-in-a-sandbox.md).

Each Salesforce package version has a unique `04t` ID. The sandbox and production links
install the same released package; only the Salesforce login destination differs.

In Salesforce packaging terms, this is a **second-generation unlocked package (2GP)**. Released
versions have fixed contents: Salesforce does not edit a released version in place.

## Before you start

Confirm whether the destination is a sandbox, production org, Developer Edition, or clean org. If
Record Health Check is already installed, preserve organization-owned Check Sets and Checks before
changing versions and follow the full [upgrade and revalidation procedure](./upgrade.md).

To see the current version, open **Setup → Installed Packages**, select **Record Health Check**, and
read **Version Number**.

## Documentation and installed version

Verify the exact target before installation. Repository source can include changes that are
not yet released. When following an example, use documentation, Check definitions, data scripts,
and expected results from the same source or release.

The [release configuration](../../config/package-releases.json) identifies the latest stable
package and its installation links. The [changelog](../../CHANGELOG.md) records release history.
Deploying source to a scratch org does not update the published package.

## Step 1: Choose a version

The public redirects can temporarily target an older version than the latest promoted artifact.
Check the current distribution notice in the [release notes](../../CHANGELOG.md), confirm the
installation screen, and validate in a sandbox before upgrading. Do not interpret an older redirect
as an in-place downgrade path for an existing installation.

Public install destinations:

| Target environment | Install |
| --- | --- |
| Sandbox | [Open the public sandbox installer](https://recordhealthcheck.com/install/sandbox) |
| Production or Developer Edition | [Open the public production installer](https://recordhealthcheck.com/install/production) |

For a repeatable installation or upgrade, record the exact package ID from the release
configuration before starting. Use that same ID in each environment you validate.

Choose **Install for Admins Only** on the Salesforce installation page, then assign **Record Health
Check Card User**, **Record Health Check User**, or **Record Health Check Admin** as described in [Install and verify in your
org](./install-in-a-sandbox.md). For troubleshooting as a Card User or User, add
**Record Health Check Diagnostics Viewer** and enable **Show Diagnostics** on the Check Set;
Admin already includes diagnostic access. See [Permission Sets](../reference/permission-sets.md)
if Diagnostics Viewer is absent from Setup.

The installation page shows the package name, publisher, target version, component access choices,
and whether the org already has a related version. Confirm the target org and version before
selecting **Install**.

## Step 2: Install an exact version with Salesforce CLI

Copy `stable.subscriberPackageVersionId` from the [release configuration](../../config/package-releases.json)
and replace `PACKAGE_VERSION_ID` below. The value begins with `04t`.

```bash
sf package install \
  --package PACKAGE_VERSION_ID \
  --target-org <org-alias> \
  --security-type AdminsOnly \
  --upgrade-type Mixed \
  --wait 30 \
  --publish-wait 10 \
  --no-prompt
```

Confirm the target org before running the command. After installation, follow the permission,
Lightning page, and user-verification steps in [Install and verify](./install-in-a-sandbox.md).

## Step 3: Roll back safely

A released 2GP package version is immutable, but that does not make in-place downgrade a dependable
rollback mechanism. Salesforce package upgrades follow version and dependency rules. Test
the intended transition in a representative sandbox; do not assume an org can install a lower
version over a higher one.

Use the recovery path that matches the situation:

| Situation | Safe path |
| --- | --- |
| A new or clean org needs a specific release | Install its recorded `04t` package version ID. |
| An upgrade has not reached production | Stop the rollout and keep production on its current installed version. |
| An installed upgrade must be reversed | Preserve subscriber-owned Check Sets and Checks, then prefer a higher corrective package version. Validate the forward fix in a sandbox before production. |
| The package must be removed | Follow [Uninstall and rollback](./uninstall.md), including configuration backup and dependency removal. Reinstall the desired release only after confirming that a clean reinstall is acceptable. |

Package rollback and configuration rollback are separate concerns. Before any upgrade or uninstall,
back up organization-owned `Record_Health_Check_Set__mdt` and `Record_Health_Check__mdt` records and
record the Lightning page placements that use them. See [Upgrade and
revalidate](./upgrade.md) and [Back up and restore configuration](../production-operations/back-up-configuration.md)
for the complete safety and verification procedure.

## Next steps

- Continue with [Install and verify in your org](./install-in-a-sandbox.md) to assign permission sets,
  place the card, and test as a regular user.
- [Upgrade and revalidate](./upgrade.md)
- [Uninstall and rollback](./uninstall.md)
