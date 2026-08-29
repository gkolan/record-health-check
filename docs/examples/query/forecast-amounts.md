# Proposal-Stage Deals Meet the Qualification Floor

> [!NOTE]
> On this page, require every proposal-stage Opportunity to meet an illustrative $25,000 qualification floor and show the observed deal values beside the policy threshold.
>
> **Setup reference**
>
> Use the [Query reference](../../reference/evaluation/query.md) for the complete setup fields and behavior.

## Scenario

A sales leader is reviewing deals that have advanced to proposal.

- Every Opportunity in **Proposal/Price Quote** must meet the organization's minimum commercial-review threshold.
- A deal below the threshold may need requalification, consolidation, or a different sales motion before proposal resources are committed.
- Accounts with no proposal-stage Opportunities have nothing to evaluate against this policy.

> [!TIP]
> **Why use Record Health Check**
>
> Record Health Check evaluates the policy only when a deal reaches the governed stage. The result shows the actual proposal values beside the qualification floor, so reviewers can investigate exceptions without treating early pipeline as defective.

## What you will learn

| Skill | How this example teaches it |
| --- | --- |
| Evaluate numeric query values | The Check reads Amount from proposal-stage Opportunities. |
| Scope a policy to the relevant lifecycle stage | Early pipeline is excluded; only **Proposal/Price Quote** is governed. |
| Require clean results across all rows | Every returned proposal must meet the qualification floor. |

## Why use Verify with a query

| Evaluation Type | Why it fits |
| --- | --- |
| **Verify with a query** | Best fit. The query reviews Amount on every proposal-stage Opportunity related to the Account. |
| **Verify with a query** using **Any record passes** | Would pass when only one proposal meets the floor and could hide undersized proposals. |
| **Verify with Apex** | Would require an Apex class for a field check the Verify with a query already handles. |

## Why not use a Validation Rule or Report

- **Validation Rule:** A Validation Rule would block the save. This health check supports an account-level review and can identify policy exceptions without preventing an authorized exception from progressing.

- **Report:** A report can find proposal-stage deals below the floor. It does not place the policy result and remediation directly on the Account under review.

## Before you start

- Install Record Health Check.
- Assign **Record Health Check Admin** to the administrator creating the Check Set and Check.
- Confirm that intended users can read Opportunity, `AccountId`, `StageName`, and `Amount` and can
  see every proposal-stage Opportunity included in the review.

## Read the result and prepare test data

`{!rhcResult.foundValue fallback="No proposal values found"}` is a Record Health Check result merge
token. It inserts the evaluated proposal values; it is not a Flow or Apex expression. Test
proposal-stage Opportunities below, at, and above the approved floor. At 201 returned rows with **Max Query Rows** 200,
the Check returns Unable to Check with `ROW_LIMIT_EXCEEDED` instead of evaluating a partial set.

Replace $25,000 with the threshold approved for the relevant segment, region, currency, and sales
motion. Decide whether the policy should use Amount, Expected Revenue, or another governed measure.
In a multi-currency org, review the documented currency rules before comparing values.

Create the Opportunities from the Account related list, add the card to the Account Lightning
page, activate the intended assignment, and test as a user with **Record Health Check Card User**.

## Step 1: Create the Check Set

In **Setup → Custom Metadata Types → Record Health Check Set → Manage Records**, select **New** and
create this Check Set:

| Setup field | Value |
| --- | --- |
| **Label** | Account Related Record Review |
| **Record Health Check Set Name** | `Account_Related_Record_Review` |
| **Object** | `Account` |
| **Card Title** | Related Record Review |
| **Card Subtitle** | Confirm proposal-stage deals meet the approved qualification floor. |
| **When Checks Run** | When the user clicks Run |
| **Summary Display** | Below Checks |
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
| **Developer Name** | [`DeveloperName`](../../reference/custom-metadata/check-fields.md#developer-name-developername) | `Proposal_Deals_Meet_Qualification_Floor` |
| **Label** | [`MasterLabel`](../../reference/custom-metadata/check-fields.md#label-masterlabel) | Proposal Deals Meet Qualification Floor |
| **Check Set** | [`Record_Health_Check_Set__c`](../../reference/custom-metadata/check-fields.md#check-set-record_health_check_set__c) | `Account_Related_Record_Review` |
| **Check Title** | [`CheckTitle__c`](../../reference/custom-metadata/check-fields.md#check-title-checktitle__c) | Proposal-stage deals meet the qualification floor |
| **Evaluation Type** | [`EvaluationType__c`](../../reference/custom-metadata/check-fields.md#evaluation-type-evaluationtype__c) | Verify with a query |
| **Source Query** | [`SourceQuery__c`](../../reference/custom-metadata/check-fields.md#source-query-sourcequery__c) | `SELECT Amount FROM Opportunity WHERE AccountId = {!record.Id} AND StageName = 'Proposal/Price Quote'` |
| **Source Query Field** | [`SourceQueryField__c`](../../reference/custom-metadata/check-fields.md#source-query-field-sourcequeryfield__c) | `Amount` |
| **How To Read Query Results** | [`QueryResultHandling__c`](../../reference/custom-metadata/check-fields.md#how-to-read-query-results-queryresulthandling__c) | Every record passes |
| **Comparison Operator** | [`ComparisonOperator__c`](../../reference/custom-metadata/check-fields.md#comparison-operator-comparisonoperator__c) | Greater than or equal |
| **Expected Value Comes From** | [`ExpectedValueSource__c`](../../reference/custom-metadata/check-fields.md#expected-value-comes-from-expectedvaluesource__c) | Fixed value |
| **Expected Value (Fixed)** | [`ExpectedFixedValue__c`](../../reference/custom-metadata/check-fields.md#expected-value-fixed-expectedfixedvalue__c) | `25000`; replace with the approved threshold |
| **If Query Finds No Records** | [`NoRowsResult__c`](../../reference/custom-metadata/check-fields.md#if-query-finds-no-records-norowsresult__c) | Skip |
| **If Field Value Is Empty** | [`EmptyValueHandling__c`](../../reference/custom-metadata/check-fields.md#if-field-value-is-empty-emptyvaluehandling__c) | Treat as not matching |
| **Max Query Rows (1-2000)** | [`MaxQueryRows__c`](../../reference/custom-metadata/check-fields.md#max-query-rows-1-2000-maxqueryrows__c) | `200`; raise only after confirming Accounts can exceed this many proposal-stage Opportunities |
| **Display: Found Text** | [`DisplayFoundText__c`](../../reference/custom-metadata/check-fields.md#display-found-text-displayfoundtext__c) | `Proposal-stage deal values: {!rhcResult.foundValue}` |
| **Display: Expected Text** | [`DisplayExpectedText__c`](../../reference/custom-metadata/check-fields.md#display-expected-text-displayexpectedtext__c) | `Qualification floor per proposal-stage deal: {!rhcResult.expectedValue}` |

## Optional configuration

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Check Description** | [`CheckDescription__c`](../../reference/custom-metadata/check-fields.md#check-description-checkdescription__c) | Applies an illustrative $25,000 qualification floor to every visible proposal-stage Opportunity; skips Accounts with none. |
| **Category** | [`Category__c`](../../reference/custom-metadata/check-fields.md#category-category__c) | Readiness |
| **Failure Severity** | [`FailureSeverity__c`](../../reference/custom-metadata/check-fields.md#failure-severity-failureseverity__c) | Warning |
| **Message When Failed** | [`FailureMessage__c`](../../reference/custom-metadata/check-fields.md#message-when-failed-failuremessage__c) | One or more proposal-stage Opportunities fall below the approved qualification floor. Review commercial fit before committing proposal resources. |
| **Message When Unable To Evaluate** | [`UnableToEvaluateMessage__c`](../../reference/custom-metadata/check-fields.md#message-when-unable-to-evaluate-unabletoevaluatemessage__c) | Unable to evaluate proposal-stage deal values. Confirm the user can read the queried fields. |
| **Applies To** | [`ApplicabilityMode__c`](../../reference/custom-metadata/check-fields.md#applies-to-applicabilitymode__c) | All records; empty-query handling creates the skip |
| **Prerequisite Check** | [`PrerequisiteCheck__c`](../../reference/custom-metadata/check-fields.md#prerequisite-check-prerequisitecheck__c) | Leave blank |
| **Fix Message** | [`FixMessage__c`](../../reference/custom-metadata/check-fields.md#fix-message-fixmessage__c) | Validate scope, pricing, and commercial fit. Requalify or return undersized deals to an earlier stage; do not inflate Amount to clear the check. |
| **Action Label** | [`ActionLabel__c`](../../reference/custom-metadata/check-fields.md#action-label-actionlabel__c) | `Review proposal-stage opportunities` |
| **Action URL** | [`ActionUrl__c`](../../reference/custom-metadata/check-fields.md#action-url-actionurl__c) | `/lightning/r/Account/{!record.Id}/related/Opportunities/view` |
| **Evaluation Order** | [`EvaluationOrder__c`](../../reference/custom-metadata/check-fields.md#evaluation-order-evaluationorder__c) | `70` |
| **Active** | [`IsActive__c`](../../reference/custom-metadata/check-fields.md#active-isactive__c) | Checked |
| **Publish User Result Event** | [`PublishUserResultEvent__c`](../../reference/custom-metadata/check-fields.md#publish-user-result-event-publishuserresultevent__c) | Unchecked |

Comparison Query, list, Formula, and Apex fields do not apply.

## What the user sees

The query rows and no-record behavior produce these health results and card values:

| Health result or card value | What the user sees |
| --- | --- |
| **`PASS`** | Every visible proposal-stage Opportunity meets or exceeds the qualification floor. |
| **`FAIL`** | At least one visible proposal-stage Opportunity falls below the floor, so the card shows Needs attention with Warning severity. |
| **`SKIPPED`** | An Account with no proposal-stage Opportunities is skipped because **No rows result** is **Skipped**. |
| **Found** | Found shows the proposal-stage deal values evaluated by the policy. |
| **Expected** | Expected shows the qualification floor applied to each returned deal. |

## Security and access

Record Health Check reads Amount and Stage on Opportunities with the running user's Salesforce access.

- **Every record passes** applies only to visible proposal-stage Opportunities. A hidden deal below the floor cannot be reported to the user.

- Missing Opportunity or Amount permission can show **Unable to evaluate**.

Before activation, test as a forecast user with restricted Opportunity sharing and confirm the result matches the records that user may review.

## Step 3: Test the Check

1. Add a proposal-stage Opportunity below the qualification floor. Confirm Warning.
2. Set every proposal-stage Amount at or above the floor, rerun, and confirm a pass.
3. Move all Opportunities out of the proposal stage and confirm skip.
4. Keep an undersized proposal-stage Opportunity that an administrator can see but a forecast user cannot. Run as
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

- [← Prev: Meaningful pipeline](./significant-opportunity.md) · [Next: Placeholder email cleanup →](./placeholder-contact-emails.md)
- [Browse Query examples](./README.md)
