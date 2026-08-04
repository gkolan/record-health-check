# Flow actions

> [!NOTE]
> On this page, build a Flow that runs the right scope of health check, branches on its Framework Status, and keeps evaluation faults separate from ordinary readiness outcomes.

Use the packaged Flow actions to evaluate a Salesforce record without writing Apex. A Flow can run
one Rule or a complete Check Set, then use a Decision element to respond to the result.

Start with the Check Set action unless your Flow intentionally needs only one specific Rule.

Salesforce can bulk an invocable action into one transaction. Each packaged action accepts at most
200 request records per call (`RecordHealthCheck.MAX_FLOW_RECORDS_PER_CALL`); the Framework's
25-Rule cap still applies to the health-check work inside each request.

## Choose the right Flow action

| What does your Flow need? | Action | What you will receive |
| --- | --- | --- |
| The complete health assessment configured for a record | **Run Record Health Check Set** | Overall status, outcome counts, and every Rule result as JSON |
| One specific health decision | **Run Record Health Check Rule** | Rule Status, Reason Code, and the complete result as JSON |

> [!TIP]
> A Check Set is the normal starting point because it keeps the Flow aligned with the same ordered
> Rules users see on the Lightning record page.

## Build your first Flow

This pattern runs a Check Set for one record and sends healthy and unhealthy results down different
Flow paths.

### Runnable demo fixture

For a demonstration scratch org, deploy `force-app` followed by `integration-tests`, then run:

```bash
sf apex run \
  --file integration-tests/scripts/demo_apex_api.apex \
  --target-org my-scratch-org
sf apex run \
  --file integration-tests/scripts/demo_flow_actions.apex \
  --target-org my-scratch-org
```

The first script creates a reusable **Record Health Check API Demo** Account. The second invokes the
same two invocable methods Flow Builder calls and prints their Status, counts, Reason Code, and
contract version. To demonstrate visually in Flow Builder, create an autolaunched Flow with an
Account record-ID input, add **Run Record Health Check Set**, use
`Account_Data_Quality` as **Check Set API Name**, and branch on the returned Status. Add a second
Action using **Run Record Health Check Rule** and `Account_DQ_BillingCity` to show a predictable
`PASS` result.

### Before you begin

- Create or install an active Check Set with at least one active Rule.
- Assign the Flow's running user the **Record Health Check User** Permission Set, or equivalent
  access to the packaged Flow action and `RecordHealthCheck` Apex class.
- Query or copy the Check Set's exact **Qualified API Name**. It can be `Account_Readiness`,
  `rhc__Account_Readiness`, or another package's qualified value, depending on who owns the record.
- Make the current record ID available to the Flow.

### Step 1: Add the action

1. In Flow Builder, add an **Action** element.
2. Search the **Record Health Check** category.
3. Select **Run Record Health Check Set**.
4. Set **Check Set Qualified API Name** to the exact `QualifiedApiName` returned by Salesforce.
5. Set **Record ID** to the ID of the record you want to evaluate.

### Step 2: Add a Decision element

Add a Decision element after the action and create explicit branches for the returned **Status**.

| Decision outcome | Status | Recommended use |
| --- | --- | --- |
| Healthy | `PASS` | Continue the normal business process |
| Needs attention | `FAIL` | Guide the user or automation to review the unhealthy conditions |
| Not applicable | `SKIPPED` | Continue only when skipping is acceptable for this process |
| Could not determine | `UNABLE_TO_EVALUATE` | Route for configuration, access, dependency, or data review |
| System problem | `ERROR` | Route for technical investigation |

Route `PASS`, `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, and `ERROR` separately.
`UNABLE_TO_EVALUATE` and `ERROR` need their own handling because neither confirms that the record is
healthy.

### Step 3: Handle recoverable errors and connect the fault path

Connect the action's fault connector. Returned statuses and Flow faults are different:

| Result | How Flow receives it | How to handle it |
| --- | --- | --- |
| `PASS`, `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, or `ERROR` | Normal action output | Use the Decision element |
| Invalid request or exceeded request limit | Normal action output with **Success** false | Branch on **Error Type** and inspect **Error Message** |
| Unhandled platform or transaction failure | Flow fault | Use the fault connector |

### Step 4: Test the Flow

Test with records that produce each status your Flow handles. Also test using the same user context
and access model that the activated Flow will use.

| Test | What to confirm |
| --- | --- |
| Healthy record | The Flow follows the `PASS` path |
| Unhealthy record | The Flow follows the `FAIL` path |
| Rule that does not apply | The Flow follows the `SKIPPED` path |
| User missing required record or field access | The Flow handles `UNABLE_TO_EVALUATE` or the documented fault path |
| Invalid API name | The action returns **Success** false, with a safe error type and message |

## Inputs and outputs

Both actions appear under the **Record Health Check** category in Flow Builder.

### Run Record Health Check Set

This action runs every active Rule in one Check Set. Its Apex implementation is
`RecordHealthCheckRunSetFlowAction`.

#### Inputs

| Input | Required | What to provide |
| --- | --- | --- |
| **Check Set Qualified API Name** | Yes | Check Set `QualifiedApiName`, such as `rhc__Account_Readiness` in a namespaced install |
| **Record ID** | Yes | ID of the Salesforce record to evaluate |
| **Event Publication** | Yes | Choose `NONE`, `ACTIONABLE`, or `ALL`. Use `NONE` when the Flow must not publish lifecycle events. |

#### Outputs

| Output | What it tells you | Typical Flow use |
| --- | --- | --- |
| **Success** | Whether this input produced an evaluation response | Branch before reading Status or counts |
| **Error Type** | `VALIDATION`, `LIMIT`, or `EXECUTION` for a recoverable input failure | Route stable error categories without parsing text |
| **Error Message** | Safe explanation when Success is false | Log or display administrator guidance |
| **Status** | Overall Check Set result | Branch in a Decision element |
| **Passed Count** | Number of Rules that passed | Display or record a summary |
| **Failed Count** | Number of Rules that found an unhealthy condition | Decide whether review is required |
| **Skipped Count** | Number of Rules that did not apply or did not run | Identify intentionally omitted checks |
| **Unable Count** | Number of Rules that could not reach a reliable conclusion | Route for configuration or access review |
| **System Error Count** | Number of Rules with unexpected execution problems | Route for technical investigation |
| **Result JSON** | Complete serialized `RecordHealthCheckResponse` for the input record | Use only when downstream automation needs Rule-level fields not exposed separately |
| **Contract Version** | Version carried by the returned response | Preserve and inspect it when a long-lived integration stores or forwards the response |

The overall Set status reflects the most serious contained result:

```text
ERROR → UNABLE_TO_EVALUATE → FAIL → PASS → SKIPPED
```

For example, one Rule that is unable to evaluate makes the Set status `UNABLE_TO_EVALUATE`, even
when other Rules pass.

### Run Record Health Check Rule

This action runs one Rule. Its Apex implementation is `RecordHealthCheckRunRuleFlowAction`.

#### Inputs

| Input | Required | What to provide |
| --- | --- | --- |
| **Rule Qualified API Name** | Yes | Rule `QualifiedApiName`, such as `rhc__Billing_City_Is_Populated` in a namespaced install |
| **Record ID** | Yes | ID of the Salesforce record to evaluate |
| **Event Publication** | Yes | Choose `NONE`, `ACTIONABLE`, or `ALL`. Use `NONE` when the Flow must not publish lifecycle events. |

#### Outputs

| Output | What it tells you | Typical Flow use |
| --- | --- | --- |
| **Success** | Whether this input produced an evaluation response | Branch before reading Status or Reason Code |
| **Error Type** | `VALIDATION`, `LIMIT`, or `EXECUTION` for a recoverable input failure | Route stable error categories without parsing text |
| **Error Message** | Safe explanation when Success is false | Log or display administrator guidance |
| **Status** | `PASS`, `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, or `ERROR` | Branch in a Decision element |
| **Reason Code** | Stable technical reason for a non-normal result | Route or log a known condition without reading message text |
| **Result JSON** | Complete serialized `RecordHealthCheckResultItem` | Use when downstream automation needs additional result fields |
| **Contract Version** | Version carried by the returned response | Preserve and inspect it when a long-lived integration stores or forwards the response |

The success value is `PASS`, not `SUCCESS`.

## Understand the returned statuses

| Status | Plain-language meaning | Is it a Flow fault? |
| --- | --- | --- |
| `PASS` | The configured health condition is satisfied | No |
| `FAIL` | Evaluation completed and found an unhealthy business condition | No |
| `SKIPPED` | The Rule intentionally did not run because of applicability, dependency, or stop behavior | No |
| `UNABLE_TO_EVALUATE` | Configuration, access, dependency, or available data prevented a reliable conclusion | No |
| `ERROR` | An unexpected evaluator or platform problem occurred | No; route the returned status, then investigate |

Use **Reason Code** or the documented count outputs for automation. Branch automation on Status,
Reason Code, and Qualified API Name; administrators can change message text without changing the
result meaning.

## Security and running-user access

Evaluation uses the effective Salesforce access of the Flow's running user. The actions do not
elevate record, object, field, or sharing access.

| Flow context | What to test |
| --- | --- |
| User-run screen flow | Test with representative users and their actual record and field access |
| Record-triggered or other automated Flow | Confirm the configured execution context and effective access |
| Troubleshooting with diagnostics | Grant only the documented administrator permission and remove it when no longer needed |

A user-run screen Flow and system-context automation can produce different results for the same
record. Always test in the Flow's actual run context.

## Limits and bulk use

Flow sends a collection of requests to the packaged action. The public limits apply to each
call.

| Limit | Maximum | What to do when you exceed it |
| --- | ---: | --- |
| Flow requests | 200 | Split the collection across transactions |

The 200-request cap limits the incoming Flow collection. Every Rule can consume SOQL, formula
evaluation, Apex, and heap resources inside the same Flow transaction. Choose a smaller collection
or Check Set when the Flow transaction cannot support the expanded work.

The action runs inside the current Flow transaction. A later fault or rollback also rolls back work
associated with that transaction and prevents Publish After Commit events from being delivered.

## Troubleshoot faults and unexpected results

| What you see | Likely cause | What to investigate |
| --- | --- | --- |
| `LIMIT` error for more than 200 requests | The request collection exceeds the public cap | Split the collection across transactions |
| `VALIDATION` or `EXECUTION` response | The supplied input is missing, malformed, or could not be evaluated | Inspect Error Message, then verify the exact `QualifiedApiName` and activation |
| Salesforce access fault or unable result | The running user lacks required record, object, field, or Apex access | Grant only the required access and retest in the same Flow context |
| Governor-limit fault | The transaction has insufficient remaining Salesforce limits | Reduce other work or run the evaluation in a separate transaction |
| `FAIL` returned as a normal output | The Rule found an unhealthy business condition | Route the status with a Decision element; keep the fault connector for invalid requests and transaction failures |

Use the [reason-code reference](../reference/contracts/reason-codes.md) when the action returns a code you do
not recognize.

## Optional: Publish lifecycle events

The synchronous Flow result is enough for most decisions. Enable lifecycle events only when an
independent subscriber needs an after-commit notification.

| Action | Event | Enable with | Quantity |
| --- | --- | --- | --- |
| Check Set action | `Record_Health_Check_Set_Run__e` | Check Set **Publish User Run Event** | One per evaluated record |
| Check Set action | `Record_Health_Check_Rule_Result__e` | Each Rule's **Publish User Result Event** | One per enabled finalized Rule |
| Rule action | `Record_Health_Check_Rule_Result__e` | Rule **Publish User Result Event** | One per completed Rule request |

Flow-published events use `Source__c = FLOW`. Publication is off by default, best effort, and does
not change the synchronous result. A successful Flow action does not prove that an asynchronous
subscriber completed.

Framework `ERROR` diagnostics are separate from these lifecycle events. The Check Set's
default-on `PublishErrorLogEvent__c` controls `Record_Health_Check_Log__e`; uncheck it to opt out
without disabling Salesforce debug logs.

Subscribers must tolerate duplicate or replayed delivery. For the complete event bodies and subscriber
guidance, see [Lifecycle events](lifecycle-events.md).

## Schema compatibility

Flow responses and lifecycle events carry independent contract-version fields because they are
different response shapes. Do not substitute one field for the other or infer either value from the
installed package release.

The version is useful when a Flow result is stored, serialized, or passed to another integration:
it identifies the shape of that response. It is separate from the Record Health Check product
version so compatible product updates do not require every Flow to be rebuilt.

Additive JSON fields can appear without breaking the current contract, so integrations must ignore
fields they do not recognize. No Flow action is deprecated.

## Related

- [Integration overview](../integration/README.md)
- [Create your first Rule](../installation/03-create-your-first-rule.md)
- [Reason Codes](../reference/contracts/reason-codes.md)
- [Lifecycle events](lifecycle-events.md)
- [Apex API](../api/apex-api.md)
