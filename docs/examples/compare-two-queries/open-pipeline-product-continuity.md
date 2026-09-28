# Check whether open pipeline includes a previously purchased product

> [!NOTE]
> **Setup reference**: [Compare Two Queries configuration](../../reference/evaluation/compare-two-queries.md)

Create a Check that compares Product IDs on open Opportunity Products with Product IDs on
closed-won Opportunity Products. It passes when the two visible lists overlap.

## Why this pattern fits

The requirement compares two sets of related records. **Compare two queries** can collect each
Product list and test for overlap without Apex.

## Before you configure it

- Confirm that closed-won Opportunity Products are your approved purchase-history source. Many
  orgs use Assets, Orders, or another object instead; adapt the comparison query when they do.
- Confirm intended users can read Opportunities, Opportunity Products, and Product IDs.
- Decide that no rows should skip. In this example, missing open pipeline or purchase history does
  not create a warning.
- Save new configuration inactive and validate it before activation.

## Step 1: Create or choose the Check Set

Use **Account Record Alignment**, or create an Account Check Set that runs on click and remains
inactive until validation succeeds.

## Step 2: Create the Check

Open **Setup → Custom Metadata Types → Record Health Check → Manage Records**, select **New**, and
enter:

| Salesforce field          | Value                                                                                                                    |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| Label                     | Open Pipeline Uses Purchased Product                                                                                     |
| Record Health Check Name  | `Open_Pipeline_Uses_Purchased_Product`                                                                                   |
| Check Set                 | Account Record Alignment                                                                                                 |
| Check Title               | Open pipeline includes a previously purchased product                                                                    |
| Evaluation Type           | Compare two queries                                                                                                      |
| Source Query              | `SELECT Product2Id FROM OpportunityLineItem WHERE Opportunity.AccountId = {!record.Id} AND Opportunity.IsClosed = false` |
| Source Query Field        | `Product2Id`                                                                                                             |
| Comparison Query          | `SELECT Product2Id FROM OpportunityLineItem WHERE Opportunity.AccountId = {!record.Id} AND Opportunity.IsWon = true`     |
| Comparison Query Field    | `Product2Id`                                                                                                             |
| How To Read Query Results | Compare as lists                                                                                                         |
| Comparison Operator       | Lists overlap                                                                                                            |
| If Query Finds No Records | Skip                                                                                                                     |
| Failure Severity          | Info                                                                                                                     |
| Message When Failed       | On `{!record.Name fallback="this Account"}`, open pipeline products do not overlap products on closed-won Opportunities. |
| Fix Message               | Review product selection and correct it only when it does not match the intended sale.                                   |
| Action Label              | Review opportunities                                                                                                     |
| Action URL                | `/lightning/r/Account/{!record.Id}/related/Opportunities/view`                                                           |
| Evaluation Order          | `10`                                                                                                                     |
| Active                    | Unchecked until validation succeeds                                                                                      |

## Step 3: Validate and activate

1. Run the [configuration-validation Flow](../../build-checks/validate-configuration.md).
2. Correct every error and confirm the purchase-history model.
3. Activate the Check and Check Set only after validation succeeds.
4. Test from the Account page with **Record Health Check Card User**.

## Step 4: Test the result

| Open-pipeline Product IDs | Closed-won Product IDs | Expected result |
| ------------------------- | ---------------------- | --------------- |
| None                      | Any                    | Skipped         |
| Any                       | None                   | Skipped         |
| A                         | B                      | Info            |
| A, B                      | B, C                   | Pass            |

Repeat with intended sharing. Hidden Opportunity Products cannot contribute to either list.

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

| What you see                         | Check this first                                                                                             |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------ |
| Expected purchase history is missing | Confirm your org records purchases on closed-won Opportunity Products                                        |
| Unrelated products pass              | Confirm **Lists overlap** means any shared Product ID; use another operator if policy requires full coverage |
| The Check skips                      | Confirm both queries return at least one visible row                                                         |
| Unable to Check                      | Confirm relationship paths, object access, field access, and sharing                                         |

## Technical reference

- [Compare two queries](../../reference/evaluation/compare-two-queries.md)
- [Query grammar and limits](../../reference/evaluation/bulk-query-grammar.md)
- [Check fields and API names](../../reference/custom-metadata/check-fields.md)

## Related

- [Previous: Contact Role coverage](./opportunity-contact-role-coverage.md)
- [Compare two queries examples](./README.md)
- [Next: Account Team coverage](./account-team-opportunity-coverage.md)
