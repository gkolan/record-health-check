# Create your first Check

> [!NOTE]
> On this page, create an Account Check for Billing City, place it on a Lightning record page, and
> verify both its passing and attention states.

Use this guide to turn one familiar business question into a working health check: does this Account
have a Billing City? You will create the configuration in Salesforce Setup, place it on an Account
page, and prove that the guidance makes sense when the field is blank and when it is populated.

## Before you start

The administrator completing this guide needs:

- the installed **Record Health Check Admin** Permission Set;
- Salesforce **Customize Application** (or equivalent Custom Metadata management access) to create
  and save Check Set and Check records; **Record Health Check Admin does not grant this Salesforce
  system permission**;
- access to edit Lightning record pages; the page builder also needs **Record Health Check Admin**
  so App Builder can load the Check Set picklist;
  and
- Read access to Account and `BillingCity`.

People who only run the completed card need **Record Health Check User** plus access to the Account
records and fields being checked.

**You do not need:** Apex or command-line tools. The validation step uses the packaged Flow action
once in Flow Builder so invalid metadata is caught before users see it.

If Record Health Check is not installed yet, complete [Install and verify in your
org](install-and-verify.md) first.

## What you will build

| Configuration | Name used in this guide | Purpose |
| --- | --- | --- |
| **Check Set** | `Account_Readiness` | Controls the card and groups related Checks |
| **Check** | `Billing_City_Is_Populated` | Asks one health question |

The Check passes when `BillingCity` contains a value and fails when it is blank. It reports the
result without blocking record save or changing Account data.

## Step 1: Create the Check Set

1. In Salesforce Setup, enter **Custom Metadata Types** in Quick Find and open it.
2. Next to **Record Health Check Set**, select **Manage Records**.
3. Select **New**.
4. Enter these values:

| Setup field | Value | Why this value is useful now |
| --- | --- | --- |
| **Label** | Account Readiness | Gives the configuration a recognizable name |
| **Developer Name** | `Account_Readiness` | Gives Salesforce a stable API name for the Check Set |
| **Object** | `Account` | Makes the Check Set available on Account pages |
| **Card Title** | Account Readiness | Tells users what the card is reviewing |
| **When Checks Run** | **When the user clicks Run** | Lets you control the first test and see exactly when the result changes |
| **Summary Display** | **Below Checks** | Places the completed result summary after the Check rows |
| **Run Button Display** | **Label and icon** | Keeps the standard, discoverable Run and Rerun action |
| **Run Button Label** | Run | Names the initial action |
| **Rerun Button Label** | Rerun | Names the action after results appear |
| **Run Button Icon** | `utility:play` | Uses a standard Lightning icon |
| **Active** | Checked | Makes the Check Set available to the Lightning component |

5. Select **Save**.

Manual execution makes the first test easier to follow because the card waits for you to select
**Run**.

`utility:play` is the name of a standard Salesforce Lightning icon. Paste the name as written; it
is not a file to upload. **Developer Name** is the stable API identity that other configuration
references. Some Salesforce screens describe the same identity as a record name.

## Step 2: Create the Check

1. Return to **Custom Metadata Types**.
2. Next to **Record Health Check**, select **Manage Records**.
3. Select **New**.
4. Enter these values:

| Setup field | Value | What it means to the user |
| --- | --- | --- |
| **Label** | Billing City Is Populated | Gives administrators a recognizable Check name |
| **Developer Name** | `Billing_City_Is_Populated` | Gives Salesforce a stable identity for the Check |
| **Check Set** | `Account_Readiness` | Places this question on the card you just created |
| **Check Title** | Billing City is populated | States the question clearly on the card |
| **Evaluation Type** | **Verify with a formula** | Reads a field on the open Account |
| **Pass Condition** | `NOT(ISBLANK(BillingCity))` | Passes when Billing City contains a value |
| **Failure Severity** | **Warning** | Signals that the missing value deserves attention without presenting it as the most serious outcome |
| **Message When Failed** | `{!record.Name fallback="This Account"}` is missing Billing City. Add it before the Account review. | Explains which Account needs attention and remains clear if its Name is unavailable |
| **Fix Message** | Edit the Account billing address and rerun the check. | Gives the user a concrete next step |
| **Action Label** | Edit account | Gives the destination a clear link label |
| **Action URL** | `/lightning/r/Account/{!record.Id}/edit` | Opens the current Account's standard edit page without saving a change |
| **Evaluation Order** | `100` | Sets this Check's position when more Checks are added later |
| **Active** | Checked | Allows the Check to run |

5. Select **Save**.

The Formula Check reads only the current Account, so it does not need SOQL or Apex.

To confirm `BillingCity`, open **Setup → Object Manager → Account → Fields & Relationships →
Billing City** and read **Field Name**. The merge token `{!record.Name fallback="This Account"}`
uses the Account Name when it is readable and substitutes “This Account” when the value is blank or
unavailable.

## Step 3: Validate the configuration

1. In Setup, open **Flows** and create a short autolaunched flow.
2. Add the **Validate Record Health Check Configuration** action.
3. Store or display its **Configuration Is Valid**, **Error Count**, **Warning Count**, and
   **Validation Report JSON** outputs, then run **Debug**.
4. Do not activate the Check Set for users while **Configuration Is Valid** is false. Correct every
   error named in the report and debug the flow again. Warnings deserve review but do not make the
   configuration invalid.

The action checks active definitions and inactive drafts, including prerequisite names and whether
SOQL can use the runtime's multi-record query grammar. Keep this small administrator flow as a
reusable validation tool after future Custom Metadata edits.

## Step 4: Add the card to an Account page

1. Open an Account record.
2. Select **Setup → Edit Page**.
3. Drag **Record Health Check** onto the Lightning record page.
4. In the component properties, select the `Account_Readiness` Check Set.
5. Confirm the component is using the intended **Check Set**. Its run timing, summary position, and
   Run/Rerun presentation come from that Check Set.
6. Save and activate the page.
7. Return to the Account and refresh the page. The card loads lightweight Check Set shell settings;
   definitions and evaluation remain deferred until you select **Run**.

If the Check Set picker is empty, confirm the Check Set is active and its **Object** value is
`Account`.

When an Example Check Set is already installed, the card can look like this example (Pass, Fail, and
Skipped outcomes with Found and Expected values):

![Example Account Relationship and Risk health check card](../../assets/img/Example_Account_Relationship_Risk_Screenshot.png)

## Step 5: Test both results

Use an Account you can safely edit.

| Test | What to do | Expected result |
| --- | --- | --- |
| Failing record | Clear Billing City, save the Account, and select **Run** | **Warning** (`FAIL`) with the failure message, fix message, and **Edit account** link |
| Passing record | Add Billing City, save, and select **Rerun** | **Pass** |

The card does not rerun automatically after a record edit. This manual example should use
**Rerun**. For an automatic Check Set whose action is hidden, refresh reevaluates the saved data,
but that refresh does not publish user-run lifecycle events.

User-run lifecycle events are optional Platform Events emitted only after a person selects Run or
Rerun and the Check Set or Check publication settings are enabled. Page-load evaluation never
publishes those result events.

Open **Edit account** during the failing test and confirm it opens the same Account. The link does
not save anything automatically; close the edit page without saving or restore the test value when
you finish.

## If the Check does not work

| What you see | What to check |
| --- | --- |
| The card is missing | Confirm the Lightning page is activated for the current app and profile |
| The Check Set is unavailable | Confirm **Active** is checked and **Object** is `Account` |
| The card has no Check rows | Confirm the Check is active and belongs to `Account_Readiness` |
| The Check cannot evaluate | Confirm the running user can read Account and `BillingCity` |
| Setup changes do not appear | Refresh the record page after saving Custom Metadata |

For authorized troubleshooting details, use [Troubleshoot Record Health Check](../guides/troubleshoot-with-show-diagnostics.md).

## Next steps

| Goal | Next page |
| --- | --- |
| Add more Formula Checks | [Formula examples](../examples/README.md#formula-examples) |
| Check Contacts, Opportunities, Cases, or other related records | [Query examples](../examples/README.md#query-examples) |
| Understand every available field | [Configure Check Sets and Checks](../guides/configure-check-sets-and-checks.md) |
| Add a link or instruction to a failed Check | [Configure action links](../guides/configure-action-links.md) |
| Prepare the Check Set for release | [Configuration review checklist](../guides/configure-check-sets-and-checks.md#step-12-review-checklist) |
| Look up exact Setup fields | [Check Set fields](../metadata/fields-check-set.md) and [Check fields](../metadata/fields-check.md) |
| Translate card labels and statuses | [Read Record Health Check results](../guides/read-results.md) |
