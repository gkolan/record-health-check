# 03 · Account Team Covers Open Opportunity Owners

> [!NOTE]
> On this page, compare Account Team members with open Opportunity owners to expose every owner who is missing from the team before a sales handoff.
>
> **Setup reference**
>
> Use the [Compare-two-queries reference](../../reference/reference-compare-two-queries.md) for the complete setup fields and behavior.

> [!IMPORTANT]
> This configuration is illustrative teaching metadata. It is not installed by the Framework package.

## Scenario

A sales manager prepares an Account for a team handoff.

- Different users own the Account's open Opportunities.
- The manager currently compares the **Account Team** with each open Opportunity owner to find coverage gaps.

> [!TIP]
> **Why use Record Health Check**
>
> Record Health Check compares open Opportunity owners with Account Team members and identifies the owners who are missing from the team. The sales manager can resolve coverage gaps from the Account review instead of comparing the two lists manually during the handoff.

## Before you configure

Use this Rule only when Account Teams are enabled and your approved process requires every open Opportunity owner to be an Account Team member.

## What you will learn

| Skill | How this example teaches it |
| --- | --- |
| Compare two lists of Salesforce users | The queries return Account Team members and open Opportunity Owners. |
| Require complete list coverage | Every Opportunity Owner must appear on the Account Team. |
| Test missing coverage | Removing one team member demonstrates a clear failing result. |

## Why use Compare two queries

| Evaluation Type | Why it fits |
| --- | --- |
| **Compare two queries** | Best fit. One query lists open Opportunity owners. The other lists Account Team members. **Lists contain all** confirms that every owner is on the Account Team. |
| **Verify with a query** | Verify with a query can return one list, but this check needs to compare both lists. |
| **Verify with a formula** | An Account formula cannot review Account Team members and related Opportunity owners. |

## Why not use a Validation Rule or Report

- **Validation Rule:** Account Team membership and Opportunity ownership are stored on different records. A Validation Rule cannot compare both lists.

- **Report:** A report can monitor many Accounts. It does not place the answer directly on the Account being handed off.

## Configure the Rule

In **Setup → Custom Metadata Types → Record Health Check Rule → Manage Records**, create the Rule:

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Developer Name** | [`DeveloperName`](../../metadata/fields-check-rule.md#developer-name-developername) | `Account_Team_Covers_Opportunity_Owners` |
| **Label** | [`MasterLabel`](../../metadata/fields-check-rule.md#label-masterlabel) | Account Team Covers Opportunity Owners |
| **Check Set** | [`Record_Health_Check_Set__c`](../../metadata/fields-check-rule.md#check-set-record_health_check_set__c) | `Account_Record_Alignment` |
| **Check Title** | [`CheckTitle__c`](../../metadata/fields-check-rule.md#check-title-checktitle__c) | Account Team Covers Opportunity Owners |
| **Evaluation Type** | [`EvaluationType__c`](../../metadata/fields-check-rule.md#evaluation-type-evaluationtype__c) | Compare two queries |
| **Source Query** | [`SourceQuery__c`](../../metadata/fields-check-rule.md#source-query-sourcequery__c) | `SELECT OwnerId FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false` |
| **Source Query Field** | [`SourceQueryField__c`](../../metadata/fields-check-rule.md#source-query-field-sourcequeryfield__c) | `OwnerId` |
| **Comparison Query** | [`ComparisonQuery__c`](../../metadata/fields-check-rule.md#comparison-query-comparisonquery__c) | `SELECT UserId FROM AccountTeamMember WHERE AccountId = {!record.Id}` |
| **Comparison Query Field** | [`ComparisonQueryField__c`](../../metadata/fields-check-rule.md#comparison-query-field-comparisonqueryfield__c) | `UserId` |
| **How To Read Query Results** | [`QueryResultHandling__c`](../../metadata/fields-check-rule.md#how-to-read-query-results-queryresulthandling__c) | Compare as lists |
| **Comparison Operator** | [`ComparisonOperator__c`](../../metadata/fields-check-rule.md#comparison-operator-comparisonoperator__c) | Lists contain all |
| **If Query Finds No Records** | [`NoRowsResult__c`](../../metadata/fields-check-rule.md#if-query-finds-no-records-norowsresult__c) | Fail |
| **Applies To** | [`ApplicabilityMode__c`](../../metadata/fields-check-rule.md#applies-to-applicabilitymode__c) | When a count query matches |
| **Applies When (Count Query)** | [`ApplicabilityCountQuery__c`](../../metadata/fields-check-rule.md#applies-when-count-query-applicabilitycountquery__c) | `SELECT COUNT() FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false` |
| **Count Must Be** | [`ApplicabilityCountOperator__c`](../../metadata/fields-check-rule.md#count-must-be-applicabilitycountoperator__c) | Greater than |
| **Count Value** | [`ApplicabilityCountThreshold__c`](../../metadata/fields-check-rule.md#count-value-applicabilitycountthreshold__c) | `0` |

## Optional configuration

These values improve presentation. Change them for your process, or leave an optional field blank.

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Failure Severity** | [`FailureSeverity__c`](../../metadata/fields-check-rule.md#failure-severity-failureseverity__c) | Warning |
| **Message When Failed** | [`FailureMessage__c`](../../metadata/fields-check-rule.md#message-when-failed-failuremessage__c) | On `{!record.Name fallback="this record"}`, one or more open Opportunity owners are missing from the Account Team. Review the missing users before the handoff. |
| **Check Description** | [`CheckDescription__c`](../../metadata/fields-check-rule.md#check-description-checkdescription__c) | Checks that the Account Team includes every open Opportunity owner. |
| **Category** | [`Category__c`](../../metadata/fields-check-rule.md#category-category__c) | Relationship coverage |
| **Message When Unable To Evaluate** | [`UnableToEvaluateMessage__c`](../../metadata/fields-check-rule.md#message-when-unable-to-evaluate-unabletoevaluatemessage__c) | Unable to compare the query results. Confirm the user can read every object and field named in both queries. |
| **Prerequisite Rule** | [`PrerequisiteRule__c`](../../metadata/fields-check-rule.md#prerequisite-rule-prerequisiterule__c) | Leave blank |
| **Fix Message** | [`FixMessage__c`](../../metadata/fields-check-rule.md#fix-message-fixmessage__c) | Compare the missing Opportunity owners with the approved Account Team and update the appropriate records. |
| **Action Label** | [`ActionLabel__c`](../../metadata/fields-check-rule.md#action-label-actionlabel__c) | Leave blank |
| **Action URL** | [`ActionUrl__c`](../../metadata/fields-check-rule.md#action-url-actionurl__c) | Leave blank; Account Team availability and navigation depend on org setup |
| **Evaluation Order** | [`EvaluationOrder__c`](../../metadata/fields-check-rule.md#evaluation-order-evaluationorder__c) | `10` |
| **Active** | [`IsActive__c`](../../metadata/fields-check-rule.md#active-isactive__c) | Checked only after confirming this example matches your business process |
| **Publish User Result Event** | [`PublishUserResultEvent__c`](../../metadata/fields-check-rule.md#publish-user-result-event-publishuserresultevent__c) | Unchecked |

Comparison display text, event publishing, and prerequisite behavior are optional. Expected-value, value-to-find, Formula-result, and Apex fields do not apply to Compare two queries.

## Check Set configuration

Use these Check Set values:

| Check Set setting | Value |
| --- | --- |
| **Check Set** | `Account_Record_Alignment` |
| **Object** | `Account` |
| **Card Title** | `Account Record Alignment` |
| **Card Subtitle** | Add one short sentence explaining what the card reviews. |
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

The Opportunity Owner and Account Team lists become these Framework outcomes and card values:

| Framework result or card value | What the user sees |
| --- | --- |
| **`PASS`** | Every open Opportunity owner appears on the Account Team. |
| **`FAIL`** | One or more open Opportunity owners is missing from the Account Team, so the card shows Needs attention. |
| **`SKIPPED`** | The Account has no open Opportunities, so there are no required owners to compare. |
| **Found** | Found represents the User IDs returned for open Opportunity owners. |
| **Expected** | Expected represents the Account Team User IDs that must contain every open Opportunity owner. |

## Security and access

Record Health Check builds the Opportunity Owner and Account Team lists with the running user's Salesforce access.

- The result includes only open Opportunity `OwnerId` values and Account Team Member `UserId` values the running user can access.

- Hidden Opportunities remove required owners from the first list; hidden Account Team rows remove coverage from the second list.

- Missing Opportunity, OwnerId, AccountTeamMember, or UserId permission can show **Unable to evaluate**.

- Use a sales manager whose Opportunity and Account Team visibility matches the intended handoff process.

## Test the Rule

1. Enable Account Teams in a test org. Create an open Opportunity owned by a user who is not on the Account Team and confirm Warning.
2. Add that user to the Account Team, rerun, and confirm a pass.
3. Close all Opportunities and confirm the Rule is skipped.
4. Repeat the missing-team-member test as a user with restricted Account Team access and confirm the list comparison follows that user's sharing access.

## Failures and remedies

| What the user sees | What to check |
| --- | --- |
| A count or list is lower than expected | Confirm the query filters and the running user's sharing access to matching records. |
| Empty results behave incorrectly | Review **If Query Finds No Records** and, when used, **If Field Value Is Empty**. |
| **Unable to evaluate** | Confirm the object and field API names, SOQL syntax, and the running user's object and field permissions. |

## Related

- [← Prev: Product continuity](02-open-pipeline-product-continuity.md)
- [Browse Compare two queries examples](README.md)
