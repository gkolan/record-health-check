# 07 · High-priority Case Backlog Is Within Review Capacity

> [!NOTE]
> On this page, enforce a maximum high-priority Case backlog with an aggregate Query Rule and enable lifecycle events only when an approved subscriber needs completion facts.
>
> **Setup reference**
>
> Use the [Query reference](../../reference/evaluation/query.md) for the complete setup fields and behavior.

> [!IMPORTANT]
> This configuration is illustrative teaching metadata. It is not installed by the Framework package.

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
| Enforce a maximum | The Rule passes while the count stays within team capacity. |
| Make operational limits visible | **Found** shows the backlog and **Expected** shows the approved ceiling. |
| Publish completion facts | Explicit runs can publish the Rule Result and Check Set Run lifecycle events. |

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

## Configure the Rule

In **Setup → Custom Metadata Types → Record Health Check Rule → Manage Records**, create the Rule:

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Developer Name** | [`DeveloperName`](../../metadata/fields-check-rule.md#developer-name-developername) | `High_Priority_Case_Limit` |
| **Label** | [`MasterLabel`](../../metadata/fields-check-rule.md#label-masterlabel) | High-Priority Case Limit |
| **Check Set** | [`Record_Health_Check_Set__c`](../../metadata/fields-check-rule.md#check-set-record_health_check_set__c) | `Account_Related_Record_Review` |
| **Check Title** | [`CheckTitle__c`](../../metadata/fields-check-rule.md#check-title-checktitle__c) | High-Priority Case Backlog Is Within Capacity |
| **Evaluation Type** | [`EvaluationType__c`](../../metadata/fields-check-rule.md#evaluation-type-evaluationtype__c) | Verify with a query |
| **Source Query** | [`SourceQuery__c`](../../metadata/fields-check-rule.md#source-query-sourcequery__c) | `SELECT COUNT() FROM Case WHERE AccountId = {!record.Id} AND IsClosed = false AND Priority = 'High'` |
| **Source Query Field** | [`SourceQueryField__c`](../../metadata/fields-check-rule.md#source-query-field-sourcequeryfield__c) | Leave blank for `COUNT()` |
| **How To Read Query Results** | [`QueryResultHandling__c`](../../metadata/fields-check-rule.md#how-to-read-query-results-queryresulthandling__c) | One row or aggregate |
| **Comparison Operator** | [`ComparisonOperator__c`](../../metadata/fields-check-rule.md#comparison-operator-comparisonoperator__c) | Less than or equal |
| **Expected Value Comes From** | [`ExpectedValueSource__c`](../../metadata/fields-check-rule.md#expected-value-comes-from-expectedvaluesource__c) | Fixed value |
| **Expected Value (Fixed)** | [`ExpectedFixedValue__c`](../../metadata/fields-check-rule.md#expected-value-fixed-expectedfixedvalue__c) | `3` (**Replace with your approved capacity limit**) |
| **Max Query Rows (1-2000)** | [`MaxQueryRows__c`](../../metadata/fields-check-rule.md#max-query-rows-1-2000-maxqueryrows__c) | `200` (default; `COUNT()` returns one result) |

Confirm the `High` Priority API value and replace `3` with the limit approved by your service team.

## Optional configuration

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Failure Severity** | [`FailureSeverity__c`](../../metadata/fields-check-rule.md#failure-severity-failureseverity__c) | Warning |
| **Message When Failed** | [`FailureMessage__c`](../../metadata/fields-check-rule.md#message-when-failed-failuremessage__c) | `{!record.Name fallback="this record"}` has more open high-priority Cases than the service team can review through its normal process. |
| **Check Description** | [`CheckDescription__c`](../../metadata/fields-check-rule.md#check-description-checkdescription__c) | Compares the visible open high-priority Case count with the approved review limit. |
| **Category** | [`Category__c`](../../metadata/fields-check-rule.md#category-category__c) | Readiness |
| **Message When Unable To Evaluate** | [`UnableToEvaluateMessage__c`](../../metadata/fields-check-rule.md#message-when-unable-to-evaluate-unabletoevaluatemessage__c) | Unable to count high-priority Cases. Confirm access to Case, AccountId, IsClosed, and Priority. |
| **Applies To** | [`ApplicabilityMode__c`](../../metadata/fields-check-rule.md#applies-to-applicabilitymode__c) | All records |
| **Prerequisite Rule** | [`PrerequisiteRule__c`](../../metadata/fields-check-rule.md#prerequisite-rule-prerequisiterule__c) | Leave blank |
| **Fix Message** | [`FixMessage__c`](../../metadata/fields-check-rule.md#fix-message-fixmessage__c) | Review ownership and response plans for the open high-priority Cases, then follow your capacity-escalation process. |
| **Action Label** | [`ActionLabel__c`](../../metadata/fields-check-rule.md#action-label-actionlabel__c) | `Review cases` |
| **Action URL** | [`ActionUrl__c`](../../metadata/fields-check-rule.md#action-url-actionurl__c) | `/lightning/r/Account/{!record.Id}/related/Cases/view` |
| **Evaluation Order** | [`EvaluationOrder__c`](../../metadata/fields-check-rule.md#evaluation-order-evaluationorder__c) | `140` |
| **Active** | [`IsActive__c`](../../metadata/fields-check-rule.md#active-isactive__c) | Checked only after confirming the Priority value and approved capacity limit |
| **Publish User Result Event** | [`PublishUserResultEvent__c`](../../metadata/fields-check-rule.md#publish-user-result-event-publishuserresultevent__c) | Checked only when an approved subscriber needs this per-Rule result |

Source Query Field stays blank because bare `COUNT()` produces the value directly. Comparison
Query, row-empty, list, Formula-result, and Apex fields do not apply. The count is `0` when no Case
matches, so the Rule passes rather than skipping.

## Check Set configuration

Use these Check Set values:

| Check Set setting | Value |
| --- | --- |
| **Check Set** | `Account_Related_Record_Review` |
| **Object** | `Account` |
| **Card Title** | `Related Record Review` |
| **Card Subtitle** | Confirm open high-priority Cases stay within capacity. |
| **When Checks Run** | Run on request |
| **Reveal Mode** | One by one |
| **Passed Checks** | Show each check |
| **Skipped Checks** | Show each check |
| **Found/Expected Display** | On demand |
| **Stop after a system error** | Unchecked |
| **Show Diagnostics** | Unchecked; enable temporarily only for authorized troubleshooting |
| **Publish User Run Event** | Checked only when an approved subscriber needs one completion summary |
| **Active** | Checked |

## What the user sees

The card turns the aggregate count and upper limit into these user-facing values:

| Framework result or card value | What the user sees |
| --- | --- |
| **`PASS`** | Zero through three visible open high-priority Cases is within the example limit. |
| **`FAIL`** | Four or more visible open high-priority Cases exceeds the limit and shows Needs attention with Warning severity. |
| **`SKIPPED`** | Bare `COUNT()` returns zero rather than no rows, and this configuration has no applicability check or prerequisite, so it does not produce `SKIPPED`. |
| **Found** | When the user reveals Found and Expected, Found shows the current visible high-priority Case count. |
| **Expected** | When the user reveals Found and Expected, Expected shows the maximum allowed count: `3`. |

Because **When Checks Run** is **Run on request**, an explicit Run or Rerun can publish lifecycle
events when the two publication settings are checked. Automatic page-load evaluation never
publishes. Configure subscribers for replay and duplicate delivery before enabling either setting.

## Security and access

Record Health Check counts open high-priority Cases related to the Account with the running user's Salesforce access.

- Hidden Cases are not counted. A service manager with broader Case access may see a higher backlog than another user.

- Missing Case or filter-field permission can show **Unable to evaluate** instead of a smaller count.

Before activation, confirm the capacity result with the Case sharing model used by service managers.

## Test the Rule

1. Confirm the Priority API value and replace the example limit with your approved number.
2. Create three visible open high-priority Cases. Confirm a pass with Found `3` and Expected `3`.
3. Create a fourth matching Case. Confirm Warning with Found `4` and Expected `3`.
4. Lower the count below the limit by closing a matching Case, rerun, and confirm a pass.
5. Repeat the failing test as a user with restricted Case sharing and confirm the visible count follows your security model.

## Failures and remedies

| What the user sees | What to check |
| --- | --- |
| A count or list is lower than expected | Confirm the query filters and the running user's sharing access to matching records. |
| Empty results behave incorrectly | Review **If Query Finds No Records** and, when used, **If Field Value Is Empty**. |
| **Unable to evaluate** | Confirm the object and field API names, SOQL syntax, and the running user's object and field permissions. |

## Related

- [← Prev: Account Owner team membership](06-account-owner-team-membership.md) · [Next: Opportunity Contact Role coverage →](../compare-two-queries/01-opportunity-contact-role-coverage.md)
- [Browse Query examples](README.md)
