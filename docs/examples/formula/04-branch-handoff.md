# 04 · Branch Account Is Ready for Handoff

> [!NOTE]
> On this page, create a Formula Rule that reads the parent Account's Billing City and gives users a direct action link when headquarters information blocks a branch handoff.
>
> **Setup reference**
>
> Use the [Formula reference](../../reference/evaluation/formula.md) for the complete setup fields and behavior.

## Scenario

A seller is preparing a branch Account for territory or service handoff.

- When the branch has a parent Account, the parent's Billing City must be present because the team uses the headquarters location for regional coordination.
- A missing headquarters location can delay the handoff or send the branch to the wrong regional team.
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
| Give users a direct next action | The Rule can link from the branch to the record that needs attention. |

## Why use Verify with a formula

| Evaluation Type | Why it fits |
| --- | --- |
| **Verify with a formula** | Best fit. An Account formula can read Billing City from the Parent Account. |
| **Verify with a query** | Would add query setup for a Parent Account field the formula can already read. |
| **Verify with Apex** | Would require an Apex class without providing a better result. |

## Why not use a Validation Rule

- The missing Billing City belongs to the parent Account, not the branch Account being edited.

- Blocking the branch save would stop the user on the wrong record.

## Configure the Rule

In **Setup → Custom Metadata Types → Record Health Check Rule → Manage Records**, create the Rule:

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Developer Name** | [`DeveloperName`](../../metadata/fields-check-rule.md#developer-name-developername) | `Parent_Account_Has_Billing_City` |
| **Label** | [`MasterLabel`](../../metadata/fields-check-rule.md#label-masterlabel) | Parent Account Has Billing City |
| **Check Set** | [`Record_Health_Check_Set__c`](../../metadata/fields-check-rule.md#check-set-record_health_check_set__c) | `Account_Data_Quality` |
| **Check Title** | [`CheckTitle__c`](../../metadata/fields-check-rule.md#check-title-checktitle__c) | Parent Account Has Billing City |
| **Evaluation Type** | [`EvaluationType__c`](../../metadata/fields-check-rule.md#evaluation-type-evaluationtype__c) | Verify with a formula |
| **Pass Condition** | [`PassConditionFormula__c`](../../metadata/fields-check-rule.md#pass-condition-passconditionformula__c) | `NOT(ISBLANK(Parent.BillingCity))` |
| **Applies To** | [`ApplicabilityMode__c`](../../metadata/fields-check-rule.md#applies-to-applicabilitymode__c) | When a formula is true |
| **Applies When (Formula)** | [`ApplicabilityFormula__c`](../../metadata/fields-check-rule.md#applies-when-formula-applicabilityformula__c) | `NOT(ISBLANK(ParentId))` |

## Optional configuration

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Check Description** | [`CheckDescription__c`](../../metadata/fields-check-rule.md#check-description-checkdescription__c) | Checks whether the parent Account has Billing City populated. |
| **Category** | [`Category__c`](../../metadata/fields-check-rule.md#category-category__c) | Completeness |
| **Failure Severity** | [`FailureSeverity__c`](../../metadata/fields-check-rule.md#failure-severity-failureseverity__c) | Warning |
| **Message When Failed** | [`FailureMessage__c`](../../metadata/fields-check-rule.md#message-when-failed-failuremessage__c) | The parent account is missing Billing City. Update Billing City on the parent Account. |
| **Message When Unable To Evaluate** | [`UnableToEvaluateMessage__c`](../../metadata/fields-check-rule.md#message-when-unable-to-evaluate-unabletoevaluatemessage__c) | Unable to read the parent Billing City. |
| **Prerequisite Rule** | [`PrerequisiteRule__c`](../../metadata/fields-check-rule.md#prerequisite-rule-prerequisiterule__c) | Leave blank |
| **Fix Message** | [`FixMessage__c`](../../metadata/fields-check-rule.md#fix-message-fixmessage__c) | Open the parent Account and enter Billing City. |
| **Action Label** | [`ActionLabel__c`](../../metadata/fields-check-rule.md#action-label-actionlabel__c) | `Edit parent billing address` |
| **Action URL** | [`ActionUrl__c`](../../metadata/fields-check-rule.md#action-url-actionurl__c) | Edit page for the parent Account, with a fallback Id: copy it from below the table |
| **Evaluation Order** | [`EvaluationOrder__c`](../../metadata/fields-check-rule.md#evaluation-order-evaluationorder__c) | `70` |
| **Active** | [`IsActive__c`](../../metadata/fields-check-rule.md#active-isactive__c) | Checked |
| **Publish User Result Event** | [`PublishUserResultEvent__c`](../../metadata/fields-check-rule.md#publish-user-result-event-publishuserresultevent__c) | Unchecked |

Copy this value into **Action URL**:

```text
/lightning/r/Account/{!record.ParentId fallback="001000000000000AAA"}/edit
```

The applicability formula prevents the action link from rendering on a top-level Account with no
Parent ID. Leave Found and Expected display formulas and Formula Result Type blank; Query and Apex
fields do not apply.

## Check Set configuration

Use these Check Set values:

| Check Set setting | Value |
| --- | --- |
| **Check Set** | `Account_Data_Quality` |
| **Object** | `Account` |
| **Card Title** | `Account Data Quality` |
| **Card Subtitle** | Confirm the parent Account billing city before branch handoff. |
| **When Checks Run** | Run on request |
| **Reveal Mode** | One by one |
| **Passed Checks** | Show each check |
| **Skipped Checks** | Show each check |
| **Found/Expected Display** | On demand |
| **Stop after a system error** | Unchecked |
| **Show Diagnostics** | Unchecked; enable temporarily only for authorized troubleshooting |
| **Publish User Run Event** | Unchecked |
| **Active** | Checked |

If the running user cannot read the parent relationship or field, the check may show unable to evaluate rather than a false pass.

## What the user sees

Formula applicability and the parent-field check become these Framework outcomes and card values:

| Framework result or card value | What the user sees |
| --- | --- |
| **`PASS`** | A child Account passes when its parent Account has Billing City. |
| **`FAIL`** | A child Account whose parent has blank Billing City shows Needs attention with Warning severity and an action link to the parent. |
| **`SKIPPED`** | A top-level Account is skipped because it has no parent handoff requirement. |
| **Found** | Found shows the parent Account's Billing City value when the user reveals Found and Expected. |
| **Expected** | Expected shows that the parent Billing City must be populated when the user reveals Found and Expected. |

## Security and access

Record Health Check reads the parent Account and its Billing City with the running user's Salesforce access.

- If the user cannot read the parent Account or Billing City, the Rule may show **Unable to evaluate**. It does not treat a value the user cannot access as blank.

- The **Edit parent billing address** link opens the parent Account. It does not give the user permission to edit the Account or Billing City.

Before activation, test both a blank and populated parent Billing City as a handoff user with the access your team plans to provide.

## Test the Rule

1. On a child Account, clear Billing City on the parent. Confirm Warning.
2. Populate the parent's Billing City, rerun, and confirm a pass.
3. Clear Parent Account and confirm the Rule is skipped.
4. Repeat the child Account test as a user who cannot read the parent's Billing City and confirm the access result does not expose the hidden value.

## Failures and remedies

| What the user sees | What to check |
| --- | --- |
| An expected value fails | Confirm the field values, field types, and blank or picklist functions used by the formula. |
| The Rule runs on the wrong records | Review **Applies To** and **Applies When (Formula)** separately from the Pass Condition. |
| **Unable to evaluate** | Confirm the formula syntax and the running user's access to every referenced field. |

## Related

- [← Prev: Partner regional assignment](03-partner-regional-assignment.md) · [Next: Program eligibility →](05-program-eligibility.md)
- [Browse Formula examples](README.md)
