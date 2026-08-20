# Use the correct Check Set and Check API names

> [!NOTE]
> Apex, Flow, Lightning App Builder, and Platform Events identify a Check Set or Check by its exact
> **Qualified API Name**. Copy that value from Salesforce. Do not type or remove `rhc__` yourself.

Lightning App Builder stores this value when you select a Check Set from the component list. You
normally copy it yourself only for a Flow or Apex request, an integration, or troubleshooting.

## Which name should I use?

A Custom Metadata record has several names. Only one belongs in Record Health Check requests.

| Name shown in Salesforce | Example | Use in Apex or Flow? |
| --- | --- | --- |
| Label | Account checks | No. This is text shown to administrators |
| Developer Name | `My_Account_Checks` | Do not use it as a substitute for the Qualified API Name |
| Qualified API Name | `My_Account_Checks` or `rhc__Example_Account_Profile_Readiness` | Yes. Copy this exact value |

For a Check Set created by an administrator in your org, Developer Name and Qualified API Name
usually look the same. They are still different Salesforce fields. Always copy **Qualified API
Name** so the same instructions also work for metadata installed from a package.

## Why does an installed example begin with `rhc__`?

`rhc` is the Record Health Check package namespace. Salesforce adds `rhc__` to the Qualified API
Name of a Custom Metadata record included with that installed package.

| Who created the Custom Metadata record? | Developer Name | Qualified API Name example |
| --- | --- | --- |
| An administrator in your org | `My_Account_Checks` | `My_Account_Checks` |
| The installed Record Health Check package | `Example_Account_Profile_Readiness` | `rhc__Example_Account_Profile_Readiness` |
| Another installed package with namespace `other` | `Account_Readiness` | `other__Account_Readiness` |

The prefix belongs to the package that supplied that particular Custom Metadata record. It does not
come from the Check Set's object or from the Apex class calling Record Health Check.

## Copy the Qualified API Name from Setup

1. From **Setup**, enter `Custom Metadata Types` in **Quick Find**.
2. Select **Custom Metadata Types**.
3. Next to **Record Health Check Set**, select **Manage Records**.
4. Open the Check Set.
5. Copy **Qualified API Name** exactly as Salesforce shows it.

To run one Check instead of its entire Check Set, repeat the steps for **Record Health Check** and
copy that Check's **Qualified API Name**.

Use the copied value without changing it:

```apex
// This example represents a Check Set created by an administrator in your org.
// Replace it with the exact Qualified API Name copied from Setup.
String checkSetApiName = 'My_Account_Checks';
```

Do not add `rhc__` because the Apex class begins with `rhc.`. These are separate names:

```apex
// rhc. identifies the installed Apex class.
// checkSetApiName identifies the selected Custom Metadata record.
rhc.RecordHealthCheckResponse response = rhc.RecordHealthCheck.evaluate(
  rhc.RecordHealthCheckRequest.forCheckSet(checkSetApiName, accountIds)
);
```

If you need to confirm the values with SOQL, query the installed Custom Metadata Type:

```sql
SELECT DeveloperName, QualifiedApiName
FROM rhc__Record_Health_Check_Set__mdt
ORDER BY QualifiedApiName
```

The `rhc__` after `FROM` identifies the Custom Metadata **Type** installed by Record Health Check.
The returned `QualifiedApiName` identifies each Check Set record. Copy the returned value; do not
add or remove a prefix.

## What happens if the name is wrong?

Record Health Check does not guess. It does not remove a namespace, add `rhc__`, retry with Developer
Name, or select a record with a similar label. The request fails clearly when the exact Qualified
API Name is missing or unknown.

This prevents a request from silently running a different Check Set that happens to have the same
Developer Name.

The Lightning card reports that its configuration could not be found. Flow and Apex return the
corresponding configuration error, including `CONFIG_NOT_FOUND` where a per-result contract
applies. Return to Setup, copy **Qualified API Name**, and replace the value without editing its
namespace prefix.

## Keep Example starter configuration explicit

The package installs four example Check Sets whose Developer Names begin with `Example_` and whose
card titles begin with `Example:`. They are learning examples, not business rules for your org:

- `Example_Account_Profile_Readiness`
- `Example_Account_Relationship_Risk`
- `Example_Contact_Relationship_Readiness`
- `Example_Opportunity_Deal_Readiness`

Create separate Check Sets with names and titles that describe your own business requirements. A
package upgrade can update its installed examples; it must not overwrite Custom Metadata records
created by your team.

## Repository checks for contributors

> [!NOTE]
> This section is only for package contributors. Administrators do not run repository commands.

Package contributors must keep the same Qualified API Name behavior in Apex, Flow, Lightning, tests,
and documentation. After changing selection logic or installed examples, run:

```bash
npm run check:configuration-identity
npm run check:package-boundary
```

The package source is under `packages/record-health-check/force-app`. Test-only metadata under
`packages/record-health-check/integration-tests` and `subscriber-app` is not included in a normal
installation.

## Related

- [Apex API](../../api/apex-api.md)
- [Flow actions](../../integration/flow-actions.md)
- [Install and verify](../../installation/install-and-verify.md)
- [Package testing and upgrades](package-testing-and-upgrades.md)
- [Glossary](../glossary.md)
