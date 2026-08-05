# 06 · Account Owner Is Included on the Account Team

> [!NOTE]
> On this page, use Query list-membership mode to compare the current Account Owner from a record formula with the User IDs returned by an Account Team query.
>
> **Setup reference**
>
> Use the [Query reference](../../reference/evaluation/02-query.md) for the complete setup fields and behavior.

> [!IMPORTANT]
> This configuration is illustrative teaching metadata. It is not installed by the Framework package.

## Scenario

A sales manager is preparing an Account for an ownership handoff.

- The Account Owner is responsible for the customer relationship.
- The Account Team lists the Users who participate in the Account and their team roles.
- When the owner is missing from that team, the handoff presents two different answers about who is responsible.

> [!TIP]
> **Why use Record Health Check**
>
> Record Health Check searches the Account Team for the current Owner and gives the manager one ownership-alignment result during the handoff.

## What you will learn

| Skill | How this example teaches it |
| --- | --- |
| Build a list from related records | The query returns Account Team member user IDs. |
| Resolve a value from the current Account | The value to find is the Account Owner ID. |
| Verify list membership | The Rule checks whether the Owner appears in the team-member list. |

## Why use Verify with a query

| Evaluation Type | Why it fits |
| --- | --- |
| **Verify with a query** | Best fit. **Value to find in the list (formula)** reads `OwnerId` from the Account, and **Comparison Query** returns the Account Team User IDs to search. |
| **Verify with a formula** | An Account formula can read OwnerId but cannot search the related Account Team. |
| **Compare two queries** | Would require two query result sets when only the Account Team is queried; the value being searched for already exists on the Account. |
| **Verify with Apex** | Would add code for list membership that Verify with a query already supports. |

## Confirm the team policy first

This Rule requires an explicit Account Team Member row for the owner. The Account Owner's record
access does not replace that row. Use this pattern only when your organization has enabled Account
Teams and requires the owner to appear in the team list.

## Why not use a Validation Rule or Report

- **Validation Rule:** A Validation Rule on Account cannot search Account Team Members. A rule on Account Team Member also cannot require that one row exists for the Account Owner.

- **Report:** A report can find ownership gaps across many Accounts. It does not place the alignment result beside the other handoff checks on the Account.

## Configure the Rule

In **Setup → Custom Metadata Types → Record Health Check Rule → Manage Records**, create the Rule:

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Developer Name** | [`DeveloperName`](../../metadata/02-fields-check-rule.md#developer-name-developername) | `Owner_Is_On_Account_Team` |
| **Label** | [`MasterLabel`](../../metadata/02-fields-check-rule.md#label-masterlabel) | Owner Is on Account Team |
| **Check Set** | [`Record_Health_Check_Set__c`](../../metadata/02-fields-check-rule.md#check-set-record_health_check_set__c) | `Account_Related_Record_Review` |
| **Check Title** | [`CheckTitle__c`](../../metadata/02-fields-check-rule.md#check-title-checktitle__c) | Account Owner Is on the Account Team |
| **Evaluation Type** | [`EvaluationType__c`](../../metadata/02-fields-check-rule.md#evaluation-type-evaluationtype__c) | Verify with a query |
| **Source Query** | [`SourceQuery__c`](../../metadata/02-fields-check-rule.md#source-query-sourcequery__c) | Leave blank; list-membership mode reads its list from **Comparison Query** |
| **Comparison Query** | [`ComparisonQuery__c`](../../metadata/02-fields-check-rule.md#comparison-query-comparisonquery__c) | `SELECT UserId FROM AccountTeamMember WHERE AccountId = {!record.Id}` |
| **Comparison Query Field** | [`ComparisonQueryField__c`](../../metadata/02-fields-check-rule.md#comparison-query-field-comparisonqueryfield__c) | `UserId` |
| **Value to find in the list (formula)** | [`FindInListFormula__c`](../../metadata/02-fields-check-rule.md#value-to-find-in-the-list-formula-findinlistformula__c) | `OwnerId` |
| **How To Read Query Results** | [`QueryResultHandling__c`](../../metadata/02-fields-check-rule.md#how-to-read-query-results-queryresulthandling__c) | Compare as lists |
| **Comparison Operator** | [`ComparisonOperator__c`](../../metadata/02-fields-check-rule.md#comparison-operator-comparisonoperator__c) | List contains any |
| **If Query Finds No Records** | [`NoRowsResult__c`](../../metadata/02-fields-check-rule.md#if-query-finds-no-records-norowsresult__c) | Fail |
| **Max Query Rows (1-2000)** | [`MaxQueryRows__c`](../../metadata/02-fields-check-rule.md#max-query-rows-1-2000-maxqueryrows__c) | `200` |
| **Formula Result Type** | [`FormulaResultType__c`](../../metadata/02-fields-check-rule.md#formula-result-type-formularesulttype__c) | Text |

## Optional configuration

These values improve presentation. Change them for your process, or leave an optional field blank.

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Check Description** | [`CheckDescription__c`](../../metadata/02-fields-check-rule.md#check-description-checkdescription__c) | Confirms that the Account Owner appears among the visible Account Team Members. |
| **Category** | [`Category__c`](../../metadata/02-fields-check-rule.md#category-category__c) | Relationship coverage |
| **Failure Severity** | [`FailureSeverity__c`](../../metadata/02-fields-check-rule.md#failure-severity-failureseverity__c) | Warning |
| **Message When Failed** | [`FailureMessage__c`](../../metadata/02-fields-check-rule.md#message-when-failed-failuremessage__c) | The owner of `{!record.Name fallback="this record"}` is not on the Account Team. Add the owner when your handoff process requires that alignment. |
| **Message When Unable To Evaluate** | [`UnableToEvaluateMessage__c`](../../metadata/02-fields-check-rule.md#message-when-unable-to-evaluate-unabletoevaluatemessage__c) | Unable to compare the Account Owner with the Account Team. Confirm access to Account Owner and Account Team Members. |
| **Applies To** | [`ApplicabilityMode__c`](../../metadata/02-fields-check-rule.md#applies-to-applicabilitymode__c) | All records |
| **Prerequisite Rule** | [`PrerequisiteRule__c`](../../metadata/02-fields-check-rule.md#prerequisite-rule-prerequisiterule__c) | Leave blank |
| **Fix Message** | [`FixMessage__c`](../../metadata/02-fields-check-rule.md#fix-message-fixmessage__c) | Review the Account Team and add the owner with the team role approved by your organization. |
| **Action Label** | [`ActionLabel__c`](../../metadata/02-fields-check-rule.md#action-label-actionlabel__c) | `Review account team` |
| **Action URL** | [`ActionUrl__c`](../../metadata/02-fields-check-rule.md#action-url-actionurl__c) | `/lightning/r/Account/{!record.Id}/related/AccountTeamMembers/view` |
| **Evaluation Order** | [`EvaluationOrder__c`](../../metadata/02-fields-check-rule.md#evaluation-order-evaluationorder__c) | `110` |
| **Active** | [`IsActive__c`](../../metadata/02-fields-check-rule.md#active-isactive__c) | Checked only when Account Teams are enabled and your policy requires an explicit row for the owner |
| **Publish User Result Event** | [`PublishUserResultEvent__c`](../../metadata/02-fields-check-rule.md#publish-user-result-event-publishuserresultevent__c) | Unchecked |

This is the Query Evaluation Type's list-membership mode. **Source Query** stays blank because the
value comes from `OwnerId` and the candidate list comes from **Comparison Query**. Expected-value,
row-empty, Formula pass-condition, and Apex fields do not apply.

## Check Set configuration

Use these Check Set values:

| Check Set setting | Value |
| --- | --- |
| **Check Set** | `Account_Related_Record_Review` |
| **Object** | `Account` |
| **Card Title** | `Related Record Review` |
| **Card Subtitle** | Confirm the Account Owner appears on the Account Team. |
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

The record formula and Account Team query become these Framework outcomes and card values:

| Framework result or card value | What the user sees |
| --- | --- |
| **`PASS`** | The Account Owner's User ID appears in the visible Account Team Member User IDs. |
| **`FAIL`** | The visible Account Team is empty or does not include the Owner, so the card shows Needs attention with Warning severity. |
| **`SKIPPED`** | This configuration has no applicability check or prerequisite and treats an empty Account Team as `FAIL`, so it does not produce `SKIPPED`. |
| **Found** | Found shows the Account Owner ID resolved from the record formula. |
| **Expected** | Expected represents the visible Account Team User IDs searched for that Owner ID. |
| **`UNABLE_TO_EVALUATE`** | Missing access to `OwnerId`, `AccountTeamMember`, or `UserId` prevents a reliable comparison. |

## Security and access

Record Health Check compares the Account Owner with visible Account Team Members using the running user's Salesforce access.

- The owner can appear missing when the running user cannot see the matching Account Team Member row.

- Missing OwnerId, AccountTeamMember, or UserId permission can show **Unable to evaluate**.

Before activation, confirm the Rule with users who have the Account Team visibility intended for ownership handoffs.

## Test the Rule

1. Remove the Account Owner from the Account Team. Run the Rule and confirm Warning.
2. Add the Owner as an Account Team Member with an approved team role. Rerun and confirm a pass.
3. Change OwnerId to another active User who is not on the Account Team and confirm Warning.
4. Repeat the failing test as a user with limited Account Team access and confirm the result follows your sharing model.

## Failures and remedies

| What the user sees | What to check |
| --- | --- |
| A count or list is lower than expected | Confirm the query filters and the running user's sharing access to matching records. |
| Empty results behave incorrectly | Review **If Query Finds No Records** and, when used, **If Field Value Is Empty**. |
| **Unable to evaluate** | Confirm the object and field API names, SOQL syntax, and the running user's object and field permissions. |

## Related

- [← Prev: Placeholder email cleanup](05-placeholder-contact-emails.md) · [Next: Case review capacity →](07-high-priority-case-capacity.md)
- [Browse Query examples](README.md)
