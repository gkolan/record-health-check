# Install and verify

> [!NOTE]
> On this page, take Record Health Check from deployment to a proven Lightning record-page result by configuring access, placing the card, and verifying as a representative user.

This tutorial takes Record Health Check from sandbox deployment to an observable Rule result on a Lightning record
page. Complete the verification as a representative user before planning a production release.

**You need:** a Salesforce sandbox, the Salesforce CLI (`sf`) or a one-click Deploy button, and
permission to deploy metadata and edit Lightning record pages.

> [!NOTE]
> **Already installed?** Use [Revalidate an installation](04-upgrading.md) to protect configuration,
> access, integrations, and rollback evidence while deploying the current repository.

## What the install includes

The documented install paths deploy the Record Health Check Framework from `force-app` via
`manifest/package.xml`: the engine, permission sets, Lightning component, Custom Metadata Types,
public APIs, and four Demo Check Sets (`Example_…`, card titles prefixed with `Demo:`).

They do **not** create Acme demo Account data. Those deterministic records come only from
[Try the demo](05-create-rhc-scratch-org.md).

Always use the manifest (or an explicit `--source-dir force-app`). A bare
`sf project deploy start` can pull more than product metadata; keep `integration-tests/` out of
sandbox installs. That tree is CI fixture metadata. See
[`integration-tests/README.md`](../../integration-tests/README.md).

## What success looks like

| Milestone | Expected result |
| --- | --- |
| Record Health Check is deployed | The Framework classes, Lightning Web Component, Custom Metadata Types, and Permission Sets exist in the sandbox |
| User access is assigned | A representative user can run the protected Apex surface |
| A Check Set is available | Lightning App Builder can select an active Check Set for the record page object |
| The card is placed | The Record Health Check card appears on the matching Lightning record page |
| A Rule runs | The card shows Pass, Fail (Failed / Warning / Info), Skipped, Unable to Check, or System Error for the record |

## 1. Connect to the sandbox

Log in and give the sandbox an alias so every later command names its target explicitly:

```bash
sf org login web --instance-url https://test.salesforce.com --alias rhc-sandbox
sf org display --target-org rhc-sandbox
```

Confirm that `sf org display` identifies the intended sandbox before deploying.

## 2. Deploy Record Health Check

Use a sandbox for the first install.

### Option A: One-click Deploy button

[![Deploy to Sandbox](https://img.shields.io/badge/Deploy%20to-Sandbox-00A1E0?logo=salesforce&logoColor=white)](https://githubsfdeploy-sandbox.herokuapp.com/app/githubdeploy/gkolan/RecordHealthCheck)

The button opens Salesforce authentication and deploys the default package directory (`force-app`)
only. For production orgs, use the **Deploy to Salesforce** badge on the repository README (same
tool, production login host).

### Option B: Salesforce CLI

From a clone of this repository:

```bash
git clone https://github.com/gkolan/RecordHealthCheck.git
cd RecordHealthCheck
sf project deploy start --manifest manifest/package.xml --target-org rhc-sandbox --wait 30
```

Then assign the runner permission set:

```bash
sf org assign permset --name Record_Health_Check_User --target-org rhc-sandbox
```

Authors and troubleshooting administrators can also receive `Record_Health_Check_Admin`; do not
assign administrative access to users who only need to run checks.

## 3. Choose or add a Check Set

The install includes four Demo Check Sets you can select immediately (Account Profile Readiness,
Account Relationship & Risk, Contact Relationship Readiness, and Opportunity Deal Readiness).
Review every Demo Rule before adapting it for production policy.

To author your own configuration, create a Check Set under **Setup → Custom Metadata Types** by
following [Create your first Rule](03-create-your-first-rule.md).

## 4. Add the card to a record page

1. Go to **Setup → Lightning App Builder**.
2. Edit a record page matching the Check Set's object.
3. Drag **Record Health Check** onto the page.
4. Select the installed or newly created Check Set.
5. Save and activate the page.

## 5. Verify the result

Open a matching record. If the card is configured for manual execution, click **Run**. The card
shows Pass, Fail (Failed, Warning, or Info by severity), Skipped, Unable to Check, or System Error
for each Rule. Edit relevant record data and rerun to
confirm the result changes. Repeat the verification as a representative user, not only as the
administrator who deployed Record Health Check.

| Verification | Expected result |
| --- | --- |
| Open the record as a user with `Record_Health_Check_User` | The Record Health Check card is visible and can run the selected Check Set |
| Run a manually configured Check Set | Each Rule shows Pass, Fail, Skipped, Unable to Check, or System Error |
| Change data used by a Rule, save, and select **Rerun** | The result reflects the saved record data |
| Open the page as a user without Framework access | The user cannot call the protected Apex surface |

## If installation or verification fails

| Symptom | What to check |
| --- | --- |
| The deployment reports an Apex or metadata permission error | Confirm that the authenticated user can deploy Apex and Custom Metadata. |
| The card has no Check Set to select | Select an active Demo Check Set whose Object matches the Lightning record page object, or create and activate your own Check Set. |
| A user cannot see or run the card | Assign `Record_Health_Check_User`, then review record, object, and field access. |
| A Rule shows Unable to Check | Review its Reason Code, Rule configuration, and the running user's Salesforce access. |
| A Rule shows System Error | Review the Reason Code, Apex plugin if any, Salesforce logs, and Show Diagnostics. |

If the card does not appear or a Rule will not evaluate, see
[Configuration Guide: Troubleshooting](../guides/configure-check-sets-and-rules.md#13-troubleshooting).

## Next steps

- [Try the demo](05-create-rhc-scratch-org.md): full scratch-org walkthrough with deterministic Acme data
- [Examples library](../examples/README.md): adapt another Rule pattern
- [Configure Check Sets and Rules](../guides/configure-check-sets-and-rules.md): configure every field
- [How It Works](01-how-it-works.md): learn the result terms and codes
