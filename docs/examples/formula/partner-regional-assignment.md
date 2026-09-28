# Check whether a Partner Account is ready for regional assignment

> [!NOTE]
> **Setup reference**: [Formula Check configuration](../../reference/evaluation/formula.md)

Create a Formula Check that applies only to Partner Accounts and passes when Billing Country is
populated. Other Account types are skipped because this requirement does not apply to them.

## Why this pattern fits

Account Type decides whether the Check applies, and Billing Country decides whether it passes.
Both fields are on the Account, so **Verify with a formula** handles the rule without SOQL or Apex.
Use a Check instead of a Validation Rule when a missing country should guide the assignment process
without blocking unrelated Account updates.

## Before you configure it

- Open **Setup → Object Manager → Account → Fields & Relationships → Type → Values** and confirm
  that `Partner` is the stored picklist value in your org. Account Type is not Record Type.
- If your org identifies partners by Record Type or a custom field, replace the applicability
  formula with your approved rule.
- Decide whether State and Country/Territory Picklists require `BillingCountryCode`.
- Confirm that intended users can read Account Type and Billing Country.
- Save new configuration inactive and validate it before activation.

## Step 1: Create or choose the Check Set

You can add this Check to an existing Account Check Set. To create one, open **Setup → Custom
Metadata Types → Record Health Check Set → Manage Records**, select **New**, and enter:

| Salesforce field             | Value                                            |
| ---------------------------- | ------------------------------------------------ |
| Label                        | Account Data Quality                             |
| Record Health Check Set Name | `Account_Data_Quality`                           |
| Object                       | `Account`                                        |
| Card Title                   | Account Data Quality                             |
| Card Subtitle                | Confirm Partner Accounts have a Billing Country. |
| When Checks Run              | When the user clicks Run                         |
| Passed Checks                | Show passed count only                           |
| Skipped Checks               | Show each skipped check                          |
| Found/Expected Display       | Show on demand                                   |
| Active                       | Unchecked until validation succeeds              |

## Step 2: Create the Check

Open **Setup → Custom Metadata Types → Record Health Check → Manage Records**, select **New**, and
enter:

| Salesforce field                | Value                                                                                     |
| ------------------------------- | ----------------------------------------------------------------------------------------- |
| Label                           | Partner Has Billing Country                                                               |
| Record Health Check Name        | `Partner_Has_Billing_Country`                                                             |
| Check Set                       | Account Data Quality, or your existing Account Check Set                                  |
| Check Title                     | Partner has Billing Country                                                               |
| Evaluation Type                 | Verify with a formula                                                                     |
| Pass Condition                  | `NOT(ISBLANK(BillingCountry))`                                                            |
| Applies To                      | When a formula is true                                                                    |
| Applies When (Formula)          | `ISPICKVAL(Type, "Partner")`                                                              |
| Failure Severity                | Critical                                                                                  |
| Message When Failed             | Partner Account `{!record.Name fallback="this record"}` must have Billing Country set.    |
| Message When Unable To Evaluate | Unable to check Partner billing requirements. Confirm access to Type and Billing Country. |
| Fix Message                     | Enter Billing Country on this Partner Account, then run the Check again.                  |
| Action Label                    | Edit billing country                                                                      |
| Action URL                      | `/lightning/r/Account/{!record.Id}/edit`                                                  |
| Evaluation Order                | `60`                                                                                      |
| Active                          | Unchecked until validation succeeds                                                       |

Leave the Found and Expected formulas blank. The failure message already names the missing value.
Leave Formula Result Type as **Automatic**.

## Step 3: Validate and activate

1. Run the [configuration-validation Flow](../../build-checks/validate-configuration.md).
2. Correct every error and confirm that `Partner` matches the picklist value in this org.
3. Set the Check and Check Set to **Active** only after validation succeeds.
4. Add **Record Health Check** to the Account Lightning record page and select the Check Set.
5. Assign **Record Health Check Card User** to the people testing the card.

## Step 4: Test the result

| Account Type          | Billing Country | Expected result                    |
| --------------------- | --------------- | ---------------------------------- |
| Partner               | Blank           | Critical                           |
| Partner               | Populated       | Pass; included in the passed count |
| Any non-Partner value | Any value       | Skipped                            |

Repeat the Partner tests with the field access intended users receive. Missing access to Type or
Billing Country must not expose the hidden value or produce a guessed result.

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

| What you see                         | Check this first                                                   |
| ------------------------------------ | ------------------------------------------------------------------ |
| A Partner Account is skipped         | Confirm the exact Type picklist value and the Applies When formula |
| A non-Partner Account runs the Check | Confirm Applies To is **When a formula is true**                   |
| Unable to Check                      | Confirm Read access to Type and Billing Country                    |
| A passing row is not visible         | This Check Set shows only the passed count by design               |

## Technical reference

- [Formula evaluation](../../reference/evaluation/formula.md)
- [Applicability fields](../../reference/custom-metadata/check-fields.md)
- [Check fields and API names](../../reference/custom-metadata/check-fields.md)
- [Check Set fields and API names](../../reference/custom-metadata/check-set-fields.md)

## Related

- [Previous: Billing address review](./billing-address-ready.md)
- [Formula examples](./README.md)
- [Next: Branch handoff](./branch-handoff.md)
