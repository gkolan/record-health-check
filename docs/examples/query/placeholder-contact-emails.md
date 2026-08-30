# Contact Emails Do Not Use a Placeholder Domain

> [!NOTE]
> On this page, warn users when a related Contact Email contains a placeholder domain, ignore blank Email fields, and run the Check only after a separate Check confirms that the Account has a Contact.
>
> **Setup reference**
>
> Use the [Query reference](../../reference/evaluation/query.md) for the complete setup fields and behavior.

## Scenario

A data steward is reviewing Accounts before employees use their Contacts for customer communication.

- A data load, test process, or another system may have saved addresses that end in a known placeholder domain such as `@example.com`.
- A populated placeholder address can look complete even though employees must not use it to contact a customer.
- The Account should need attention when any visible related Contact Email contains that domain.

> [!TIP]
> **Why use Record Health Check**
>
> Record Health Check warns the data steward when the Account still contains a placeholder address and provides a direct path to the related Contacts.

## What you will learn

| Skill | How this example teaches it |
| --- | --- |
| Inspect text returned by SOQL | The Check evaluates Contact email addresses. |
| Detect a disallowed text pattern | Placeholder domains cause the Check to fail. |
| Handle blank query fields | Contacts with blank Email are ignored instead of failing the text comparison. |
| Use a prerequisite Check | The email-quality Check waits for the Contact-presence Check to pass. |

## Why use Verify with a query

| Evaluation Type | Why it fits |
| --- | --- |
| **Verify with a query** | Best fit. The query reviews Email on every visible related Contact and checks each returned value. |
| **Verify with a formula** | An Account formula cannot review Email on every related Contact. |
| **Verify with a query** using **Contains text** | Looks for text that must be present. This example needs **Does not contain text** because the placeholder domain must be absent. |

The text comparison is case-sensitive. Replace `@example.com` with the exact placeholder text used
in your Salesforce data. Confirm that value with the team responsible for the data before activating
the Check; do not assume that an unfamiliar customer domain is a placeholder.

## Why not use a Validation Rule or Report

- **Validation Rule:** A Validation Rule can prevent a known placeholder during new edits. It does not identify imported or legacy Contacts that already contain one.

- **Report:** A report can support a bulk cleanup project. It does not place the warning directly on the Account currently being reviewed.

## Before you start

- Install Record Health Check.
- Assign **Record Health Check Admin** to the administrator creating the Check Set and Check.
- Confirm the exact placeholder domain or text that employees must not use.
- Confirm that intended users can read Contact, `AccountId`, and `Email` and can see the Contacts
  whose email addresses they are responsible for correcting.
- Create the prerequisite Check from [Customer handoff](./customer-contact.md). Its Developer Name is
  `Has_At_Least_One_Contact`.

The prerequisite and this Check must use the same Check Set. The prerequisite uses evaluation order
`10`; this example uses `100`, so Salesforce evaluates the prerequisite first.

## Confirm the text and prerequisite behavior

**Does not contain text** performs a substring check. A value such as
`person@example.com.customer.com` still contains `example.com`, so test legitimate domains before
using the rule. Also test case variants such as `Example.COM` according to the documented operator
behavior. Use reviewed Apex when several domains or stricter email parsing are required.

**Ignore record** for a blank Email leaves that row out of the comparison; it does not remove the
Contact from Salesforce or prove the email is acceptable. Select the prerequisite from the Check's
**Prerequisite Check** field. It must be active, in the same Check Set, and have a lower Evaluation
Order. If you already created Customer Handoff, reuse it rather than creating a duplicate Set.

Confirm Email under **Setup → Object Manager → Contact → Fields & Relationships**, add the card to
the Account Lightning page, activate the intended assignment, and test as a user with **Record
Health Check User**.

## Step 1: Create the Check Set

In **Setup → Custom Metadata Types → Record Health Check Set → Manage Records**, select **New** and
create this Check Set:

| Setup field | Value |
| --- | --- |
| **Label** | Account Related Record Review |
| **Record Health Check Set Name** | `Account_Related_Record_Review` |
| **Object** | `Account` |
| **Card Title** | Related Record Review |
| **Card Subtitle** | Confirm Contact emails do not use a placeholder domain. |
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
| **Developer Name** | [`DeveloperName`](../../reference/custom-metadata/check-fields.md#developer-name-developername) | `Contact_Email_Avoids_Placeholder` |
| **Label** | [`MasterLabel`](../../reference/custom-metadata/check-fields.md#label-masterlabel) | Contact Email Avoids Placeholder Domain |
| **Check Set** | [`Record_Health_Check_Set__c`](../../reference/custom-metadata/check-fields.md#check-set-record_health_check_set__c) | `Account_Related_Record_Review` |
| **Check Title** | [`CheckTitle__c`](../../reference/custom-metadata/check-fields.md#check-title-checktitle__c) | Contact Emails Exclude Placeholder Domain |
| **Evaluation Type** | [`EvaluationType__c`](../../reference/custom-metadata/check-fields.md#evaluation-type-evaluationtype__c) | Verify with a query |
| **Source Query** | [`SourceQuery__c`](../../reference/custom-metadata/check-fields.md#source-query-sourcequery__c) | `SELECT Email FROM Contact WHERE AccountId = {!record.Id}` |
| **Source Query Field** | [`SourceQueryField__c`](../../reference/custom-metadata/check-fields.md#source-query-field-sourcequeryfield__c) | `Email` |
| **How To Read Query Results** | [`QueryResultHandling__c`](../../reference/custom-metadata/check-fields.md#how-to-read-query-results-queryresulthandling__c) | Every record passes |
| **Comparison Operator** | [`ComparisonOperator__c`](../../reference/custom-metadata/check-fields.md#comparison-operator-comparisonoperator__c) | Does not contain text |
| **Expected Value Comes From** | [`ExpectedValueSource__c`](../../reference/custom-metadata/check-fields.md#expected-value-comes-from-expectedvaluesource__c) | Fixed value |
| **Expected Value (Fixed)** | [`ExpectedFixedValue__c`](../../reference/custom-metadata/check-fields.md#expected-value-fixed-expectedfixedvalue__c) | `@example.com`; replace this sample with the exact placeholder text confirmed for your data |
| **If Query Finds No Records** | [`NoRowsResult__c`](../../reference/custom-metadata/check-fields.md#if-query-finds-no-records-norowsresult__c) | Skip |
| **If Field Value Is Empty** | [`EmptyValueHandling__c`](../../reference/custom-metadata/check-fields.md#if-field-value-is-empty-emptyvaluehandling__c) | Ignore the record |
| **Max Query Rows (1-2000)** | [`MaxQueryRows__c`](../../reference/custom-metadata/check-fields.md#max-query-rows-1-2000-maxqueryrows__c) | `200`; raise only after confirming an Account can have more than 200 Contacts |
| **Display: Found Text** | [`DisplayFoundText__c`](../../reference/custom-metadata/check-fields.md#display-found-text-displayfoundtext__c) | Count of contact emails using the placeholder domain out of the total: copy it from below the table |
| **Display: Expected Text** | [`DisplayExpectedText__c`](../../reference/custom-metadata/check-fields.md#display-expected-text-displayexpectedtext__c) | `No contact email uses the confirmed placeholder domain` |

Copy this value into **Display: Found Text**:

```text
{!rhcResult.failedRecordCount} of {!rhcResult.totalRecordCount fallback="0"} contact emails use the placeholder domain
```

## Optional configuration

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Check Description** | [`CheckDescription__c`](../../reference/custom-metadata/check-fields.md#check-description-checkdescription__c) | Checks populated Contact emails for a confirmed placeholder or test domain. |
| **Category** | [`Category__c`](../../reference/custom-metadata/check-fields.md#category-category__c) | Consistency |
| **Failure Severity** | [`FailureSeverity__c`](../../reference/custom-metadata/check-fields.md#failure-severity-failureseverity__c) | Warning |
| **Message When Failed** | [`FailureMessage__c`](../../reference/custom-metadata/check-fields.md#message-when-failed-failuremessage__c) | One or more Contacts use a placeholder email domain. Replace each placeholder with a verified address or clear it according to your data policy. |
| **Message When Unable To Evaluate** | [`UnableToEvaluateMessage__c`](../../reference/custom-metadata/check-fields.md#message-when-unable-to-evaluate-unabletoevaluatemessage__c) | Unable to check Contact Email. Confirm the user can read Contact, AccountId, and Email. |
| **Applies To** | [`ApplicabilityMode__c`](../../reference/custom-metadata/check-fields.md#applies-to-applicabilitymode__c) | All records |
| **Prerequisite Check** | [`PrerequisiteCheck__c`](../../reference/custom-metadata/check-fields.md#prerequisite-check-prerequisitecheck__c) | `Has_At_Least_One_Contact` from [Customer handoff](./customer-contact.md) |
| **Fix Message** | [`FixMessage__c`](../../reference/custom-metadata/check-fields.md#fix-message-fixmessage__c) | Review the related Contacts and correct only addresses that have been verified. |
| **Action Label** | [`ActionLabel__c`](../../reference/custom-metadata/check-fields.md#action-label-actionlabel__c) | `Review contacts` |
| **Action URL** | [`ActionUrl__c`](../../reference/custom-metadata/check-fields.md#action-url-actionurl__c) | `/lightning/r/Account/{!record.Id}/related/Contacts/view` |
| **Evaluation Order** | [`EvaluationOrder__c`](../../reference/custom-metadata/check-fields.md#evaluation-order-evaluationorder__c) | `100` |
| **Active** | [`IsActive__c`](../../reference/custom-metadata/check-fields.md#active-isactive__c) | Checked only after replacing the sample domain with a confirmed value |
| **Publish User Result Event** | [`PublishUserResultEvent__c`](../../reference/custom-metadata/check-fields.md#publish-user-result-event-publishuserresultevent__c) | Unchecked |

Comparison Query, list, Formula, and Apex fields do not apply.

## What the user sees

The query rows, blank-email handling, and prerequisite produce these health results and card values:

| Health result or card value | What the user sees |
| --- | --- |
| **`PASS`** | At least one visible related Contact has a populated Email, and every populated Email avoids the configured placeholder text. Blank Email fields are ignored. |
| **`FAIL`** | At least one visible related Contact Email contains the configured placeholder text, so the card shows Needs attention with Warning severity. |
| **`SKIPPED`** | The prerequisite did not pass, the query returned no Contacts, or every returned Contact Email was blank and therefore ignored. |
| **Found** | The configured display text shows the number of returned Contact emails that contain the placeholder text out of the total number of returned Contacts. The total includes Contacts whose blank Email was ignored. |
| **Expected** | The configured display text shows `No contact email uses the confirmed placeholder domain`. |

## Security and access

Record Health Check reads Email on visible Contacts related to the Account with the running user's Salesforce access.

- A Contact hidden by sharing is not returned by the query. Its Email cannot affect the result or be
  exposed to the user.

- Missing Read access to Contact, `AccountId`, or `Email` can produce `UNABLE_TO_EVALUATE`.

Before activation, test placeholder-domain, verified-domain, and restricted-Contact cases with the intended data-steward permissions.

## Step 3: Test the Check

1. Replace `@example.com` with your confirmed placeholder domain before activation.
2. Give one related Contact an address at that domain. Confirm Warning.
3. Replace it with a verified address, rerun, and confirm a pass.
4. Clear every related Contact Email and confirm the Check is skipped because no populated Email remains to evaluate.
5. Remove every related Contact and confirm the prerequisite causes this Check to return `SKIPPED`.
6. Keep a placeholder Contact that an administrator can see but the intended user cannot. Run as the
   intended user and confirm the hidden Contact is not counted or revealed.
7. In a sandbox-only permission test, remove Read access to Contact Email and confirm
   `UNABLE_TO_EVALUATE`. Restore access after the test.

## Failures and remedies

| What the user sees | What to check |
| --- | --- |
| A count or list is lower than expected | Confirm the query filters and the running user's sharing access to matching records. |
| Empty results behave incorrectly | Review **If Query Finds No Records** and, when used, **If Field Value Is Empty**. |
| **Unable to evaluate** | Confirm the object and field API names, SOQL syntax, and the running user's object and field permissions. |

## Related

- [← Prev: Forecast amounts](./forecast-amounts.md) · [Next: Account Owner team membership →](./account-owner-team-membership.md)
- [Browse Query examples](./README.md)
