# 03 · Partner Account Is Ready for Regional Assignment

> [!NOTE]
> On this page, use Formula applicability to require Billing Country for Partner Accounts and return `SKIPPED` for Accounts that do not belong in the regional-assignment process.
>
> **Setup reference**
>
> Use the [Formula reference](../../reference/evaluation/formula.md) for the complete setup fields and behavior.

## Scenario

A channel manager is preparing a Partner Account for regional assignment.

- Billing Country determines which regional channel team should receive the Partner Account.
- A missing country can delay assignment or send the Partner Account to the wrong team.
- Customer and prospect Accounts do not participate in this channel process.

> [!TIP]
> **Why use Record Health Check**
>
> Record Health Check requests Billing Country on Partner Accounts and skips Accounts that do not participate in the regional channel process.

## What you will learn

| Skill | How this example teaches it |
| --- | --- |
| Limit when a Rule applies | Applicability keeps the Rule focused on partner Accounts. |
| Separate applicability from pass/fail | One formula decides whether to run; another evaluates readiness. |
| Explain `SKIPPED` correctly | Non-partner Accounts are not failures because the Rule does not apply. |

## Why use Verify with a formula

| Evaluation Type | Why it fits |
| --- | --- |
| **Verify with a formula** | Best fit. Account Type and Billing Country are both on the Account. |
| **Verify with a query** | Would add query setup for fields the Account formula can already read. |
| **Verify with Apex** | Would require an Apex class for a picklist and blank-field check. |

## Why not use a Validation Rule

- Billing Country is needed when a Partner Account enters regional assignment, not necessarily when someone first creates or updates it.

- Customer and prospect Accounts are outside this assignment process and should not be blocked.

## Configure the Rule

In **Setup → Custom Metadata Types → Record Health Check Rule → Manage Records**, create the Rule:

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Developer Name** | [`DeveloperName`](../../metadata/fields-check-rule.md#developer-name-developername) | `Partner_Has_Billing_Country` |
| **Label** | [`MasterLabel`](../../metadata/fields-check-rule.md#label-masterlabel) | Partner Has Billing Country |
| **Check Set** | [`Record_Health_Check_Set__c`](../../metadata/fields-check-rule.md#check-set-record_health_check_set__c) | `Account_Data_Quality` |
| **Check Title** | [`CheckTitle__c`](../../metadata/fields-check-rule.md#check-title-checktitle__c) | Partner Has Billing Country |
| **Evaluation Type** | [`EvaluationType__c`](../../metadata/fields-check-rule.md#evaluation-type-evaluationtype__c) | Verify with a formula |
| **Pass Condition** | [`PassConditionFormula__c`](../../metadata/fields-check-rule.md#pass-condition-passconditionformula__c) | `NOT(ISBLANK(BillingCountry))` |
| **Applies To** | [`ApplicabilityMode__c`](../../metadata/fields-check-rule.md#applies-to-applicabilitymode__c) | When a formula is true |
| **Applies When (Formula)** | [`ApplicabilityFormula__c`](../../metadata/fields-check-rule.md#applies-when-formula-applicabilityformula__c) | `ISPICKVAL(Type, "Partner")` |

Confirm the `Partner` picklist API value in your org before relying on the applicability formula.

## Optional configuration

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Check Description** | [`CheckDescription__c`](../../metadata/fields-check-rule.md#check-description-checkdescription__c) | Requires Billing Country only when Account Type is Partner. |
| **Category** | [`Category__c`](../../metadata/fields-check-rule.md#category-category__c) | Completeness |
| **Failure Severity** | [`FailureSeverity__c`](../../metadata/fields-check-rule.md#failure-severity-failureseverity__c) | Critical |
| **Message When Failed** | [`FailureMessage__c`](../../metadata/fields-check-rule.md#message-when-failed-failuremessage__c) | Partner account `{!record.Name fallback="this record"}` must have Billing Country set. |
| **Message When Unable To Evaluate** | [`UnableToEvaluateMessage__c`](../../metadata/fields-check-rule.md#message-when-unable-to-evaluate-unabletoevaluatemessage__c) | Unable to check Partner billing requirements. Confirm the user can read Type and Billing Country. |
| **Prerequisite Rule** | [`PrerequisiteRule__c`](../../metadata/fields-check-rule.md#prerequisite-rule-prerequisiterule__c) | Leave blank |
| **Fix Message** | [`FixMessage__c`](../../metadata/fields-check-rule.md#fix-message-fixmessage__c) | Enter Billing Country on this Partner Account. |
| **Action Label** | [`ActionLabel__c`](../../metadata/fields-check-rule.md#action-label-actionlabel__c) | `Edit billing country` |
| **Action URL** | [`ActionUrl__c`](../../metadata/fields-check-rule.md#action-url-actionurl__c) | `/lightning/r/Account/{!record.Id}/edit` |
| **Evaluation Order** | [`EvaluationOrder__c`](../../metadata/fields-check-rule.md#evaluation-order-evaluationorder__c) | `60` |
| **Active** | [`IsActive__c`](../../metadata/fields-check-rule.md#active-isactive__c) | Checked after confirming the `Partner` picklist value |
| **Publish User Result Event** | [`PublishUserResultEvent__c`](../../metadata/fields-check-rule.md#publish-user-result-event-publishuserresultevent__c) | Unchecked |

The applicability fields in **Configure the Rule** create the skip for non-Partner Accounts. Leave
Found and Expected display formulas and Formula Result Type blank because the failure already names
the missing field. Query and Apex fields do not apply.

## Check Set configuration

Use these Check Set values:

| Check Set setting | Value |
| --- | --- |
| **Check Set** | `Account_Data_Quality` |
| **Object** | `Account` |
| **Card Title** | `Account Data Quality` |
| **Card Subtitle** | Confirm partner Accounts have a billing country when the Rule applies. |
| **When Checks Run** | Run on request |
| **Reveal Mode** | One by one |
| **Passed Checks** | Show count only |
| **Skipped Checks** | Show each check |
| **Found/Expected Display** | On demand |
| **Stop after a system error** | Unchecked |
| **Show Diagnostics** | Unchecked; enable temporarily only for authorized troubleshooting |
| **Publish User Run Event** | Unchecked |
| **Active** | Checked |

## What the user sees

Formula applicability and the Pass Condition become these Framework outcomes and card values:

| Framework result or card value | What the user sees |
| --- | --- |
| **`PASS`** | A Partner Account passes when Billing Country is populated. |
| **`FAIL`** | A Partner Account with blank Billing Country shows Needs attention with Critical severity. |
| **`SKIPPED`** | A non-Partner Account is skipped because the Rule does not apply to its regional-assignment process. |
| **Found** | Found shows the evaluated Billing Country value when the user reveals Found and Expected. |
| **Expected** | Expected shows that Billing Country must be populated when the user reveals Found and Expected. |

This Check Set uses **Show count only** for passed Rules so successful partner requirements do not
crowd the card. Skipped Rules remain visible because the `SKIPPED` result explains why the Rule did
not apply.

## Security and access

Record Health Check evaluates both applicability and the Pass Condition with the running user's Salesforce access.

- Type decides whether the Rule applies; Billing Country decides Pass or Needs attention.

- Missing access to either field can prevent the framework from deciding whether to Skip, Pass, or show Needs attention.

Before activation, test a Partner Account and a non-Partner Account with the Permission Sets assigned to the regional-assignment team.

## Test the Rule

1. Set Type to Partner and clear Billing Country. Confirm Critical.
2. Set Billing Country, rerun, and confirm a pass.
3. Change Type away from Partner and confirm the Rule is skipped.
4. Repeat the Partner Account test as a user without access to Billing Country and confirm **Unable to evaluate**.

## Failures and remedies

| What the user sees | What to check |
| --- | --- |
| An expected value fails | Confirm the field values, field types, and blank or picklist functions used by the formula. |
| The Rule runs on the wrong records | Review **Applies To** and **Applies When (Formula)** separately from the Pass Condition. |
| **Unable to evaluate** | Confirm the formula syntax and the running user's access to every referenced field. |

## Related

- [← Prev: Billing address review](02-billing-address-ready.md) · [Next: Branch handoff →](04-branch-handoff.md)
- [Browse Formula examples](README.md)
