# Check whether a branch Account is ready for handoff

> [!NOTE]
> **Setup reference**: [Formula Check configuration](../../reference/evaluation/formula.md)

Create a Formula Check that applies to child Accounts and passes when the parent Account has a
Billing City. If headquarters information is missing, the card links to the parent Account.

## Why this pattern fits

An Account formula can follow the Parent Account relationship, so **Verify with a formula** can
review the headquarters field without SOQL or Apex. A Validation Rule on the branch would block a
save on the wrong record; this Check points the user to the parent record that needs attention.

## Before you configure it

- Confirm **Parent Account** and **Billing City** under **Setup → Object Manager → Account → Fields
  & Relationships**.
- Confirm that the people using the card can read the child Account, Parent Account, and parent
  Billing City. They also need edit access to use the action successfully.
- If headquarters is stored somewhere else, adapt the relationship instead of copying this formula.
- Save new configuration inactive and validate it before activation.

## Step 1: Create or choose the Check Set

You can add this Check to an existing Account Check Set. To create one, open **Setup → Custom
Metadata Types → Record Health Check Set → Manage Records**, select **New**, and enter:

| Salesforce field             | Value                                                      |
| ---------------------------- | ---------------------------------------------------------- |
| Label                        | Account Data Quality                                       |
| Record Health Check Set Name | `Account_Data_Quality`                                     |
| Object                       | `Account`                                                  |
| Card Title                   | Account Data Quality                                       |
| Card Subtitle                | Confirm the parent Account location before branch handoff. |
| When Checks Run              | When the user clicks Run                                   |
| Summary Display              | Show below checks                                          |
| Skipped Checks               | Show each skipped check                                    |
| Active                       | Unchecked until validation succeeds                        |

## Step 2: Create the Check

Open **Setup → Custom Metadata Types → Record Health Check → Manage Records**, select **New**, and
enter:

| Salesforce field                | Value                                                                                           |
| ------------------------------- | ----------------------------------------------------------------------------------------------- |
| Label                           | Parent Account Has Billing City                                                                 |
| Record Health Check Name        | `Parent_Account_Has_Billing_City`                                                               |
| Check Set                       | Account Data Quality, or your existing Account Check Set                                        |
| Check Title                     | Parent Account has Billing City                                                                 |
| Evaluation Type                 | Verify with a formula                                                                           |
| Pass Condition                  | `NOT(ISBLANK(Parent.BillingCity))`                                                              |
| Applies To                      | When a formula is true                                                                          |
| Applies When (Formula)          | `NOT(ISBLANK(ParentId))`                                                                        |
| Failure Severity                | Warning                                                                                         |
| Message When Failed             | The parent Account for `{!record.Name fallback="this branch Account"}` is missing Billing City. |
| Message When Unable To Evaluate | Unable to read the parent Account Billing City.                                                 |
| Fix Message                     | Open the parent Account and enter Billing City.                                                 |
| Action Label                    | Edit parent billing address                                                                     |
| Action URL                      | `/lightning/r/Account/{!record.ParentId}/edit`                                                  |
| Evaluation Order                | `70`                                                                                            |
| Active                          | Unchecked until validation succeeds                                                             |

The applicability formula skips top-level Accounts. The action URL uses the real Parent Account ID;
it does not grant access to that Account.

## Step 3: Validate and activate

1. Run the [configuration-validation Flow](../../build-checks/validate-configuration.md).
2. Correct every error and review every warning.
3. Set the Check and Check Set to **Active** only after validation succeeds.
4. Add **Record Health Check** to the Account Lightning record page and select the Check Set.
5. Assign **Record Health Check Card User** to the people testing the card.

## Step 4: Test the result

| Parent Account | Parent Billing City | Expected result                     |
| -------------- | ------------------- | ----------------------------------- |
| Populated      | Blank               | Warning with the parent edit action |
| Populated      | Populated           | Pass                                |
| Blank          | Not applicable      | Skipped                             |

Also test the child Account as a user who cannot read the parent Billing City. The Check must not
expose the hidden value. Selecting the action must still respect that user's edit permissions.

## What the user sees

The card evaluates the formula and compares its result with the configured expected value.

| Result detail | Meaning                                                                                         |
| ------------- | ----------------------------------------------------------------------------------------------- |
| **`PASS`**    | The formula result satisfies the configured comparison.                                         |
| **`FAIL`**    | The formula result does not satisfy the comparison, and the card shows the configured guidance. |
| **`SKIPPED`** | The Check does not apply or a configured prerequisite did not pass.                             |
| **Found**     | The evaluated formula result for the current record.                                            |
| **Expected**  | The configured fixed value or evaluated expected formula.                                       |

## If it does not work

| What you see                                  | Check this first                                                              |
| --------------------------------------------- | ----------------------------------------------------------------------------- |
| A top-level Account is not skipped            | Confirm Applies To and the `ParentId` applicability formula                   |
| A child Account cannot be evaluated           | Confirm access to Parent Account and parent Billing City                      |
| The action is missing                         | Confirm Parent Account is populated and copy the Action URL exactly           |
| The action opens the record but editing fails | Grant appropriate record and field access; the link does not grant permission |

## Technical reference

- [Formula evaluation](../../reference/evaluation/formula.md)
- [Applicability fields](../../reference/custom-metadata/check-fields.md)
- [Merge tokens](../../reference/merge-syntax/README.md)
- [Action links](../../build-checks/add-fix-link.md)
- [Check fields and API names](../../reference/custom-metadata/check-fields.md)

## Related

- [Previous: Partner regional assignment](./partner-regional-assignment.md)
- [Formula examples](./README.md)
- [Next: Program eligibility](./program-eligibility.md)
