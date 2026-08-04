# 02 · Billing Address Is Ready for Review

> [!NOTE]
> On this page, create one Formula Rule that requires Billing City, Billing State, and Billing Country together while showing users the Found and Expected address details they need to act.
>
> **Setup reference**
>
> Use the [Formula reference](../../reference/evaluation/formula.md) for the complete setup fields and behavior.

## Scenario

A Salesforce user is preparing an Account for tax and territory review.

- Billing City, Billing State, and Billing Country determine where the Account belongs and which tax process applies.
- A missing part of the address can delay the review or send the Account to the wrong team.
- The complete billing location is needed before the review begins.

> [!TIP]
> **Why use Record Health Check**
>
> Record Health Check presents the billing address as one readiness result and points the user to the fields that still need attention.

## What you will learn

| Skill | How this example teaches it |
| --- | --- |
| Require a complete group of fields | `AND` requires every billing-address field. |
| Treat blank text consistently | `ISBLANK` makes each missing value visible in the decision. |
| Test a completeness Rule | You verify both a complete and an incomplete Account. |

## Why use Verify with a formula

| Evaluation Type | Why it fits |
| --- | --- |
| **Verify with a formula** | Best fit. Billing City, Billing State, and Billing Country are all on the Account, and one formula can require all three. |
| **Verify with a query** | Would add query setup for fields the Account formula can already read. |
| **Verify with Apex** | Would require an Apex class for logic that Verify with a formula already handles. |

## Why not use a Validation Rule

- The address is needed for tax and territory review, but it may not be needed for every Account edit.

- Blocking every save would interrupt users who are updating unrelated information.

## Configure the Rule

In **Setup → Custom Metadata Types → Record Health Check Rule → Manage Records**, create the Rule:

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Developer Name** | [`DeveloperName`](../../metadata/fields-check-rule.md#developer-name-developername) | `Billing_Address_Is_Complete` |
| **Label** | [`MasterLabel`](../../metadata/fields-check-rule.md#label-masterlabel) | Billing Address Is Complete |
| **Check Set** | [`Record_Health_Check_Set__c`](../../metadata/fields-check-rule.md#check-set-record_health_check_set__c) | `Account_Data_Quality` |
| **Check Title** | [`CheckTitle__c`](../../metadata/fields-check-rule.md#check-title-checktitle__c) | Billing Address Is Complete |
| **Evaluation Type** | [`EvaluationType__c`](../../metadata/fields-check-rule.md#evaluation-type-evaluationtype__c) | Verify with a formula |
| **Pass Condition** | [`PassConditionFormula__c`](../../metadata/fields-check-rule.md#pass-condition-passconditionformula__c) | `AND(NOT(ISBLANK(BillingCity)), NOT(ISBLANK(BillingState)), NOT(ISBLANK(BillingCountry)))` |
| **Display: Found Formula** | [`DisplayFoundFormula__c`](../../metadata/fields-check-rule.md#display-found-formula-displayfoundformula__c) | `IF(ISBLANK(BillingCity), "City missing; ", "") & IF(ISBLANK(BillingState), "State missing; ", "") & IF(ISBLANK(BillingCountry), "Country missing", "")` |
| **Display: Expected Formula** | [`DisplayExpectedFormula__c`](../../metadata/fields-check-rule.md#display-expected-formula-displayexpectedformula__c) | `"City, State, and Country populated"` |
| **Formula Result Type** | [`FormulaResultType__c`](../../metadata/fields-check-rule.md#formula-result-type-formularesulttype__c) | Text |

## Optional configuration

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Check Description** | [`CheckDescription__c`](../../metadata/fields-check-rule.md#check-description-checkdescription__c) | Checks whether Billing City, State, and Country are all populated. |
| **Category** | [`Category__c`](../../metadata/fields-check-rule.md#category-category__c) | Completeness |
| **Failure Severity** | [`FailureSeverity__c`](../../metadata/fields-check-rule.md#failure-severity-failureseverity__c) | Critical |
| **Message When Failed** | [`FailureMessage__c`](../../metadata/fields-check-rule.md#message-when-failed-failuremessage__c) | `{!record.Name fallback="this record"}` has an incomplete billing address: City, State, and Country are all required. |
| **Message When Unable To Evaluate** | [`UnableToEvaluateMessage__c`](../../metadata/fields-check-rule.md#message-when-unable-to-evaluate-unabletoevaluatemessage__c) | Unable to check the billing address. Confirm the user can read all three fields. |
| **Applies To** | [`ApplicabilityMode__c`](../../metadata/fields-check-rule.md#applies-to-applicabilitymode__c) | All records |
| **Prerequisite Rule** | [`PrerequisiteRule__c`](../../metadata/fields-check-rule.md#prerequisite-rule-prerequisiterule__c) | Leave blank |
| **Fix Message** | [`FixMessage__c`](../../metadata/fields-check-rule.md#fix-message-fixmessage__c) | Add every billing-address field named in Found. |
| **Action Label** | [`ActionLabel__c`](../../metadata/fields-check-rule.md#action-label-actionlabel__c) | `Edit billing address` |
| **Action URL** | [`ActionUrl__c`](../../metadata/fields-check-rule.md#action-url-actionurl__c) | `/lightning/r/Account/{!record.Id}/edit` |
| **Evaluation Order** | [`EvaluationOrder__c`](../../metadata/fields-check-rule.md#evaluation-order-evaluationorder__c) | `40` |
| **Active** | [`IsActive__c`](../../metadata/fields-check-rule.md#active-isactive__c) | Checked |
| **Publish User Result Event** | [`PublishUserResultEvent__c`](../../metadata/fields-check-rule.md#publish-user-result-event-publishuserresultevent__c) | Unchecked |

The Found formula names the missing address parts, so the user does not have to inspect all three
fields. Query and Apex fields do not apply.

## Check Set configuration

Use these Check Set values:

| Check Set setting | Value |
| --- | --- |
| **Check Set** | `Account_Data_Quality` |
| **Object** | `Account` |
| **Card Title** | `Account Data Quality` |
| **Card Subtitle** | Confirm billing address fields are complete for fulfillment. |
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

The card turns the Formula result and its display formulas into these user-facing values:

| Framework result or card value | What the user sees |
| --- | --- |
| **`PASS`** | The Account passes only when Billing City, Billing State, and Billing Country are all populated. |
| **`FAIL`** | Clearing any required field shows Needs attention with Critical severity and the configured failure and fix guidance. |
| **`SKIPPED`** | This configuration applies to every Account and has no prerequisite, so it does not produce `SKIPPED`. |
| **Found** | When the user reveals Found and Expected, Found names each missing address part, such as `City missing; Country missing`. |
| **Expected** | When the user reveals Found and Expected, Expected shows `City, State, and Country populated`. |

## Security and access

Record Health Check reads Billing City, Billing State, and Billing Country on the Account with the running user's Salesforce access.

- If the user cannot read any referenced address field, the card may show **Unable to evaluate** instead of treating the field as blank.

Before activation, run the complete-address and missing-address cases with the Permission Sets assigned to the intended reviewers.

## Test the Rule

1. Populate City and State, clear Billing Country. Confirm Critical.
2. Populate all three, rerun, and confirm a pass.
3. Clear Billing City only and confirm Critical again.
4. Repeat the failing test as a user without access to one referenced Billing Address field and confirm **Unable to evaluate**.

## Failures and remedies

| What the user sees | What to check |
| --- | --- |
| An expected value fails | Confirm the field values, field types, and blank or picklist functions used by the formula. |
| The Rule runs on the wrong records | Review **Applies To** and **Applies When (Formula)** separately from the Pass Condition. |
| **Unable to evaluate** | Confirm the formula syntax and the running user's access to every referenced field. |

## Related

- [← Prev: Seller research readiness](01-account-research-ready.md) · [Next: Partner regional assignment →](03-partner-regional-assignment.md)
- [Browse Formula examples](README.md)
