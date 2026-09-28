# Check whether the billing address is ready for review

> [!NOTE]
> **Setup reference**: [Formula Check configuration](../../reference/evaluation/formula.md)

Create a Formula Check that passes only when Billing City, Billing State, and Billing Country are
all populated. When a value is missing, the card tells the user which address part needs attention.

## Why this pattern fits

All three values are fields on the Account that is already open, so **Verify with a formula** is
the simplest evaluation type. This is guidance rather than a Validation Rule because an incomplete
billing address should not block every unrelated Account update.

## Before you configure it

- Confirm the required address parts with the teams that use the address for tax or territory work.
- In orgs with State and Country/Territory Picklists, decide whether the formula should use
  `BillingStateCode` and `BillingCountryCode` instead of the display fields.
- Confirm that the people using the card can read all fields in the formula.
- Save new configuration inactive and validate it before activation.

## Step 1: Create or choose the Check Set

You can add this Check to an existing Account Check Set. To create one, open **Setup → Custom
Metadata Types → Record Health Check Set → Manage Records**, select **New**, and enter:

| Salesforce field             | Value                                                                 |
| ---------------------------- | --------------------------------------------------------------------- |
| Label                        | Account Data Quality                                                  |
| Record Health Check Set Name | `Account_Data_Quality`                                                |
| Object                       | `Account`                                                             |
| Card Title                   | Account Data Quality                                                  |
| Card Subtitle                | Confirm the billing address is complete for tax and territory review. |
| When Checks Run              | When the user clicks Run                                              |
| Summary Display              | Show below checks                                                     |
| Found/Expected Display       | Show on demand                                                        |
| Active                       | Unchecked until validation succeeds                                   |

## Step 2: Create the Check

Open **Setup → Custom Metadata Types → Record Health Check → Manage Records**, select **New**, and
enter:

| Salesforce field          | Value                                                                                                                                                    |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Label                     | Billing Address Is Complete                                                                                                                              |
| Record Health Check Name  | `Billing_Address_Is_Complete`                                                                                                                            |
| Check Set                 | Account Data Quality, or your existing Account Check Set                                                                                                 |
| Check Title               | Billing address is complete                                                                                                                              |
| Evaluation Type           | Verify with a formula                                                                                                                                    |
| Pass Condition            | `AND(NOT(ISBLANK(BillingCity)), NOT(ISBLANK(BillingState)), NOT(ISBLANK(BillingCountry)))`                                                               |
| Display: Found Formula    | `IF(ISBLANK(BillingCity), "City missing; ", "") & IF(ISBLANK(BillingState), "State missing; ", "") & IF(ISBLANK(BillingCountry), "Country missing", "")` |
| Display: Expected Formula | `"City, State, and Country populated"`                                                                                                                   |
| Formula Result Type       | Automatic                                                                                                                                                |
| Failure Severity          | Critical                                                                                                                                                 |
| Message When Failed       | `{!record.Name fallback="This Account"}` has an incomplete billing address.                                                                              |
| Fix Message               | Add every billing-address value named in Found, then run the Check again.                                                                                |
| Action Label              | Edit billing address                                                                                                                                     |
| Action URL                | `/lightning/r/Account/{!record.Id}/edit`                                                                                                                 |
| Evaluation Order          | `40`                                                                                                                                                     |
| Active                    | Unchecked until validation succeeds                                                                                                                      |

Add Street or Postal Code to both the pass formula and user guidance if your business requires
them. The Found formula is display guidance; only the Pass Condition decides the health result.

## Step 3: Validate and activate

1. Run the [configuration-validation Flow](../../build-checks/validate-configuration.md).
2. Correct every error and review every warning.
3. Set the Check and Check Set to **Active** only after validation succeeds.
4. Add **Record Health Check** to the Account Lightning record page and select the Check Set.
5. Assign **Record Health Check Card User** to the people testing the card.

## Step 4: Test the result

Use sandbox Accounts that are safe to edit.

| Billing City | Billing State | Billing Country | Expected result                         |
| ------------ | ------------- | --------------- | --------------------------------------- |
| Populated    | Populated     | Populated       | Pass                                    |
| Blank        | Populated     | Populated       | Critical; Found names City              |
| Populated    | Blank         | Blank           | Critical; Found names State and Country |

Repeat a failing case with the same field access intended users receive. An unreadable referenced
field must produce **Unable to Check**, not a guessed pass or failure.

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

| What you see                                      | Check this first                                                                        |
| ------------------------------------------------- | --------------------------------------------------------------------------------------- |
| A complete address fails                          | Confirm whether your org uses the Code fields for State and Country/Territory Picklists |
| Found does not name every missing part            | Copy the complete Display: Found Formula and verify its quotes                          |
| Unable to Check                                   | Confirm Read access to every address field in the formula                               |
| The Check Set is missing in Lightning App Builder | Confirm Object is `Account` and both records are active                                 |

## Technical reference

- [Formula evaluation](../../reference/evaluation/formula.md)
- [Check fields and API names](../../reference/custom-metadata/check-fields.md)
- [Check Set fields and API names](../../reference/custom-metadata/check-set-fields.md)
- [Formula functions and supported result types](../../reference/evaluation/formula.md)

## Related

- [Previous: Seller research readiness](./account-research-ready.md)
- [Formula examples](./README.md)
- [Next: Partner regional assignment](./partner-regional-assignment.md)
