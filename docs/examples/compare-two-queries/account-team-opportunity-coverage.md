# Check whether the Account Team covers open Opportunity owners

> [!NOTE]
> **Setup reference**: [Compare Two Queries configuration](../../reference/evaluation/compare-two-queries.md)

Create a Check that compares open Opportunity Owner IDs with Account Team Member User IDs. It
passes only when every visible open Opportunity owner appears on the visible Account Team.

## Why this pattern fits

This requirement compares two lists on related records. **Compare two queries** can verify complete
list coverage without custom Apex.

## Before you configure it

- Confirm Account Teams are enabled and your process requires Opportunity owners to be explicit
  Account Team members.
- Confirm intended users can read open Opportunities, their owners, and Account Team Members.
- Decide how empty lists should behave. This example fails when either required list is empty.
- Save new configuration inactive and validate it before activation.

## Step 1: Create or choose the Check Set

Use **Account Record Alignment**, or create an Account Check Set that runs on click and remains
inactive until validation succeeds.

## Step 2: Create the Check

Open **Setup → Custom Metadata Types → Record Health Check → Manage Records**, select **New**, and
enter:

| Salesforce field                | Value                                                                                                               |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| Label                           | Account Team Covers Opportunity Owners                                                                              |
| Record Health Check Name        | `Account_Team_Covers_Opportunity_Owners`                                                                            |
| Check Set                       | Account Record Alignment                                                                                            |
| Check Title                     | Account Team covers Opportunity owners                                                                              |
| Evaluation Type                 | Compare two queries                                                                                                 |
| Source Query                    | `SELECT OwnerId FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false`                               |
| Source Query Field              | `OwnerId`                                                                                                           |
| Comparison Query                | `SELECT UserId FROM AccountTeamMember WHERE AccountId = {!record.Id}`                                               |
| Comparison Query Field          | `UserId`                                                                                                            |
| How To Read Query Results       | Compare as lists                                                                                                    |
| Comparison Operator             | Lists contain all                                                                                                   |
| If Query Finds No Records       | Fail                                                                                                                |
| Failure Severity                | Warning                                                                                                             |
| Message When Failed             | On `{!record.Name fallback="this Account"}`, one or more open Opportunity owners are missing from the Account Team. |
| Message When Unable To Evaluate | Unable to compare Opportunity owners with Account Team Members.                                                     |
| Fix Message                     | Review missing owners and update only the records required by your handoff policy.                                  |
| Evaluation Order                | `10`                                                                                                                |
| Active                          | Unchecked until validation succeeds                                                                                 |

The Source list contains Opportunity Owner IDs. The Comparison list contains Account Team User IDs.
**Lists contain all** verifies that the Account Team contains every source value. Leave action
fields blank unless you have tested an org-specific Account Team destination.

## Step 3: Validate and activate

1. Run the [configuration-validation Flow](../../build-checks/validate-configuration.md).
2. Confirm the list direction and empty-list policy, then correct every error.
3. Activate the Check and Check Set only after validation succeeds.
4. Test from the Account page with **Record Health Check Card User**.

## Step 4: Test the result

| Open Opportunity owners | Account Team members | Expected result                                |
| ----------------------- | -------------------- | ---------------------------------------------- |
| None                    | Any                  | Warning under this example's empty-list policy |
| A                       | A                    | Pass                                           |
| A, B                    | A                    | Warning                                        |
| A, B                    | A, B, C              | Pass                                           |

Repeat as a restricted user. Both lists reflect the running user's visible records.

## What the user sees

The card compares the two visible query results using the configured list or numeric operator.

| Result detail | Meaning                                                                              |
| ------------- | ------------------------------------------------------------------------------------ |
| **`PASS`**    | The source and comparison results satisfy the configured operator.                   |
| **`FAIL`**    | The results do not satisfy the operator, and the card shows the configured guidance. |
| **`SKIPPED`** | The Check does not apply or a configured prerequisite did not pass.                  |
| **Found**     | The normalized result returned by the source query.                                  |
| **Expected**  | The normalized result returned by the comparison query.                              |

## If it does not work

| What you see                                    | Check this first                                                               |
| ----------------------------------------------- | ------------------------------------------------------------------------------ |
| The relationship passes in the wrong direction  | Source must be Opportunity `OwnerId`; Comparison must be Account Team `UserId` |
| All Accounts fail                               | Confirm Account Teams are enabled and team rows are visible                    |
| Accounts with no open Opportunities should skip | Change the no-row policy only after confirming the intended business behavior  |
| Unable to Check                                 | Confirm access to both objects, relationship fields, and user ID fields        |

## Technical reference

- [Compare two queries](../../reference/evaluation/compare-two-queries.md)
- [Query grammar and limits](../../reference/evaluation/bulk-query-grammar.md)
- [Check fields and API names](../../reference/custom-metadata/check-fields.md)

## Related

- [Previous: Product continuity](./open-pipeline-product-continuity.md)
- [Compare two queries examples](./README.md)
- [Next: Apex examples](../apex/README.md)
