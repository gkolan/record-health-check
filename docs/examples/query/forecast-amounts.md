# Check proposal-stage Opportunity amounts

> [!NOTE]
> **Setup reference**: [Query Check configuration](../../reference/evaluation/query.md)

Create a Query Check that requires every visible proposal-stage Opportunity to meet a confirmed
qualification floor. This example uses 25,000; replace it with your approved amount.

## Why this pattern fits

The Account can have several related Opportunities and every returned Amount must pass. **Verify
with a query** supports the stage filter, row-by-row comparison, and no-record behavior.

## Before you configure it

- Confirm the stored Opportunity Stage value is exactly `Proposal/Price Quote` in your org.
- Replace 25,000 with a reviewed business threshold; do not treat the sample as policy.
- Confirm intended users can read Opportunity Stage and Amount and see the pipeline in scope.
- Save new configuration inactive and validate it before activation.

## Step 1: Create or choose the Check Set

Use **Account Related Record Review**, or create an Account Check Set that runs on click, shows
Found/Expected on demand, and stays inactive until validation succeeds.

## Step 2: Create the Check

Open **Setup → Custom Metadata Types → Record Health Check → Manage Records**, select **New**, and
enter:

| Salesforce field          | Value                                                                                                                              |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| Label                     | Proposal Deals Meet Qualification Floor                                                                                            |
| Record Health Check Name  | `Proposal_Deals_Meet_Qualification_Floor`                                                                                          |
| Check Set                 | Account Related Record Review                                                                                                      |
| Check Title               | Proposal-stage deals meet the qualification floor                                                                                  |
| Evaluation Type           | Verify with a query                                                                                                                |
| Source Query              | `SELECT Amount FROM Opportunity WHERE AccountId = {!record.Id} AND StageName = 'Proposal/Price Quote'`                             |
| Source Query Field        | `Amount`                                                                                                                           |
| How To Read Query Results | Every record passes                                                                                                                |
| Comparison Operator       | Greater than or equal                                                                                                              |
| Expected Value Comes From | Fixed value                                                                                                                        |
| Expected Value (Fixed)    | `25000`                                                                                                                            |
| If Query Finds No Records | Skip                                                                                                                               |
| If Field Value Is Empty   | Treat as not matching                                                                                                              |
| Max Query Rows            | `200`                                                                                                                              |
| Display: Found Text       | `Proposal-stage deal values: {!rhcResult.foundValue}`                                                                              |
| Display: Expected Text    | `Qualification floor per proposal-stage deal: {!rhcResult.expectedValue}`                                                          |
| Failure Severity          | Warning                                                                                                                            |
| Message When Failed       | On `{!record.Name fallback="this Account"}`, one or more proposal-stage Opportunities fall below the approved qualification floor. |
| Fix Message               | Validate scope, pricing, and fit. Do not inflate Amount merely to clear this Check.                                                |
| Action Label              | Review proposal-stage opportunities                                                                                                |
| Action URL                | `/lightning/r/Account/{!record.Id}/related/Opportunities/view`                                                                     |
| Evaluation Order          | `70`                                                                                                                               |
| Active                    | Unchecked until validation succeeds                                                                                                |

## Step 3: Validate and activate

1. Run the [configuration-validation Flow](../../build-checks/validate-configuration.md).
2. Correct every error and confirm the stage value and threshold.
3. Set the Check and Check Set to **Active** only after validation succeeds.
4. Test from the Account page with **Record Health Check Card User**.

## Step 4: Test the result

| Visible proposal-stage Amounts | Expected result |
| ------------------------------ | --------------- |
| None                           | Skipped         |
| 25,000                         | Pass            |
| 25,000 and 40,000              | Pass            |
| 24,999 and 40,000              | Warning         |
| Blank                          | Warning         |

Repeat with restricted Opportunity sharing. A hidden deal below the floor cannot be reported.

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

| What you see                     | Check this first                                                     |
| -------------------------------- | -------------------------------------------------------------------- |
| No Opportunities are returned    | Confirm the exact Stage value and record sharing                     |
| One undersized deal still passes | Confirm **Every record passes**, not Any record passes               |
| A value equal to 25,000 fails    | Confirm **Greater than or equal**                                    |
| Unable to Check                  | Confirm Opportunity, Stage, and Amount access and validate the query |

## Technical reference

- [Query evaluation](../../reference/evaluation/query.md)
- [Check fields and API names](../../reference/custom-metadata/check-fields.md)
- [Result display tokens](../../reference/merge-syntax/README.md)

## Related

- [Previous: Meaningful pipeline](./significant-opportunity.md)
- [Query examples](./README.md)
- [Next: Placeholder email cleanup](./placeholder-contact-emails.md)
