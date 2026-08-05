# 02 · Open Pipeline Includes a Previously Purchased Product

> [!NOTE]
> On this page, compare two SOQL lists to show whether the Account's open pipeline includes at least one Product the customer has already purchased.
>
> **Setup reference**
>
> Use the [Compare-two-queries reference](../../reference/evaluation/03-compare-two-queries.md) for the complete setup fields and behavior.

> [!IMPORTANT]
> This configuration is illustrative teaching metadata. It is not installed by the Framework package.

## Scenario

An account manager is preparing an existing customer for a pipeline review.

- The customer has products recorded on closed-won Opportunities.
- The open Opportunities also contain proposed products.
- The manager must compare the two histories to see whether the current pipeline includes any product the customer already owns.

> [!TIP]
> **Why use Record Health Check**
>
> Record Health Check compares the open and purchased Product lists on the Account. The manager can see whether they overlap without opening every Opportunity and comparing its **Products** related list manually.

## What you will learn

| Skill | How this example teaches it |
| --- | --- |
| Return a list from each SOQL query | One list represents open pipeline; the other represents purchase history. |
| Compare lists for overlap | The Rule passes when the two Product lists share a value. |
| Explain list-based results | The card connects product continuity to an Account planning decision. |

## Why use Compare two queries

| Evaluation Type | Why it fits |
| --- | --- |
| **Compare two queries** | Best fit. One query returns Product IDs from open Opportunities. The other returns Product IDs from closed-won Opportunities. **Lists overlap** passes when at least one Product ID appears in both lists. |
| **Verify with a query** | Can inspect one product list, but cannot compare two query-produced lists with the **Lists overlap** operator. |
| **Verify with a formula** | An Account formula cannot build Product lists from related Opportunity Products. |
| **Verify with Apex** | Would add code for a two-list comparison already supported by Compare two queries. |

## Why not use a Validation Rule or Report

- **Validation Rule:** A Validation Rule cannot compare Product IDs across the Account's open and closed-won Opportunity Products.

- **Report:** A joined or custom report can support portfolio analysis. It does not place this product-continuity decision beside the other Account review checks.

## Configure the Rule

In **Setup → Custom Metadata Types → Record Health Check Rule → Manage Records**, create the Rule:

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Developer Name** | [`DeveloperName`](../../metadata/02-fields-check-rule.md#developer-name-developername) | `Open_Pipeline_Uses_Purchased_Product` |
| **Label** | [`MasterLabel`](../../metadata/02-fields-check-rule.md#label-masterlabel) | Open Pipeline Uses Purchased Product |
| **Check Set** | [`Record_Health_Check_Set__c`](../../metadata/02-fields-check-rule.md#check-set-record_health_check_set__c) | `Account_Record_Alignment` |
| **Check Title** | [`CheckTitle__c`](../../metadata/02-fields-check-rule.md#check-title-checktitle__c) | Open Pipeline Includes a Previously Purchased Product |
| **Evaluation Type** | [`EvaluationType__c`](../../metadata/02-fields-check-rule.md#evaluation-type-evaluationtype__c) | Compare two queries |
| **Source Query** | [`SourceQuery__c`](../../metadata/02-fields-check-rule.md#source-query-sourcequery__c) | `SELECT Product2Id FROM OpportunityLineItem WHERE Opportunity.AccountId = {!record.Id} AND Opportunity.IsClosed = false` |
| **Source Query Field** | [`SourceQueryField__c`](../../metadata/02-fields-check-rule.md#source-query-field-sourcequeryfield__c) | `Product2Id` |
| **Comparison Query** | [`ComparisonQuery__c`](../../metadata/02-fields-check-rule.md#comparison-query-comparisonquery__c) | `SELECT Product2Id FROM OpportunityLineItem WHERE Opportunity.AccountId = {!record.Id} AND Opportunity.IsWon = true` |
| **Comparison Query Field** | [`ComparisonQueryField__c`](../../metadata/02-fields-check-rule.md#comparison-query-field-comparisonqueryfield__c) | `Product2Id` |
| **How To Read Query Results** | [`QueryResultHandling__c`](../../metadata/02-fields-check-rule.md#how-to-read-query-results-queryresulthandling__c) | Compare as lists |
| **Comparison Operator** | [`ComparisonOperator__c`](../../metadata/02-fields-check-rule.md#comparison-operator-comparisonoperator__c) | Lists overlap |
| **If Query Finds No Records** | [`NoRowsResult__c`](../../metadata/02-fields-check-rule.md#if-query-finds-no-records-norowsresult__c) | Skip |
| **Applies To** | [`ApplicabilityMode__c`](../../metadata/02-fields-check-rule.md#applies-to-applicabilitymode__c) | When a count query matches |
| **Applies When (Count Query)** | [`ApplicabilityCountQuery__c`](../../metadata/02-fields-check-rule.md#applies-when-count-query-applicabilitycountquery__c) | `SELECT COUNT() FROM OpportunityLineItem WHERE Opportunity.AccountId = {!record.Id} AND Opportunity.IsWon = true` |
| **Count Must Be** | [`ApplicabilityCountOperator__c`](../../metadata/02-fields-check-rule.md#count-must-be-applicabilitycountoperator__c) | Greater than |
| **Count Value** | [`ApplicabilityCountThreshold__c`](../../metadata/02-fields-check-rule.md#count-value-applicabilitycountthreshold__c) | `0` |

## Optional configuration

These values improve presentation. Change them for your process, or leave an optional field blank.

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Failure Severity** | [`FailureSeverity__c`](../../metadata/02-fields-check-rule.md#failure-severity-failureseverity__c) | Info |
| **Message When Failed** | [`FailureMessage__c`](../../metadata/02-fields-check-rule.md#message-when-failed-failuremessage__c) | On `{!record.Name fallback="this record"}`, open pipeline products do not overlap the products recorded on closed-won Opportunities. Confirm whether the proposal should include an existing product. |
| **Check Description** | [`CheckDescription__c`](../../metadata/02-fields-check-rule.md#check-description-checkdescription__c) | Compares open-pipeline Product IDs with previously purchased Product IDs. |
| **Category** | [`Category__c`](../../metadata/02-fields-check-rule.md#category-category__c) | Consistency |
| **Message When Unable To Evaluate** | [`UnableToEvaluateMessage__c`](../../metadata/02-fields-check-rule.md#message-when-unable-to-evaluate-unabletoevaluatemessage__c) | Unable to compare the query results. Confirm the user can read every object and field named in both queries. |
| **Prerequisite Rule** | [`PrerequisiteRule__c`](../../metadata/02-fields-check-rule.md#prerequisite-rule-prerequisiterule__c) | Leave blank |
| **Fix Message** | [`FixMessage__c`](../../metadata/02-fields-check-rule.md#fix-message-fixmessage__c) | Review the open and closed-won Opportunity Products. Correct the product selection only when it does not match the intended sale. |
| **Action Label** | [`ActionLabel__c`](../../metadata/02-fields-check-rule.md#action-label-actionlabel__c) | `Review opportunities` |
| **Action URL** | [`ActionUrl__c`](../../metadata/02-fields-check-rule.md#action-url-actionurl__c) | `/lightning/r/Account/{!record.Id}/related/Opportunities/view` |
| **Evaluation Order** | [`EvaluationOrder__c`](../../metadata/02-fields-check-rule.md#evaluation-order-evaluationorder__c) | `10` |
| **Active** | [`IsActive__c`](../../metadata/02-fields-check-rule.md#active-isactive__c) | Checked only after confirming this example matches your business process |
| **Publish User Result Event** | [`PublishUserResultEvent__c`](../../metadata/02-fields-check-rule.md#publish-user-result-event-publishuserresultevent__c) | Unchecked |

The applicability count keeps the Rule focused on Accounts with purchased-product history. **If
Query Finds No Records** then skips an Account whose open Opportunities have no Opportunity
Products. Expected-value, value-to-find, Formula-result, and Apex fields do not apply.

## Check Set configuration

Use these Check Set values:

| Check Set setting | Value |
| --- | --- |
| **Check Set** | `Account_Record_Alignment` |
| **Object** | `Account` |
| **Card Title** | `Account Record Alignment` |
| **Card Subtitle** | Confirm open pipeline Products overlap purchased Products. |
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

The two Product lists and no-row behavior become these Framework outcomes and card values:

| Framework result or card value | What the user sees |
| --- | --- |
| **`PASS`** | At least one Product ID appears in both the open-pipeline and closed-won lists. |
| **`FAIL`** | Both lists contain Products but none of their Product IDs overlap, so the card shows Needs attention. |
| **`SKIPPED`** | The Account has no closed-won Opportunity Product history or no open-pipeline Opportunity Products to compare. |
| **Found** | Found represents the Product IDs returned by the open-pipeline query. |
| **Expected** | Expected represents the Product IDs returned by the closed-won history query. |

## Security and access

Record Health Check builds both Product lists with the running user's Salesforce access.

- Open and closed-won Opportunities, their Opportunity Products, and Product2Id.

- A hidden Opportunity Product can remove the only overlapping Product ID and change Pass to Needs attention or Skip.

- Missing OpportunityLineItem or Product2Id permission can show **Unable to evaluate**.

- Run the overlap and no-overlap cases with the Opportunity Product access assigned to account managers.

## Test the Rule

1. Add Product A to a closed-won Opportunity and Product B to an open Opportunity. Run the Rule and confirm Info.
2. Add Product A to the open Opportunity, rerun, and confirm a pass because the lists overlap.
3. Remove all Opportunity Products from the open pipeline and confirm Skip.
4. Test an Account with open Opportunity Products but no closed-won Opportunity Products and confirm the applicability count produces Skip.
5. Repeat the failing test with restricted Opportunity Product access and confirm the result follows the running user's access.

## Failures and remedies

| What the user sees | What to check |
| --- | --- |
| A count or list is lower than expected | Confirm the query filters and the running user's sharing access to matching records. |
| Empty results behave incorrectly | Review **If Query Finds No Records** and, when used, **If Field Value Is Empty**. |
| **Unable to evaluate** | Confirm the object and field API names, SOQL syntax, and the running user's object and field permissions. |

## Related

- [← Prev: Opportunity Contact Role coverage](01-opportunity-contact-role-coverage.md) · [Next: Account Team coverage →](03-account-team-opportunity-coverage.md)
- [Browse Compare two queries examples](README.md)
