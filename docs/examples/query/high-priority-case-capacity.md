# High-priority Case Backlog Is Within Review Capacity

> [!NOTE]
> On this page, count open high-priority Cases, compare the count with your team's agreed limit, and optionally publish the result for a Flow, Apex trigger, or integration.
>
> **Setup reference**
>
> Use the [Query reference](../../reference/evaluation/query.md) for the complete setup fields and behavior.

## Scenario

A service manager is preparing for the daily review of an important customer Account.

- Several open high-priority Cases can compete for the same service team's attention.
- The team has agreed that more than three requires a workload review and an explicit response plan.
- The manager currently counts the qualifying Cases from the related list before deciding whether to escalate capacity.

> [!TIP]
> **Why use Record Health Check**
>
> Record Health Check places the current backlog count beside the approved limit, so the manager can start the capacity discussion without counting Cases manually.

## What you will learn

| Skill | How this example teaches it |
| --- | --- |
| Count a filtered backlog | SOQL counts only high-priority open Cases. |
| Enforce a maximum | The Check passes while the count stays within team capacity. |
| Make operational limits visible | **Found** shows the backlog and **Expected** shows the approved ceiling. |
| Share results with automation | An optional Platform Event can tell a Flow, Apex trigger, or integration how the Check finished. |

## Why use Verify with a query

| Evaluation Type | Why it fits |
| --- | --- |
| **Verify with a query** | Best fit. `COUNT()` returns the number of visible open high-priority Cases, and **Less than or equal** compares that count with the approved limit. |
| **Verify with a formula** | An Account formula cannot count related Cases unless a suitable roll-up field already exists. |
| **Compare two queries** | Would require a second query even though the approved limit is a fixed value. |
| **Verify with Apex** | Would add code for a related Case count and number comparison already supported by Verify with a query. |

## Why not use a Validation Rule or Report

- **Validation Rule:** A Validation Rule on Account cannot count its related Cases. Blocking a Case save would also prevent agents from recording the service work that created the capacity concern.

- **Report:** A report is useful for service-wide workload planning. It does not place this Account's count and limit beside the other review checks.

## Before you start

- Install Record Health Check.
- Assign **Record Health Check Admin** to the administrator creating the Check Set and Check.
- Confirm the Case Priority value used for urgent work. This example uses the standard value `High`.
- Confirm the maximum number of matching Cases your service team considers manageable. This
  example uses `3` only to demonstrate the setup.
- Confirm that intended users can read Case, `AccountId`, `IsClosed`, and `Priority` and can see the
  Cases included in the service review.

## Read the query and prepare test data

`IsClosed = false` uses Salesforce's closed-status classification rather than naming one Status.
The Priority comparison uses the stored API value `High`; confirm it under **Setup → Object Manager
→ Case → Fields & Relationships → Priority → Values**. **Less than or equal** expected `3` means
three or fewer open High-priority Cases pass and four fail.

Create four open High-priority Cases related to one sandbox Account to prove the failing case, then
close or lower the priority of one to prove the pass. Do not use this example unchanged if Cases
are unavailable, your org uses custom priority values, or the policy counts only queue-owned Cases.

Add the card to the Account Lightning page, activate the intended assignment, and test as a user
with **Record Health Check Card User**. The optional Platform Event section is for an automation owner;
card-only administrators can skip it.

## Step 1: Create the Check Set

In **Setup → Custom Metadata Types → Record Health Check Set → Manage Records**, select **New** and
create this Check Set:

| Setup field | Value |
| --- | --- |
| **Label** | Account Related Record Review |
| **Record Health Check Set Name** | `Account_Related_Record_Review` |
| **Object** | `Account` |
| **Card Title** | Related Record Review |
| **Card Subtitle** | Confirm open high-priority Cases stay within capacity. |
| **When Checks Run** | When the user clicks Run |
| **Summary Display** | Below Checks |
| **Reveal Mode** | One by one |
| **Passed Checks** | Show each check |
| **Skipped Checks** | Show each check |
| **Found/Expected Display** | On demand |
| **Stop after a system error** | Unchecked |
| **Show Diagnostics** | Unchecked; enable temporarily only for authorized troubleshooting |
| **Publish User Run Event** | Unchecked unless a Flow, Apex trigger, or integration needs one summary after the Check Set finishes |
| **Active** | Checked |

## Step 2: Configure the Check

In **Setup → Custom Metadata Types → Record Health Check → Manage Records**, create the Check:

| Setup field | API name | Value |
| --- | --- | --- |
| **Developer Name** | [`DeveloperName`](../../reference/custom-metadata/check-fields.md#developer-name-developername) | `High_Priority_Case_Limit` |
| **Label** | [`MasterLabel`](../../reference/custom-metadata/check-fields.md#label-masterlabel) | High-Priority Case Limit |
| **Check Set** | [`Record_Health_Check_Set__c`](../../reference/custom-metadata/check-fields.md#check-set-record_health_check_set__c) | `Account_Related_Record_Review` |
| **Check Title** | [`CheckTitle__c`](../../reference/custom-metadata/check-fields.md#check-title-checktitle__c) | High-Priority Case Backlog Is Within Capacity |
| **Evaluation Type** | [`EvaluationType__c`](../../reference/custom-metadata/check-fields.md#evaluation-type-evaluationtype__c) | Verify with a query |
| **Source Query** | [`SourceQuery__c`](../../reference/custom-metadata/check-fields.md#source-query-sourcequery__c) | `SELECT COUNT() FROM Case WHERE AccountId = {!record.Id} AND IsClosed = false AND Priority = 'High'` |
| **Source Query Field** | [`SourceQueryField__c`](../../reference/custom-metadata/check-fields.md#source-query-field-sourcequeryfield__c) | Leave blank for `COUNT()` |
| **How To Read Query Results** | [`QueryResultHandling__c`](../../reference/custom-metadata/check-fields.md#how-to-read-query-results-queryresulthandling__c) | One row or aggregate |
| **Comparison Operator** | [`ComparisonOperator__c`](../../reference/custom-metadata/check-fields.md#comparison-operator-comparisonoperator__c) | Less than or equal |
| **Expected Value Comes From** | [`ExpectedValueSource__c`](../../reference/custom-metadata/check-fields.md#expected-value-comes-from-expectedvaluesource__c) | Fixed value |
| **Expected Value (Fixed)** | [`ExpectedFixedValue__c`](../../reference/custom-metadata/check-fields.md#expected-value-fixed-expectedfixedvalue__c) | `3`; replace this example with your team's agreed limit |
| **Max Query Rows (1-2000)** | [`MaxQueryRows__c`](../../reference/custom-metadata/check-fields.md#max-query-rows-1-2000-maxqueryrows__c) | `200` (default; `COUNT()` returns one result) |

Confirm the `High` Priority API value and replace `3` with the limit approved by your service team.

## Optional configuration

| Setup field | API name | Value |
| --- | --- | --- |
| **Failure Severity** | [`FailureSeverity__c`](../../reference/custom-metadata/check-fields.md#failure-severity-failureseverity__c) | Warning |
| **Message When Failed** | [`FailureMessage__c`](../../reference/custom-metadata/check-fields.md#message-when-failed-failuremessage__c) | `{!record.Name fallback="this record"}` has more open high-priority Cases than the service team can review through its normal process. |
| **Check Description** | [`CheckDescription__c`](../../reference/custom-metadata/check-fields.md#check-description-checkdescription__c) | Compares the visible open high-priority Case count with the approved review limit. |
| **Category** | [`Category__c`](../../reference/custom-metadata/check-fields.md#category-category__c) | Readiness |
| **Message When Unable To Evaluate** | [`UnableToEvaluateMessage__c`](../../reference/custom-metadata/check-fields.md#message-when-unable-to-evaluate-unabletoevaluatemessage__c) | Unable to count high-priority Cases. Confirm access to Case, AccountId, IsClosed, and Priority. |
| **Applies To** | [`ApplicabilityMode__c`](../../reference/custom-metadata/check-fields.md#applies-to-applicabilitymode__c) | All records |
| **Prerequisite Check** | [`PrerequisiteCheck__c`](../../reference/custom-metadata/check-fields.md#prerequisite-check-prerequisitecheck__c) | Leave blank |
| **Fix Message** | [`FixMessage__c`](../../reference/custom-metadata/check-fields.md#fix-message-fixmessage__c) | Review ownership and response plans for the open high-priority Cases, then follow your capacity-escalation process. |
| **Action Label** | [`ActionLabel__c`](../../reference/custom-metadata/check-fields.md#action-label-actionlabel__c) | `Review cases` |
| **Action URL** | [`ActionUrl__c`](../../reference/custom-metadata/check-fields.md#action-url-actionurl__c) | `/lightning/r/Account/{!record.Id}/related/Cases/view` |
| **Evaluation Order** | [`EvaluationOrder__c`](../../reference/custom-metadata/check-fields.md#evaluation-order-evaluationorder__c) | `140` |
| **Active** | [`IsActive__c`](../../reference/custom-metadata/check-fields.md#active-isactive__c) | Checked only after confirming the Priority value and approved capacity limit |
| **Publish User Result Event** | [`PublishUserResultEvent__c`](../../reference/custom-metadata/check-fields.md#publish-user-result-event-publishuserresultevent__c) | Unchecked unless a Flow, Apex trigger, or integration needs the result from this Check |

Source Query Field stays blank because bare `COUNT()` produces the value directly. Comparison
Query, row-empty, list, Formula-result, and Apex fields do not apply. The count is `0` when no Case
matches, so the Check passes rather than skipping.

## What the user sees

The card turns the aggregate count and upper limit into these user-facing values:

| Health result or card value | What the user sees |
| --- | --- |
| **`PASS`** | Zero through three visible open high-priority Cases is within the example limit. |
| **`FAIL`** | Four or more visible open high-priority Cases exceeds the limit and shows Needs attention with Warning severity. |
| **`SKIPPED`** | Bare `COUNT()` returns zero rather than no rows, and this configuration has no applicability check or prerequisite, so it does not produce `SKIPPED`. |
| **Found** | When the user reveals Found and Expected, Found shows the current visible high-priority Case count. |
| **Expected** | When the user reveals Found and Expected, Expected shows the maximum allowed count: `3`. |

## Optional: Send the result to automation

Leave both event settings unchecked when users only need to see results on the Account. This avoids
publishing Platform Events that nothing uses.

Use **Publish User Result Event** when a Flow, Apex trigger, or integration needs the result from this
individual Check. Use **Publish User Run Event** when it needs one summary after the entire Check Set
finishes. A user must select **Run** or **Rerun** for these settings to publish events; a Check that
runs automatically when the page opens does not publish them.

Creating an event is only the sending side. Before enabling either setting, build and test the Flow,
Apex trigger, or integration that receives the event, including how it handles a replayed or repeated
event. See [Lifecycle events](../../save-results/when-to-use-platform-events.md) for the event fields and setup
choices.

## Security and access

Record Health Check counts open high-priority Cases related to the Account with the running user's Salesforce access.

- Hidden Cases are not counted. A service manager with broader Case access may see a higher backlog than another user.

- Missing Read access to Case, `AccountId`, `IsClosed`, or `Priority` can produce
  `UNABLE_TO_EVALUATE` instead of a smaller count.

Before activation, confirm the capacity result with the Case sharing model used by service managers.

## Step 3: Test the Check

1. Confirm the Priority API value and replace the example limit with your approved number.
2. Create three visible open high-priority Cases. Confirm a pass with Found `3` and Expected `3`.
3. Create a fourth matching Case. Confirm Warning with Found `4` and Expected `3`.
4. Lower the count below the limit by closing a matching Case, rerun, and confirm a pass.
5. Keep a matching Case that an administrator can see but the intended user cannot. Run as the
   intended user and confirm the hidden Case is not counted.
6. In a sandbox-only permission test, remove Read access to Case Priority and confirm
   `UNABLE_TO_EVALUATE`. Restore access after the test.
7. If you enabled either event setting, run the Check by selecting **Run** or **Rerun** and confirm
   that the receiving Flow, Apex trigger, or integration records exactly the expected event data.

## Failures and remedies

| What the user sees | What to check |
| --- | --- |
| A count or list is lower than expected | Confirm the query filters and the running user's sharing access to matching records. |
| Empty results behave incorrectly | Review **If Query Finds No Records** and, when used, **If Field Value Is Empty**. |
| **Unable to evaluate** | Confirm the object and field API names, SOQL syntax, and the running user's object and field permissions. |

## Related

- [← Prev: Account Owner team membership](./account-owner-team-membership.md) · [Next: Opportunity Contact Role coverage →](../compare-two-queries/opportunity-contact-role-coverage.md)
- [Browse Query examples](./README.md)
