# Check whether open Opportunities have Contact Roles

> [!NOTE]
> **Setup reference**: [Compare Two Queries configuration](../../reference/evaluation/compare-two-queries.md)

Create a Check that compares the number of open Opportunities with Contact Roles against the total
number of open Opportunities. Equal counts mean every open Opportunity is covered.

## Why this pattern fits

One aggregate query counts distinct covered Opportunities and another counts all open
Opportunities. **Compare two queries** can compare those values without Apex.

## Before you configure it

- Confirm your process requires at least one Contact Role on every open Opportunity.
- Confirm intended users can read Opportunity and Opportunity Contact Role records and fields.
- Decide whether Accounts with no open Opportunities should pass. Both counts are zero here, so
  they pass.
- Save new configuration inactive and validate it before activation.

## Step 1: Create or choose the Check Set

Use or create an Account Check Set named **Account Record Alignment**. Run it on click, show
Found/Expected on demand, and leave it inactive until validation succeeds.

## Step 2: Create the Check

Open **Setup → Custom Metadata Types → Record Health Check → Manage Records**, select **New**, and
enter:

| Salesforce field          | Value                                                                                                                                                       |
| ------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Label                     | Open Opportunities Have Contact Roles                                                                                                                       |
| Record Health Check Name  | `Open_Opportunities_Have_Contact_Roles`                                                                                                                     |
| Check Set                 | Account Record Alignment                                                                                                                                    |
| Check Title               | Open Opportunities have Contact Roles                                                                                                                       |
| Evaluation Type           | Compare two queries                                                                                                                                         |
| Source Query              | `SELECT COUNT_DISTINCT(OpportunityId) coveredCount FROM OpportunityContactRole WHERE Opportunity.AccountId = {!record.Id} AND Opportunity.IsClosed = false` |
| Source Query Field        | `coveredCount`                                                                                                                                              |
| Comparison Query          | `SELECT COUNT() FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false`                                                                       |
| How To Read Query Results | One row or aggregate                                                                                                                                        |
| Comparison Operator       | Equals                                                                                                                                                      |
| Failure Severity          | Info                                                                                                                                                        |
| Message When Failed       | `{!record.Name fallback="This Account"}` has one or more open Opportunities with no Contact Roles.                                                          |
| Fix Message               | Add the appropriate stakeholder Contact Roles before forecast review.                                                                                       |
| Action Label              | Review opportunities                                                                                                                                        |
| Action URL                | `/lightning/r/Account/{!record.Id}/related/Opportunities/view`                                                                                              |
| Evaluation Order          | `10`                                                                                                                                                        |
| Active                    | Unchecked until validation succeeds                                                                                                                         |

The Source result is **Found** and the Comparison result is **Expected**. The distinct count avoids
counting an Opportunity twice when it has several Contact Roles.

## Step 3: Validate and activate

1. Run the [configuration-validation Flow](../../build-checks/validate-configuration.md).
2. Correct every error and review the zero-opportunity behavior.
3. Activate the Check and Check Set only after validation succeeds.
4. Test from the Account page with **Record Health Check Card User**.

## Step 4: Test the result

| Open Opportunities | Opportunities with a Contact Role | Expected result |
| ------------------ | --------------------------------- | --------------- |
| 0                  | 0                                 | Pass            |
| 1                  | 0                                 | Info            |
| 1                  | 1                                 | Pass            |
| 3                  | 2                                 | Info            |
| 3                  | 3                                 | Pass            |

Repeat with intended sharing because both counts reflect records visible to the running user.

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

| What you see                          | Check this first                                                                            |
| ------------------------------------- | ------------------------------------------------------------------------------------------- |
| Found is larger than expected         | Confirm `COUNT_DISTINCT(OpportunityId)` and alias `coveredCount`                            |
| Accounts with no pipeline should skip | Add an approved applicability or prerequisite rule; this example intentionally passes 0 = 0 |
| Counts differ from a report           | Run the report with the same user and matching filters                                      |
| Unable to Check                       | Confirm access to both objects, relationship fields, and queried fields                     |

## Technical reference

- [Compare two queries](../../reference/evaluation/compare-two-queries.md)
- [Aggregate query grammar](../../reference/evaluation/bulk-query-grammar.md)
- [Check fields and API names](../../reference/custom-metadata/check-fields.md)

## Related

- [Compare two queries examples](./README.md)
- [Next: Product continuity](./open-pipeline-product-continuity.md)
