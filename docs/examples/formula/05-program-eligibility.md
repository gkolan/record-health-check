# 05 · Account Meets the Small-business Program Minimum

> [!NOTE]
> On this page, compare Number of Employees with a program minimum and keep the numeric Found and Expected values visible so eligibility is immediately understandable.
>
> **Setup reference**
>
> Use the [Formula reference](../../reference/evaluation/01-formula.md) for the complete setup fields and behavior.

## Scenario

A territory planner is reviewing Accounts for a small-business program whose confirmed minimum is 10 employees.

- For each Account, the planner currently compares Number of Employees with the program minimum.
- Overlooking a low or missing value could place an ineligible Account in the program.

> [!TIP]
> **Why use Record Health Check**
>
> Record Health Check shows the recorded employee count beside the program minimum, so the planner can understand the eligibility result without calculating it separately.

## What you will learn

| Skill | How this example teaches it |
| --- | --- |
| Compare a number with a threshold | Employee count is evaluated against the program limit. |
| Make **Found** and **Expected** meaningful | Users see the current count and required minimum. |
| Write an eligibility message | The result explains the decision without exposing formula syntax. |

## Why use Verify with a formula

| Evaluation Type | Why it fits |
| --- | --- |
| **Verify with a formula** | Best fit. Number of Employees is on the Account, and the minimum is a value the administrator enters in the Rule. |
| **Verify with a query** | Is not needed because the employee count is already stored on the Account. |
| **Verify with Apex** | Would require an Apex class without providing a better result. |

## Why not use a Validation Rule

- An Account below the program minimum is still a valid Account.

- Program eligibility should be reviewed when needed instead of blocking unrelated Account updates.

## Configure the Rule

In **Setup → Custom Metadata Types → Record Health Check Rule → Manage Records**, create the Rule:

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Developer Name** | [`DeveloperName`](../../metadata/02-fields-check-rule.md#developer-name-developername) | `Employee_Count_Meets_Minimum` |
| **Label** | [`MasterLabel`](../../metadata/02-fields-check-rule.md#label-masterlabel) | Employee Count Meets Minimum |
| **Check Set** | [`Record_Health_Check_Set__c`](../../metadata/02-fields-check-rule.md#check-set-record_health_check_set__c) | `Account_Data_Quality` |
| **Check Title** | [`CheckTitle__c`](../../metadata/02-fields-check-rule.md#check-title-checktitle__c) | Employee Count Meets Minimum |
| **Evaluation Type** | [`EvaluationType__c`](../../metadata/02-fields-check-rule.md#evaluation-type-evaluationtype__c) | Verify with a formula |
| **Pass Condition** | [`PassConditionFormula__c`](../../metadata/02-fields-check-rule.md#pass-condition-passconditionformula__c) | `BLANKVALUE(NumberOfEmployees, 0) >= 10` |
| **Display: Found Formula** | [`DisplayFoundFormula__c`](../../metadata/02-fields-check-rule.md#display-found-formula-displayfoundformula__c) | `BLANKVALUE(NumberOfEmployees, 0)` |
| **Display: Expected Formula** | [`DisplayExpectedFormula__c`](../../metadata/02-fields-check-rule.md#display-expected-formula-displayexpectedformula__c) | `10` |
| **Formula Result Type** | [`FormulaResultType__c`](../../metadata/02-fields-check-rule.md#formula-result-type-formularesulttype__c) | Number |

This scenario uses a confirmed minimum of 10 employees. When adapting the Rule, replace `10` in the
Pass Condition and Expected Formula with the minimum approved for your program.

Keep the display formulas consistent with the Pass Condition. The engine does not compare Found to Expected; only Pass Condition decides the status. Mirror each side of the comparison: Found is the left side, Expected the right side.

## Optional configuration

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Check Description** | [`CheckDescription__c`](../../metadata/02-fields-check-rule.md#check-description-checkdescription__c) | Compares Number of Employees with a minimum of 10 and displays both values. |
| **Category** | [`Category__c`](../../metadata/02-fields-check-rule.md#category-category__c) | Eligibility |
| **Failure Severity** | [`FailureSeverity__c`](../../metadata/02-fields-check-rule.md#failure-severity-failureseverity__c) | Warning |
| **Message When Failed** | [`FailureMessage__c`](../../metadata/02-fields-check-rule.md#message-when-failed-failuremessage__c) | Names the record, then points to Found and Expected: copy it from below the table |
| **Message When Unable To Evaluate** | [`UnableToEvaluateMessage__c`](../../metadata/02-fields-check-rule.md#message-when-unable-to-evaluate-unabletoevaluatemessage__c) | Unable to compare employee count. Confirm the user can read Number of Employees. |
| **Applies To** | [`ApplicabilityMode__c`](../../metadata/02-fields-check-rule.md#applies-to-applicabilitymode__c) | All records |
| **Prerequisite Rule** | [`PrerequisiteRule__c`](../../metadata/02-fields-check-rule.md#prerequisite-rule-prerequisiterule__c) | Leave blank |
| **Fix Message** | [`FixMessage__c`](../../metadata/02-fields-check-rule.md#fix-message-fixmessage__c) | Review Found and enter an employee count of at least 10. |
| **Action Label** | [`ActionLabel__c`](../../metadata/02-fields-check-rule.md#action-label-actionlabel__c) | `Edit employee count` |
| **Action URL** | [`ActionUrl__c`](../../metadata/02-fields-check-rule.md#action-url-actionurl__c) | `/lightning/r/Account/{!record.Id}/edit` |
| **Evaluation Order** | [`EvaluationOrder__c`](../../metadata/02-fields-check-rule.md#evaluation-order-evaluationorder__c) | `80` |
| **Active** | [`IsActive__c`](../../metadata/02-fields-check-rule.md#active-isactive__c) | Checked |
| **Publish User Result Event** | [`PublishUserResultEvent__c`](../../metadata/02-fields-check-rule.md#publish-user-result-event-publishuserresultevent__c) | Unchecked |

Copy this value into **Message When Failed**:

```text
{!record.Name fallback="this record"} is below the staffing minimum. Compare Found and Expected, then update Employees.
```

Query and Apex fields do not apply. This Rule leaves **Display: Found Text** / **Display: Expected
Text** blank and gets its readable values from the Found/Expected formulas. Set them when the
wording around a value matters more than the value alone - they replace what the Framework wrote on
a Formula Rule too.

## Check Set configuration

Use these Check Set values:

| Check Set setting | Value |
| --- | --- |
| **Check Set** | `Account_Data_Quality` |
| **Object** | `Account` |
| **Card Title** | `Account Data Quality` |
| **Card Subtitle** | Confirm employee count meets the program threshold. |
| **When Checks Run** | Run on request |
| **Reveal Mode** | One by one |
| **Passed Checks** | Show each check |
| **Skipped Checks** | Show each check |
| **Found/Expected Display** | Every check |
| **Stop after a system error** | Unchecked |
| **Show Diagnostics** | Unchecked; enable temporarily only for authorized troubleshooting |
| **Publish User Run Event** | Unchecked |
| **Active** | Checked |

## What the user sees

The card turns the numeric Formula result and its display formulas into these user-facing values:

| Framework result or card value | What the user sees |
| --- | --- |
| **`PASS`** | An Account with 10 or more employees passes. |
| **`FAIL`** | An Account with fewer than 10 employees shows Needs attention. |
| **`SKIPPED`** | This configuration applies to every Account and has no prerequisite, so it does not produce `SKIPPED`. |
| **Found** | Found shows the Account's current Number of Employees. |
| **Expected** | Expected shows the program minimum: `10 employees`. |

This Check Set uses **Every check** for **Found/Expected Display** because the employee count and
program minimum are useful during both passing and failing eligibility reviews.

The Found and Expected display formulas never change the Pass or Needs attention decision. If a
display formula cannot be evaluated, the card uses its standard display instead.

## Security and access

Record Health Check reads Number of Employees with the running user's Salesforce access. This field supplies both the eligibility decision and the Found value.

- If the user cannot read Number of Employees, the card may show **Unable to evaluate**. A display-formula problem does not change Pass or Needs attention; the card falls back to its standard text.

Before activation, confirm the result and Found / Expected display with the Permission Sets assigned to program planners.

## Test the Rule

1. Set Employees below 10. Confirm Warning and Found / Expected when display is configured.
2. Set Employees to 10 or more, rerun, and confirm a pass.
3. Clear both display formulas and confirm the row uses Pass Condition text only.
4. Repeat the failing test as a user without access to Number of Employees and confirm **Unable to evaluate**.

## Failures and remedies

| What the user sees | What to check |
| --- | --- |
| An expected value fails | Confirm the field values, field types, and blank or picklist functions used by the formula. |
| The Rule runs on the wrong records | Review **Applies To** and **Applies When (Formula)** separately from the Pass Condition. |
| **Unable to evaluate** | Confirm the formula syntax and the running user's access to every referenced field. |

## Related

- [← Prev: Branch handoff](04-branch-handoff.md)
- [Browse Formula examples](README.md)
