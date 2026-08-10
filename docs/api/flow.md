# Run Record Health Check from Flow

> [!NOTE]
> Use this page when a Flow must run a Check or Check Set and make an immediate decision from the
> returned status.

## What the Flow actions do

Flow Builder provides two actions in the **Record Health Check** category:

| Action | Use it when |
| --- | --- |
| **Run Record Health Check Set** | Several related Checks should run for the record. |
| **Run Record Health Check** | Only one Check should run. |

Both actions use the same inputs and results as the Apex API. The action receives a Custom Metadata
**Qualified API Name**, a record ID, and an event-publication choice. It returns result fields that
the Flow can use in a Decision element.

### Example: Warn an account owner before escalation

A record-triggered Flow runs when an Account moves to **At Risk**. The Flow runs the **Account Data
Quality** Check Set for that Account. A Decision element sends `FAIL` to an owner-notification path
and lets `PASS` continue without a notification.

Use **Run Record Health Check Set** because the Flow needs several related Checks and must use the
result immediately. Leave event publication as `NONE` because this Flow already receives the result.

## Before you start

1. Activate and test the Check or Check Set.
2. Assign the Flow's running user the packaged **Record Health Check User** Permission Set. Use
   **Record Health Check Admin** only when that user also configures Checks or views diagnostics.
   Both include **Custom Permission label:** Record Health Check Run, **Custom Permission API
   name:** `rhc__Record_Health_Check_Run`, and the required Flow action access.
3. Confirm that the running user can read the target records and fields used by every selected
   Check.
4. In Setup, go to **Custom Metadata Types → Record Health Check Set → Manage Records** and copy the
   **Qualified API Name**. One created by an administrator can look like `My_Account_Checks`. One
   included with the installed package can look like `rhc__Account_Data_Quality`.
5. Decide whether another automation also needs Platform Events. Choose `NONE` when this Flow uses
   the returned result itself, `ACTIONABLE` to publish only attention-needed results, or `ALL` to
   publish `PASS` and every other status.

## Build the Flow

1. Open the Flow in Flow Builder.
2. Add an **Action** element.
3. In the **Record Health Check** category, select **Run Record Health Check Set** or **Run Record
   Health Check**.
4. For **Check Set Qualified API Name** or **Check Qualified API Name**, enter the exact value copied
   from Setup.
5. Set **Record ID** to the ID of the record the Flow should check.
6. Set **Event Publication** to `NONE` when this Flow uses the returned result. Select `ACTIONABLE`
   or `ALL` only when another Flow, Apex trigger, or integration is ready to receive Platform
   Events.
7. Add a Decision element after the action. Check **Success** first.
8. When **Success** is false, use **Error Type** and **Error Message** to handle the rejected input.
9. When **Success** is true, create paths for `PASS`, `FAIL`, `SKIPPED`,
   `UNABLE_TO_EVALUATE`, and `ERROR`.
10. Connect the action's fault path to the organization's Flow error handling for a Salesforce
    transaction failure that prevented the action from returning outputs.
11. Debug the Flow as the real running user, or a user with the same access, before activation.

See [Flow action inputs and outputs](../integration/flow-actions.md#inputs-and-outputs) for every
available field returned by each action.

## Read the action outputs

| Output or path | Meaning | Flow handling |
| --- | --- | --- |
| **Success** is false | The input was rejected or evaluation could not return a normal response. | Read **Error Type** and **Error Message**. Do not read Status. |
| `PASS` | The record met the Check condition. | Continue the normal Flow path. |
| `FAIL` | The record did not meet the business condition. This is not a Flow fault. | Start the approved follow-up path. |
| `SKIPPED` | The Check did not apply. | Continue or use a separate skipped path. |
| `UNABLE_TO_EVALUATE` | Access, configuration, or data prevented a reliable result. | Send the record for access, data, or configuration review. |
| `ERROR` | Record Health Check returned a system or evaluator problem as a result. | Send approved details to operational monitoring. |
| Fault connector | A Salesforce transaction failure prevented the action from returning outputs. | Use the organization's Flow fault handling. |

Do not send every non-`PASS` result to the fault path. `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, and
`ERROR` are returned outputs for the Decision element.

## Bulk and transaction limits

- One Flow action run accepts at most 200 input rows.
- One action run accepts at most 10 distinct selection/publication groups.
- All result data converted to JSON must total no more than 2,000,000 characters.
- Reuse the same Check Set and publication mode across rows when possible. Creating a different
  selection for each row can exceed the group limit.
- Split larger record lists across transactions or use Queueable or Batch Apex.

A group means Flow rows that use the same Check or Check Set and the same Event Publication value.
For example, 20 rows using `My_Account_Checks` and `NONE` count as one group, not 20 groups.

## Verify the Flow

Test at least one path for each status the selected Checks can return. Confirm that:

- `FAIL` follows a Decision path instead of the fault connector;
- an invalid input follows the **Success is false** path;
- a Salesforce transaction failure follows the fault connector;
- the running user sees only authorized display data;
- Platform Events appear only when `ACTIONABLE` or `ALL` was selected and a Flow, Apex trigger, or
  external integration is configured to receive them.

## Troubleshooting

| Symptom | Check first |
| --- | --- |
| The action is not available | The installed package version and the user's Apex class access |
| The action reports authorization failure | The running user's **Record Health Check Run** Custom Permission |
| A result is `UNABLE_TO_EVALUATE` | The reason code, record access, field access, and Check configuration |
| A collection is rejected before evaluation | The 200-row limit, 10-group limit, and 2,000,000-character JSON result limit |
| No Platform Event is received | The publication input, Check metadata event setting, and the Flow, Apex trigger, or integration that should receive it |

## Related

- [Flow actions: complete input and output reference](../integration/flow-actions.md)
- [API overview](README.md)
- [Apex API](apex-api.md)
- [Platform Event behavior](../integration/lifecycle-events.md)
- [Platform Event subscriptions](../platform-events/README.md)
