# Check Contact emails for a placeholder domain

> [!NOTE]
> **Setup reference**: [Query Check configuration](../../reference/evaluation/query.md)

Create a Query Check that reviews Contact Email values related to an Account. It passes only when
every populated email avoids a confirmed placeholder domain such as `@example.com`.

## Why this pattern fits

The Check reviews a list of values on related Contact records. **Verify with a query** can ignore
blank emails, compare every populated value, and skip Accounts with no visible Contacts.

## Before you configure it

- Replace `@example.com` with a placeholder value confirmed from your own data policy.
- Confirm whether matching should be case-sensitive and whether more than one pattern is required.
- Create the [Contact-count prerequisite](./customer-contact.md) first.
- Confirm intended users can read Contact Account and Email fields.
- Save new configuration inactive and validate it before activation.

## Step 1: Create or choose the Check Set

Use **Account Related Record Review**, or create an Account Check Set that runs on click, shows
Found/Expected on demand, and remains inactive until validation succeeds.

## Step 2: Create the Check

Open **Setup → Custom Metadata Types → Record Health Check → Manage Records**, select **New**, and
enter:

| Salesforce field          | Value                                                                                                                    |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| Label                     | Contact Email Avoids Placeholder Domain                                                                                  |
| Record Health Check Name  | `Contact_Email_Avoids_Placeholder`                                                                                       |
| Check Set                 | Account Related Record Review                                                                                            |
| Check Title               | Contact emails exclude placeholder domain                                                                                |
| Evaluation Type           | Verify with a query                                                                                                      |
| Source Query              | `SELECT Email FROM Contact WHERE AccountId = {!record.Id}`                                                               |
| Source Query Field        | `Email`                                                                                                                  |
| How To Read Query Results | Every record passes                                                                                                      |
| Comparison Operator       | Does not contain text                                                                                                    |
| Expected Value Comes From | Fixed value                                                                                                              |
| Expected Value (Fixed)    | `@example.com`; replace before activation                                                                                |
| If Query Finds No Records | Skip                                                                                                                     |
| If Field Value Is Empty   | Ignore the record                                                                                                        |
| Max Query Rows            | `200`                                                                                                                    |
| Display: Found Text       | `{!rhcResult.failedRecordCount} of {!rhcResult.totalRecordCount fallback="0"} contact emails use the placeholder domain` |
| Display: Expected Text    | No contact email uses the confirmed placeholder domain                                                                   |
| Prerequisite Check        | Has At Least One Contact                                                                                                 |
| Failure Severity          | Warning                                                                                                                  |
| Message When Failed       | One or more Contacts use a placeholder email domain. Replace only with a verified address.                               |
| Fix Message               | Review the related Contacts and follow your data-correction policy.                                                      |
| Action Label              | Review contacts                                                                                                          |
| Action URL                | `/lightning/r/Account/{!record.Id}/related/Contacts/view`                                                                |
| Evaluation Order          | `100`                                                                                                                    |
| Active                    | Unchecked until validation succeeds                                                                                      |

## Step 3: Validate and activate

1. Replace the sample domain with the confirmed value.
2. Run the [configuration-validation Flow](../../build-checks/validate-configuration.md).
3. Correct every error, then activate the prerequisite, this Check, and the Check Set.
4. Test from the Account page with **Record Health Check Card User**.

## Step 4: Test the result

| Visible Contacts | Email values                      | Expected result                |
| ---------------- | --------------------------------- | ------------------------------ |
| None             | Not applicable                    | Skipped by the prerequisite    |
| One              | Blank                             | Pass; the blank row is ignored |
| Two              | Both verified domains             | Pass                           |
| Two              | One contains the placeholder text | Warning                        |

Also test different letter casing and subdomains if your policy distinguishes them.

## What the user sees

The card reads the visible query result and compares it with the configured expected value.

| Result detail | Meaning                                                                                       |
| ------------- | --------------------------------------------------------------------------------------------- |
| **`PASS`**    | The query result satisfies the configured comparison.                                         |
| **`FAIL`**    | The query result does not satisfy the comparison, and the card shows the configured guidance. |
| **`SKIPPED`** | The Check does not apply or a configured prerequisite did not pass.                           |
| **Found**     | The normalized row, list, or aggregate value returned by the query.                           |
| **Expected**  | The configured fixed value or evaluated expected formula.                                     |

## If it does not work

| What you see                                  | Check this first                                                           |
| --------------------------------------------- | -------------------------------------------------------------------------- |
| The sample domain is still displayed          | Do not activate until both the fixed value and display text match policy   |
| Accounts with no Contacts behave unexpectedly | Confirm the prerequisite and its evaluation order                          |
| Blank Email fails                             | Confirm **If Field Value Is Empty** is **Ignore the record**               |
| A known placeholder is missed                 | Confirm the exact stored text, comparison behavior, and user record access |

## Technical reference

- [Query evaluation](../../reference/evaluation/query.md)
- [Check prerequisites](../../reference/custom-metadata/check-fields.md)
- [Result merge tokens](../../reference/merge-syntax/README.md)

## Related

- [Previous: Forecast amounts](./forecast-amounts.md)
- [Query examples](./README.md)
- [Next: Account owner team membership](./account-owner-team-membership.md)
