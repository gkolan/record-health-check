# 04 · Open Pipeline Is Ready for Forecast Review

> [!NOTE]
> On this page, require every open Opportunity to carry a positive Amount and use result-summary merge tokens to tell users how much pipeline passed the forecast check.
>
> **Setup reference**
>
> Use the [Query reference](../../reference/evaluation/query.md) for the complete setup fields and behavior.

## Scenario

A seller is preparing an Account for forecast review.

- Every open Opportunity must have a positive Amount so pipeline totals do not include placeholder deals with no value.
- One incomplete Opportunity is enough to make the Account's pipeline unreliable.
- Accounts with no open Opportunities have no pipeline to prepare for forecast review.

> [!TIP]
> **Why use Record Health Check**
>
> Record Health Check shows how many open Opportunities still need Amount, so the seller can correct the incomplete deals before forecast review.

## What you will learn

| Skill | How this example teaches it |
| --- | --- |
| Evaluate numeric query values | The Check reads Amount from open Opportunities. |
| Handle empty values deliberately | A blank Amount is treated as incomplete forecast data. |
| Require clean results across all rows | Every returned Opportunity must have an Amount above zero. |

## Why use Verify with a query

| Evaluation Type | Why it fits |
| --- | --- |
| **Verify with a query** | Best fit. The query reviews Amount on every open Opportunity related to the Account. |
| **Verify with a query** using **Any record passes** | Would pass when only one Opportunity has an Amount and could hide other incomplete Opportunities. |
| **Verify with Apex** | Would require an Apex class for a field check the Verify with a query already handles. |

## Why not use a Validation Rule or Report

- **Validation Rule:** A Validation Rule would require Amount during every Opportunity save, even when early pipeline records may not have an amount yet.

- **Report:** A report can find missing Amounts across the pipeline. It does not place the summary directly on the Account being prepared for forecast review.

## Before you start

- Install Record Health Check.
- Assign **Record Health Check Admin** to the administrator creating the Check Set and Check.
- Confirm that intended users can read Opportunity, `AccountId`, `IsClosed`, and `Amount` and can
  see every open Opportunity included in forecast review.

## Step 1: Create the Check Set

In **Setup → Custom Metadata Types → Record Health Check Set → Manage Records**, select **New** and
create this Check Set:

| Setup field | Value |
| --- | --- |
| **Label** | Account Related Record Review |
| **Record Health Check Set Name** | `Account_Related_Record_Review` |
| **Object** | `Account` |
| **Card Title** | Related Record Review |
| **Card Subtitle** | Confirm every open Opportunity has a positive Amount. |
| **When Checks Run** | Run on request |
| **Reveal Mode** | One by one |
| **Passed Checks** | Show each check |
| **Skipped Checks** | Show each check |
| **Found/Expected Display** | On demand |
| **Stop after a system error** | Unchecked |
| **Show Diagnostics** | Unchecked; enable temporarily only for authorized troubleshooting |
| **Publish User Run Event** | Unchecked |
| **Active** | Checked |

## Step 2: Configure the Check

In **Setup → Custom Metadata Types → Record Health Check → Manage Records**, create the Check:

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Developer Name** | [`DeveloperName`](../../metadata/fields-check.md#developer-name-developername) | `Open_Opps_Have_Positive_Amount` |
| **Label** | [`MasterLabel`](../../metadata/fields-check.md#label-masterlabel) | All Open Opportunities Have Positive Amount |
| **Check Set** | [`Record_Health_Check_Set__c`](../../metadata/fields-check.md#check-set-record_health_check_set__c) | `Account_Related_Record_Review` |
| **Check Title** | [`CheckTitle__c`](../../metadata/fields-check.md#check-title-checktitle__c) | All Open Opportunities Have Positive Amount |
| **Evaluation Type** | [`EvaluationType__c`](../../metadata/fields-check.md#evaluation-type-evaluationtype__c) | Verify with a query |
| **Source Query** | [`SourceQuery__c`](../../metadata/fields-check.md#source-query-sourcequery__c) | `SELECT Amount FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false` |
| **Source Query Field** | [`SourceQueryField__c`](../../metadata/fields-check.md#source-query-field-sourcequeryfield__c) | `Amount` |
| **How To Read Query Results** | [`QueryResultHandling__c`](../../metadata/fields-check.md#how-to-read-query-results-queryresulthandling__c) | Every record passes |
| **Comparison Operator** | [`ComparisonOperator__c`](../../metadata/fields-check.md#comparison-operator-comparisonoperator__c) | Greater than |
| **Expected Value Comes From** | [`ExpectedValueSource__c`](../../metadata/fields-check.md#expected-value-comes-from-expectedvaluesource__c) | Fixed value |
| **Expected Value (Fixed)** | [`ExpectedFixedValue__c`](../../metadata/fields-check.md#expected-value-fixed-expectedfixedvalue__c) | `0` |
| **If Query Finds No Records** | [`NoRowsResult__c`](../../metadata/fields-check.md#if-query-finds-no-records-norowsresult__c) | Skip |
| **If Field Value Is Empty** | [`EmptyValueHandling__c`](../../metadata/fields-check.md#if-field-value-is-empty-emptyvaluehandling__c) | Treat as not matching |
| **Max Query Rows (1-2000)** | [`MaxQueryRows__c`](../../metadata/fields-check.md#max-query-rows-1-2000-maxqueryrows__c) | `200`; raise only after confirming Accounts can exceed this many open Opportunities |
| **Display: Found Text** | [`DisplayFoundText__c`](../../metadata/fields-check.md#display-found-text-displayfoundtext__c) | Count of open opportunities missing Amount out of the total: copy it from below the table |
| **Display: Expected Text** | [`DisplayExpectedText__c`](../../metadata/fields-check.md#display-expected-text-displayexpectedtext__c) | `Every open opportunity has Amount greater than zero` |

Copy this value into **Display: Found Text**:

```text
{!rhcResult.failedRecordCount} of {!rhcResult.totalRecordCount fallback="0"} open opportunities need Amount
```

## Optional configuration

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Check Description** | [`CheckDescription__c`](../../metadata/fields-check.md#check-description-checkdescription__c) | Checks every visible open Opportunity for an Amount greater than zero; skips Accounts with none. |
| **Category** | [`Category__c`](../../metadata/fields-check.md#category-category__c) | Readiness |
| **Failure Severity** | [`FailureSeverity__c`](../../metadata/fields-check.md#failure-severity-failureseverity__c) | Warning |
| **Message When Failed** | [`FailureMessage__c`](../../metadata/fields-check.md#message-when-failed-failuremessage__c) | One or more open Opportunities have Amount zero or blank. Enter a positive Amount on every open Opportunity. |
| **Message When Unable To Evaluate** | [`UnableToEvaluateMessage__c`](../../metadata/fields-check.md#message-when-unable-to-evaluate-unabletoevaluatemessage__c) | Unable to check open Opportunity Amounts. Confirm the user can read the queried fields. |
| **Applies To** | [`ApplicabilityMode__c`](../../metadata/fields-check.md#applies-to-applicabilitymode__c) | All records; empty-query handling creates the skip |
| **Prerequisite Check** | [`PrerequisiteCheck__c`](../../metadata/fields-check.md#prerequisite-check-prerequisitecheck__c) | Leave blank |
| **Fix Message** | [`FixMessage__c`](../../metadata/fields-check.md#fix-message-fixmessage__c) | Use Found to see how many open Opportunities need Amount, then correct each one. |
| **Action Label** | [`ActionLabel__c`](../../metadata/fields-check.md#action-label-actionlabel__c) | `Review open opportunities` |
| **Action URL** | [`ActionUrl__c`](../../metadata/fields-check.md#action-url-actionurl__c) | `/lightning/r/Account/{!record.Id}/related/Opportunities/view` |
| **Evaluation Order** | [`EvaluationOrder__c`](../../metadata/fields-check.md#evaluation-order-evaluationorder__c) | `70` |
| **Active** | [`IsActive__c`](../../metadata/fields-check.md#active-isactive__c) | Checked |
| **Publish User Result Event** | [`PublishUserResultEvent__c`](../../metadata/fields-check.md#publish-user-result-event-publishuserresultevent__c) | Unchecked |

Comparison Query, list, Formula, and Apex fields do not apply.

## What the user sees

The query rows and no-record behavior produce these health results and card values:

| Health result or card value | What the user sees |
| --- | --- |
| **`PASS`** | Every visible open Opportunity has Amount greater than zero. |
| **`FAIL`** | At least one visible open Opportunity has blank, zero, or negative Amount, so the card shows Needs attention with Warning severity. |
| **`SKIPPED`** | An Account with no open Opportunities is skipped because **No rows result** is **Skipped**. |
| **Found** | Found summarizes how many returned Opportunities need an Amount, using the configured result-count merge tokens. |
| **Expected** | The configured display text shows `Every open opportunity has Amount greater than zero`. |

## Security and access

Record Health Check reads Amount on open Opportunities with the running user's Salesforce access.

- **Every record passes** applies only to visible open Opportunities. A hidden deal with blank Amount cannot be reported to the user.

- Missing Opportunity or Amount permission can show **Unable to evaluate**.

Before activation, test as a forecast user with restricted Opportunity sharing and confirm the result matches the records that user may review.

## Step 3: Test the Check

1. Add an open Opportunity with Amount zero. Confirm Warning.
2. Set all open Amounts above zero, rerun, and confirm a pass.
3. Remove open Opportunities and confirm skip.
4. Keep a zero-Amount Opportunity that an administrator can see but a forecast user cannot. Run as
   the forecast user and confirm the hidden Opportunity is not counted.
5. In a sandbox-only permission test, remove Read access to Amount and confirm
   `UNABLE_TO_EVALUATE`. Restore access after the test.

## Failures and remedies

| What the user sees | What to check |
| --- | --- |
| A count or list is lower than expected | Confirm the query filters and the running user's sharing access to matching records. |
| Empty results behave incorrectly | Review **If Query Finds No Records** and, when used, **If Field Value Is Empty**. |
| **Unable to evaluate** | Confirm the object and field API names, SOQL syntax, and the running user's object and field permissions. |

## Related

- [← Prev: Meaningful pipeline](significant-opportunity.md) · [Next: Placeholder email cleanup →](placeholder-contact-emails.md)
- [Browse Query examples](README.md)
