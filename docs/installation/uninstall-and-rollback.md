# Uninstall and rollback

> [!NOTE]
> On this page, preserve organization-owned configuration, remove Record Health Check dependencies
> in a safe order, uninstall the package, and verify that the org is clean.

Use this guide when an org no longer needs Record Health Check. You will preserve anything needed
for a future reinstall, remove the places where people and automation depend on Record Health
Check, and then uninstall it without leaving broken pages or processes behind.

## Before you start

Uninstalling removes the card, Check Set and Check configuration types, permission sets, and
automation entry points. Before making that change, identify where Record Health Check is used:

1. In **Setup → Lightning App Builder**, open each record page for the supported objects and list
   every page that contains the **Record Health Check** card. Include its activation assignment.
2. Ask the owners of Salesforce automation whether a Flow, Apex class, scheduled job, or integration
   uses Record Health Check or receives its Platform Events.
3. List the people assigned **Record Health Check User** or **Record Health Check Admin**.
4. Agree on when users and automation should stop relying on Record Health Check.

## Preserve the configuration first

Check Sets and Checks contain the questions, messages, and guidance your organization authored.
Back them up before removing anything by following
[Back up and restore configuration](../guides/back-up-configuration.md):

1. Export every **Record Health Check Set** (`Record_Health_Check_Set__mdt`) record.
2. Export every **Record Health Check** (`Record_Health_Check__mdt`) record.
3. Record which Lightning record pages had the component placed, and which Check Set each one
   selected.

Open the retrieved files and confirm that they contain every administrator-created Check Set and
Check you expect. Store that verified backup with the record-page list and access assignments. If
the removal is temporary, these items turn a future reinstall into a restoration instead of
rebuilding the configuration from memory.

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

1. Deactivate Flows that call **Run Record Health Check** or **Run Record Health Check Set**. Keep
   them for rollback unless your normal change process separately approves deletion.
2. Deactivate Platform Event-triggered Flows that receive
   `Record_Health_Check_Set_Run__e`, `Record_Health_Check_Result__e`, or
   `Record_Health_Check_Log__e`.
3. Stop scheduled work and update your own Apex that calls `rhc.RecordHealthCheck.evaluate(...)`,
   implements `rhc.RecordHealthCheckPlugin`, or receives the Platform Events above. Apex references
   to removed package classes or interfaces can block uninstall or fail a later deployment.
4. Remove scheduled jobs created from `rhc.RecordHealthCheckScheduled`.

In Setup, the corresponding Platform Event labels are **Record Health Check Set Run**, **Record
Health Check Result**, and **Record Health Check Log**. The API names above are for Flow, Apex, and
integration searches.

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
sf org remove permsetassign --name rhc__Record_Health_Check_User --target-org <org-alias> --on-behalf-of <username>
sf org remove permsetassign --name rhc__Record_Health_Check_Admin --target-org <org-alias> --on-behalf-of <username>
```

The `rhc__` prefix belongs to the permission-set API names from the installed package. Replace the
org alias and username placeholders; do not remove the namespace prefix.

## Step 4: Uninstall the package

Open **Setup → Installed Packages**, find **Record Health Check**, and select **Uninstall**. Review
Salesforce's list of components and dependencies before confirming. Uninstalling removes package
components and cannot be undone without installing the package again.

If Salesforce shows **Cannot Uninstall**, use the dependency list to return to Steps 1 and 2; do
not delete unrelated metadata to force removal. After confirmation, Salesforce can finish in the
background and send an email with the result.

Teams that manage packages with the Salesforce CLI should first find the exact installed package
version ID:

```bash
sf package installed list --target-org <org-alias>
sf package uninstall --package <installed-04t-package-version-id> --target-org <org-alias> --wait 30
```

Replace `<installed-04t-package-version-id>` with the Record Health Check ID returned by the first
command. Confirm the target org and `04t` value before running the uninstall command.

Salesforce blocks an uninstall if other metadata in the org still depends on package components
(for example, a Flow that references a packaged Custom Metadata field or an Apex class that
implements the packaged interface). Resolve every dependency identified in
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
| Search Custom Metadata Types and **Setup → Apex Classes** | No **Record Health Check Set** (`Record_Health_Check_Set__mdt`), **Record Health Check** (`Record_Health_Check__mdt`), or `RecordHealthCheck*` Apex classes remain (unless intentionally retained) |
| Review Permission Sets | **Record Health Check User** (`rhc__Record_Health_Check_User`) and **Record Health Check Admin** (`rhc__Record_Health_Check_Admin`) no longer exist or have no assignees |
| Review scheduled jobs | No job references `RecordHealthCheckScheduled` |
| Review Flow, Apex, and integrations | No automation still references the removed Platform Events or Apex classes |

## Roll back a removal

If Record Health Check needs to come back, treat it as a new installation using the retained
backup:

1. Reinstall the package (or redeploy the source) following
   [Install and verify in your org](install-and-verify.md).
2. Restore the exported **Record Health Check Set** (`Record_Health_Check_Set__mdt`) and **Record Health Check** (`Record_Health_Check__mdt`) records.
3. Reassign **Record Health Check User** (`rhc__Record_Health_Check_User`) and **Record Health Check Admin** (`rhc__Record_Health_Check_Admin`) to the users identified in
   [Before you start](#before-you-start).
4. Re-add the Lightning component to the record pages that had it.
5. Re-enable any Flow, Apex, or Platform Event integration that was disabled during removal.
6. Re-verify with the same passing and failing scenarios described in
   [Install and verify in your org: Verify the experience as a user](install-and-verify.md#step-4-verify-the-experience-as-a-user).

## Next steps

- [Upgrade and revalidate](upgrading.md)
- [Install and verify in your org](install-and-verify.md)
- [Operate in production](../guides/operate-in-production.md)
- [Configuration identity](../reference/framework/configuration-identity.md)
- [Security and data access](../reference/framework/security.md)
- [Back up and restore configuration](../guides/back-up-configuration.md)
