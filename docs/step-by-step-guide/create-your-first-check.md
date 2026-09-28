# Create your first Check

Create an Account health check that answers one question: **Does this Account have a Billing
City?** You will save the configuration inactive, validate it, add the card to an Account record
page, and test both results.

## Before you start

You need:

- Record Health Check installed in a sandbox;
- **Record Health Check Admin**;
- **Customize Application**, or equivalent access to manage Custom Metadata;
- access to edit Lightning record pages; and
- Read access to Account and Billing City.

The person testing the finished card needs **Record Health Check Card User** plus access to the
Account and Billing City. You do not need Apex or command-line tools.

## What you will create

| Record    | Name                      | What it does                                             |
| --------- | ------------------------- | -------------------------------------------------------- |
| Check Set | Account Readiness         | Controls the card on the Account page                    |
| Check     | Billing City Is Populated | Reviews Billing City and shows guidance when it is blank |

Keep both records inactive until validation succeeds.

## Step 1: Create the Check Set

1. From **Setup**, enter `Custom Metadata Types` in **Quick Find**.
2. Open **Custom Metadata Types**.
3. Next to **Record Health Check Set**, select **Manage Records**.
4. Select **New**.
5. Enter these values.

| Salesforce field             | Value                    |
| ---------------------------- | ------------------------ |
| Label                        | Account Readiness        |
| Record Health Check Set Name | `Account_Readiness`      |
| Object                       | `Account`                |
| Card Title                   | Account Readiness        |
| When Checks Run              | When the user clicks Run |
| Summary Display              | Show below checks        |
| Run Button Display           | Show label and icon      |
| Run Button Label             | Run                      |
| Rerun Button Label           | Rerun                    |
| Run Button Icon              | `utility:play`           |
| Active                       | Unchecked                |

6. Select **Save**.

`utility:play` is the name of a standard Salesforce icon. It is not a file upload.

## Step 2: Create the Check

1. Return to **Custom Metadata Types**.
2. Next to **Record Health Check**, select **Manage Records**.
3. Select **New**.
4. Enter these values.

| Salesforce field         | Value                                                             |
| ------------------------ | ----------------------------------------------------------------- |
| Label                    | Billing City Is Populated                                         |
| Record Health Check Name | `Billing_City_Is_Populated`                                       |
| Check Set                | Account Readiness                                                 |
| Check Title              | Billing City is populated                                         |
| Evaluation Type          | Verify with a formula                                             |
| Pass Condition           | `NOT(ISBLANK(BillingCity))`                                       |
| Failure Severity         | Warning                                                           |
| Message When Failed      | `{!record.Name fallback="This Account"}` is missing Billing City. |
| Fix Message              | Edit the billing address, then run the Check again.               |
| Action Label             | Edit account                                                      |
| Action URL               | `/lightning/r/Account/{!record.Id}/edit`                          |
| Evaluation Order         | `100`                                                             |
| Active                   | Unchecked                                                         |

5. Select **Save**.

The formula reads Billing City on the open Account. The message uses the Account Name when the
running user can read it and uses “This Account” otherwise. The action opens Salesforce's standard
Account edit page; it does not save a change.

## Step 3: Validate before activation

Run **Validate Record Health Check Configuration** from your reusable configuration-validation
Flow. If you do not have one, follow [Build the configuration-validation Flow](../build-checks/validate-configuration.md).

Continue only when:

- **Configuration Is Valid** is true;
- **Error Count** is zero; and
- you have reviewed every warning.

Return to the two Custom Metadata records, select **Edit**, check **Active**, and save each one.
Activating only after validation keeps unfinished configuration out of Lightning App Builder and
record-page runs.

## Step 4: Add the card to an Account page

1. Open an Account record in the sandbox.
2. Select **Setup → Edit Page**.
3. Drag **Record Health Check** onto the page.
4. In the component properties, select **Account Readiness**.
5. Save and activate the page for the intended app, record type, and profiles.
6. Return to the Account and refresh the page.

The card should show **Account Readiness** and a **Run** button. If Account Readiness is not in the
picker, confirm that the Check Set is active and its Object is `Account`.

## Step 5: Test both results

Use an Account that is safe to change in the sandbox.

| Test            | Change                                       | Expected card result                                                     |
| --------------- | -------------------------------------------- | ------------------------------------------------------------------------ |
| Needs attention | Clear Billing City, save, and select **Run** | Warning, the missing-city message, the fix message, and **Edit account** |
| Pass            | Enter Billing City and save                  | Pass after the completed card refreshes; select **Rerun** if needed      |

Open **Edit account** during the first test and confirm that it opens the same Account. Restore the
test data when finished.

## Troubleshoot your Check

| What you see                           | Check this first                                                             |
| -------------------------------------- | ---------------------------------------------------------------------------- |
| The component is missing               | Confirm that the Lightning page is activated for the current app and profile |
| Account Readiness is not in the picker | Confirm that the Check Set is active and Object is `Account`                 |
| The card has no rows                   | Confirm that the Check is active and belongs to Account Readiness            |
| Unable to Check                        | Confirm that the running user can read Account and Billing City              |
| A Setup change is not visible          | Save the Custom Metadata record, then refresh the record page                |

For restricted troubleshooting detail, follow [Troubleshoot a run](../diagnostics/browser-console.md).

## Understand the technical values

The first walkthrough uses Salesforce labels wherever possible. Use these references when you need
API names, limits, or exact runtime behavior:

- [Check Set fields](../reference/custom-metadata/check-set-fields.md)
- [Check fields](../reference/custom-metadata/check-fields.md)
- [Formula behavior](../reference/evaluation/formula.md)
- [Merge syntax](../reference/merge-syntax/README.md)
- [Result labels and API statuses](../reference/results/statuses-and-labels.md)

## Next steps

- [Choose another example](../examples/README.md)
- [Add a safe action link](../build-checks/add-fix-link.md)
- [Configure Checks and Check Sets](../build-checks/configure-check-sets-and-checks.md)
