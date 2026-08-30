# Choose a package version

> [!NOTE]
> On this page, choose an immutable Record Health Check package version, install it in the intended
> Salesforce environment, and understand the safe recovery path if a release must be reversed.

Use this page only when a release owner must pin an exact version, verify the installed version, or
plan recovery. For a normal first installation, follow [Install and verify](./install-in-a-sandbox.md).

Each Salesforce package version has a unique `04t` ID. The sandbox and production buttons for a row
install the same immutable package; only the Salesforce login destination differs.

In Salesforce packaging terms, this is a **second-generation unlocked package (2GP)**. Released
versions have fixed contents: Salesforce does not edit a released version in place.

## Before you start

Confirm whether the destination is a sandbox, production org, Developer Edition, or clean org. If
Record Health Check is already installed, preserve organization-owned Check Sets and Checks before
changing versions and follow the full [upgrade and revalidation procedure](./upgrade.md).

To see the current version, open **Setup → Installed Packages**, select **Record Health Check**, and
read **Version Number**.

## Step 1: Choose a version

Versions are listed newest first. The catalog retains Record Health Check 2.0.4.2 as the previous
production release; earlier development and release-candidate versions are intentionally not
listed.

| Version | Release name | Package version ID | Sandbox | Production or Developer Edition |
| --- | --- | --- | --- | --- |
| **2.0.5.1** | Version 2.0.5 | `04tak000000eIO1AAM` | [Install 2.0.5.1 in Sandbox](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tak000000eIO1AAM) | [Install 2.0.5.1 in Production](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tak000000eIO1AAM) |
| **2.0.4.2** | Version 2.0.4 | `04tak000000cZBFAA2` | [Install 2.0.4.2 in Sandbox](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tak000000cZBFAA2) | [Install 2.0.4.2 in Production](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tak000000cZBFAA2) |
| **2.0.3.1** | Version 2.0.3 | `04tak000000ajbJAAQ` | [Install 2.0.3.1 in Sandbox](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tak000000ajbJAAQ) | [Install 2.0.3.1 in Production](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tak000000ajbJAAQ) |

Choose **Install for Admins Only** on the Salesforce installation page, then assign **Record Health
Check User** or **Record Health Check Admin** as described in [Install and verify in your
org](./install-in-a-sandbox.md).

The installation page shows the package name, publisher, target version, component access choices,
and whether the org already has a related version. Confirm the target org and version before
selecting **Install**.

## Step 2: Install an exact version with Salesforce CLI

Use the `04t` value from the table when an automated process must install a specific version:

```bash
sf package install \
  --package 04tak000000eIO1AAM \
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
| A new or clean org needs a listed release | Install that version's exact `04t` from the table. |
| An upgrade has not reached production | Stop the rollout and keep production on its current installed version. |
| An installed upgrade must be reversed | Preserve subscriber-owned Check Sets and Checks, then prefer a higher corrective package version. Validate the forward fix in a sandbox before production. |
| The package must be removed | Follow [Uninstall and rollback](./uninstall.md), including configuration backup and dependency removal. Reinstall the desired listed version only after confirming that a clean reinstall is acceptable. |

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
