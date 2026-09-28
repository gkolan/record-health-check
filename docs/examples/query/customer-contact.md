# Check whether an Account has a Contact

> [!NOTE]
> **Setup reference**: [Query Check configuration](../../reference/evaluation/query.md)

Create a Query Check that counts Contacts related to the Account. The Check passes when the count
is greater than zero and guides the user to the Contacts related list when none are found.

## Why this pattern fits

Contacts are separate records, so an Account formula cannot count them. **Verify with a query** can
count the related records without custom Apex. This should guide a handoff rather than block every
Account save with a Validation Rule.

## Before you configure it

- Confirm that at least one Contact is required for your handoff process.
- Confirm that intended users can read Contact and Contact.AccountId.
- Remember that the count reflects records visible to the running user.
- Save new configuration inactive and validate it before activation.

## Step 1: Create or choose the Check Set

To create a Check Set, open **Setup → Custom Metadata Types → Record Health Check Set → Manage
Records**, select **New**, and enter:

| Salesforce field             | Value                                          |
| ---------------------------- | ---------------------------------------------- |
| Label                        | Account Related Record Review                  |
| Record Health Check Set Name | `Account_Related_Record_Review`                |
| Object                       | `Account`                                      |
| Card Title                   | Account Related Record Review                  |
| Card Subtitle                | Confirm related records are ready for handoff. |
| When Checks Run              | When the user clicks Run                       |
| Summary Display              | Show below checks                              |
| Found/Expected Display       | Show on demand                                 |
| Active                       | Unchecked until validation succeeds            |

## Step 2: Create the Check

Open **Setup → Custom Metadata Types → Record Health Check → Manage Records**, select **New**, and
enter:

| Salesforce field                | Value                                                                                                 |
| ------------------------------- | ----------------------------------------------------------------------------------------------------- |
| Label                           | Has At Least One Contact                                                                              |
| Record Health Check Name        | `Has_At_Least_One_Contact`                                                                            |
| Check Set                       | Account Related Record Review                                                                         |
| Check Title                     | Has at least one Contact                                                                              |
| Evaluation Type                 | Verify with a query                                                                                   |
| Source Query                    | `SELECT COUNT() FROM Contact WHERE AccountId = {!record.Id}`                                          |
| How To Read Query Results       | One row or aggregate                                                                                  |
| Comparison Operator             | Greater than                                                                                          |
| Expected Value Comes From       | Fixed value                                                                                           |
| Expected Value (Fixed)          | `0`                                                                                                   |
| Failure Severity                | Warning                                                                                               |
| Message When Failed             | `{!record.Name fallback="This Account"}` has no Contacts. Add at least one Contact before continuing. |
| Message When Unable To Evaluate | Unable to count Contacts. Confirm access to Contact and AccountId.                                    |
| Fix Message                     | Add a Contact related to this Account.                                                                |
| Action Label                    | Review contacts                                                                                       |
| Action URL                      | `/lightning/r/Account/{!record.Id}/related/Contacts/view`                                             |
| Evaluation Order                | `10`                                                                                                  |
| Active                          | Unchecked until validation succeeds                                                                   |

`COUNT()` returns one aggregate result. A result greater than zero passes.

## Step 3: Validate and activate

1. Run the [configuration-validation Flow](../../build-checks/validate-configuration.md).
2. Correct every error and review every warning.
3. Set the Check and Check Set to **Active** only after validation succeeds.
4. Add **Record Health Check** to the Account Lightning record page and select the Check Set.
5. Assign **Record Health Check Card User** to the people testing the card.

## Step 4: Test the result

| Contacts visible to the user | Expected result                                                      |
| ---------------------------- | -------------------------------------------------------------------- |
| 0                            | Warning; Found is 0 and Expected is 0 with a Greater than comparison |
| 1                            | Pass                                                                 |
| More than 1                  | Pass                                                                 |

Repeat the tests with the sharing and field access intended users receive. This Check confirms a
visible Contact, not necessarily every Contact related to the Account.

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

| What you see                     | Check this first                                                          |
| -------------------------------- | ------------------------------------------------------------------------- |
| The count is lower than expected | Confirm Contact sharing and Read access for the running user              |
| Every Account fails              | Confirm the comparison is **Greater than**, not **Greater than or equal** |
| Unable to Check                  | Confirm access to Contact and AccountId and validate the SOQL             |
| Review contacts does not open    | Confirm the Account Contacts related-list API name in your org            |

## Technical reference

- [Query evaluation](../../reference/evaluation/query.md)
- [Query grammar, safety, and result handling](../../reference/evaluation/query.md)
- [Check fields and API names](../../reference/custom-metadata/check-fields.md)
- [Merge tokens](../../reference/merge-syntax/README.md)

## Related

- [Query examples](./README.md)
- [Next: Opportunity next steps](./opportunity-next-steps.md)
