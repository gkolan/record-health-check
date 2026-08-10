# Package versions, installation, and rollback

> [!NOTE]
> On this page, choose an immutable Record Health Check package version, install it in the intended
> Salesforce environment, and understand the safe recovery path if a release must be reversed.

Each Salesforce package version has a unique `04t` ID. The sandbox and production buttons for a row
install the same immutable package; only the Salesforce login destination differs.

## Available versions

Versions are listed newest first. This catalog begins with Record Health Check 2.0.2.1; earlier
2.0.1 development and release-candidate versions are intentionally not listed.

| Version | Release name | Package version ID | Sandbox | Production or Developer Edition |
| --- | --- | --- | --- | --- |
| **2.0.2.1** | August 2026 Release | `04tak000000aWZFAA2` | [Install 2.0.2.1 in Sandbox](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tak000000aWZFAA2) | [Install 2.0.2.1 in Production](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tak000000aWZFAA2) |

Choose **Install for Admins Only** on the Salesforce installation page, then assign **Record Health
Check User** or **Record Health Check Admin** as described in [Install and verify in your
org](install-and-verify.md).

## Install an exact version with Salesforce CLI

Use the `04t` value from the table when an automated process must install a specific version:

```bash
sf package install \
  --package 04tak000000aWZFAA2 \
  --target-org <org-alias> \
  --security-type AdminsOnly \
  --upgrade-type DeprecateOnly \
  --wait 30 \
  --publish-wait 10 \
  --no-prompt
```

Confirm the target org before running the command. After installation, follow the permission,
Lightning page, and user-verification steps in [Install and verify](install-and-verify.md).

## Roll back safely

A released 2GP package version is immutable, but that does not make in-place downgrade a dependable
rollback mechanism. Salesforce package upgrades follow version ancestry and dependency rules. Test
the intended transition in a representative sandbox; do not assume an org can install a lower
version over a higher one.

Use the recovery path that matches the situation:

| Situation | Safe path |
| --- | --- |
| A new or clean org needs a listed release | Install that version's exact `04t` from the table. |
| An upgrade has not reached production | Stop the rollout and keep production on its current installed version. |
| An installed upgrade must be reversed | Preserve subscriber-owned Check Sets and Checks, then prefer a higher corrective package version. Validate the forward fix in a sandbox before production. |
| The package must be removed | Follow [Uninstall and rollback](uninstall-and-rollback.md), including configuration backup and dependency removal. Reinstall the desired listed version only after confirming that a clean reinstall is acceptable. |

Package rollback and configuration rollback are separate concerns. Before any upgrade or uninstall,
export organization-owned `Record_Health_Check_Set__mdt` and `Record_Health_Check__mdt` records and
record the Lightning page placements that use them. See [Upgrade and
revalidate](upgrading.md) for the complete safety and verification procedure.

## Related guides

- [Install and verify in your org](install-and-verify.md)
- [Upgrade and revalidate](upgrading.md)
- [Uninstall and rollback](uninstall-and-rollback.md)

