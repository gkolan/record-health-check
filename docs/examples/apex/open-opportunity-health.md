# Check open Opportunity health with Apex

> [!NOTE]
> **Setup reference**: [Open Opportunity health implementation](../../developer-guides/apex-check-examples/open-opportunity-health.md)

Configure a custom Apex Check that fails only when an open Opportunity is stale, has no Next Step,
and has a Close Date outside the current quarter.

## Why this pattern fits

The rule combines several Opportunity conditions and activity logic. Reviewed Apex keeps that
logic testable while returning one clear card result.

## Before you configure it

- Have a Salesforce developer review, deploy, and test `AccountOpenOpportunityHealthCheck` from the
  developer reference. This class is an integration example, not a packaged runtime class.
- Agree on the stale-activity window; this example uses 30 days.
- Confirm intended users can read every Opportunity field used by the class.
- Save configuration inactive until the Apex tests and configuration validation succeed.

## Step 1: Create or choose the Check Set

Use or create the **Account Apex Readiness** Check Set and leave it inactive.

## Step 2: Create the Check

Then create:

| Salesforce field         | Value                                                                                                                                           |
| ------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| Label                    | Open Opportunities Are Healthy                                                                                                                  |
| Record Health Check Name | `Open_Opportunities_Are_Healthy`                                                                                                                |
| Check Set                | Account Apex Readiness                                                                                                                          |
| Check Title              | Open Opportunities are healthy                                                                                                                  |
| Evaluation Type          | Verify with Apex                                                                                                                                |
| Apex Class               | `AccountOpenOpportunityHealthCheck`                                                                                                             |
| Apex Parameters (JSON)   | `{"staleDays": 30}`                                                                                                                             |
| Failure Severity         | Critical                                                                                                                                        |
| Message When Failed      | `{!record.Name fallback="This Account"}` has one or more open Opportunities that are stale, missing Next Step, and outside the current quarter. |
| Fix Message              | Review activity, Next Step, and Close Date on each unhealthy Opportunity.                                                                       |
| Action Label             | Review open opportunities                                                                                                                       |
| Action URL               | `/lightning/r/Account/{!record.Id}/related/Opportunities/view`                                                                                  |
| Evaluation Order         | `20`                                                                                                                                            |
| Active                   | Unchecked until validation succeeds                                                                                                             |

## Step 3: Validate and activate

1. Require a passing Apex test deployment.
2. Run the [configuration-validation Flow](../../build-checks/validate-configuration.md).
3. Activate only after both checks succeed.
4. Assign **Record Health Check Card User**.

## Step 4: Test the result

Test a healthy deal and each rule individually, then one deal that meets all three failure
conditions. Repeat with intended record and field access.

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

Confirm the class name, deployed Apex test result, JSON parameter, and running user's access before
changing the business rule.

## Technical reference

See [Open Opportunity health implementation](../../developer-guides/apex-check-examples/open-opportunity-health.md)
for complete source, tests, context/result contracts, security behavior, and customization.

## Related

- [Previous: Recent activity](./recent-activity.md)
- [Apex examples](./README.md)
- [Next: Strategic readiness](./strategic-readiness.md)
