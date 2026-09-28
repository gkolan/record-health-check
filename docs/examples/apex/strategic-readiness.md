# Check strategic Account readiness with Apex

> [!NOTE]
> **Setup reference**: [Strategic readiness implementation](../../developer-guides/apex-check-examples/strategic-readiness.md)

Configure a custom Apex Check that combines Contact coverage, open pipeline, recent activity, and
billing-address completeness into a numeric readiness score.

## Why this pattern fits

The score combines Account fields and several related-record checks. Reviewed Apex keeps the
weights, queries, and result contract together and covered by tests.

## Before you configure it

- Have a Salesforce developer review, deploy, and test `AccountStrategicReadinessCheck` from the
  developer reference. This class is an integration example, not a packaged runtime class.
- Approve the score weights, minimum score, activity window, and blank-value behavior.
- Confirm intended users can read all Account and related-record data used by the score.
- Save configuration inactive until Apex tests and validation succeed.

## Step 1: Create or choose the Check Set

Use or create the **Account Apex Readiness** Check Set and leave it inactive.

## Step 2: Create the Check

Then create:

| Salesforce field         | Value                                                                         |
| ------------------------ | ----------------------------------------------------------------------------- |
| Label                    | Strategic Account Is Ready                                                    |
| Record Health Check Name | `Strategic_Account_Is_Ready`                                                  |
| Check Set                | Account Apex Readiness                                                        |
| Check Title              | Strategic Account is ready                                                    |
| Evaluation Type          | Verify with Apex                                                              |
| Apex Class               | `AccountStrategicReadinessCheck`                                              |
| Apex Parameters (JSON)   | `{"minScore": 80, "activityDaysBack": 60}`                                    |
| Failure Severity         | Critical                                                                      |
| Message When Failed      | This strategic Account's readiness score is below the approved minimum.       |
| Fix Message              | Review Contact coverage, open pipeline, recent activity, and billing address. |
| Evaluation Order         | `30`                                                                          |
| Active                   | Unchecked until validation succeeds                                           |

Leave action fields blank unless your org has one tested playbook or report that covers all four
readiness areas.

## Step 3: Validate and activate

1. Require a passing Apex test deployment.
2. Run the [configuration-validation Flow](../../build-checks/validate-configuration.md).
3. Activate only after both checks succeed.
4. Assign **Record Health Check Card User**.

## Step 4: Test the result

Test scores below, equal to, and above 80, including missing related data. Repeat as a restricted
user and confirm the score does not expose inaccessible data.

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

Confirm the class name, passing Apex tests, JSON parameter names and ranges, and access to every
record and field used in the score.

## Technical reference

See [Strategic readiness implementation](../../developer-guides/apex-check-examples/strategic-readiness.md)
for scoring rules, complete source, tests, context/result contracts, and customization.

## Related

- [Previous: Open Opportunity health](./open-opportunity-health.md)
- [Apex examples](./README.md)
