# Create your first Rule

> [!NOTE]
> On this page, build your first Account readiness experience in Salesforce Setup and prove that its Formula Rule communicates both a passing record and a record that needs attention.

Use this guide to create one Check Set and one Formula Rule in Salesforce Setup. When you finish,
an Account record page will show whether Billing City is populated.

**You need:** Record Health Check installed, permission to manage Custom Metadata and edit
Lightning record pages, and the `Record_Health_Check_User` Permission Set.

**You do not need:** Apex, Flow, or command-line tools.

If Record Health Check is not installed yet, complete [Install and verify](02-install-and-verify.md) first.

## What you will build

| Configuration | Name used in this guide | Purpose |
| --- | --- | --- |
| **Check Set** | `Account_Readiness` | Controls the card and groups related Rules |
| **Rule** | `Billing_City_Is_Populated` | Asks one health question |

The Rule passes when `BillingCity` contains a value and fails when it is blank. It reports the
result without blocking record save or changing Account data.

## Step 1: Create the Check Set

1. In Salesforce Setup, open **Custom Metadata Types**.
2. Next to **Record Health Check Set**, select **Manage Records**.
3. Select **New**.
4. Enter these values:

| Setup field | API name | Value |
| --- | --- | --- |
| **Label** | [`MasterLabel`](../metadata/01-fields-check-set.md#label-masterlabel) | Account Readiness |
| **Developer Name** | [`DeveloperName`](../metadata/01-fields-check-set.md#developer-name-developername) | `Account_Readiness` |
| **Object** | [`ObjectApiName__c`](../metadata/01-fields-check-set.md#object-objectapiname__c) | `Account` |
| **Card Title** | [`CardTitle__c`](../metadata/01-fields-check-set.md#card-title-cardtitle__c) | Account Readiness |
| **When Checks Run** | [`CardRunMode__c`](../metadata/01-fields-check-set.md#when-checks-run-cardrunmode__c) | **When the user clicks Run** (`RUN_ON_REQUEST`) |
| **Active** | [`IsActive__c`](../metadata/01-fields-check-set.md#active-isactive__c) | Checked |

5. Select **Save**.

Manual execution makes the first test easier to follow because the card waits for you to select
**Run**.

## Step 2: Create the Rule

1. Return to **Custom Metadata Types**.
2. Next to **Record Health Check Rule**, select **Manage Records**.
3. Select **New**.
4. Enter these values:

| Setup field | API name | Value |
| --- | --- | --- |
| **Label** | [`MasterLabel`](../metadata/02-fields-check-rule.md#label-masterlabel) | Billing City Is Populated |
| **Developer Name** | [`DeveloperName`](../metadata/02-fields-check-rule.md#developer-name-developername) | `Billing_City_Is_Populated` |
| **Check Set** | [`Record_Health_Check_Set__c`](../metadata/02-fields-check-rule.md#check-set-record_health_check_set__c) | `Account_Readiness` |
| **Check Title** | [`CheckTitle__c`](../metadata/02-fields-check-rule.md#check-title-checktitle__c) | Billing City is populated |
| **Evaluation Type** | [`EvaluationType__c`](../metadata/02-fields-check-rule.md#evaluation-type-evaluationtype__c) | **Verify with a formula** (`FORMULA`) |
| **Pass Condition** | [`PassConditionFormula__c`](../metadata/02-fields-check-rule.md#pass-condition-passconditionformula__c) | `NOT(ISBLANK(BillingCity))` |
| **Failure Severity** | [`FailureSeverity__c`](../metadata/02-fields-check-rule.md#failure-severity-failureseverity__c) | **Warning** (`WARNING`) |
| **Message When Failed** | [`FailureMessage__c`](../metadata/02-fields-check-rule.md#message-when-failed-failuremessage__c) | Billing City is missing. Add it before the Account review. |
| **Fix Message** | [`FixMessage__c`](../metadata/02-fields-check-rule.md#fix-message-fixmessage__c) | Edit the Account billing address and rerun the check. |
| **Evaluation Order** | [`EvaluationOrder__c`](../metadata/02-fields-check-rule.md#evaluation-order-evaluationorder__c) | `100` |
| **Active** | [`IsActive__c`](../metadata/02-fields-check-rule.md#active-isactive__c) | Checked |

5. Select **Save**.

The Formula Rule reads only the current Account, so it does not need SOQL or Apex.

## Step 3: Add the card to an Account page

1. Open an Account record.
2. Select **Setup → Edit Page**.
3. Drag **Record Health Check** onto the Lightning record page.
4. In the component properties, select the `Account_Readiness` Check Set.
5. Save and activate the page.
6. Return to the Account and refresh the page.

If the Check Set picker is empty, confirm the Check Set is active and its **Object** value is
`Account`.

When a Demo Check Set is already installed, the card can look like this example (Pass, Fail, and
Skipped outcomes with Found and Expected values):

![Example Account Relationship and Risk health check card](../../assets/img/Example_Account_Relationship_Risk_Screenshot.png)

## Step 4: Test both results

Use an Account you can safely edit.

| Test | What to do | Expected result |
| --- | --- | --- |
| Failing record | Clear Billing City, save the Account, and select **Run** | **Warning** (Fail) with the failure and fix messages |
| Passing record | Add Billing City, save, and select **Rerun** | **Pass** |

The card does not rerun automatically after a record edit. Select **Rerun** or refresh the page.

## If the Rule does not work

| What you see | What to check |
| --- | --- |
| The card is missing | Confirm the Lightning page is activated for the current app and profile |
| The Check Set is unavailable | Confirm **Active** is checked and **Object** is `Account` |
| The card has no Rule rows | Confirm the Rule is active and belongs to `Account_Readiness` |
| The Rule cannot evaluate | Confirm the running user can read Account and `BillingCity` |
| Setup changes do not appear | Refresh the record page after saving Custom Metadata |

For authorized troubleshooting details, use [Troubleshoot with Show Diagnostics](../guides/07-troubleshoot-with-show-diagnostics.md).

## What to learn next

| Goal | Next page |
| --- | --- |
| Add more Formula Rules | [Formula examples](../examples/README.md#formula-examples) |
| Check Contacts, Opportunities, Cases, or other related records | [Query examples](../examples/README.md#query-examples) |
| Understand every available field | [Configure Check Sets and Rules](../guides/03-configure-check-sets-and-rules.md) |
| Add a link or instruction to a failed Rule | [Configure action links](../guides/04-configure-action-links.md) |
| Prepare the Check Set for release | [Configuration review checklist](../guides/03-configure-check-sets-and-rules.md#14-review-checklist) |

## Next steps

- [Examples library](../examples/README.md)
- [Configure Check Sets and Rules](../guides/03-configure-check-sets-and-rules.md)
- [Check Set fields](../metadata/01-fields-check-set.md)
- [Rule fields](../metadata/02-fields-check-rule.md)
