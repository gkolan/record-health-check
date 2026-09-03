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
3. Export or record assignments for every installed Record Health Check permission set: **Record Health Check Card
   User**, **Record Health Check User**, **Record Health Check Admin**, **Record Health Check MCP
   Integration**, **Record Health Check Diagnostics Viewer**, and **Record Health Check Error Log
   Publisher**. Diagnostics Viewer is present only if that addition has been deployed or is included in your installed version.
4. Agree on when users and automation should stop relying on Record Health Check.

## Preserve the configuration first

Check Sets and Checks contain the questions, messages, and guidance your organization authored.
Back them up before removing anything by following
[Back up and restore configuration](../production-operations/back-up-configuration.md):

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

In **Setup → Permission Sets**, open each packaged permission set listed in
[Before you start](#before-you-start), then use **Manage Assignments** to remove its users.

Removing assignments first provides a clear record of who lost access and when. Salesforce also
removes packaged permission sets during uninstall, so this step is preparation rather than a
technical requirement.

If assignments are managed through automation, use the team's approved user-access process to
remove the recorded permission-set assignments.

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

## Step 5: Confirm the org is clean

| Check | Expected result |
| --- | --- |
| Open a record page that previously had the card | No Record Health Check component appears, and Lightning App Builder no longer offers it |
| Search Custom Metadata Types and **Setup → Apex Classes** | No **Record Health Check Set** (`Record_Health_Check_Set__mdt`), **Record Health Check** (`Record_Health_Check__mdt`), or `RecordHealthCheck*` Apex classes remain (unless intentionally retained) |
| Review Permission Sets | The installed packaged permission sets listed in [Before you start](#before-you-start) no longer exist after uninstall |
| Review scheduled jobs | No job references `RecordHealthCheckScheduled` |
| Review Flow, Apex, and integrations | No automation still references the removed Platform Events or Apex classes |

## Roll back a removal

If Record Health Check needs to come back, treat it as a new installation using the retained
backup:

1. Reinstall the package following
   [Install and verify in your org](./install-in-a-sandbox.md).
2. Restore the exported **Record Health Check Set** (`Record_Health_Check_Set__mdt`) and **Record Health Check** (`Record_Health_Check__mdt`) records.
3. Restore the approved assignments recorded for each packaged permission set in
   [Before you start](#before-you-start).
4. Re-add the Lightning component to the record pages that had it.
5. Re-enable any Flow, Apex, or Platform Event integration that was disabled during removal.
6. Re-verify with the same passing and failing scenarios described in
   [Install and verify in your org: Verify the experience as a user](./install-in-a-sandbox.md#step-4-verify-the-experience-as-a-user).

## Next steps

- [Upgrade and revalidate](./upgrade.md)
- [Install and verify in your org](./install-in-a-sandbox.md)
- [Operate in production](../production-operations/operate-in-production.md)
- [Configuration identity](../reference/configuration/names-and-api-identities.md)
- [Security and data access](../architecture/security-and-data-access.md)
- [Back up and restore configuration](../production-operations/back-up-configuration.md)
