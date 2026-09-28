# Check whether an Account is ready for research

> [!NOTE]
> **Setup reference**: [Formula Check configuration](../../reference/evaluation/formula.md)

Create a Formula Check that passes when an Account has either a Phone or a Website. When both are
blank, the card asks the user to add a reliable starting point before outreach.

## Why this pattern fits

Phone and Website are fields on the Account that is already open. **Verify with a formula** can
review both fields without SOQL or Apex. This is guidance rather than a Validation Rule because a
missing research starting point should not block an unrelated Account update.

## Before you configure it

- Confirm Phone and Website under **Setup → Object Manager → Account → Fields & Relationships**.
- Decide whether either field is enough. This example uses either; use `AND` instead of `OR` if your
  requirement needs both.
- Confirm that the people using the card can read Account, Phone, and Website.
- Save new configuration inactive and validate it before activation.

## Step 1: Create or choose the Check Set

You can add this Check to an existing Account Check Set. To create a new one, open **Setup → Custom
Metadata Types → Record Health Check Set → Manage Records**, select **New**, and enter:

| Salesforce field             | Value                                                         |
| ---------------------------- | ------------------------------------------------------------- |
| Label                        | Account Data Quality                                          |
| Record Health Check Set Name | `Account_Data_Quality`                                        |
| Object                       | `Account`                                                     |
| Card Title                   | Account Data Quality                                          |
| Card Subtitle                | Confirm Phone or Website is available before seller research. |
| When Checks Run              | When the user clicks Run                                      |
| Summary Display              | Show below checks                                             |
| Found/Expected Display       | Show on demand                                                |
| Active                       | Unchecked until validation succeeds                           |

## Step 2: Create the Check

Open **Setup → Custom Metadata Types → Record Health Check → Manage Records**, select **New**, and
enter:

| Salesforce field         | Value                                                                                     |
| ------------------------ | ----------------------------------------------------------------------------------------- |
| Label                    | Account Is Ready for Seller Research                                                      |
| Record Health Check Name | `Account_Ready_For_Seller_Research`                                                       |
| Check Set                | Account Data Quality, or your existing Account Check Set                                  |
| Check Title              | Ready for seller research                                                                 |
| Evaluation Type          | Verify with a formula                                                                     |
| Pass Condition           | `OR(NOT(ISBLANK(Phone)), NOT(ISBLANK(Website)))`                                          |
| Failure Severity         | Warning                                                                                   |
| Message When Failed      | `{!record.Name fallback="This Account"}` needs a Phone or Website before seller research. |
| Fix Message              | Add a verified business phone number or website, then run the Check again.                |
| Action Label             | Edit account                                                                              |
| Action URL               | `/lightning/r/Account/{!record.Id}/edit`                                                  |
| Evaluation Order         | `10`                                                                                      |
| Active                   | Unchecked until validation succeeds                                                       |

The formula checks only whether a value is present. A placeholder website still passes, so use a
different pattern when validity matters more than presence.

## Step 3: Validate and activate

1. Run the [configuration-validation Flow](../../build-checks/validate-configuration.md).
2. Correct every error and review every warning.
3. Set the Check and Check Set to **Active** only after validation succeeds.
4. Add **Record Health Check** to the Account Lightning record page and select the Check Set.
5. Assign **Record Health Check Card User** to the people testing the card.

## Step 4: Test the result

Use sandbox Accounts that are safe to edit.

| Phone     | Website   | Expected result                              |
| --------- | --------- | -------------------------------------------- |
| Blank     | Blank     | Warning with the research-readiness guidance |
| Populated | Blank     | Pass                                         |
| Blank     | Populated | Pass                                         |
| Populated | Populated | Pass                                         |

Run the same tests with the field access used by the people who will use the card. If Phone or
Website is not readable, the Check must not guess a result.

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

| What you see                                      | Check this first                                                                       |
| ------------------------------------------------- | -------------------------------------------------------------------------------------- |
| The Check Set is missing in Lightning App Builder | Confirm Object is `Account` and the Check Set is active                                |
| The card has no Check row                         | Confirm the Check is active and belongs to the selected Check Set                      |
| Unable to Check                                   | Confirm Read access to Account, Phone, and Website                                     |
| A placeholder website passes                      | Presence is all this formula tests; use Query or reviewed Apex for stronger validation |
| Edit account does not open the same record        | Copy the Action URL exactly and keep `{!record.Id}` in the path                        |

## Technical reference

- [Formula evaluation](../../reference/evaluation/formula.md)
- [Check fields and API names](../../reference/custom-metadata/check-fields.md)
- [Check Set fields and API names](../../reference/custom-metadata/check-set-fields.md)
- [Merge tokens](../../reference/merge-syntax/README.md)
- [Action links](../../build-checks/add-fix-link.md)

## Related

- [Formula examples](./README.md)
- [Create your first Check](../../step-by-step-guide/create-your-first-check.md)
- [Next: Billing address review](./billing-address-ready.md)
