# Flow actions

> [!NOTE]
> On this page, build a Flow that runs one Check Set or Check, branches on the returned Status, and
> keeps an unhealthy record separate from a Flow input, access, or transaction problem.

Use the packaged Flow actions to evaluate a Salesforce record without writing Apex. A Flow can run
one Check or a complete Check Set, then use a Decision element to respond to the result.

Start with the Check Set action unless your Flow intentionally needs only one specific Check.

For the complete New Flow, trigger, Action, Decision, debug, and rollback recipe, start with
[Run Record Health Check from Flow](../api/flow.md). Use this page as the complete input/output and
limits reference after that first build.

Salesforce can send a collection of Flow inputs to one action call. Each packaged action accepts at
most 200 inputs, using no more than ten distinct Check-or-Check-Set and Event Publication
combinations. If a Check Set contains more than 25 active Checks, Flow rejects the
entire request with `LIMIT` and `FRAMEWORK_MAX_CHECKS_EXCEEDED`; it does not run a
partial first page.

## Choose the right Flow action

| What does your Flow need? | Action | What you will receive |
| --- | --- | --- |
| The complete health assessment configured for a record | **Run Record Health Check Set** | Overall status, outcome counts, and every Check result as JSON |
| One specific health decision | **Run Record Health Check** | Check Status, Reason Code, and the complete result as JSON |

> [!TIP]
> A Check Set is the normal starting point because it keeps the Flow aligned with the same ordered
> Checks users see on the Lightning record page.

## Build your first Flow

This pattern runs a Check Set for one record and sends healthy and unhealthy results down different
Flow paths.

### Before you begin

- Create or install an active Check Set with at least one active Check.
- Assign the Flow's running user the **Record Health Check User** Permission Set, or equivalent
  access to the packaged Flow action and `RecordHealthCheck` Apex class.
- Copy the Check Set's exact **Qualified API Name** from Setup. An administrator-created Check Set
  in your org might be `Account_Readiness`. A Check Set included with the installed package might
  be `rhc__Example_Account_Profile_Readiness`. Do not add or remove `rhc__` yourself.
- Make the current record ID available to the Flow.

### Step 1: Add the action

1. In Flow Builder, add an **Action** element.
2. Search the **Record Health Check** category.
3. Select **Run Record Health Check Set**.
4. Set **Check Set Qualified API Name** to the exact `QualifiedApiName` returned by Salesforce.
5. Set **Record ID** to the ID of the record you want to evaluate.
6. Set **Event Publication** to `NONE`. The Flow already receives the result directly, so it does
   not need a Platform Event unless a separate process must also receive the result.

**Event Publication** is required. In Flow Builder, choose the value whose API form is `NONE`,
`ACTIONABLE`, or `ALL`; use `NONE` for this recipe. Do not parse Result JSON when Status, counts, and
Reason Code already provide the decision data.

### Step 2: Check whether the action succeeded

Add a Decision element immediately after the action:

- When **Success** is `false`, route by **Error Type** and record the safe **Error Message** for an
  administrator.
- When **Success** is `true`, continue to the Status Decision described next.

Do not read **Status** or the count outputs when **Success** is false because the action did not
produce a health result for that input.

### Step 3: Branch on Status

After the **Success = true** path, add another Decision element with explicit branches for the
returned **Status**.

| Decision outcome | Status | Recommended use |
| --- | --- | --- |
| Healthy | `PASS` | Continue the normal business process |
| Needs attention | `FAIL` | Guide the user or automation to review the unhealthy conditions |
| Not applicable | `SKIPPED` | Continue only when skipping is acceptable for this process |
| Could not determine | `UNABLE_TO_EVALUATE` | Route for configuration, access, required data, or Salesforce limit review |
| System problem | `ERROR` | Route for technical investigation |

Route `PASS`, `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, and `ERROR` separately.
`UNABLE_TO_EVALUATE` and `ERROR` need their own handling because neither confirms that the record is
healthy.

### Step 4: Connect the fault path

Connect the action's fault connector. Returned statuses and Flow faults are different:

| Result | How Flow receives it | How to handle it |
| --- | --- | --- |
| `PASS`, `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, or `ERROR` | Normal action output | Use the Decision element |
| Missing authorization, invalid input, too many inputs or groups, response too large, or another recoverable execution problem | Normal action output with **Success** false | Branch on **Error Type** and inspect **Error Message** |
| Unhandled platform or transaction failure | Flow fault | Use the fault connector |

### Step 5: Test the Flow

Test with records that produce each status your Flow handles. Also test using the same user context
and access model that the activated Flow will use.

| Test | What to confirm |
| --- | --- |
| Healthy record | The Flow follows the `PASS` path |
| Unhealthy record | The Flow follows the `FAIL` path |
| Check that does not apply | The Flow follows the `SKIPPED` path |
| User missing required record or field access | The Flow handles `UNABLE_TO_EVALUATE` or the documented fault path |
| Invalid API name | The action returns **Success** false, with a safe error type and message |

## Inputs and outputs

Both actions appear under the **Record Health Check** category in Flow Builder.

### Run Record Health Check Set

This action runs every active Check in one Check Set. Its Apex implementation is
`RecordHealthCheckRunSetFlowAction`.

#### Inputs

| Input | Required | What to provide |
| --- | --- | --- |
| **Check Set Qualified API Name** | Yes | Exact value copied from Setup, such as `Account_Readiness` for an administrator-created Check Set or `rhc__Example_Account_Profile_Readiness` for an installed example |
| **Record ID** | Yes | ID of the Salesforce record to evaluate |
| **Event Publication** | Yes | Use `NONE` for no Platform Events; `ACTIONABLE` for actionable Check Results plus a completed Set Run heartbeat; or `ALL` for every result, including `PASS` and `SKIPPED`. |

#### Outputs

| Output | What it tells you | Typical Flow use |
| --- | --- | --- |
| **Success** | Whether this input produced an evaluation response | Branch before reading Status or counts |
| **Error Type** | `AUTHORIZATION`, `VALIDATION`, `LIMIT`, or `EXECUTION` for a recoverable action problem | Route stable error categories without parsing text |
| **Error Message** | Safe explanation when Success is false | Log or display administrator guidance |
| **Status** | Overall Check Set result | Branch in a Decision element |
| **Passed Count** | Number of Checks that passed | Display or record a summary |
| **Failed Count** | Number of Checks that found an unhealthy condition | Decide whether review is required |
| **Skipped Count** | Number of Checks that did not apply or did not run | Identify intentionally omitted checks |
| **Unable Count** | Number of Checks that could not reach a reliable conclusion | Route for configuration or access review |
| **System Error Count** | Number of Checks with unexpected execution problems | Route for technical investigation |
| **Result JSON** | Complete serialized `RecordHealthCheckResponse` for the input record | Use only when later Flow elements or another integration need Check-level fields not exposed separately |
| **Contract Version** | Version carried by the returned response | Preserve and inspect it when a long-lived integration stores or forwards the response |

Flow actions always request the evaluation-only result mode. `Result JSON` therefore omits display
messages, formatted values, and actions, regardless of the running user's diagnostics permission.
An Apex caller that is building a user interface can explicitly request
`EVALUATION_WITH_DISPLAY`; Flow automation should branch on the stable evaluation fields above.

The overall Set status reflects the most serious contained result:

```text
ERROR → UNABLE_TO_EVALUATE → FAIL → PASS → SKIPPED
```

For example, one Check that is unable to evaluate makes the Set status `UNABLE_TO_EVALUATE`, even
when other Checks pass.

### Run Record Health Check

This action runs one Check. Its Apex implementation is `RecordHealthCheckRunCheckFlowAction`.

#### Inputs

| Input | Required | What to provide |
| --- | --- | --- |
| **Check Qualified API Name** | Yes | Exact value copied from Setup, such as `Billing_City_Is_Populated` for an administrator-created Check or `rhc__Example_Profile_Billing_Address` for an installed example |
| **Record ID** | Yes | ID of the Salesforce record to evaluate |
| **Event Publication** | Yes | Use `NONE` for no Platform Events; `ACTIONABLE` for actionable Check Results plus a completed Set Run heartbeat; or `ALL` for every result, including `PASS` and `SKIPPED`. |

#### Outputs

| Output | What it tells you | Typical Flow use |
| --- | --- | --- |
| **Success** | Whether this input produced an evaluation response | Branch before reading Status or Reason Code |
| **Error Type** | `AUTHORIZATION`, `VALIDATION`, `LIMIT`, or `EXECUTION` for a recoverable action problem | Route stable error categories without parsing text |
| **Error Message** | Safe explanation when Success is false | Log or display administrator guidance |
| **Status** | `PASS`, `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, or `ERROR` | Branch in a Decision element |
| **Reason Code** | Stable technical reason for a non-normal result | Route or log a known condition without reading message text |
| **Result JSON** | Complete serialized `RecordHealthCheckResultItem` | Use when later Flow elements or another integration need additional result fields |
| **Contract Version** | Version carried by the returned response | Preserve and inspect it when a long-lived integration stores or forwards the response |

The success value is `PASS`, not `SUCCESS`.

## Understand the returned statuses

| Status | Plain-language meaning | Is it a Flow fault? |
| --- | --- | --- |
| `PASS` | The configured health condition is satisfied | No |
| `FAIL` | Evaluation completed and found an unhealthy business condition | No |
| `SKIPPED` | The Check intentionally did not run because of applicability, dependency, or stop behavior | No |
| `UNABLE_TO_EVALUATE` | Configuration, access, required data, or a Salesforce limit prevented a reliable conclusion | No |
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

No-rows behavior is also context-relative: it means the Flow transaction's effective user-mode
scope contained no matching visible rows. The action does not issue an elevated comparison query to
discover rows hidden by sharing, restriction rules, or scoping rules.

## Limits and bulk use

Flow sends a collection of requests to the packaged action. The public limits apply to each
call.

| Limit | Maximum | What to do when you exceed it |
| --- | ---: | --- |
| Flow requests | 200 | Split the collection across transactions |
| Distinct Check-or-Check-Set and Event Publication combinations in one action call | 10 | Use fewer Check identities or publication choices in the call, or split the work across transactions. |
| Combined Result JSON returned by one action call | 2,000,000 characters | Use fewer records or a smaller Check Set per transaction. |

The 200-input cap does not guarantee that every collection of 200 will fit in one Salesforce
transaction. Each Check can use query, formula, Apex CPU-time, and memory limits. Use fewer records
or a smaller Check Set when realistic testing reaches one of those limits.

The action runs inside the current Flow transaction. If later Flow work causes Salesforce to roll
back that transaction, Platform Events configured to publish after commit are not delivered.

## Troubleshoot faults and unexpected results

| What you see | Likely cause | What to investigate |
| --- | --- | --- |
| `LIMIT` error for more than 200 requests | The request collection exceeds the public cap | Split the collection across transactions |
| `VALIDATION` or `EXECUTION` response | The supplied input is missing, malformed, or could not be evaluated | Inspect Error Message, then verify the exact `QualifiedApiName` and activation |
| Salesforce access fault or unable result | The running user lacks required record, object, field, or Apex access | Grant only the required access and retest in the same Flow context |
| Governor-limit fault | The transaction has insufficient remaining Salesforce limits | Reduce other work or run the evaluation in a separate transaction |
| `FAIL` returned as a normal output | The Check found an unhealthy business condition | Route the status with a Decision element; keep the fault connector for invalid requests and transaction failures |

Use the [reason-code reference](../reference/contracts/reason-codes.md) when the action returns a code you do
not recognize.

## Optional: Publish Platform Events

The Flow outputs are enough for most automation. Use Platform Events only when a separate Flow,
Apex trigger, or external integration must also receive the results after Salesforce successfully
commits the Flow transaction.

| **Event Publication** input | Platform Events from the Flow call |
| --- | --- |
| `NONE` | No Set Run or Check Result events. Use this when the current Flow handles the result itself. |
| `ACTIONABLE` | Check Result events only for `FAIL`, `UNABLE_TO_EVALUATE`, and `ERROR`, plus a completed Set Run heartbeat for every scanned record. |
| `ALL` | A Check Result event for every result, including `PASS` and `SKIPPED`, plus the Set Run event. |

**Event Publication** is required, so explicitly use `NONE` when no event is needed. For Flow calls,
this input controls result publication directly. The Check Set's **Publish User Run Event** and the
Check's **Publish User Result Event** settings control user-initiated Lightning-card runs; they do
not override the Flow input.

Flow-published events use `Source__c = FLOW`. Publication can fail and does not change the result
returned to Flow. A successful Flow action does not prove that the receiving Flow, Apex trigger, or
integration completed.

Record Health Check `ERROR` diagnostics are separate from these result events. The Check Set's
default-off `PublishErrorLogEvent__c` controls `Record_Health_Check_Log__e`; enable it only after
assigning **Record Health Check Error Log Publisher** to the running identity. Leaving it off does
not disable Salesforce debug logs.

Receiving automation must tolerate repeated or replayed delivery. Use `EventId__c` so the same event
does not create the same follow-up work twice. For the complete event fields and receiving-process
guidance, see [Lifecycle events](lifecycle-events.md).

## Response and event versions

Flow responses and lifecycle events carry independent contract-version fields because they are
different response shapes. Do not substitute one field for the other or infer either value from the
installed package release.

The version is useful when a Flow result is stored, serialized, or passed to another integration:
it identifies the shape of that response. It is separate from the Record Health Check product
version so compatible product updates do not require every Flow to be rebuilt.

New JSON fields can be added without changing the existing fields, so integrations should ignore
fields they do not recognize.

## Related

- [Integration overview](../integration/README.md)
- [Create your first Check](../installation/create-your-first-check.md)
- [Reason Codes](../reference/contracts/reason-codes.md)
- [Lifecycle events](lifecycle-events.md)
- [Apex API](../api/apex-api.md)
