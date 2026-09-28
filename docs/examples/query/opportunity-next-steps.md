# Check whether open Opportunities have Next Steps

> [!NOTE]
> **Setup reference**: [Query Check configuration](../../reference/evaluation/query.md)

Create a Query Check that reviews every visible open Opportunity related to an Account. It passes
only when each returned Opportunity has a Next Step and skips Accounts with no open Opportunities.

## Why this pattern fits

The values are on related Opportunity records, so **Verify with a query** is the simplest option.
The Check gives pipeline guidance on the Account without forcing a Next Step during every
Opportunity save.

## Before you configure it

- Confirm **Next Step** under **Setup → Object Manager → Opportunity → Fields & Relationships**.
- Decide whether every open stage needs a Next Step. Add stage filters if early deals are exempt.
- Confirm that intended users can read Opportunity, Account, Is Closed, and Next Step.
- Save new configuration inactive and validate it before activation.

## Step 1: Create or choose the Check Set

Use the Account Related Record Review Check Set from the previous example, or create it from
**Setup → Custom Metadata Types → Record Health Check Set → Manage Records**:

| Salesforce field             | Value                                                  |
| ---------------------------- | ------------------------------------------------------ |
| Label                        | Account Related Record Review                          |
| Record Health Check Set Name | `Account_Related_Record_Review`                        |
| Object                       | `Account`                                              |
| Card Title                   | Account Related Record Review                          |
| Card Subtitle                | Confirm related records are ready for pipeline review. |
| When Checks Run              | When the user clicks Run                               |
| Summary Display              | Show below checks                                      |
| Found/Expected Display       | Show on demand                                         |
| Active                       | Unchecked until validation succeeds                    |

## Step 2: Create the Check

Open **Setup → Custom Metadata Types → Record Health Check → Manage Records**, select **New**, and
enter:

| Salesforce field                | Value                                                                                          |
| ------------------------------- | ---------------------------------------------------------------------------------------------- |
| Label                           | Open Opportunities Have Next Steps                                                             |
| Record Health Check Name        | `Open_Opportunities_Have_Next_Steps`                                                           |
| Check Set                       | Account Related Record Review                                                                  |
| Check Title                     | Open Opportunities are ready for review                                                        |
| Evaluation Type                 | Verify with a query                                                                            |
| Source Query                    | `SELECT NextStep FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false`         |
| Source Query Field              | `NextStep`                                                                                     |
| How To Read Query Results       | Every record passes                                                                            |
| Comparison Operator             | Is not empty                                                                                   |
| If Query Finds No Records       | Skip                                                                                           |
| If Field Value Is Empty         | Treat as not matching                                                                          |
| Max Query Rows                  | `200`                                                                                          |
| Failure Severity                | Warning                                                                                        |
| Message When Failed             | `{!record.Name fallback="This Account"}` has one or more open Opportunities with no Next Step. |
| Message When Unable To Evaluate | Unable to check open Opportunity Next Step. Confirm access to the queried fields.              |
| Fix Message                     | Enter Next Step on every open Opportunity that still needs one.                                |
| Action Label                    | Review open opportunities                                                                      |
| Action URL                      | `/lightning/r/Account/{!record.Id}/related/Opportunities/view`                                 |
| Evaluation Order                | `40`                                                                                           |
| Active                          | Unchecked until validation succeeds                                                            |

**Every record passes** evaluates each returned row. A blank Next Step is **Treat as not matching**,
so one blank value fails the Check. No returned rows produce Skipped.

## Step 3: Validate and activate

1. Run the [configuration-validation Flow](../../build-checks/validate-configuration.md).
2. Correct every error and review every warning.
3. Set the Check and Check Set to **Active** only after validation succeeds.
4. Add **Record Health Check** to the Account Lightning record page and select the Check Set.
5. Assign **Record Health Check Card User** to the people testing the card.

## Step 4: Test the result

| Visible open Opportunities | Next Step values | Expected result |
| -------------------------- | ---------------- | --------------- |
| None                       | Not applicable   | Skipped         |
| One                        | Populated        | Pass            |
| Two                        | Both populated   | Pass            |
| Two                        | One blank        | Warning         |

Repeat the failing case as a user who can see only part of the pipeline. The result must follow the
running user's record sharing and field access; it cannot report hidden Opportunities.

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

| What you see                     | Check this first                                                                 |
| -------------------------------- | -------------------------------------------------------------------------------- |
| A closed Opportunity is included | Copy the complete `IsClosed = false` filter                                      |
| A blank Next Step passes         | Confirm **Every record passes**, **Is not empty**, and **Treat as not matching** |
| The Account skips unexpectedly   | Confirm the user can see its open Opportunities                                  |
| Unable to Check                  | Confirm object access, field access, and SOQL field names                        |

## Technical reference

- [Query evaluation](../../reference/evaluation/query.md)
- [Check fields and API names](../../reference/custom-metadata/check-fields.md)
- [Merge tokens](../../reference/merge-syntax/README.md)
- [Query examples](./README.md)

## Related

- [Previous: Customer handoff](./customer-contact.md)
- [Next: Significant pipeline](./significant-opportunity.md)
