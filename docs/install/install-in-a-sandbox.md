# Install and verify in a sandbox

> [!NOTE]
> On this page, install Record Health Check, assign the intended access, place the card on a
> Lightning record page, and verify the experience as a regular user.

Use this guide when you want Record Health Check in a Salesforce org you already use. You will
install the package, decide who can use it, add the card to a record page, and confirm that it reads
your Salesforce data correctly.

When you finish, a user can open a record and see clear guidance from a working Check Set.

> [!TIP]
> Looking for a prepared evaluation environment instead? [Deploy to a demo scratch
> org](./install-demo-in-a-scratch-org.md) creates a separate org with known records and expected results.
> It does not change your existing sandbox or production org.

## Before you begin

Start in a sandbox. It gives you room to decide where the card belongs, who should see it, and which
checks make sense before you introduce the experience in production.

You need:

- the **Download AppExchange Packages** permission, which System Administrators commonly have;
- permission to edit Lightning record pages; and
- at least one Account, Contact, or Opportunity you can use for verification.

You do not need this repository, Salesforce CLI, Apex, or Flow for the steps below.

## What the package adds

The package adds the Record Health Check card, the configuration used to define checks, permission
sets, and APIs for future automation. It also includes four active Example Check Set records:

- **Example: Account Check Builder Guide** is active, with 25 Checks.
- **Example: Account Relationship & Risk** keeps the original Account example from earlier releases.
- **Example: Contact Relationship Readiness**
- **Example: Opportunity Deal Readiness**

The 25-Check Account guide does not assign categories. Its title tooltips explain the Evaluation
Type, what Salesforce evaluates, which values are compared, and the condition that produces a pass.

The Example Check Sets are ready to evaluate records already in your org. They do not create or change
Accounts, Contacts, Opportunities, or other business data.

## Step 1: Install the package

Choose the destination that matches the org where you are signed in:

| Destination | Use it when | Install |
| --- | --- | --- |
| Sandbox | You are installing or verifying the current release | [Install in Sandbox](https://recordhealthcheck.com/install/sandbox) |
| Production or Developer Edition | You are installing the current release | [Install in Production](https://recordhealthcheck.com/install/production) |

Both links route to the latest Record Health Check package version. The different login domains
send the same package version to the appropriate Salesforce environment.

Salesforce first shows package details and the access choices **Install for Admins Only**, **Install
for All Users**, and **Install for Specific Profiles**. Choose **Install for Admins Only**. This installs the complete
package, but it does not automatically grant its packaged permissions to every user profile. You
will give non-admin users access with permission sets in the next step.

Choosing **Install for All Users** does not make Record Health Check write to records or run checks by
itself. The concern is access: Salesforce grants the package's profile-level permissions broadly,
including to people who may not need the card. That is harder to review and remove later. **Install
for Admins Only** followed by permission-set assignments keeps access visible and intentional.

The installation can remain in progress while Salesforce verifies components. Keep the browser
open until Salesforce reports completion; a longer installation can finish in the background and
send email. Afterward, open **Setup → Installed Packages** and confirm that **Record Health Check**
is listed.

## Step 2: Choose who can use it

The package includes permission sets so people receive only the access their work requires.

| Permission set | Assign it to | What it allows |
| --- | --- | --- |
| **Record Health Check Card User** | People who use only the Lightning record-page card | Card execution, its App Builder Check Set picker, and explicitly enabled card lifecycle events |
| **Record Health Check User** | People or automation that also use Flow, Agent, REST, Apex, Queueable, Batch, or Scheduled entry points | The broader packaged runtime surface; do not assign it merely to display the card |
| **Record Health Check Admin** | People who configure Check Sets or investigate unexpected results | User access plus package configuration and diagnostic access |

To give a non-admin access after choosing **Install for Admins Only**:

1. In **Setup**, open **Permission Sets**.
2. Open **Record Health Check Card User**.
3. Select **Manage Assignments**, then **Add Assignments**.
4. Select the users who should run the card and complete the assignment.

Repeat those steps with **Record Health Check Admin** only for administrators and troubleshooters.
The **Issue**, **Where**, and **Why** diagnosis requires both **Show Diagnostics** on the Check Set
and the **Record Health Check View Diagnostics** custom permission. The card-user and standard-user
permission sets do not grant that diagnostic permission.
A person can be a Salesforce non-admin and still run Record Health Check; the **Record Health Check
Card User** permission set provides card access, while the person's existing Salesforce access
still controls which records and fields the checks can read.

The Admin permission set does not by itself make someone a Salesforce Setup administrator. A person
who edits Check Set or Check Custom Metadata or Lightning record pages also needs the appropriate
org-level Setup permissions assigned by your organization.

## Step 3: Add a meaningful check to a record page

Use one of the packaged Example Check Sets for the first review. **Example: Account Check Builder
Guide** is a useful starting point because its 25 Checks demonstrate Formula, Query, Compare Two
Queries, Apex, clear evidence, remediation guidance, and applicability rules.

1. Open an Account in the sandbox.
2. Select **Setup → Edit Page**.
3. Drag **Record Health Check** from the **Custom** components into a useful position on the page.
4. In the component properties, select **Example: Account Check Builder Guide**.
5. Save the page, then select **Activate**. Choose the assignment that matches the users you are
   testing: **Org Default**, **App Default**, or an app, record type, and profile assignment. An App
   Default affects only that Lightning app. Record the assignment you chose.
6. Return to the Account and refresh the page.

The component appears under **Custom** because Record Health Check is an unlocked package. Nothing
is wrong if you do not see it under **Custom - Managed**.

Lightning App Builder selects the Check Set; the Check Set metadata owns run timing and card
presentation. In **Setup → Custom Metadata Types → Record Health Check Set**, use **Summary
Display** to place the overall or category summary above or below the Check rows.

**Setup → Edit Page** opens the active Lightning page for the current record context. If your org
uses several apps or profile assignments, confirm the page name and activation assignment before
saving so you do not update a page that the test user never receives.

The packaged component is supported on Lightning record pages in Lightning Experience. Do not
treat this guide as verification for Salesforce Classic, an App or Home page, Experience Cloud, or
Salesforce mobile; validate any additional surface separately before promising support.

![Account Check Builder Guide on the existing demo Account record page](../../assets/img/Example_Account_Relationship_Risk_Screenshot.png)

## Step 4: Verify the experience as a user

Open the Account as the person who received **Record Health Check Card User**. This matters: a successful
administrator test does not prove that an everyday user has the right access.

Select **Run** if the card is waiting. Then review the result as a user would:

- Does every Check communicate a clear outcome?
- Do **Found** and **Expected** explain why attention is needed?
- Does a skipped Check explain why it does not apply?
- Can the user understand the suggested next step without leaving the record?

A Check can show **Pass**, **Failed**, **Warning**, **Info**, **Skipped**, **Unable to Check**, or
**System Error**. A business condition that needs attention should appear as Failed, Warning, or
Info. Unable to Check and System Error mean Record Health Check could not give a reliable business answer.

For one final confidence check, change a field used by an Example Check on a record you can safely edit.
Save the record. A completed card should refresh and follow the saved Salesforce data. Select
**Rerun** if the editing surface does not send a standard RefreshView notification. The
health check should not change the record itself.

## You are ready to continue when

- **Setup → Installed Packages** lists Record Health Check;
- the intended user can see and run the card;
- the card is active on the correct Lightning record page;
- each Check communicates an understandable outcome; and
- rerunning the Check Set reflects a saved change to the record.

At this point, the installation is proven. The Example Check Set is still teaching content, not your
organization's policy. Review it before wider use, or [create your first Check](../step-by-step-guide/create-your-first-check.md)
around a decision your users actually make.

## If the result is not what you expected

| What you see | What to check first |
| --- | --- |
| Installation cannot continue | Confirm that you are signed in to the intended org and can install packages |
| Installation remains pending | Wait for the Salesforce completion email, then refresh **Setup → Installed Packages**. If it remains pending, give Salesforce Support the package version and target Org ID. |
| Salesforce reports an `rhc` namespace conflict | Use an org that does not already contain the package or another package with the same namespace; do not rename packaged components. |
| Record Health Check is missing in Lightning App Builder | Confirm the package appears in **Setup → Installed Packages**, then look under **Custom** components |
| No Check Set is available | Use an Example Check Set for the same object as the record page, such as an Account Example Check Set on an Account page |
| A user cannot see or run the card | Confirm that the user has **Record Health Check Card User** and can read the record and fields being checked |
| A Check shows **Unable to Check** | Read the explanation on the card, then check the user's access and the Check configuration |
| A Check shows **System Error** | Ask a Record Health Check administrator to enable Show Diagnostics temporarily and capture the diagnostic details |
| Salesforce reports a conflict with `RecordHealthCheckController` | The org already contains an unpackaged copy of Record Health Check; install into an org that has not received that source deployment |

For a guided investigation, see [Troubleshoot with Show
Diagnostics](../diagnostics/browser-console.md).

## Optional: Install from the Salesforce CLI

Use the command-line path when you are automating installation. The same commands work on Windows,
macOS, and Linux after the Salesforce CLI is installed.

```bash
sf org login web --instance-url https://test.salesforce.com --alias rhc-sandbox
sf org display --target-org rhc-sandbox
sf package install --package 04tak000000eIO1AAM --target-org rhc-sandbox --security-type AdminsOnly --upgrade-type Mixed --wait 30 --publish-wait 10 --no-prompt
sf org assign permset --name rhc__Record_Health_Check_Card_User --target-org rhc-sandbox
```

The `sf org display` step helps prevent installing into the wrong org. After the command succeeds,
continue with [Step 3](#step-3-add-a-meaningful-check-to-a-record-page). The `rhc__` prefix belongs
to the installed package's permission-set API name. Do not remove it from this command.

## Next steps

| Your next goal | Continue with |
| --- | --- |
| Prove the complete prepared experience in a separate org | [Deploy to a demo scratch org](./install-demo-in-a-scratch-org.md) |
| Build a small check that belongs to your organization | [Create your first Check](../step-by-step-guide/create-your-first-check.md) |
| Inspect every packaged example | [Installed example Check Sets](./explore-installed-examples.md) |
| Adapt a tested pattern | [Examples library](../examples/README.md) |
| Review security before production | [Security and data access](../architecture/security-and-data-access.md) |
| Revalidate after an upgrade | [Upgrade and revalidate](./upgrade.md) |
| Remove the package | [Uninstall and rollback](./uninstall.md) |
