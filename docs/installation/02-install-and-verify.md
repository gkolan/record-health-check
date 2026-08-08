# Install and verify

> [!NOTE]
> On this page, install Record Health Check in a sandbox, place the card on a Lightning record
> page, and prove a Rule result as a representative user before you plan production.

**You need:** a Salesforce sandbox, permission to install an unlocked package, and permission to
edit Lightning record pages.

**You do not need:** this repository's source, Apex, or the Salesforce CLI for the main path below.

> [!TIP]
> Install the promoted unlocked package only. Assign **Record Health Check User** (`rhc__Record_Health_Check_User`), place the
> card, and pick a Demo Check Set.
>
> **Already installed?** Use [Revalidate an installation](04-upgrading.md).
> **Want the maintained demo org?** See [Try the demo](05-create-rhc-scratch-org.md).

## What success looks like

| Milestone | Expected result |
| --- | --- |
| Package installed | Setup → Installed Packages lists **Record Health Check** (`rhc`) |
| Access assigned | A normal user with **Record Health Check User** (`rhc__Record_Health_Check_User`) can open the card and run it |
| Check Set selected | Lightning App Builder offers an active Check Set for that object |
| Card on the page | The Record Health Check card appears on the Lightning record page |
| A Rule runs | Each Rule shows Pass, Fail (Failed / Warning / Info), Skipped, Unable to Check, or System Error |

## What the install includes

You get the Framework, permission sets, Lightning component, Custom Metadata Types, public APIs,
and four Demo Check Sets (`Example_…`, card titles prefixed with `Demo:`).

You do **not** get the Acme demo Accounts. Those records come only from
[Try the demo](05-create-rhc-scratch-org.md).

The promoted version and install links live in
[`config/package-releases.json`](../../config/package-releases.json).

## 1. Install in a sandbox

Use a sandbox first. Single-currency and multi-currency orgs use the same steps; currency mode only
changes how Found / Expected currency values look. See the
[currency FAQ](../guides/02-faq.md#does-record-health-check-work-in-single-currency-and-multi-currency-orgs).

[![Install in Sandbox](https://img.shields.io/badge/Install_in_Sandbox-032D60?style=for-the-badge&logo=salesforce&logoColor=white)](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tak000000ZXVlAAO)

| Org type | When to use it | Install |
| --- | --- | --- |
| Sandbox | First install and everyday verification | [Install in Sandbox](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tak000000ZXVlAAO) |
| Production / Developer Edition | After the sandbox path works | [Install in Production](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tak000000ZXVlAAO) |

Both links install the same package: **Record Health Check** (`rhc`) version **2.0.0.6**
(`04tak000000ZXVlAAO`). Only the login host differs.

On the install screen, choose **Install for Admins Only** unless you have a reason not to. People
get access from the permission sets in the next step, not from that install-time profile choice.

## 2. Give people access

In **Setup → Permission Sets**:

1. Assign **Record Health Check User** (`rhc__Record_Health_Check_User`) to everyone who should run the card.
2. Assign **Record Health Check Admin** (`rhc__Record_Health_Check_Admin`) only to people who configure Check Sets or troubleshoot
   with Show Diagnostics.

Leave packaged Apex and packaged tests as the package shipped them. Put your own tests in your own
repo. See [Package testing and upgrades](../reference/framework/07-package-testing-and-upgrades.md)
when you need that boundary spelled out.

## 3. Pick a Demo Check Set

The install already includes four Demo Check Sets you can select right away:

- Account Profile Readiness
- Account Relationship & Risk
- Contact Relationship Readiness
- Opportunity Deal Readiness

Open an Account and look at **Demo: Account Relationship & Risk** first. Review each Demo Rule
before you treat it as production policy.

![Demo Account Relationship and Risk health check card on an Account record page](../../assets/img/Example_Account_Relationship_Risk_Screenshot.png)

When you are ready to write your own configuration, follow
[Create your first Rule](03-create-your-first-rule.md).

## 4. Add the card to a record page

1. Go to **Setup → Lightning App Builder**.
2. Edit a record page for the same object as the Check Set (Account for the Demo Account cards).
3. Drag **Record Health Check** onto the page. In App Builder it appears under **Custom** (unlocked
   packages do; **Custom - Managed** is for managed packages).
4. Select the Demo Check Set or one you created.
5. Save and activate the page.

## 5. Verify the result

Open a matching record as someone who has **Record Health Check User** (`rhc__Record_Health_Check_User`), not only as the installer.
If the card waits for a click, select **Run**.

Each Rule should show Pass, Fail (Failed, Warning, or Info by severity), Skipped, Unable to Check,
or System Error. Change a field a Rule cares about, save, and select **Rerun**. The result should
follow the saved data.

| Verification | Expected result |
| --- | --- |
| User with **Record Health Check User** (`rhc__Record_Health_Check_User`) opens the record | The card is visible and can run |
| User runs the Check Set | Every Rule shows one of the statuses above |
| User changes related data, saves, and selects **Rerun** | The result matches the saved record |
| User without Framework access opens the page | That user cannot run the checks |

## If something fails

| Symptom | What to check |
| --- | --- |
| Install fails on permissions | Confirm the signed-in user can install unlocked packages |
| App Builder has no Check Set to pick | Choose an active Demo Check Set whose Object matches the page, or create and activate your own |
| A user cannot see or run the card | Assign **Record Health Check User** (`rhc__Record_Health_Check_User`), then check object, field, and record access |
| Component sits under **Custom**, not **Custom - Managed** | Expected for an unlocked package. Confirm **Setup → Installed Packages** shows Record Health Check (`rhc`) |
| Install fails with a package/caller mismatch about `RecordHealthCheckController` | That org already has unpackaged Framework source from this repository. Use an org that has never received that source deploy |
| A Rule shows Unable to Check | Read the Reason Code, check the Rule, and confirm the running user's Salesforce access |
| A Rule shows System Error | Read the Reason Code, check any Apex plugin, review logs, and turn on Show Diagnostics if you have Admin access |

Need a longer diagnostic path? See
[Configure Check Sets and Rules: Troubleshooting](../guides/03-configure-check-sets-and-rules.md#13-troubleshooting)
or the [FAQ](../guides/02-faq.md).

## Optional: Install with the Salesforce CLI

Use this when a pipeline or script should perform the install. Commands work the same on Windows,
macOS, and Linux.

```bash
sf org login web --instance-url https://test.salesforce.com --alias rhc-sandbox
sf org display --target-org rhc-sandbox

sf package install \
  --package 04tak000000ZXVlAAO \
  --target-org rhc-sandbox \
  --upgrade-type DeprecateOnly \
  --wait 30 \
  --publish-wait 10

sf org assign permset --name rhc__Record_Health_Check_User --target-org rhc-sandbox
```

Then continue from [Pick a Demo Check Set](#3-pick-a-demo-check-set).

## Optional: Call the package from your own Apex or metadata

Everything the package installs lives in the `rhc` namespace. Your org does not need a namespace of
its own. Subscriber-owned Custom Metadata records stay unnamespaced even when the type is prefixed.

| What you are referencing | Write it as |
| --- | --- |
| Custom Metadata Type | **Record Health Check Set** (`rhc__Record_Health_Check_Set__mdt`), **Record Health Check Rule** (`rhc__Record_Health_Check_Rule__mdt`) |
| A packaged field on those types | **Card Title** (`rhc__CardTitle__c`), **Active** (`rhc__IsActive__c`) |
| Standard fields on those types | `DeveloperName`, `QualifiedApiName` (no prefix) |
| Apex classes and public API types | `rhc.RecordHealthCheck`, `rhc.RecordHealthCheckRequest`, `rhc.RecordHealthCheckResponse` |
| Permission sets | **Record Health Check User** (`rhc__Record_Health_Check_User`), **Record Health Check Admin** (`rhc__Record_Health_Check_Admin`) |
| Your own Check Set metadata file | `rhc__Record_Health_Check_Set__mdt.My_Check_Set.md-meta.xml`, with `rhc__`-prefixed `<field>` names |

To list the Demo Check Sets after install:

```sql
SELECT DeveloperName, QualifiedApiName, rhc__CardTitle__c
FROM rhc__Record_Health_Check_Set__mdt
WHERE DeveloperName LIKE 'Example_%'
ORDER BY QualifiedApiName
```

Use `QualifiedApiName` exactly when Apex, Flow, or App Builder asks for a Check Set identity. See
[Configuration identity](../reference/framework/06-configuration-identity.md).

## Next steps

- [Create your first Rule](03-create-your-first-rule.md): build one Check Set of your own
- [Try the demo](05-create-rhc-scratch-org.md): full Acme scenario with `npm run setup`
- [Examples library](../examples/README.md): adapt another Rule pattern
- [Configure Check Sets and Rules](../guides/03-configure-check-sets-and-rules.md): every field in depth
- [How it works](01-how-it-works.md): result terms and when to use a Validation Rule instead
- [Security and data access](../reference/framework/02-security.md): trust model before production
- [Uninstall and rollback](06-uninstall-and-rollback.md): remove the card and package cleanly
