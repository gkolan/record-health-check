# 04 · Branch Account Is Ready for Handoff

> [!NOTE]
> On this page, create a Formula Check that reads the parent Account's Billing City and gives users a direct action link when headquarters information blocks a branch handoff.
>
> **Setup reference**
>
> Use the [Formula reference](../../reference/evaluation/formula.md) for the complete setup fields and behavior.

## Scenario

A seller is preparing a branch Account for territory or service handoff.

- When the branch has a parent Account, the parent's Billing City must be present because the
  headquarters location determines regional coordination.
- A missing headquarters location can delay the handoff or send the branch to the wrong region.
- Top-level Accounts have no parent location to review.

> [!TIP]
> **Why use Record Health Check**
>
> Record Health Check identifies the missing headquarters information while the seller is reviewing the branch and provides a link to correct the parent Account.

## What you will learn

| Skill | How this example teaches it |
| --- | --- |
| Read a parent Salesforce record | The formula follows the Account parent relationship. |
| Check a handoff dependency | The branch passes only when headquarters information is ready. |
| Give users a direct next action | The Check can link from the branch to the record that needs attention. |

## Why use Verify with a formula

| Evaluation Type | Why it fits |
| --- | --- |
| **Verify with a formula** | Best fit. An Account formula can read Billing City from the Parent Account. |
| **Verify with a query** | Would add query setup for a Parent Account field the formula can already read. |
| **Verify with Apex** | Would require an Apex class without providing a better result. |

## Why not use a Validation Rule

- The missing Billing City belongs to the parent Account, not the branch Account being edited.

- Blocking the branch save would stop the user on the wrong record.

## Before you start

- Install Record Health Check.
- Assign **Record Health Check Admin** to the administrator creating the Check Set and Check.
- Confirm that intended users can read the branch Account, Parent Account lookup, parent Account,
  and parent Billing City.
- Confirm that the same users have permission to edit the parent Account if they will use the action
  link.

## Confirm the example fits your org

`ParentId` is the Account's Parent Account lookup. `Parent.BillingCity` follows that one lookup to
read the parent's Billing City. Confirm both fields under **Setup → Object Manager → Account →
Fields & Relationships**. If headquarters is stored on a custom object or on the branch itself,
adapt the relationship and do not copy this formula unchanged.

For test data, create or open a parent Account, create a child Account with **Parent Account** set
to it, and change Billing City on the parent. The action URL opens the parent only when the running
user can read `ParentId`; a blank or inaccessible parent can produce Unable to Check rather than a
business skip. Test read access to the child, parent, and parent Billing City separately from edit
access to the action destination.

Add the card to the child Account Lightning page, activate the intended assignment, and test as a
user with **Record Health Check User**.

## Step 1: Create the Check Set

In **Setup → Custom Metadata Types → Record Health Check Set → Manage Records**, select **New** and
create this Check Set:

| Setup field | Value |
| --- | --- |
| **Label** | Account Data Quality |
| **Record Health Check Set Name** | `Account_Data_Quality` |
| **Object** | `Account` |
| **Card Title** | Account Data Quality |
| **Card Subtitle** | Confirm the parent Account Billing City before branch handoff. |
| **When Checks Run** | When the user clicks Run |
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
| **Developer Name** | [`DeveloperName`](../../metadata/fields-check.md#developer-name-developername) | `Parent_Account_Has_Billing_City` |
| **Label** | [`MasterLabel`](../../metadata/fields-check.md#label-masterlabel) | Parent Account Has Billing City |
| **Check Set** | [`Record_Health_Check_Set__c`](../../metadata/fields-check.md#check-set-record_health_check_set__c) | `Account_Data_Quality` |
| **Check Title** | [`CheckTitle__c`](../../metadata/fields-check.md#check-title-checktitle__c) | Parent Account Has Billing City |
| **Evaluation Type** | [`EvaluationType__c`](../../metadata/fields-check.md#evaluation-type-evaluationtype__c) | Verify with a formula |
| **Pass Condition** | [`PassConditionFormula__c`](../../metadata/fields-check.md#pass-condition-passconditionformula__c) | `NOT(ISBLANK(Parent.BillingCity))` |
| **Applies To** | [`ApplicabilityMode__c`](../../metadata/fields-check.md#applies-to-applicabilitymode__c) | When a formula is true |
| **Applies When (Formula)** | [`ApplicabilityFormula__c`](../../metadata/fields-check.md#applies-when-formula-applicabilityformula__c) | `NOT(ISBLANK(ParentId))` |

## Optional configuration

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Check Description** | [`CheckDescription__c`](../../metadata/fields-check.md#check-description-checkdescription__c) | Checks whether the parent Account has Billing City populated. |
| **Category** | [`Category__c`](../../metadata/fields-check.md#category-category__c) | Completeness |
| **Failure Severity** | [`FailureSeverity__c`](../../metadata/fields-check.md#failure-severity-failureseverity__c) | Warning |
| **Message When Failed** | [`FailureMessage__c`](../../metadata/fields-check.md#message-when-failed-failuremessage__c) | The parent Account for `{!record.Name fallback="this branch Account"}` is missing Billing City. Update Billing City on the parent Account. |
| **Message When Unable To Evaluate** | [`UnableToEvaluateMessage__c`](../../metadata/fields-check.md#message-when-unable-to-evaluate-unabletoevaluatemessage__c) | Unable to read the parent Billing City. |
| **Prerequisite Check** | [`PrerequisiteCheck__c`](../../metadata/fields-check.md#prerequisite-check-prerequisitecheck__c) | Leave blank |
| **Fix Message** | [`FixMessage__c`](../../metadata/fields-check.md#fix-message-fixmessage__c) | Open the parent Account and enter Billing City. |
| **Action Label** | [`ActionLabel__c`](../../metadata/fields-check.md#action-label-actionlabel__c) | `Edit parent billing address` |
| **Action URL** | [`ActionUrl__c`](../../metadata/fields-check.md#action-url-actionurl__c) | `/lightning/r/Account/{!record.ParentId}/edit` |
| **Evaluation Order** | [`EvaluationOrder__c`](../../metadata/fields-check.md#evaluation-order-evaluationorder__c) | `70` |
| **Active** | [`IsActive__c`](../../metadata/fields-check.md#active-isactive__c) | Checked |
| **Publish User Result Event** | [`PublishUserResultEvent__c`](../../metadata/fields-check.md#publish-user-result-event-publishuserresultevent__c) | Unchecked |

The applicability formula prevents the action link from rendering on a top-level Account with no
Parent ID. A blank URL token also suppresses the link, so the URL never opens a fabricated fallback
record. Leave **Display: Found Formula** and **Display: Expected Formula** blank and leave **Formula
Result Type** as **Auto**. Query and Apex fields do not apply.

If the running user cannot read the parent relationship or field, the check may show unable to evaluate rather than a false pass.

## What the user sees

Formula applicability and the parent-field check produce these health results and card values:

| Health result or card value | What the user sees |
| --- | --- |
| **`PASS`** | A child Account passes when its parent Account has Billing City. |
| **`FAIL`** | A child Account whose parent has blank Billing City shows Needs attention with Warning severity and an action link to the parent. |
| **`SKIPPED`** | A top-level Account is skipped because it has no parent handoff requirement. |
| **Found** | Blank because **Display: Found Formula** is blank. |
| **Expected** | The expanded details label the Pass Condition as **Passes when** and show `NOT(ISBLANK(Parent.BillingCity))`. |

## Security and access

Record Health Check reads the parent Account and its Billing City with the running user's Salesforce access.

- If the user cannot read the parent Account or Billing City, the Check may show **Unable to evaluate**. It does not treat a value the user cannot access as blank.

- The **Edit parent billing address** link opens the parent Account. It does not give the user permission to edit the Account or Billing City.

Before activation, test both a blank and populated parent Billing City with the access intended
handoff users receive.

## Step 3: Test the Check

1. On a child Account, clear Billing City on the parent. Confirm Warning.
2. Populate the parent's Billing City, rerun, and confirm a pass.
3. Clear Parent Account and confirm the Check is skipped.
4. Repeat the child Account test as a user who cannot read the parent's Billing City and confirm the access result does not expose the hidden value.

## Failures and remedies

| What the user sees | What to check |
| --- | --- |
| An expected value fails | Confirm the field values, field types, and blank or picklist functions used by the formula. |
| The Check runs on the wrong records | Review **Applies To** and **Applies When (Formula)** separately from the Pass Condition. |
| **Unable to evaluate** | Confirm the formula syntax and the running user's access to every referenced field. |

## Related

- [← Prev: Partner regional assignment](partner-regional-assignment.md) · [Next: Program eligibility →](program-eligibility.md)
- [Browse Formula examples](README.md)
