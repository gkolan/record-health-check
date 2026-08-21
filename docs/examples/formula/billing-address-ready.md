# 02 · Billing Address Is Ready for Review

> [!NOTE]
> On this page, create one Formula Check that requires Billing City, Billing State, and Billing Country together while showing users the Found and Expected address details they need to act.
>
> **Setup reference**
>
> Use the [Formula reference](../../reference/evaluation/formula.md) for the complete setup fields and behavior.

## Scenario

A Salesforce user is preparing an Account for tax and territory review.

- Billing City, Billing State, and Billing Country determine where the Account belongs and which tax process applies.
- A missing part of the address can delay the review or send the Account to the wrong territory.
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
| Test a completeness Check | You verify both a complete and an incomplete Account. |

## Why use Verify with a formula

| Evaluation Type | Why it fits |
| --- | --- |
| **Verify with a formula** | Best fit. Billing City, Billing State, and Billing Country are all on the Account, and one formula can require all three. |
| **Verify with a query** | Would add query setup for fields the Account formula can already read. |
| **Verify with Apex** | Would require an Apex class for logic that Verify with a formula already handles. |

## Why not use a Validation Rule

- The address is needed for tax and territory review, but it may not be needed for every Account edit.

- Blocking every save would interrupt users who are updating unrelated information.

## Before you start

- Install Record Health Check.
- Assign **Record Health Check Admin** to the administrator creating the Check Set and Check.
- Confirm that Billing City, Billing State, and Billing Country are the address fields required by
  your tax or territory process.
- Confirm that intended users can read all three fields.

## Confirm the example fits your org

- `AND()` requires every listed address value. `IF()` chooses display text, and `&` joins text.
- In State and Country/Territory Picklists orgs, confirm whether your policy should use
  `BillingStateCode` and `BillingCountryCode` instead of the display fields in this example.
- Add Street or Postal Code to the formula if a complete address requires them.
- **Display: Found Formula** returns Text. An empty Found value on a passing record is possible and
does not mean evaluation failed; use the PASS status as the result.
- Verify field access from **Permission Sets → [User permission set] → Object Settings → Account →
  Field Permissions**.

Create an Account with a partial billing address, add the card to the Account Lightning page,
activate the intended assignment, assign **Record Health Check User**, and test both partial and
complete addresses.

## Step 1: Create the Check Set

In **Setup → Custom Metadata Types → Record Health Check Set → Manage Records**, select **New** and
create this Check Set:

| Setup field | Value |
| --- | --- |
| **Label** | Account Data Quality |
| **Record Health Check Set Name** | `Account_Data_Quality` |
| **Object** | `Account` |
| **Card Title** | Account Data Quality |
| **Card Subtitle** | Confirm billing address fields are complete for tax and territory review. |
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
| **Developer Name** | [`DeveloperName`](../../metadata/fields-check.md#developer-name-developername) | `Billing_Address_Is_Complete` |
| **Label** | [`MasterLabel`](../../metadata/fields-check.md#label-masterlabel) | Billing Address Is Complete |
| **Check Set** | [`Record_Health_Check_Set__c`](../../metadata/fields-check.md#check-set-record_health_check_set__c) | `Account_Data_Quality` |
| **Check Title** | [`CheckTitle__c`](../../metadata/fields-check.md#check-title-checktitle__c) | Billing Address Is Complete |
| **Evaluation Type** | [`EvaluationType__c`](../../metadata/fields-check.md#evaluation-type-evaluationtype__c) | Verify with a formula |
| **Pass Condition** | [`PassConditionFormula__c`](../../metadata/fields-check.md#pass-condition-passconditionformula__c) | `AND(NOT(ISBLANK(BillingCity)), NOT(ISBLANK(BillingState)), NOT(ISBLANK(BillingCountry)))` |
| **Display: Found Formula** | [`DisplayFoundFormula__c`](../../metadata/fields-check.md#display-found-formula-displayfoundformula__c) | `IF(ISBLANK(BillingCity), "City missing; ", "") & IF(ISBLANK(BillingState), "State missing; ", "") & IF(ISBLANK(BillingCountry), "Country missing", "")` |
| **Display: Expected Formula** | [`DisplayExpectedFormula__c`](../../metadata/fields-check.md#display-expected-formula-displayexpectedformula__c) | `"City, State, and Country populated"` |
| **Formula Result Type** | [`FormulaResultType__c`](../../metadata/fields-check.md#formula-result-type-formularesulttype__c) | Text |

## Optional configuration

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Check Description** | [`CheckDescription__c`](../../metadata/fields-check.md#check-description-checkdescription__c) | Checks whether Billing City, State, and Country are all populated. |
| **Category** | [`Category__c`](../../metadata/fields-check.md#category-category__c) | Completeness |
| **Failure Severity** | [`FailureSeverity__c`](../../metadata/fields-check.md#failure-severity-failureseverity__c) | Critical |
| **Message When Failed** | [`FailureMessage__c`](../../metadata/fields-check.md#message-when-failed-failuremessage__c) | `{!record.Name fallback="this record"}` has an incomplete billing address: City, State, and Country are all required. |
| **Message When Unable To Evaluate** | [`UnableToEvaluateMessage__c`](../../metadata/fields-check.md#message-when-unable-to-evaluate-unabletoevaluatemessage__c) | Unable to check the billing address. Confirm the user can read all three fields. |
| **Applies To** | [`ApplicabilityMode__c`](../../metadata/fields-check.md#applies-to-applicabilitymode__c) | All records |
| **Prerequisite Check** | [`PrerequisiteCheck__c`](../../metadata/fields-check.md#prerequisite-check-prerequisitecheck__c) | Leave blank |
| **Fix Message** | [`FixMessage__c`](../../metadata/fields-check.md#fix-message-fixmessage__c) | Add every billing-address field named in Found. |
| **Action Label** | [`ActionLabel__c`](../../metadata/fields-check.md#action-label-actionlabel__c) | `Edit billing address` |
| **Action URL** | [`ActionUrl__c`](../../metadata/fields-check.md#action-url-actionurl__c) | `/lightning/r/Account/{!record.Id}/edit` |
| **Evaluation Order** | [`EvaluationOrder__c`](../../metadata/fields-check.md#evaluation-order-evaluationorder__c) | `40` |
| **Active** | [`IsActive__c`](../../metadata/fields-check.md#active-isactive__c) | Checked |
| **Publish User Result Event** | [`PublishUserResultEvent__c`](../../metadata/fields-check.md#publish-user-result-event-publishuserresultevent__c) | Unchecked |

The Found formula names the missing address parts, so the user does not have to inspect all three
fields. Query and Apex fields do not apply.

## What the user sees

The card turns the Formula result and its display formulas into these user-facing values:

| Health result or card value | What the user sees |
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

## Step 3: Test the Check

1. Populate City and State, clear Billing Country. Confirm Critical.
2. Populate all three, rerun, and confirm a pass.
3. Clear Billing City only and confirm Critical again.
4. Repeat the failing test as a user without access to one referenced Billing Address field and confirm **Unable to evaluate**.

## Failures and remedies

| What the user sees | What to check |
| --- | --- |
| An expected value fails | Confirm the field values, field types, and blank or picklist functions used by the formula. |
| The Check runs on the wrong records | Review **Applies To** and **Applies When (Formula)** separately from the Pass Condition. |
| **Unable to evaluate** | Confirm the formula syntax and the running user's access to every referenced field. |

## Related

- [← Prev: Seller research readiness](account-research-ready.md) · [Next: Partner regional assignment →](partner-regional-assignment.md)
- [Browse Formula examples](README.md)
