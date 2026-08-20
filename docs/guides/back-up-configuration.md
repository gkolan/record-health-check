# Back Up and Restore Record Health Check Configuration

> [!NOTE]
> Use this page before an upgrade, uninstall, or broad configuration change. Record Health Check
> Sets and Checks are Custom Metadata records, not business-data rows.

Salesforce Setup does not provide a standard button that downloads Custom Metadata records as a
restorable file. Choose one of the supported organization change paths below and prove the restore
in a sandbox before relying on it.

## Before you start

- Identify the source org and the sandbox or production org that would receive the backup.
- Record the current package version from **Setup → Installed Packages → Record Health Check**.
- Include both **Record Health Check Set** and **Record Health Check** records. A Check depends on
  its Check Set.
- Keep the backup in your organization's approved, access-controlled source repository or release
  system.

## Option 1: Use a change set between connected orgs

Use this path when the source and destination are connected through a Salesforce deployment
connection and your release process permits change sets.

1. In Setup, enter **Outbound Change Sets** in Quick Find and open it.
2. Create a change set with a clear date and purpose.
3. Select **Add** under Change Set Components.
4. Add the relevant Custom Metadata records for **Record Health Check Set** and **Record Health
   Check**. Include every referenced Set before its Checks.
5. Upload the change set to the connected destination.
6. In the destination org, open **Inbound Change Sets**, validate, and deploy it through your normal
   approval process.
7. Open both Custom Metadata Types and compare Developer Names, Active values, Check order, and
   referenced Check Sets with the source org.

A change set is a transport between connected orgs, not a downloadable archive. It cannot restore
configuration after the only copy has been deleted from every connected org.

## Option 2: Retrieve metadata into source control

Use Salesforce CLI when you need a versioned, reviewable backup or the orgs are not connected.
This is a developer or release-engineer task.

```bash
sf project retrieve start \
  --metadata "CustomMetadata:Record_Health_Check_Set.*" \
  --metadata "CustomMetadata:Record_Health_Check.*" \
  --target-org your-org-alias
```

In a managed-package subscriber org, confirm the namespace and retrieved member names before
committing anything. Keep organization-owned configuration separate from package-owned examples.

To restore, review the retrieved files, authorize the target org, and deploy only the approved
Custom Metadata records through the organization's release process. Validate in a sandbox first.

## Prove the backup

| Verification | Expected result |
| --- | --- |
| Check Set count and Developer Names | Matches the approved source configuration |
| Check count and Check Set references | Every Check points to an existing Check Set |
| Active values and order | Match the approved source configuration |
| Metadata validation | No missing dependency, object mismatch, or invalid field warning |
| Lightning test | A known passing and known failing record produce the expected rows |

## Important rollback limit

Salesforce does not support installing an older managed-package version over a newer version as a
general rollback method. Configuration backup and package rollback are separate. If an upgrade is
not acceptable, stop the rollout and follow the package-version and uninstall guidance approved by
your release owner.

## Related

- [Upgrade and revalidate](../installation/upgrading.md)
- [Uninstall and rollback](../installation/uninstall-and-rollback.md)
- [Operate in production](operate-in-production.md)
- [Package versions](../installation/package-versions.md)
