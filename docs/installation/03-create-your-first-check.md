# Create your first Check

Use this guide to turn one familiar business question into a working health check: does this Account
have a Billing City? You will create the configuration in Salesforce Setup, place it on an Account
page, and prove that the guidance makes sense when the field is blank and when it is populated.

You need Record Health Check installed, permission to manage Custom Metadata and edit Lightning
record pages, and **Record Health Check User** access.

**You do not need:** Apex, Flow, or command-line tools.

If Record Health Check is not installed yet, complete [Install and verify in your
org](02-install-and-verify.md) first.

## What you will build

| Configuration | Name used in this guide | Purpose |
| --- | --- | --- |
| **Check Set** | `Account_Readiness` | Controls the card and groups related Checks |
| **Check** | `Billing_City_Is_Populated` | Asks one health question |

The Check passes when `BillingCity` contains a value and fails when it is blank. It reports the
result without blocking record save or changing Account data.

## Step 1: Create the Check Set

1. In Salesforce Setup, open **Custom Metadata Types**.
2. Next to **Record Health Check Set**, select **Manage Records**.
3. Select **New**.
4. Enter these values:

| Setup field | Value | Why this value is useful now |
| --- | --- | --- |
| **Label** | Account Readiness | Gives the configuration a recognizable name |
| **Developer Name** | `Account_Readiness` | Gives Salesforce a stable identity for the Check Set |
| **Object** | `Account` | Makes the Check Set available on Account pages |
| **Card Title** | Account Readiness | Tells users what the card is reviewing |
| **When Checks Run** | **When the user clicks Run** | Lets you control the first test and see exactly when the result changes |
| **Active** | Checked | Makes the Check Set available to the Lightning component |

5. Select **Save**.

Manual execution makes the first test easier to follow because the card waits for you to select
**Run**.

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
| **Message When Failed** | Billing City is missing. Add it before the Account review. | Explains why the result matters |
| **Fix Message** | Edit the Account billing address and rerun the check. | Gives the user a concrete next step |
| **Evaluation Order** | `100` | Sets this Check's position when more Checks are added later |
| **Active** | Checked | Allows the Check to run |

5. Select **Save**.

The Formula Check reads only the current Account, so it does not need SOQL or Apex.

## Step 3: Add the card to an Account page

1. Open an Account record.
2. Select **Setup → Edit Page**.
3. Drag **Record Health Check** onto the Lightning record page.
4. In the component properties, select the `Account_Readiness` Check Set.
5. Save and activate the page.
6. Return to the Account and refresh the page.

If the Check Set picker is empty, confirm the Check Set is active and its **Object** value is
`Account`.

When a Demo Check Set is already installed, the card can look like this example (Pass, Fail, and
Skipped outcomes with Found and Expected values):

![Example Account Relationship and Risk health check card](../../assets/img/Example_Account_Relationship_Risk_Screenshot.png)

## Step 4: Test both results

Use an Account you can safely edit.

| Test | What to do | Expected result |
| --- | --- | --- |
| Failing record | Clear Billing City, save the Account, and select **Run** | **Warning** (Fail) with the failure and fix messages |
| Passing record | Add Billing City, save, and select **Rerun** | **Pass** |

The card does not rerun automatically after a record edit. Select **Rerun** or refresh the page.

## If the Check does not work

| What you see | What to check |
| --- | --- |
| The card is missing | Confirm the Lightning page is activated for the current app and profile |
| The Check Set is unavailable | Confirm **Active** is checked and **Object** is `Account` |
| The card has no Check rows | Confirm the Check is active and belongs to `Account_Readiness` |
| The Check cannot evaluate | Confirm the running user can read Account and `BillingCity` |
| Setup changes do not appear | Refresh the record page after saving Custom Metadata |

For authorized troubleshooting details, use [Troubleshoot with Show Diagnostics](../guides/07-troubleshoot-with-show-diagnostics.md).

## What to learn next

| Goal | Next page |
| --- | --- |
| Add more Formula Checks | [Formula examples](../examples/README.md#formula-examples) |
| Check Contacts, Opportunities, Cases, or other related records | [Query examples](../examples/README.md#query-examples) |
| Understand every available field | [Configure Check Sets and Checks](../guides/03-configure-check-sets-and-checks.md) |
| Add a link or instruction to a failed Check | [Configure action links](../guides/04-configure-action-links.md) |
| Prepare the Check Set for release | [Configuration review checklist](../guides/03-configure-check-sets-and-checks.md#14-review-checklist) |

## Next steps

- [Examples library](../examples/README.md)
- [Configure Check Sets and Checks](../guides/03-configure-check-sets-and-checks.md)
- [Check Set fields](../metadata/01-fields-check-set.md)
- [Check fields](../metadata/02-fields-check.md)
