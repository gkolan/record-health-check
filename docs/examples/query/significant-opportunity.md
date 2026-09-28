# Check whether an Account has meaningful open pipeline

> [!NOTE]
> **Setup reference**: [Query Check configuration](../../reference/evaluation/query.md)

Create a Query Check that passes when at least one visible open Opportunity has an Amount greater
than 10% of the Account's Annual Revenue. Accounts without positive Annual Revenue are skipped.

## Why this pattern fits

The Check compares related Opportunity records with a value calculated from the Account. **Verify
with a query** supports that record formula and can pass when any returned Opportunity qualifies.

## Before you configure it

- Confirm that Annual Revenue is maintained consistently and that 10% is an approved threshold.
- Confirm intended users can read Account Annual Revenue and Opportunity Amount.
- Decide whether pipeline with a blank Amount should be ignored or treated as a problem. This query
  excludes blank Amounts.
- Save new configuration inactive and validate it before activation.

## Step 1: Create or choose the Check Set

Use an Account Check Set such as **Account Related Record Review**. If you create it now, use Object
`Account`, run on click, show Found/Expected on demand, and leave **Active** unchecked until
validation succeeds.

## Step 2: Create the Check

Open **Setup → Custom Metadata Types → Record Health Check → Manage Records**, select **New**, and
enter:

| Salesforce field                | Value                                                                                                   |
| ------------------------------- | ------------------------------------------------------------------------------------------------------- |
| Label                           | Has Significant Open Opportunity                                                                        |
| Record Health Check Name        | `Has_Significant_Open_Opportunity`                                                                      |
| Check Set                       | Account Related Record Review                                                                           |
| Check Title                     | Has significant open Opportunity                                                                        |
| Evaluation Type                 | Verify with a query                                                                                     |
| Source Query                    | `SELECT Amount FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false AND Amount != null` |
| Source Query Field              | `Amount`                                                                                                |
| How To Read Query Results       | Any record passes                                                                                       |
| Comparison Operator             | Greater than                                                                                            |
| Expected Value Comes From       | Record formula                                                                                          |
| Expected Value (Formula)        | `AnnualRevenue * 0.1`                                                                                   |
| If Query Finds No Records       | Fail                                                                                                    |
| If Field Value Is Empty         | Treat as not matching                                                                                   |
| Max Query Rows                  | `200`                                                                                                   |
| Applies To                      | When a formula is true                                                                                  |
| Applies When (Formula)          | `BLANKVALUE(AnnualRevenue, 0) > 0`                                                                      |
| Failure Severity                | Info                                                                                                    |
| Message When Failed             | `{!record.Name fallback="This Account"}` has no open Opportunity greater than 10% of Annual Revenue.    |
| Message When Unable To Evaluate | Unable to compare Opportunity Amount with Annual Revenue. Confirm access to both fields.                |
| Fix Message                     | Review Annual Revenue and open Opportunity Amounts, then correct only inaccurate values.                |
| Evaluation Order                | `60`                                                                                                    |
| Active                          | Unchecked until validation succeeds                                                                     |

Leave Action Label and Action URL blank unless your org has one verified destination that can guide
users through both Account and Opportunity values.

## Step 3: Validate and activate

1. Run the [configuration-validation Flow](../../build-checks/validate-configuration.md).
2. Correct every error and confirm the business threshold.
3. Set the Check and Check Set to **Active** only after validation succeeds.
4. Add **Record Health Check** to the Account Lightning record page and select the Check Set.
5. Assign **Record Health Check Card User** to the people testing the card.

## Step 4: Test the result

For an Account with Annual Revenue of 1,000,000, the expected value is 100,000.

| Annual Revenue | Visible open Opportunity Amounts | Expected result                           |
| -------------- | -------------------------------- | ----------------------------------------- |
| Blank or 0     | Any                              | Skipped                                   |
| 1,000,000      | None                             | Info                                      |
| 1,000,000      | 75,000 and 100,000               | Info; comparison is strictly greater than |
| 1,000,000      | 75,000 and 125,000               | Pass                                      |

Repeat the tests with intended sharing. A hidden qualifying Opportunity cannot make the Check pass.

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

| What you see                           | Check this first                                                                           |
| -------------------------------------- | ------------------------------------------------------------------------------------------ |
| An Amount equal to the threshold fails | This example uses **Greater than**; choose Greater than or equal if policy allows equality |
| Expected is 0 or blank                 | Confirm Annual Revenue and the applicability formula                                       |
| A qualifying deal is not found         | Confirm Opportunity sharing, Is Closed, and nonblank Amount                                |
| Unable to Check                        | Confirm Read access to both objects and all queried or formula fields                      |

## Technical reference

- [Query evaluation](../../reference/evaluation/query.md)
- [Check fields and API names](../../reference/custom-metadata/check-fields.md)
- [Formula evaluation](../../reference/evaluation/formula.md)

## Related

- [Previous: Opportunity next steps](./opportunity-next-steps.md)
- [Query examples](./README.md)
- [Next: Forecast amounts](./forecast-amounts.md)
