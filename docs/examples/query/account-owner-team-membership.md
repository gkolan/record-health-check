# Check whether the Account Owner is on the Account Team

> [!NOTE]
> **Setup reference**: [Query Check configuration](../../reference/evaluation/query.md)

Create a Query Check that reads Account Team Member User IDs and confirms that the Account Owner ID
appears in the list.

## Why this pattern fits

This is a list-membership question across related records. **Verify with a query** can compare the
Account's Owner ID with every visible Account Team Member User ID without custom Apex.

## Before you configure it

- Confirm Account Teams are enabled and your policy truly requires an explicit team row for the
  owner. Salesforce ownership alone may already provide the access your process needs.
- Confirm intended users can read Account Owner and Account Team Members.
- Decide which Account Team Role the owner should receive; this Check verifies membership only.
- Save new configuration inactive and validate it before activation.

## Step 1: Create or choose the Check Set

Use **Account Related Record Review**, or create an Account Check Set that runs on click and remains
inactive until validation succeeds.

## Step 2: Create the Check

Open **Setup → Custom Metadata Types → Record Health Check → Manage Records**, select **New**, and
enter:

| Salesforce field                    | Value                                                                             |
| ----------------------------------- | --------------------------------------------------------------------------------- |
| Label                               | Owner Is on Account Team                                                          |
| Record Health Check Name            | `Owner_Is_On_Account_Team`                                                        |
| Check Set                           | Account Related Record Review                                                     |
| Check Title                         | Account Owner is on the Account Team                                              |
| Evaluation Type                     | Verify with a query                                                               |
| Source Query                        | Leave blank                                                                       |
| Comparison Query                    | `SELECT UserId FROM AccountTeamMember WHERE AccountId = {!record.Id}`             |
| Comparison Query Field              | `UserId`                                                                          |
| Value to find in the list (formula) | `OwnerId`                                                                         |
| How To Read Query Results           | Compare as lists                                                                  |
| Comparison Operator                 | List contains any                                                                 |
| If Query Finds No Records           | Fail                                                                              |
| Max Query Rows                      | `200`                                                                             |
| Formula Result Type                 | Automatic                                                                         |
| Failure Severity                    | Warning                                                                           |
| Message When Failed                 | The owner of `{!record.Name fallback="this Account"}` is not on the Account Team. |
| Fix Message                         | Add the owner with the team role approved by your organization.                   |
| Action Label                        | Review account team                                                               |
| Action URL                          | `/lightning/r/Account/{!record.Id}/related/AccountTeamMembers/view`               |
| Evaluation Order                    | `110`                                                                             |
| Active                              | Unchecked until validation succeeds                                               |

In list-membership mode, the Comparison Query supplies the list and `OwnerId` supplies the value to
find. Leave Source Query blank.

## Step 3: Validate and activate

1. Run the [configuration-validation Flow](../../build-checks/validate-configuration.md).
2. Confirm Account Teams and the explicit-membership policy, then correct every validation error.
3. Set the Check and Check Set to **Active** only after validation succeeds.
4. Test from the Account page with **Record Health Check Card User**.

## Step 4: Test the result

| Visible Account Team                | Expected result |
| ----------------------------------- | --------------- |
| No rows                             | Warning         |
| Contains users other than the owner | Warning         |
| Contains the Account Owner          | Pass            |

Repeat as a user with the access intended card users receive. The comparison uses only team rows
visible to the running user.

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

| What you see                             | Check this first                                                       |
| ---------------------------------------- | ---------------------------------------------------------------------- |
| Account Team related list is unavailable | Confirm Account Teams are enabled                                      |
| Every Account fails                      | Confirm Source Query is blank and Comparison Query returns `UserId`    |
| The wrong team role passes               | Membership is all this Check tests; use another rule when role matters |
| Unable to Check                          | Confirm access to OwnerId, AccountTeamMember, AccountId, and UserId    |

## Technical reference

- [Query list comparison](../../reference/evaluation/query.md)
- [Check fields and API names](../../reference/custom-metadata/check-fields.md)
- [Merge tokens](../../reference/merge-syntax/README.md)

## Related

- [Previous: Placeholder email cleanup](./placeholder-contact-emails.md)
- [Query examples](./README.md)
- [Next: High-priority Case capacity](./high-priority-case-capacity.md)
