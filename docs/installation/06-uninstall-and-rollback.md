# Uninstall and rollback

Use this guide when an org no longer needs Record Health Check. You will preserve anything needed
for a future reinstall, remove the places where people and automation depend on the Framework, and
then uninstall it without leaving broken pages or processes behind.

## Before you start

Uninstalling removes the card, Check Set and Rule configuration types, permission sets, and
automation entry points. Before making that change, identify where the Framework is used:

1. List every Lightning record page that contains the **Record Health Check** card.
2. Ask the owners of Salesforce automation whether a Flow, Apex class, scheduled job, or event
   subscriber uses Record Health Check.
3. List the people assigned **Record Health Check User** or **Record Health Check Admin**.
4. Agree on when users and automation should stop relying on the Framework.

## Preserve the configuration first

Check Sets and Rules contain the questions, messages, and guidance your organization authored.
Export them before removing anything:

1. Export every **Record Health Check Set** (`Record_Health_Check_Set__mdt`) record.
2. Export every **Record Health Check Rule** (`Record_Health_Check_Rule__mdt`) record.
3. Record which Lightning record pages had the component placed, and which Check Set each one
   selected.

Store the export with the record-page list and access assignments. If the removal is temporary,
these items turn a future reinstall into a restoration instead of a reconstruction exercise.

## Step 1: Remove Lightning placements

For every record page identified above:

1. Go to **Setup → Lightning App Builder**.
2. Edit the page.
3. Remove the **Record Health Check** component from the page.
4. Save and reactivate the page.

Removing the placement first means users stop seeing a card that will shortly call an Apex class
that may no longer exist, instead of encountering an error mid-removal.

## Step 2: Stop connected automation

If your organization does not connect Record Health Check to Flow, Apex, scheduled work, or Platform
Events, continue to Step 3. Otherwise, work with the automation owner to disable those dependencies
before uninstalling:

1. Deactivate or delete Flows that call **Run Record Health Check Rule** or **Run Record Health
   Check Set**.
2. Deactivate or delete platform-event-triggered Flows subscribed to
   `Record_Health_Check_Set_Run__e`, `Record_Health_Check_Rule_Result__e`, or
   `Record_Health_Check_Log__e`.
3. Remove or stop scheduling any Apex class that calls the public
   `RecordHealthCheck.evaluate(...)` API, implements `RecordHealthCheckRule`, or subscribes to the
   platform events above.
4. Remove any scheduled job created from `RecordHealthCheckScheduled`.

## Step 3: Remove user access

In **Setup → Permission Sets**, open **Record Health Check User** and **Record Health Check Admin**,
then use **Manage Assignments** to remove their users.

Removing assignments first provides a clear record of who lost access and when. Salesforce also
removes packaged permission sets during uninstall, so this step is preparation rather than a
technical requirement.

Teams that manage assignments with the Salesforce CLI can use:

```bash
sf org list users --target-org <org-alias>
```

```bash
sf org remove permsetassign --name Record_Health_Check_User --target-org <org-alias> --on-behalf-of <username>
sf org remove permsetassign --name Record_Health_Check_Admin --target-org <org-alias> --on-behalf-of <username>
```

## Step 4: Uninstall the package

Open **Setup → Installed Packages**, find **Record Health Check**, and select **Uninstall**. Teams
that manage packages with the Salesforce CLI can use:

```bash
sf package uninstall --package "Record Health Check" --target-org <org-alias> --wait 30
```

Salesforce blocks an uninstall if other metadata in the org still depends on package components
(for example, a Flow that references a packaged Custom Metadata Type field, or a non-packaged Apex
class extending a packaged interface without an override). Resolve every dependency identified in
[Before you start](#before-you-start) first, then retry.

## Contributor-only alternative: Remove development source

If Record Health Check was source-deployed during contributor development, remove the same manifest
that installed it. Run these commands from `packages/record-health-check/` or pass the full manifest
path from the repository root:

```bash
cd packages/record-health-check

sf project delete source \
  --manifest manifest/package.xml \
  --target-org <org-alias> \
  --check-only
```

Review the `--check-only` (dry-run) output before removing the check. Confirm the manifest does not
include anything the org still needs, then run the deletion:

```bash
sf project delete source \
  --manifest manifest/package.xml \
  --target-org <org-alias>
```

Do not run a bare deletion without a manifest. Deleting by manifest keeps the operation scoped to
Record Health Check's own components.

This alternative applies only to contributor development orgs. An org that used the public package
installer should follow [Step 4](#step-4-uninstall-the-package).

## Step 5: Confirm the org is clean

| Check | Expected result |
| --- | --- |
| Open a record page that previously had the card | No Record Health Check component appears, and Lightning App Builder no longer offers it |
| Search Setup for `Record Health Check` object and Apex references | No **Record Health Check Set** (`Record_Health_Check_Set__mdt`), **Record Health Check Rule** (`Record_Health_Check_Rule__mdt`), or `RecordHealthCheck*` Apex classes remain (unless intentionally retained) |
| Review Permission Sets | **Record Health Check User** (`Record_Health_Check_User`) and **Record Health Check Admin** (`Record_Health_Check_Admin`) no longer exist or have no assignees |
| Review scheduled jobs | No job references `RecordHealthCheckScheduled` |
| Review Flow and Apex subscribers | No automation still references the removed platform events or Apex classes |

## Roll back a removal

If Record Health Check needs to come back, treat it as a new installation using the retained
backup:

1. Reinstall the package (or redeploy the source) following
   [Install and verify in your org](02-install-and-verify.md).
2. Restore the exported **Record Health Check Set** (`Record_Health_Check_Set__mdt`) and **Record Health Check Rule** (`Record_Health_Check_Rule__mdt`) records.
3. Reassign **Record Health Check User** (`Record_Health_Check_User`) and **Record Health Check Admin** (`Record_Health_Check_Admin`) to the users identified in
   [Before you start](#before-you-start).
4. Re-add the Lightning component to the record pages that had it.
5. Re-enable any Flow, Apex, or event subscriber automation that was disabled during removal.
6. Re-verify with the same passing and failing scenarios described in
   [Install and verify in your org: Verify the experience as a user](02-install-and-verify.md#step-4-verify-the-experience-as-a-user).

## Next steps

- [Upgrade and revalidate](04-upgrading.md)
- [Install and verify in your org](02-install-and-verify.md)
- [Operate in production](../guides/08-operate-in-production.md)
- [Configuration identity](../reference/framework/06-configuration-identity.md)
- [Security and data access](../reference/framework/02-security.md)
