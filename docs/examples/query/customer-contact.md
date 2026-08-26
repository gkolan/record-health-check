# Account Is Ready for Customer Handoff

> [!NOTE]
> On this page, create a Query Check that turns a related Contact count and a visible minimum into a clear Account handoff decision users can understand.
>
> **Setup reference**
>
> Use the [Query reference](../../reference/evaluation/query.md) for the complete setup fields and behavior.

## Scenario

A seller is preparing an Account for a handoff or account review.

- At least one Contact must be related so the next person knows who at the customer can be reached.
- An Account with no Contact often sends the next user back to spreadsheets, email, or the previous owner.
- That search delays the handoff and leaves the new owner without a confirmed customer relationship.

> [!TIP]
> **Why use Record Health Check**
>
> Record Health Check confirms that the Account has a customer Contact before handoff and provides a direct path to add one when needed.

## What you will learn

| Skill | How this example teaches it |
| --- | --- |
| Count related Salesforce records | SOQL counts Contacts related to the current Account. |
| Compare against a minimum | The Check passes when the count is greater than zero. |
| Show an actionable result | **Found** is the Contact count and **Expected** is the minimum. |

## Why use Verify with a query

| Evaluation Type | Why it fits |
| --- | --- |
| **Verify with a query** | Best fit. The query counts Contacts related to the Account and checks whether the count is greater than zero. |
| **Verify with a formula** | An Account formula cannot count related Contacts unless the Account already has a roll-up summary field. |
| **Verify with Apex** | Would require an Apex class to perform the same Contact count. |

## Why not use a Validation Rule or Report

- **Validation Rule:** A Validation Rule on Account cannot count related Contacts. Blocking an Account edit would also interrupt work outside the handoff.

- **Report:** A report can find many Accounts with no Contacts. It does not place the answer on the Account page beside the other handoff checks.

## Before you start

- Install Record Health Check.
- Assign **Record Health Check Admin** to the administrator creating the Check Set and Check.
- Confirm that intended users can read Contact and `AccountId` and can see the Contacts that should
  count for this handoff requirement.

## Read the query and prepare test data

`SELECT COUNT() FROM Contact WHERE AccountId = {!record.Id}` counts Contacts related to the open
Account. `{!record.Id}` is replaced with that Account's ID. **Greater than** expected `0` means one
or more visible Contacts pass; it does not mean the count should equal zero. Bare `COUNT()` returns
one aggregate value, so **One row or aggregate** is correct and Source Query Field stays blank.

Confirm Contact and Account Name access under **Permission Sets → [permission set] → Object
Settings**. Create a Contact from the Account's Contacts related list for the passing case instead
of relying on removing every existing Contact. If your business uses indirect Contacts, Person
Account relationships, or a junction object, adapt the query.

Add the card to the Account Lightning page, activate the intended assignment, assign **Record
Health Check User**, and test as the intended user. The card label is **Unable to Check** for an
`UNABLE_TO_EVALUATE` status.

## Step 1: Create the Check Set

In **Setup → Custom Metadata Types → Record Health Check Set → Manage Records**, select **New** and
create this Check Set:

| Setup field | Value |
| --- | --- |
| **Label** | Account Related Record Review |
| **Record Health Check Set Name** | `Account_Related_Record_Review` |
| **Object** | `Account` |
| **Card Title** | Related Record Review |
| **Card Subtitle** | Confirm at least one related Contact exists for handoff. |
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
| **Developer Name** | [`DeveloperName`](../../reference/custom-metadata/check-fields.md#developer-name-developername) | `Has_At_Least_One_Contact` |
| **Label** | [`MasterLabel`](../../reference/custom-metadata/check-fields.md#label-masterlabel) | Has At Least One Contact |
| **Check Set** | [`Record_Health_Check_Set__c`](../../reference/custom-metadata/check-fields.md#check-set-record_health_check_set__c) | `Account_Related_Record_Review` |
| **Check Title** | [`CheckTitle__c`](../../reference/custom-metadata/check-fields.md#check-title-checktitle__c) | Has At Least One Contact |
| **Evaluation Type** | [`EvaluationType__c`](../../reference/custom-metadata/check-fields.md#evaluation-type-evaluationtype__c) | Verify with a query |
| **Source Query** | [`SourceQuery__c`](../../reference/custom-metadata/check-fields.md#source-query-sourcequery__c) | `SELECT COUNT() FROM Contact WHERE AccountId = {!record.Id}` |
| **How To Read Query Results** | [`QueryResultHandling__c`](../../reference/custom-metadata/check-fields.md#how-to-read-query-results-queryresulthandling__c) | One row or aggregate |
| **Comparison Operator** | [`ComparisonOperator__c`](../../reference/custom-metadata/check-fields.md#comparison-operator-comparisonoperator__c) | Greater than |
| **Expected Value Comes From** | [`ExpectedValueSource__c`](../../reference/custom-metadata/check-fields.md#expected-value-comes-from-expectedvaluesource__c) | Fixed value |
| **Expected Value (Fixed)** | [`ExpectedFixedValue__c`](../../reference/custom-metadata/check-fields.md#expected-value-fixed-expectedfixedvalue__c) | `0` |
| **Max Query Rows (1-2000)** | [`MaxQueryRows__c`](../../reference/custom-metadata/check-fields.md#max-query-rows-1-2000-maxqueryrows__c) | `200` (default; `COUNT()` returns one result) |

## Optional configuration

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Check Description** | [`CheckDescription__c`](../../reference/custom-metadata/check-fields.md#check-description-checkdescription__c) | Checks whether the Account has at least one visible Contact. |
| **Category** | [`Category__c`](../../reference/custom-metadata/check-fields.md#category-category__c) | Relationship coverage |
| **Failure Severity** | [`FailureSeverity__c`](../../reference/custom-metadata/check-fields.md#failure-severity-failureseverity__c) | Warning |
| **Message When Failed** | [`FailureMessage__c`](../../reference/custom-metadata/check-fields.md#message-when-failed-failuremessage__c) | `{!record.Name fallback="this record"}` has no Contacts. Add at least one Contact before continuing. |
| **Message When Unable To Evaluate** | [`UnableToEvaluateMessage__c`](../../reference/custom-metadata/check-fields.md#message-when-unable-to-evaluate-unabletoevaluatemessage__c) | Unable to count Contacts. Confirm the user can read Contact and AccountId. |
| **Applies To** | [`ApplicabilityMode__c`](../../reference/custom-metadata/check-fields.md#applies-to-applicabilitymode__c) | All records |
| **Prerequisite Check** | [`PrerequisiteCheck__c`](../../reference/custom-metadata/check-fields.md#prerequisite-check-prerequisitecheck__c) | Leave blank |
| **Fix Message** | [`FixMessage__c`](../../reference/custom-metadata/check-fields.md#fix-message-fixmessage__c) | Add a Contact related to this Account. |
| **Action Label** | [`ActionLabel__c`](../../reference/custom-metadata/check-fields.md#action-label-actionlabel__c) | `Review contacts` |
| **Action URL** | [`ActionUrl__c`](../../reference/custom-metadata/check-fields.md#action-url-actionurl__c) | `/lightning/r/Account/{!record.Id}/related/Contacts/view` |
| **Evaluation Order** | [`EvaluationOrder__c`](../../reference/custom-metadata/check-fields.md#evaluation-order-evaluationorder__c) | `10` |
| **Active** | [`IsActive__c`](../../reference/custom-metadata/check-fields.md#active-isactive__c) | Checked |
| **Publish User Result Event** | [`PublishUserResultEvent__c`](../../reference/custom-metadata/check-fields.md#publish-user-result-event-publishuserresultevent__c) | Unchecked |

`COUNT()` always returns one aggregate result, even when the count is zero. Therefore **Source Query
Field**, **If Query Finds No Records**, and **If Field Value Is Empty** do not apply. Comparison Query,
list, Formula, and Apex fields also do not apply.

## What the user sees

The Contact count produces these health results and card values:

| Health result or card value | What the user sees |
| --- | --- |
| **`PASS`** | The Check passes when at least one visible related Contact exists. |
| **`FAIL`** | A count of zero shows Needs attention with Warning severity. |
| **`SKIPPED`** | Bare `COUNT()` returns zero rather than no rows, and this configuration has no applicability check or prerequisite, so it does not produce `SKIPPED`. |
| **Found** | Found shows the visible related Contact count when Found/Expected display is enabled on the Check Set. |
| **Expected** | Expected shows the fixed minimum required by the Check: `0` with the **Greater than** operator. |

## Security and access

Record Health Check counts Contacts related to the open Account with the running user's Salesforce access.

- Hidden Contacts are not included in the count, so two users can receive different valid results for the same Account.

- Missing Contact or AccountId permission can show **Unable to evaluate** instead of a zero count.

Before activation, run the no-Contact and has-Contact cases with the sharing access assigned to handoff users.

## Step 3: Test the Check

1. Remove all Contacts from an Account. Run the check and confirm Warning.
2. Add one Contact, rerun, and confirm a pass.
3. Keep one Contact that an administrator can see but the handoff user cannot see. Run as the
   handoff user and confirm Found is `0` and the result is `FAIL`.
4. Remove the user's Read access to Contact or `AccountId` in a sandbox-only permission test and
   confirm `UNABLE_TO_EVALUATE`. Restore access after the test.

## Failures and remedies

| What the user sees | What to check |
| --- | --- |
| A count or list is lower than expected | Confirm the query filters and the running user's sharing access to matching records. |
| Empty results behave incorrectly | Review **If Query Finds No Records** and, when used, **If Field Value Is Empty**. |
| **Unable to evaluate** | Confirm the object and field API names, SOQL syntax, and the running user's object and field permissions. |


## Related

- [Next: Pipeline next steps →](./opportunity-next-steps.md)
- [Browse Query examples](./README.md)
