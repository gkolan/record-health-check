# Check whether an Account has recent activity

> [!NOTE]
> **Setup reference**: [Recent activity implementation](../../developer-guides/apex-check-examples/recent-activity.md)

Configure the packaged Apex Check that counts completed Tasks and past Events related to an
Account. This example requires two activities in the last 90 days.

## Why this pattern fits

The packaged Apex plugin handles Task and Event rules that would be awkward to maintain as one
record formula or query configuration.

## Before you configure it

- Agree on the activity window and minimum count. `daysBack` accepts 1–3,650 and
  `minimumActivities` accepts 1–1,000.
- Confirm intended users can read the Account and qualifying activities.
- Use the packaged `AccountHasRecentActivityCheck`; no custom Apex is required.
- Save the Check Set and Check inactive until validation succeeds.

## Step 1: Create or choose the Check Set

Create an Account Check Set named **Account Apex Readiness**. Set it to run on click and leave
**Active** unchecked.

## Step 2: Create the Check

Then create this Check:

| Salesforce field         | Value                                                                                        |
| ------------------------ | -------------------------------------------------------------------------------------------- |
| Label                    | Has Recent Activity                                                                          |
| Record Health Check Name | `Account_Has_Recent_Activity`                                                                |
| Check Set                | Account Apex Readiness                                                                       |
| Check Title              | Has recent activity                                                                          |
| Evaluation Type          | Verify with Apex                                                                             |
| Apex Class               | `AccountHasRecentActivityCheck`                                                              |
| Apex Parameters (JSON)   | `{"daysBack": 90, "minimumActivities": 2}`                                                   |
| Failure Severity         | Warning                                                                                      |
| Message When Failed      | `{!record.Name fallback="This Account"}` needs two completed activities in the last 90 days. |
| Fix Message              | Review the timeline and log only activity that actually occurred.                            |
| Action Label             | Log account activity                                                                         |
| Action URL               | `/lightning/o/Task/new?defaultFieldValues=WhatId={!record.Id}`                               |
| Evaluation Order         | `10`                                                                                         |
| Active                   | Unchecked until validation succeeds                                                          |

## Step 3: Validate and activate

1. Run the [configuration-validation Flow](../../build-checks/validate-configuration.md).
2. Activate the Check and Check Set only after validation succeeds.
3. Assign **Record Health Check Card User**.

## Step 4: Test the result

Test zero, one, and two qualifying activities. Repeat as a restricted user; hidden activities cannot
contribute to the count. Enter invalid JSON in a sandbox and confirm **Unable to Check**, then
restore valid parameters.

## What the user sees

The Apex class returns the outcome and display values after applicability and prerequisite checks.

| Result detail | Meaning                                                                                       |
| ------------- | --------------------------------------------------------------------------------------------- |
| **`PASS`**    | The class reports that the configured business rule is satisfied.                             |
| **`FAIL`**    | The class reports a normal business-rule failure, and the card shows the configured guidance. |
| **`SKIPPED`** | The Check does not apply or a prerequisite prevents the Apex class from running.              |
| **Found**     | The class-provided value that explains the observed record state.                             |
| **Expected**  | The class-provided target or comparison value.                                                |

## If it does not work

| What you see                         | Check this first                                                                 |
| ------------------------------------ | -------------------------------------------------------------------------------- |
| Apex class is not found              | Confirm the package version and copy the class name exactly                      |
| Invalid Apex parameters              | Use JSON integers and only `daysBack` and `minimumActivities`                    |
| Count is lower than expected         | Confirm activity dates, completion status, relationship, and running-user access |
| Log activity does not open correctly | Verify the action URL in your org before activation                              |

## Technical reference

See [Recent activity Apex implementation](../../developer-guides/apex-check-examples/recent-activity.md)
for the plugin contract, packaged source, tests, parameter validation, and customization guidance.

## Related

- [Apex examples](./README.md)
- [Next: Open Opportunity health](./open-opportunity-health.md)
