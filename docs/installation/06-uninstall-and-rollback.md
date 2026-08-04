# Uninstall and rollback

> [!NOTE]
> On this page, remove Record Health Check from an org safely: back up configuration first, remove
> Lightning placements and automation subscribers, then uninstall the package or remove
> source-deployed metadata.

Use this page when an org no longer needs Record Health Check, or when a revalidation in
[Revalidate an installation](04-upgrading.md) fails and the release owner decides to roll back to
"not installed" rather than to a prior version.

## Before you start

Removing Record Health Check removes the Lightning card, the Apex API, the Flow actions, and the
Custom Metadata Types it defines. Anything built on top of those surfaces stops working the moment
its dependency is gone. Confirm the blast radius before you begin:

1. Identify every Lightning record page that places the **Record Health Check** component.
2. Identify every Apex class that calls `RecordHealthCheck.evaluate(...)` or references
   `RecordHealthCheckRule`, `RecordHealthCheckScope`, or `RecordHealthCheckOutcome`.
3. Identify every Flow that uses **Run Record Health Check Rule** or **Run Record Health Check
   Set**.
4. Identify every Flow or Apex trigger subscribed to `Record_Health_Check_Set_Run__e`,
   `Record_Health_Check_Rule_Result__e`, or `Record_Health_Check_Log__e`.
5. Identify every user assigned `Record_Health_Check_User` or `Record_Health_Check_Admin`.

## Back up Custom Metadata first

Check Set and Rule configuration lives entirely in Custom Metadata. Export it before removing
anything, the same way [Revalidate an installation](04-upgrading.md#before-you-start) does for an
upgrade:

1. Export every `Record_Health_Check_Set__mdt` record.
2. Export every `Record_Health_Check_Rule__mdt` record.
3. Record which Lightning record pages had the component placed, and which Check Set each one
   selected.

Store the export somewhere the org can restore from later. If the removal is temporary or
experimental, this backup is what makes a future reinstall a restoration rather than a rebuild.

## Step 1: Remove Lightning placements

For every record page identified above:

1. Go to **Setup → Lightning App Builder**.
2. Edit the page.
3. Remove the **Record Health Check** component from the page.
4. Save and reactivate the page.

Removing the placement first means users stop seeing a card that will shortly call an Apex class
that may no longer exist, instead of encountering an error mid-removal.

## Step 2: Remove Flow and Apex event subscribers

Disable or remove automation that depends on Record Health Check before removing the Framework
itself, so nothing is left calling into a surface that is about to disappear:

1. Deactivate or delete Flows that call **Run Record Health Check Rule** or **Run Record Health
   Check Set**.
2. Deactivate or delete platform-event-triggered Flows subscribed to
   `Record_Health_Check_Set_Run__e`, `Record_Health_Check_Rule_Result__e`, or
   `Record_Health_Check_Log__e`.
3. Remove or stop scheduling any Apex class that calls the public
   `RecordHealthCheck.evaluate(...)` API, implements `RecordHealthCheckRule`, or subscribes to the
   platform events above.
4. Remove any scheduled job created from `RecordHealthCheckScheduled`.

## Step 3: Remove Permission Set assignments

Remove `Record_Health_Check_User` and `Record_Health_Check_Admin` assignments before uninstalling
the package or removing source metadata:

```bash
sf org list users --target-org <org-alias>
```

Then remove each affected user's assignment through **Setup → Permission Sets → (Permission Set) →
Manage Assignments**, or with the CLI:

```bash
sf org remove permsetassign --name Record_Health_Check_User --target-org <org-alias> --on-behalf-of <username>
sf org remove permsetassign --name Record_Health_Check_Admin --target-org <org-alias> --on-behalf-of <username>
```

This step is not strictly required before uninstalling (an uninstalled package removes its
Permission Sets along with everything else), but doing it explicitly gives you a clean audit trail
of who lost access and when.

## Step 4a: Uninstall the unlocked package

If Record Health Check was installed as the namespaced unlocked package (`rhc`), uninstall it from
**Setup → Installed Packages**, or with the CLI:

```bash
sf package uninstall --package "Record Health Check" --target-org <org-alias> --wait 30
```

Salesforce blocks an uninstall if other metadata in the org still depends on package components
(for example, a Flow that references a packaged Custom Metadata Type field, or a non-packaged Apex
class extending a packaged interface without an override). Resolve every dependency identified in
[Before you start](#before-you-start) first, then retry.

## Step 4b: Remove source-deployed metadata

If Record Health Check was source-deployed (a contributor or scratch-org install), remove the same
manifest that installed it, carefully:

```bash
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
Record Health Check's own components, the same discipline
[Install and verify](02-install-and-verify.md#what-the-install-includes) uses for installation.

## Step 5: Verify removal

| Check | Expected result |
| --- | --- |
| Open a record page that previously had the card | No Record Health Check component appears, and Lightning App Builder no longer offers it |
| Search Setup for `Record Health Check` object and Apex references | No `Record_Health_Check_Set__mdt`, `Record_Health_Check_Rule__mdt`, or `RecordHealthCheck*` Apex classes remain (unless intentionally retained) |
| Review Permission Sets | `Record_Health_Check_User` and `Record_Health_Check_Admin` no longer exist or have no assignees |
| Review scheduled jobs | No job references `RecordHealthCheckScheduled` |
| Review Flow and Apex subscribers | No automation still references the removed platform events or Apex classes |

## Roll back a removal

If Record Health Check needs to come back, treat it as a new installation using the retained
backup:

1. Reinstall the package (or redeploy the source) following
   [Install and verify](02-install-and-verify.md).
2. Restore the exported `Record_Health_Check_Set__mdt` and `Record_Health_Check_Rule__mdt` records.
3. Reassign `Record_Health_Check_User` and `Record_Health_Check_Admin` to the users identified in
   [Before you start](#before-you-start).
4. Re-add the Lightning component to the record pages that had it.
5. Re-enable any Flow, Apex, or event subscriber automation that was disabled during removal.
6. Re-verify with the same passing and failing scenarios described in
   [Install and verify: Verify the result](02-install-and-verify.md#5-verify-the-result).

## Next steps

- [Revalidate an installation](04-upgrading.md)
- [Install and verify](02-install-and-verify.md)
- [Operate in production](../guides/operate-in-production.md)
- [Configuration identity](../reference/framework/configuration-identity.md)
- [Security and data access](../reference/framework/security.md)
