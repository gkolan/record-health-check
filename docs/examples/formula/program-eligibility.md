# Check whether an Account meets a program minimum

> [!NOTE]
> **Setup reference**: [Formula Check configuration](../../reference/evaluation/formula.md)

Create a Formula Check that compares Number of Employees with a confirmed minimum of 10. The card
shows the current employee count beside the required minimum so the result is easy to understand.

## Why this pattern fits

Number of Employees is on the Account, and the threshold is a value in the Check, so **Verify with
a formula** handles the comparison without SOQL or Apex. An Account below the minimum is still a
valid Account, so this guidance should not block unrelated saves with a Validation Rule.

## Before you configure it

- Confirm **Employees** under **Setup → Object Manager → Account → Fields & Relationships**.
- Confirm that Employees is the approved source and that 10 is the approved program minimum.
- Decide how blank Employees should behave. This example treats blank as zero.
- Confirm that intended users can read Employees.
- Save new configuration inactive and validate it before activation.

## Step 1: Create or choose the Check Set

You can add this Check to an existing Account Check Set. To create one, open **Setup → Custom
Metadata Types → Record Health Check Set → Manage Records**, select **New**, and enter:

| Salesforce field             | Value                                             |
| ---------------------------- | ------------------------------------------------- |
| Label                        | Account Data Quality                              |
| Record Health Check Set Name | `Account_Data_Quality`                            |
| Object                       | `Account`                                         |
| Card Title                   | Account Data Quality                              |
| Card Subtitle                | Confirm employee count meets the program minimum. |
| When Checks Run              | When the user clicks Run                          |
| Summary Display              | Show below checks                                 |
| Found/Expected Display       | Show for every check                              |
| Active                       | Unchecked until validation succeeds               |

## Step 2: Create the Check

Open **Setup → Custom Metadata Types → Record Health Check → Manage Records**, select **New**, and
enter:

| Salesforce field                | Value                                                                                                                                    |
| ------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| Label                           | Employee Count Meets Minimum                                                                                                             |
| Record Health Check Name        | `Employee_Count_Meets_Minimum`                                                                                                           |
| Check Set                       | Account Data Quality, or your existing Account Check Set                                                                                 |
| Check Title                     | Employee count meets minimum                                                                                                             |
| Evaluation Type                 | Verify with a formula                                                                                                                    |
| Pass Condition                  | `BLANKVALUE(NumberOfEmployees, 0) >= 10`                                                                                                 |
| Display: Found Formula          | `BLANKVALUE(NumberOfEmployees, 0)`                                                                                                       |
| Display: Expected Formula       | `10`                                                                                                                                     |
| Formula Result Type             | Automatic                                                                                                                                |
| Failure Severity                | Warning                                                                                                                                  |
| Message When Failed             | `{!record.Name fallback="This Account"}` is below the staffing minimum. Confirm the employee count before deciding whether it qualifies. |
| Message When Unable To Evaluate | Unable to compare employee count. Confirm access to Employees.                                                                           |
| Fix Message                     | Correct Employees if it is inaccurate. If it is below 10, the Account does not meet this requirement.                                    |
| Action Label                    | Edit employee count                                                                                                                      |
| Action URL                      | `/lightning/r/Account/{!record.Id}/edit`                                                                                                 |
| Evaluation Order                | `80`                                                                                                                                     |
| Active                          | Unchecked until validation succeeds                                                                                                      |

Change `10` in both the Pass Condition and Display: Expected Formula when your approved threshold
is different. Found and Expected explain the result; only the Pass Condition decides whether it
passes.

## Step 3: Validate and activate

1. Run the [configuration-validation Flow](../../build-checks/validate-configuration.md).
2. Correct every error and confirm that the threshold is approved.
3. Set the Check and Check Set to **Active** only after validation succeeds.
4. Add **Record Health Check** to the Account Lightning record page and select the Check Set.
5. Assign **Record Health Check Card User** to the people testing the card.

## Step 4: Test the result

| Employees | Expected result | Found | Expected |
| --------- | --------------- | ----- | -------- |
| Blank     | Warning         | 0     | 10       |
| 9         | Warning         | 9     | 10       |
| 10        | Pass            | 10    | 10       |
| 25        | Pass            | 25    | 10       |

Repeat a failing case with the same field access intended users receive. If Employees is unreadable,
the Check must show **Unable to Check** instead of treating the value as zero.

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

| What you see                                | Check this first                                               |
| ------------------------------------------- | -------------------------------------------------------------- |
| A blank value should be unknown, not zero   | Replace the formula with your approved blank-handling rule     |
| Found and Expected disagree with the result | Keep the display formulas synchronized with the Pass Condition |
| Unable to Check                             | Confirm Read access to Employees                               |
| A passing result has no individual row      | Review the Check Set's Passed Checks display setting           |

## Technical reference

- [Formula evaluation](../../reference/evaluation/formula.md)
- [Check fields and API names](../../reference/custom-metadata/check-fields.md)
- [Check Set fields and API names](../../reference/custom-metadata/check-set-fields.md)
- [Formula display values](../../reference/evaluation/formula.md)

## Related

- [Previous: Branch handoff](./branch-handoff.md)
- [Formula examples](./README.md)
