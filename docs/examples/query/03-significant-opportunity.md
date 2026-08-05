# 03 · Account Has Meaningful Pipeline

> [!NOTE]
> On this page, compare open Opportunity amounts with an Account-specific threshold so one meaningful deal can satisfy the Rule only when the Account is eligible for the review.
>
> **Setup reference**
>
> Use the [Query reference](../../reference/evaluation/02-query.md) for the complete setup fields and behavior.

## Scenario

A strategic-account seller is preparing for a pipeline review and needs to know whether the Account has a deal that is meaningful for a customer of its size.

- Sales leadership has defined a significant deal as more than 10% of the Account's Annual Revenue.
- A fixed amount would overstate significance for some customers and understate it for others.
- Without a usable Annual Revenue value, the seller cannot make the comparison.

> [!TIP]
> **Why use Record Health Check**
>
> Record Health Check compares the Account with its open Opportunities and shows whether meaningful pipeline exists for the review.

## What you will learn

| Skill | How this example teaches it |
| --- | --- |
| Compare query data with the current record | Opportunity Amount is evaluated against an Account-specific threshold. |
| Resolve a record formula as **Expected** | The target can vary from Account to Account. |
| Detect meaningful pipeline | At least one returned Opportunity must meet the threshold. |

## Why use Verify with a query

| Evaluation Type | Why it fits |
| --- | --- |
| **Verify with a query** | Best fit. The query reviews related Opportunity Amounts, and the expected-value formula calculates 10% of the Account's Annual Revenue. |
| **Verify with a formula** | Can read Annual Revenue on the Account but cannot review Amount on every related Opportunity. |
| **Verify with a query** with a fixed expected value | Would use the same amount for every Account instead of adjusting to Account size. |

## Why not use a Validation Rule or Report

- **Validation Rule:** A Validation Rule cannot compare an Account value with all related Opportunity Amounts.

- **Report:** A report can support portfolio analysis. It does not place the answer directly on the Account beside the other strategic-account checks.

## Configure the Rule

In **Setup → Custom Metadata Types → Record Health Check Rule → Manage Records**, create the Rule:

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Developer Name** | [`DeveloperName`](../../metadata/02-fields-check-rule.md#developer-name-developername) | `Has_Significant_Open_Opportunity` |
| **Label** | [`MasterLabel`](../../metadata/02-fields-check-rule.md#label-masterlabel) | Has Significant Open Opportunity |
| **Check Set** | [`Record_Health_Check_Set__c`](../../metadata/02-fields-check-rule.md#check-set-record_health_check_set__c) | `Account_Related_Record_Review` |
| **Check Title** | [`CheckTitle__c`](../../metadata/02-fields-check-rule.md#check-title-checktitle__c) | Has Significant Open Opportunity |
| **Evaluation Type** | [`EvaluationType__c`](../../metadata/02-fields-check-rule.md#evaluation-type-evaluationtype__c) | Verify with a query |
| **Source Query** | [`SourceQuery__c`](../../metadata/02-fields-check-rule.md#source-query-sourcequery__c) | `SELECT Amount FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false AND Amount != null` |
| **Source Query Field** | [`SourceQueryField__c`](../../metadata/02-fields-check-rule.md#source-query-field-sourcequeryfield__c) | `Amount` |
| **How To Read Query Results** | [`QueryResultHandling__c`](../../metadata/02-fields-check-rule.md#how-to-read-query-results-queryresulthandling__c) | Any record passes |
| **Comparison Operator** | [`ComparisonOperator__c`](../../metadata/02-fields-check-rule.md#comparison-operator-comparisonoperator__c) | Greater than |
| **Expected Value Comes From** | [`ExpectedValueSource__c`](../../metadata/02-fields-check-rule.md#expected-value-comes-from-expectedvaluesource__c) | Record formula |
| **Expected Value (Formula)** | [`ExpectedRecordFormula__c`](../../metadata/02-fields-check-rule.md#expected-value-formula-expectedrecordformula__c) | `AnnualRevenue * 0.1` |
| **If Query Finds No Records** | [`NoRowsResult__c`](../../metadata/02-fields-check-rule.md#if-query-finds-no-records-norowsresult__c) | Fail |
| **If Field Value Is Empty** | [`EmptyValueHandling__c`](../../metadata/02-fields-check-rule.md#if-field-value-is-empty-emptyvaluehandling__c) | Treat as not matching; the query excludes blank Amount |
| **Max Query Rows (1-2000)** | [`MaxQueryRows__c`](../../metadata/02-fields-check-rule.md#max-query-rows-1-2000-maxqueryrows__c) | `200` |
| **Applies To** | [`ApplicabilityMode__c`](../../metadata/02-fields-check-rule.md#applies-to-applicabilitymode__c) | When a formula is true |
| **Applies When (Formula)** | [`ApplicabilityFormula__c`](../../metadata/02-fields-check-rule.md#applies-when-formula-applicabilityformula__c) | `BLANKVALUE(AnnualRevenue, 0) > 0` |

This scenario uses a confirmed 10% threshold. When adapting the Rule, replace `0.1` with the
percentage approved for your pipeline review.

## Optional configuration

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Check Description** | [`CheckDescription__c`](../../metadata/02-fields-check-rule.md#check-description-checkdescription__c) | Checks whether an open Opportunity exceeds 10% of Annual Revenue when Annual Revenue is available. |
| **Category** | [`Category__c`](../../metadata/02-fields-check-rule.md#category-category__c) | Readiness |
| **Failure Severity** | [`FailureSeverity__c`](../../metadata/02-fields-check-rule.md#failure-severity-failureseverity__c) | Info |
| **Message When Failed** | [`FailureMessage__c`](../../metadata/02-fields-check-rule.md#message-when-failed-failuremessage__c) | `{!record.Name fallback="this record"}` has no open Opportunity that exceeds 10% of Annual Revenue. Increase an open Opportunity Amount or revisit the Account Annual Revenue. |
| **Message When Unable To Evaluate** | [`UnableToEvaluateMessage__c`](../../metadata/02-fields-check-rule.md#message-when-unable-to-evaluate-unabletoevaluatemessage__c) | Unable to compare open Opportunity Amount with Annual Revenue. Confirm access to both objects and fields. |
| **Prerequisite Rule** | [`PrerequisiteRule__c`](../../metadata/02-fields-check-rule.md#prerequisite-rule-prerequisiterule__c) | Leave blank; applicability already prevents a meaningless zero threshold. |
| **Fix Message** | [`FixMessage__c`](../../metadata/02-fields-check-rule.md#fix-message-fixmessage__c) | Review Annual Revenue and open Opportunity Amounts, then correct the value that is inaccurate. |
| **Action Label** | [`ActionLabel__c`](../../metadata/02-fields-check-rule.md#action-label-actionlabel__c) | Leave blank: one portable link cannot edit both Account and Opportunity values. |
| **Action URL** | [`ActionUrl__c`](../../metadata/02-fields-check-rule.md#action-url-actionurl__c) | Leave blank; use a verified org-specific report or playbook if needed. |
| **Evaluation Order** | [`EvaluationOrder__c`](../../metadata/02-fields-check-rule.md#evaluation-order-evaluationorder__c) | `60` |
| **Active** | [`IsActive__c`](../../metadata/02-fields-check-rule.md#active-isactive__c) | Checked |
| **Publish User Result Event** | [`PublishUserResultEvent__c`](../../metadata/02-fields-check-rule.md#publish-user-result-event-publishuserresultevent__c) | Unchecked |

Display Found/Expected Text applies only to **Every record passes**, so leave it blank here.
Comparison Query, list, Formula, and Apex fields do not apply.

## Check Set configuration

Use these Check Set values:

| Check Set setting | Value |
| --- | --- |
| **Check Set** | `Account_Related_Record_Review` |
| **Object** | `Account` |
| **Card Title** | `Related Record Review` |
| **Card Subtitle** | Confirm a significant open Opportunity relative to the Account. |
| **When Checks Run** | Run on request |
| **Reveal Mode** | One by one |
| **Passed Checks** | Show each check |
| **Skipped Checks** | Show each check |
| **Found/Expected Display** | On demand |
| **Stop after a system error** | Unchecked |
| **Show Diagnostics** | Unchecked; enable temporarily only for authorized troubleshooting |
| **Publish User Run Event** | Unchecked |
| **Active** | Checked |

## What the user sees

Formula applicability and the query comparison become these Framework outcomes and card values:

| Framework result or card value | What the user sees |
| --- | --- |
| **`PASS`** | At least one visible open Opportunity Amount is greater than 10% of Account Annual Revenue. |
| **`FAIL`** | No visible open Opportunity exceeds the Account-specific threshold, so the card shows Needs attention with Info severity. |
| **`SKIPPED`** | Blank or zero Annual Revenue skips the Rule so a zero threshold cannot create a misleading pass. |
| **Found** | Found shows the Opportunity Amount evaluated by the successful or representative query result. |
| **Expected** | Expected shows the Account-specific threshold calculated from Annual Revenue. |

## Security and access

Record Health Check reads Account Annual Revenue and visible open Opportunity Amounts with the running user's Salesforce access.

- A qualifying Opportunity hidden from the user does not contribute to **Any record passes**, so users can legitimately receive different results.

- Missing Annual Revenue, Opportunity, or Amount permission can show **Unable to evaluate**.

Before activation, run the Rule with the Account and Opportunity access assigned to pipeline reviewers.

## Test the Rule

1. Set Annual Revenue and open Opportunity Amounts so none exceed 10% of Annual Revenue. Confirm Info.
2. Raise one open Opportunity Amount above that formula result, rerun, and confirm a pass.
3. Clear Annual Revenue and confirm the Rule is skipped.
4. Repeat the failing test as a user with restricted Opportunity Amount access and confirm the Rule follows that user's field access.

## Failures and remedies

| What the user sees | What to check |
| --- | --- |
| A count or list is lower than expected | Confirm the query filters and the running user's sharing access to matching records. |
| Empty results behave incorrectly | Review **If Query Finds No Records** and, when used, **If Field Value Is Empty**. |
| **Unable to evaluate** | Confirm the object and field API names, SOQL syntax, and the running user's object and field permissions. |

## Related

- [← Prev: Pipeline next steps](02-opportunity-next-steps.md) · [Next: Forecast amounts →](04-forecast-amounts.md)
- [Browse Query examples](README.md)
