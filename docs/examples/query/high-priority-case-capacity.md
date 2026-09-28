# Check whether the high-priority Case backlog is within capacity

> [!NOTE]
> **Setup reference**: [Query Check configuration](../../reference/evaluation/query.md)

Create a Query Check that counts visible, open, high-priority Cases related to an Account. The
example passes when the count is three or fewer; replace three with your approved limit.

## Why this pattern fits

Cases are related records and the result is an aggregate count, so **Verify with a query** handles
the requirement without Apex. The card provides situational guidance without blocking Case saves.

## Before you configure it

- Confirm `High` is the stored Case Priority value in your org.
- Replace three with a capacity limit approved by the service team.
- Confirm intended users can read Case Account, Is Closed, and Priority.
- Save new configuration inactive and validate it before activation.

## Step 1: Create or choose the Check Set

Use **Account Related Record Review**, or create an Account Check Set that runs on click, shows
Found/Expected on demand, and remains inactive until validation succeeds.

## Step 2: Create the Check

Open **Setup → Custom Metadata Types → Record Health Check → Manage Records**, select **New**, and
enter:

| Salesforce field                | Value                                                                                                       |
| ------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| Label                           | High-Priority Case Limit                                                                                    |
| Record Health Check Name        | `High_Priority_Case_Limit`                                                                                  |
| Check Set                       | Account Related Record Review                                                                               |
| Check Title                     | High-priority Case backlog is within capacity                                                               |
| Evaluation Type                 | Verify with a query                                                                                         |
| Source Query                    | `SELECT COUNT() FROM Case WHERE AccountId = {!record.Id} AND IsClosed = false AND Priority = 'High'`        |
| Source Query Field              | Leave blank for `COUNT()`                                                                                   |
| How To Read Query Results       | One row or aggregate                                                                                        |
| Comparison Operator             | Less than or equal                                                                                          |
| Expected Value Comes From       | Fixed value                                                                                                 |
| Expected Value (Fixed)          | `3`; replace with the approved limit                                                                        |
| Max Query Rows                  | `200`                                                                                                       |
| Failure Severity                | Warning                                                                                                     |
| Message When Failed             | `{!record.Name fallback="This Account"}` has more open high-priority Cases than the normal review capacity. |
| Message When Unable To Evaluate | Unable to count high-priority Cases. Confirm access to the queried fields.                                  |
| Fix Message                     | Review ownership and response plans, then follow the capacity-escalation process.                           |
| Action Label                    | Review cases                                                                                                |
| Action URL                      | `/lightning/r/Account/{!record.Id}/related/Cases/view`                                                      |
| Evaluation Order                | `140`                                                                                                       |
| Active                          | Unchecked until validation succeeds                                                                         |

Bare `COUNT()` returns zero instead of no rows, so zero matching Cases passes rather than skips.

## Step 3: Validate and activate

1. Confirm the Priority value and approved limit.
2. Run the [configuration-validation Flow](../../build-checks/validate-configuration.md).
3. Correct every error, then activate the Check and Check Set.
4. Test from the Account page with **Record Health Check Card User**.

## Step 4: Test the result

| Visible open high-priority Cases      | Expected result                                   |
| ------------------------------------- | ------------------------------------------------- |
| 0                                     | Pass; Found is 0 and Expected is 3                |
| 3                                     | Pass                                              |
| 4                                     | Warning                                           |
| 4, with one Case hidden from the user | Pass for that user because the visible count is 3 |

If automation consumes results, enable **Publish User Result Event** only after the receiving Flow,
Apex trigger, or integration is tested. Events publish for an explicit Run or Rerun, not an
automatic page-load evaluation. See [lifecycle events](../../save-results/when-to-use-platform-events.md).

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

| What you see                        | Check this first                                                  |
| ----------------------------------- | ----------------------------------------------------------------- |
| Count is lower than expected        | Confirm Case sharing and the exact Priority and Is Closed filters |
| Three Cases fail                    | Confirm **Less than or equal**, not Less than                     |
| Source Query Field validation fails | Leave it blank for bare `COUNT()`                                 |
| Unable to Check                     | Confirm Case object and queried-field access                      |

## Technical reference

- [Query evaluation](../../reference/evaluation/query.md)
- [Platform Event delivery](../../save-results/when-to-use-platform-events.md)
- [Check fields and API names](../../reference/custom-metadata/check-fields.md)

## Related

- [Previous: Account Owner team membership](./account-owner-team-membership.md)
- [Query examples](./README.md)
- [Next: Opportunity Contact Role coverage](../compare-two-queries/opportunity-contact-role-coverage.md)
