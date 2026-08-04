# 02 · Open Opportunities Are Ready for Pipeline Review

> [!NOTE]
> On this page, require every open Opportunity to have a Next Step, fail on an empty value, and skip the Rule entirely when the Account has no open pipeline to review.
>
> **Setup reference**
>
> Use the [Query reference](../../reference/evaluation/query.md) for the complete setup fields and behavior.

> [!IMPORTANT]
> This configuration is illustrative teaching metadata. It is not installed by the Framework package.

## Scenario

An account executive opens an Account before a pipeline discussion.

- Every open Opportunity must identify a Next Step so each deal has a documented action for the pipeline discussion.
- A missing Next Step leaves the account executive and manager without an agreed action for that deal.
- Accounts with no open pipeline are outside this pipeline discussion.

> [!TIP]
> **Why use Record Health Check**
>
> Record Health Check shows one pipeline-readiness result and identifies how many open Opportunities still need a Next Step.

## What you will learn

| Skill | How this example teaches it |
| --- | --- |
| Evaluate several related records | The query returns every open Opportunity for the Account. |
| Require every row to qualify | The Rule checks that each Opportunity has a Next Step. |
| Test mixed query results | One incomplete Opportunity is enough to produce `FAIL`. |

## Why use Verify with a query

| Evaluation Type | Why it fits |
| --- | --- |
| **Verify with a query** | Best fit. The query reviews Next Step on every open Opportunity related to the Account. |
| **Verify with a formula** | An Account formula cannot review fields on all related Opportunities. |
| **Verify with a query** that fails when no records are found | Would mark an Account with no open Opportunities as needing attention. This example should skip it. |

## Why not use a Validation Rule or Report

- **Validation Rule:** A Validation Rule would enforce Next Step during every Opportunity save, even when early-stage deals may remain incomplete.

- **Report:** A report can list missing values across the pipeline. It does not place the answer directly on the Account being prepared for review.

## Configure the Rule

In **Setup → Custom Metadata Types → Record Health Check Rule → Manage Records**, create the Rule:

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Developer Name** | [`DeveloperName`](../../metadata/fields-check-rule.md#developer-name-developername) | `Open_Opportunities_Have_Next_Steps` |
| **Label** | [`MasterLabel`](../../metadata/fields-check-rule.md#label-masterlabel) | Open Opportunities Have Next Steps |
| **Check Set** | [`Record_Health_Check_Set__c`](../../metadata/fields-check-rule.md#check-set-record_health_check_set__c) | `Account_Related_Record_Review` |
| **Check Title** | [`CheckTitle__c`](../../metadata/fields-check-rule.md#check-title-checktitle__c) | Open Opportunities Are Ready for Review |
| **Evaluation Type** | [`EvaluationType__c`](../../metadata/fields-check-rule.md#evaluation-type-evaluationtype__c) | Verify with a query |
| **Source Query** | [`SourceQuery__c`](../../metadata/fields-check-rule.md#source-query-sourcequery__c) | `SELECT NextStep FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false` |
| **Source Query Field** | [`SourceQueryField__c`](../../metadata/fields-check-rule.md#source-query-field-sourcequeryfield__c) | `NextStep` |
| **How To Read Query Results** | [`QueryResultHandling__c`](../../metadata/fields-check-rule.md#how-to-read-query-results-queryresulthandling__c) | Every record passes |
| **Comparison Operator** | [`ComparisonOperator__c`](../../metadata/fields-check-rule.md#comparison-operator-comparisonoperator__c) | Is not empty |
| **If Query Finds No Records** | [`NoRowsResult__c`](../../metadata/fields-check-rule.md#if-query-finds-no-records-norowsresult__c) | Skip |
| **If Field Value Is Empty** | [`EmptyValueHandling__c`](../../metadata/fields-check-rule.md#if-field-value-is-empty-emptyvaluehandling__c) | Treat as not matching |
| **Max Query Rows (1-2000)** | [`MaxQueryRows__c`](../../metadata/fields-check-rule.md#max-query-rows-1-2000-maxqueryrows__c) | `200` |

## Optional configuration

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Check Description** | [`CheckDescription__c`](../../metadata/fields-check-rule.md#check-description-checkdescription__c) | Confirms that every visible open Opportunity has a Next Step; skips Accounts with none. |
| **Category** | [`Category__c`](../../metadata/fields-check-rule.md#category-category__c) | Readiness |
| **Failure Severity** | [`FailureSeverity__c`](../../metadata/fields-check-rule.md#failure-severity-failureseverity__c) | Warning |
| **Message When Failed** | [`FailureMessage__c`](../../metadata/fields-check-rule.md#message-when-failed-failuremessage__c) | `{!record.Name fallback="this record"}` has one or more open Opportunities with no Next Step. Add the next planned action to each deal that needs attention. |
| **Message When Unable To Evaluate** | [`UnableToEvaluateMessage__c`](../../metadata/fields-check-rule.md#message-when-unable-to-evaluate-unabletoevaluatemessage__c) | Unable to check open Opportunity Next Step. Confirm the user can read the queried fields. |
| **Applies To** | [`ApplicabilityMode__c`](../../metadata/fields-check-rule.md#applies-to-applicabilitymode__c) | All records; empty-query handling creates the skip |
| **Prerequisite Rule** | [`PrerequisiteRule__c`](../../metadata/fields-check-rule.md#prerequisite-rule-prerequisiterule__c) | Leave blank |
| **Fix Message** | [`FixMessage__c`](../../metadata/fields-check-rule.md#fix-message-fixmessage__c) | Review open Opportunities and enter Next Step on every deal that still needs one. |
| **Action Label** | [`ActionLabel__c`](../../metadata/fields-check-rule.md#action-label-actionlabel__c) | `Review open opportunities` |
| **Action URL** | [`ActionUrl__c`](../../metadata/fields-check-rule.md#action-url-actionurl__c) | `/lightning/r/Account/{!record.Id}/related/Opportunities/view` |
| **Evaluation Order** | [`EvaluationOrder__c`](../../metadata/fields-check-rule.md#evaluation-order-evaluationorder__c) | `40` |
| **Active** | [`IsActive__c`](../../metadata/fields-check-rule.md#active-isactive__c) | Checked |
| **Publish User Result Event** | [`PublishUserResultEvent__c`](../../metadata/fields-check-rule.md#publish-user-result-event-publishuserresultevent__c) | Unchecked |

Comparison Query, list, Formula, and Apex fields do not apply.

## Check Set configuration

Use these Check Set values:

| Check Set setting | Value |
| --- | --- |
| **Check Set** | `Account_Related_Record_Review` |
| **Object** | `Account` |
| **Card Title** | `Related Record Review` |
| **Card Subtitle** | Confirm open Opportunities have a Next Step. |
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

The query rows and no-row behavior become these Framework outcomes and card values:

| Framework result or card value | What the user sees |
| --- | --- |
| **`PASS`** | Every visible open Opportunity has Next Step populated. |
| **`FAIL`** | At least one visible open Opportunity has blank Next Step, so the card shows Needs attention with Warning severity. |
| **`SKIPPED`** | An Account with no open Opportunities is skipped because **No rows result** is **Skipped**. |
| **Found** | Found identifies the returned Next Step value or empty value that determined the result. |
| **Expected** | Expected shows that Next Step must not be empty. |

## Security and access

Record Health Check reads open Opportunities and their Next Step with the running user's Salesforce access.

- The Rule evaluates only visible open Opportunities. A hidden Opportunity with blank Next Step cannot appear in the result.

- Missing object or field permission can show **Unable to evaluate** rather than Pass or Needs attention.

Before activation, repeat the test as a user who can see only part of the Account's pipeline.

## Test the Rule

1. Add an open Opportunity with Next Step blank. Confirm Warning.
2. Enter Next Step on every open Opportunity, rerun, and confirm a pass.
3. Close or remove open Opportunities and confirm the Rule is skipped.
4. Repeat the blank Next Step test as a user with restricted Opportunity access and confirm the result follows that user's visible records and fields.

## Failures and remedies

| What the user sees | What to check |
| --- | --- |
| A count or list is lower than expected | Confirm the query filters and the running user's sharing access to matching records. |
| Empty results behave incorrectly | Review **If Query Finds No Records** and, when used, **If Field Value Is Empty**. |
| **Unable to evaluate** | Confirm the object and field API names, SOQL syntax, and the running user's object and field permissions. |

## Related

- [← Prev: Customer handoff](01-customer-contact.md) · [Next: Significant pipeline →](03-significant-opportunity.md)
- [Browse Query examples](README.md)
