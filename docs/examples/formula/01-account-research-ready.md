# 01 · Account Is Ready for Seller Research

> [!NOTE]
> On this page, create a Formula Rule that considers an Account ready for seller research when either Phone or Website gives the seller a useful place to begin.
>
> **Setup reference**
>
> Use the [Formula reference](../../reference/evaluation/formula.md) for the complete setup fields and behavior.

## Scenario

A seller is preparing to contact an Account and needs a reliable place to begin.

- Some Accounts provide a business phone number; others provide a website for learning about the company.
- Either one is enough to begin preparing for the conversation.
- When both are missing, the seller must enrich the Account before outreach.

> [!TIP]
> **Why use Record Health Check**
>
> Record Health Check combines Phone and Website into one readiness result and requests enrichment when neither starting point is available.

## What you will learn

| Skill | How this example teaches it |
| --- | --- |
| Choose **Verify with a formula** | The decision uses only fields on the current Account. |
| Allow more than one valid path | `OR` lets either Phone or Website satisfy the Rule. |
| Write useful remediation | The failure message tells the seller exactly what to add before outreach. |

## Why use Verify with a formula

| Evaluation Type | Why it fits |
| --- | --- |
| **Verify with a formula** | Best fit. Phone and Website are both on the Account, and one formula can accept either field. |
| **Verify with a query** | Would add separate setup for values already available to the Account formula. |
| **Verify with Apex** | Would require an Apex class for logic that Verify with a formula already handles. |

## Why not use a Validation Rule

- A missing Phone and Website should prompt research, not block an unrelated Account update.

- The readiness question belongs in the seller's outreach preparation with the other checks for that work.

## Configure the Rule

In **Setup → Custom Metadata Types → Record Health Check Rule → Manage Records**, create the Rule:

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Developer Name** | [`DeveloperName`](../../metadata/fields-check-rule.md#developer-name-developername) | `Phone_Or_Website_Is_Required` |
| **Label** | [`MasterLabel`](../../metadata/fields-check-rule.md#label-masterlabel) | Phone or Website Is Required |
| **Check Set** | [`Record_Health_Check_Set__c`](../../metadata/fields-check-rule.md#check-set-record_health_check_set__c) | `Account_Data_Quality` |
| **Check Title** | [`CheckTitle__c`](../../metadata/fields-check-rule.md#check-title-checktitle__c) | Phone or Website Is Required |
| **Evaluation Type** | [`EvaluationType__c`](../../metadata/fields-check-rule.md#evaluation-type-evaluationtype__c) | Verify with a formula |
| **Pass Condition** | [`PassConditionFormula__c`](../../metadata/fields-check-rule.md#pass-condition-passconditionformula__c) | `OR(NOT(ISBLANK(Phone)), NOT(ISBLANK(Website)))` |

## Optional configuration

These values improve presentation. Change them for your process, or leave an optional field blank.

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Check Description** | [`CheckDescription__c`](../../metadata/fields-check-rule.md#check-description-checkdescription__c) | Checks whether the Account has at least one contact channel: Phone or Website. |
| **Category** | [`Category__c`](../../metadata/fields-check-rule.md#category-category__c) | Completeness |
| **Failure Severity** | [`FailureSeverity__c`](../../metadata/fields-check-rule.md#failure-severity-failureseverity__c) | Warning |
| **Message When Failed** | [`FailureMessage__c`](../../metadata/fields-check-rule.md#message-when-failed-failuremessage__c) | `{!record.Name fallback="this record"}` has neither Phone nor Website set. Add at least one contact channel. |
| **Message When Unable To Evaluate** | [`UnableToEvaluateMessage__c`](../../metadata/fields-check-rule.md#message-when-unable-to-evaluate-unabletoevaluatemessage__c) | Unable to check Phone and Website. Confirm the user can read both fields. |
| **Applies To** | [`ApplicabilityMode__c`](../../metadata/fields-check-rule.md#applies-to-applicabilitymode__c) | All records |
| **Prerequisite Rule** | [`PrerequisiteRule__c`](../../metadata/fields-check-rule.md#prerequisite-rule-prerequisiterule__c) | Leave blank |
| **Fix Message** | [`FixMessage__c`](../../metadata/fields-check-rule.md#fix-message-fixmessage__c) | Enter either Phone or Website on the Account. Both are not required. |
| **Action Label** | [`ActionLabel__c`](../../metadata/fields-check-rule.md#action-label-actionlabel__c) | `Edit contact details` |
| **Action URL** | [`ActionUrl__c`](../../metadata/fields-check-rule.md#action-url-actionurl__c) | `/lightning/r/Account/{!record.Id}/edit` |
| **Evaluation Order** | [`EvaluationOrder__c`](../../metadata/fields-check-rule.md#evaluation-order-evaluationorder__c) | `20` |
| **Active** | [`IsActive__c`](../../metadata/fields-check-rule.md#active-isactive__c) | Checked |
| **Publish User Result Event** | [`PublishUserResultEvent__c`](../../metadata/fields-check-rule.md#publish-user-result-event-publishuserresultevent__c) | Unchecked |

Leave the Found and Expected display formulas and Formula Result Type blank. The failure message
already identifies both acceptable fields. Query and Apex fields do not apply.

## Check Set configuration

Use these Check Set values:

| Check Set setting | Value |
| --- | --- |
| **Check Set** | `Account_Data_Quality` |
| **Object** | `Account` |
| **Card Title** | `Account Data Quality` |
| **Card Subtitle** | Confirm phone or website is available before seller research. |
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

The Formula result becomes these Framework outcomes and card values:

| Framework result or card value | What the user sees |
| --- | --- |
| **`PASS`** | The Rule passes as soon as Phone or Website has a value. |
| **`FAIL`** | When both fields are blank, the card shows Needs attention with Warning severity and the configured guidance. |
| **`SKIPPED`** | This configuration applies to every Account and has no prerequisite, so it does not produce `SKIPPED`. |
| **Found** | The standard Formula result identifies the evaluated value when the user reveals Found and Expected. |
| **Expected** | The standard Formula result identifies the passing requirement when the user reveals Found and Expected. |

## Security and access

Record Health Check reads Phone and Website on the Account with the running user's Salesforce access.

- If the user cannot read either referenced field, the card may show **Unable to evaluate** instead of Pass or Needs attention.

Before activation, run the Rule with the Permission Sets and field access assigned to the sellers who will use the card.

## Test the Rule

1. Open an Account on a page that includes Record Health Check for this Rule’s Check Set.
2. Clear both Phone and Website. Run the check and confirm Warning with the failure message.
3. Populate Phone only (leave Website blank), rerun, and confirm a pass.
4. Clear Phone, set Website only, rerun, and confirm a pass again.
5. Repeat the failing test as a user who cannot read Phone or Website and confirm the Rule follows your field-access design.

## Failures and remedies

| What the user sees | What to check |
| --- | --- |
| An expected value fails | Confirm the field values, field types, and blank or picklist functions used by the formula. |
| The Rule runs on the wrong records | Review **Applies To** and **Applies When (Formula)** separately from the Pass Condition. |
| **Unable to evaluate** | Confirm the formula syntax and the running user's access to every referenced field. |

## Related

- [Next: Billing address is ready for review →](02-billing-address-ready.md)
- [Browse Formula examples](README.md)
