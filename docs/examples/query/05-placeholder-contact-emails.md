# 05 · Imported Contact Emails Are Ready for Use

> [!NOTE]
> On this page, exclude placeholder Contact email domains, ignore genuinely blank Email fields, and use a prerequisite Rule so cleanup runs only when Contacts exist.
>
> **Setup reference**
>
> Use the [Query reference](../../reference/evaluation/query.md) for the complete setup fields and behavior.

> [!IMPORTANT]
> This configuration is illustrative teaching metadata. It is not installed by the Framework package.

## Scenario

A data steward is preparing Accounts imported from a test or legacy system.

- Every related Contact Email must exclude the placeholder domain `@example.com`; Accounts with no Contact emails skip.
- Placeholder addresses can route customer communication nowhere while still looking populated.
- The data steward needs to find and correct those addresses before the Account is used for customer communication.

> [!TIP]
> **Why use Record Health Check**
>
> Record Health Check warns the data steward when the Account still contains a placeholder address and provides a direct path to the related Contacts.

## What you will learn

| Skill | How this example teaches it |
| --- | --- |
| Inspect text returned by SOQL | The Rule evaluates Contact email addresses. |
| Detect a disallowed text pattern | Placeholder domains cause the Rule to fail. |
| Handle blank query fields | Contacts with blank Email are ignored instead of failing the text comparison. |
| Use a prerequisite Rule | The email-quality Rule waits for the Contact-presence Rule to pass. |

## Why use Verify with a query

| Evaluation Type | Why it fits |
| --- | --- |
| **Verify with a query** | Best fit. The query reviews Email on every related Contact and looks for the placeholder domain. |
| **Verify with a formula** | An Account formula cannot review Email on every related Contact. |
| **Verify with a query** using **Contains text** | Looks for text that must be present. This example needs **Does not contain text** because the placeholder domain must be absent. |

The sample domain is intentionally obvious. Replace it with a domain confirmed by your data or
integration owner; leave legitimate customer domains alone even when they resemble test data.

## Why not use a Validation Rule or Report

- **Validation Rule:** A Validation Rule can prevent a known placeholder during new edits. It does not identify imported or legacy Contacts that already contain one.

- **Report:** A report can support a bulk cleanup project. It does not place the warning directly on the Account currently being reviewed.

## Configure the Rule

In **Setup → Custom Metadata Types → Record Health Check Rule → Manage Records**, create the Rule:

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Developer Name** | [`DeveloperName`](../../metadata/fields-check-rule.md#developer-name-developername) | `Contact_Email_Excludes_Placeholder_Domain` |
| **Label** | [`MasterLabel`](../../metadata/fields-check-rule.md#label-masterlabel) | Contact Email Excludes Placeholder Domain |
| **Check Set** | [`Record_Health_Check_Set__c`](../../metadata/fields-check-rule.md#check-set-record_health_check_set__c) | `Account_Related_Record_Review` |
| **Check Title** | [`CheckTitle__c`](../../metadata/fields-check-rule.md#check-title-checktitle__c) | Contact Emails Exclude Placeholder Domain |
| **Evaluation Type** | [`EvaluationType__c`](../../metadata/fields-check-rule.md#evaluation-type-evaluationtype__c) | Verify with a query |
| **Source Query** | [`SourceQuery__c`](../../metadata/fields-check-rule.md#source-query-sourcequery__c) | `SELECT Email FROM Contact WHERE AccountId = {!record.Id}` |
| **Source Query Field** | [`SourceQueryField__c`](../../metadata/fields-check-rule.md#source-query-field-sourcequeryfield__c) | `Email` |
| **How To Read Query Results** | [`QueryResultHandling__c`](../../metadata/fields-check-rule.md#how-to-read-query-results-queryresulthandling__c) | Every record passes |
| **Comparison Operator** | [`ComparisonOperator__c`](../../metadata/fields-check-rule.md#comparison-operator-comparisonoperator__c) | Does not contain text |
| **Expected Value Comes From** | [`ExpectedValueSource__c`](../../metadata/fields-check-rule.md#expected-value-comes-from-expectedvaluesource__c) | Fixed value |
| **Expected Value (Fixed)** | [`ExpectedFixedValue__c`](../../metadata/fields-check-rule.md#expected-value-fixed-expectedfixedvalue__c) | `@example.com` (**Replace with your confirmed placeholder or test domain**) |
| **If Query Finds No Records** | [`NoRowsResult__c`](../../metadata/fields-check-rule.md#if-query-finds-no-records-norowsresult__c) | Skip |
| **If Field Value Is Empty** | [`EmptyValueHandling__c`](../../metadata/fields-check-rule.md#if-field-value-is-empty-emptyvaluehandling__c) | Ignore the record |
| **Max Query Rows (1-2000)** | [`MaxQueryRows__c`](../../metadata/fields-check-rule.md#max-query-rows-1-2000-maxqueryrows__c) | `200` |
| **Display: Found Text** | [`DisplayFoundText__c`](../../metadata/fields-check-rule.md#display-found-text-displayfoundtext__c) | Count of contact emails using the placeholder domain out of the total: copy it from below the table |
| **Display: Expected Text** | [`DisplayExpectedText__c`](../../metadata/fields-check-rule.md#display-expected-text-displayexpectedtext__c) | `No contact email uses the confirmed placeholder domain` |

Copy this value into **Display: Found Text**:

```text
{!rhcResult.failedRecordCount} of {!rhcResult.totalRecordCount fallback="0"} contact emails use the placeholder domain
```

## Optional configuration

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Check Description** | [`CheckDescription__c`](../../metadata/fields-check-rule.md#check-description-checkdescription__c) | Checks populated Contact emails for a confirmed placeholder or test domain. |
| **Category** | [`Category__c`](../../metadata/fields-check-rule.md#category-category__c) | Consistency |
| **Failure Severity** | [`FailureSeverity__c`](../../metadata/fields-check-rule.md#failure-severity-failureseverity__c) | Warning |
| **Message When Failed** | [`FailureMessage__c`](../../metadata/fields-check-rule.md#message-when-failed-failuremessage__c) | One or more Contacts use a placeholder email domain. Replace each placeholder with a verified address or clear it according to your data policy. |
| **Message When Unable To Evaluate** | [`UnableToEvaluateMessage__c`](../../metadata/fields-check-rule.md#message-when-unable-to-evaluate-unabletoevaluatemessage__c) | Unable to check Contact Email. Confirm the user can read Contact, AccountId, and Email. |
| **Applies To** | [`ApplicabilityMode__c`](../../metadata/fields-check-rule.md#applies-to-applicabilitymode__c) | All records |
| **Prerequisite Rule** | [`PrerequisiteRule__c`](../../metadata/fields-check-rule.md#prerequisite-rule-prerequisiterule__c) | `Has_At_Least_One_Contact` from [Customer handoff](01-customer-contact.md) |
| **Fix Message** | [`FixMessage__c`](../../metadata/fields-check-rule.md#fix-message-fixmessage__c) | Review the related Contacts and correct only addresses that have been verified. |
| **Action Label** | [`ActionLabel__c`](../../metadata/fields-check-rule.md#action-label-actionlabel__c) | `Review contacts` |
| **Action URL** | [`ActionUrl__c`](../../metadata/fields-check-rule.md#action-url-actionurl__c) | `/lightning/r/Account/{!record.Id}/related/Contacts/view` |
| **Evaluation Order** | [`EvaluationOrder__c`](../../metadata/fields-check-rule.md#evaluation-order-evaluationorder__c) | `100` |
| **Active** | [`IsActive__c`](../../metadata/fields-check-rule.md#active-isactive__c) | Checked only after replacing the sample domain with a confirmed value |
| **Publish User Result Event** | [`PublishUserResultEvent__c`](../../metadata/fields-check-rule.md#publish-user-result-event-publishuserresultevent__c) | Unchecked |

The prerequisite and this Rule must belong to the same Check Set. Give
`Has_At_Least_One_Contact` a lower **Evaluation Order** so it runs first. Comparison Query, list,
Formula, and Apex fields do not apply.

## Check Set configuration

Use these Check Set values:

| Check Set setting | Value |
| --- | --- |
| **Check Set** | `Account_Related_Record_Review` |
| **Object** | `Account` |
| **Card Title** | `Related Record Review` |
| **Card Subtitle** | Confirm Contact emails are not placeholder domains. |
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

The query rows, empty-value handling, and prerequisite become these Framework outcomes and card values:

| Framework result or card value | What the user sees |
| --- | --- |
| **`PASS`** | Every returned Email excludes the confirmed placeholder domain. |
| **`FAIL`** | Any returned Email containing that domain shows Needs attention with Warning severity. |
| **`SKIPPED`** | The Rule is skipped when its Contact prerequisite does not pass or when no returned Contact has a populated Email to evaluate. |
| **Found** | Found summarizes how many returned Contact emails use the placeholder domain, using the configured result-count merge tokens. |
| **Expected** | Expected shows that returned Email values must not contain the configured placeholder text. |

## Security and access

Record Health Check reads Email on visible Contacts related to the Account with the running user's Salesforce access.

- Hidden Contacts and Email values are not searched for the placeholder domain and are not exposed in the result.

- Missing Contact or Email permission can show **Unable to evaluate**.

Before activation, test placeholder-domain, verified-domain, and restricted-Contact cases with the intended data-steward permissions.

## Test the Rule

1. Replace `@example.com` with your confirmed placeholder domain before activation.
2. Give one related Contact an address at that domain. Confirm Warning.
3. Replace it with a verified address, rerun, and confirm a pass.
4. Clear every related Contact Email and confirm the Rule is skipped because no populated Email remains to evaluate.
5. Remove every related Contact and confirm the prerequisite causes this Rule to return `SKIPPED`.
6. Repeat the placeholder-domain test as a user with restricted Contact access and confirm the Rule does not reveal hidden Email values.

## Failures and remedies

| What the user sees | What to check |
| --- | --- |
| A count or list is lower than expected | Confirm the query filters and the running user's sharing access to matching records. |
| Empty results behave incorrectly | Review **If Query Finds No Records** and, when used, **If Field Value Is Empty**. |
| **Unable to evaluate** | Confirm the object and field API names, SOQL syntax, and the running user's object and field permissions. |

## Related

- [← Prev: Forecast amounts](04-forecast-amounts.md) · [Next: Account Owner team membership →](06-account-owner-team-membership.md)
- [Browse Query examples](README.md)
