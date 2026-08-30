# Draft Check configuration with AI

> [!NOTE]
> On this page, use a review prompt to help an AI assistant draft a Check Set and Check, then verify
> every suggested Salesforce API name, rule, and outcome before entering anything in Setup.

An AI assistant can help organize a business requirement and suggest configuration. It cannot know
your org's fields, sharing, data meaning, or approved business rules unless you provide them. Treat
its answer as a draft, not as configuration that is ready to activate.

## What this guide does not authorize

- Do not paste unreviewed AI output into a production org.
- Do not let an AI assistant invent object, field, relationship, Check Set, Check, report, or Apex
  class API names.
- Do not send customer data, credentials, Salesforce session details, or other restricted
  information to an AI service.
- Do not activate a Check until an administrator has tested pass, fail, skipped, access-restricted,
  and unable-to-evaluate cases in a sandbox.

Follow your organization's AI, privacy, security, and change-management policies.

Use only an AI product approved by your organization. Start a new text conversation in that product
and paste the prompt from Step 2, followed by the business requirement from Step 3. This guide does
not require or endorse a particular vendor.

## Before you ask an AI assistant

Collect these answers from the business owner and Salesforce Setup:

| Question | Example answer |
| --- | --- |
| Which Salesforce object is checked? | Account (`Account`) |
| What must be true? | The Account has at least one Contact. |
| Where does the answer come from? | Contact records related through `Contact.AccountId`. |
| What should happen when no Contact exists? | Fail. |
| What should users see? | Add at least one verified Contact before handoff. |
| Does the Check apply to every record? | Yes. |
| Should it block a save? | No. It is guidance during an Account handoff. |
| Which users will run it? | Account managers with access to the Contacts they manage. |

Copy API names from **Setup → Object Manager → [Object] → Fields & Relationships**. Open the field
and copy **Field Name**. Do not provide a label such as “Customer Tier” and
expect the assistant to guess whether the API name is `Customer_Tier__c`.

## Step 1: Choose the likely Evaluation Type

| Where the answer comes from | Evaluation Type shown in Setup |
| --- | --- |
| Fields on the current record or a parent record reachable by formula | **Verify with a formula** |
| Records or a value returned by one SOQL query | **Verify with a query** |
| Two separate SOQL query results | **Compare two queries** |
| Logic that the supported formula and query settings cannot express | **Verify with Apex** |

If the requirement must prevent Salesforce from saving a record, use a Validation Rule,
record-triggered Flow custom error, or Apex trigger instead. Record Health Check never blocks a
save.

## Step 2: System prompt to copy into an AI assistant

Copy the following prompt. Then add the business requirement and verified API names collected above.

```text
You are helping a Salesforce administrator draft Record Health Check Custom Metadata.

Return a proposal for human review. Never claim that the proposal is ready for production.
Never invent an object, field, relationship, Check Set, Check, report, or Apex class API name.
Mark any value not supplied by the administrator as "Confirm in Salesforce Setup".

Use this output order:
1. Plain-language summary: what passes, what fails, and when the Check is skipped.
2. Clarifying questions that must be answered before configuration.
3. Check Set table: Setup label, API field name, proposed value, and why.
4. Check table: Setup label, API field name, proposed value, and why.
5. What users see for PASS, FAIL, SKIPPED, UNABLE_TO_EVALUATE, and ERROR.
6. Permissions and sharing assumptions that an administrator must test.
7. Sandbox test cases.
8. Fields and values that still require confirmation in Salesforce Setup.

Choose the simplest Evaluation Type:
- FORMULA: fields on the current record or a formula-reachable parent record.
- QUERY: one SOQL query supplies the value or records being checked.
- COMPARE_TWO_QUERIES: two separate SOQL results are compared.
- APEX: the supported formula and query settings cannot express the requirement safely.

Configuration rules:
- A Formula Check uses PassConditionFormula__c and that formula must return Boolean true or false.
- A Query Check normally uses SourceQuery__c. Bare COUNT() needs no SourceQueryField__c.
- SUM, AVG, MIN, MAX, COUNT(field), and COUNT_DISTINCT(field) require an alias, and the matching
  query-field setting contains that alias.
- ONE_RESULT reads one value or aggregate. ANY_ROW_PASSES passes when at least one returned row
  matches. ALL_ROWS_PASS requires every evaluated row to match. COMPARE_AS_LISTS is for supported
  list operators.
- LIST_CONTAINS_ANY and LIST_CONTAINS_NONE read the single value from FindInListFormula__c and the
  list from ComparisonQuery__c. SourceQuery__c stays blank for these two operators.
- A Compare Two Queries Check uses SourceQuery__c and ComparisonQuery__c. It does not use
  ExpectedValueSource__c.
- Ask whether zero query rows should Pass, Fail, Skip, or be Unable to Evaluate. Do not decide for
  the administrator.
- Queries run with the running user's Salesforce sharing and object and field access.
- The Lightning card runs the first 25 active Checks in Evaluation Order. Direct Apex and Flow
  reject the entire Check Set when it has more than 25 active Checks.
- MaxQueryRows__c must be a whole number from 1 through 2000.
- A prerequisite must be active, belong to the same Check Set, and have a lower Evaluation Order.
- Record Health Check does not update the record being checked.
- Apex Check code must implement rhc.RecordHealthCheckPlugin, query in bulk with user access, return
  one outcome for each requested record ID, and avoid data changes, callouts, event publication, and
  starting asynchronous work.

Use Setup labels in explanations and include API field names only so the administrator can verify
them against the Record Health Check field reference.
```

## Step 3: Add the business requirement

Use a short, specific request after the system prompt. For example:

```text
Draft an Account Check Set and Check for this requirement:

- Base object: Account
- Verified relationship: Contact.AccountId
- Pass: at least one Contact visible to the running user exists for the Account
- Fail: no visible Contact exists
- Skip: never; this applies to every Account
- Failure message: Add at least one verified Contact before handoff.
- Do not publish Platform Events.
- Use administrator-created API names without an rhc__ prefix.
```

This request provides the business decision for zero Contacts instead of asking the assistant to
guess it.

## Step 4: Review the proposed Check Set

The AI draft should use Setup labels and API names together. A typical proposal might contain:

| Setup field | API field | Example value |
| --- | --- | --- |
| **Label** | `MasterLabel` | Account Handoff Review |
| **Record Health Check Set Name** | `DeveloperName` | `Account_Handoff_Review` |
| **Object** | `ObjectApiName__c` | `Account` |
| **Card Title** | `CardTitle__c` | Account Handoff Review |
| **When Checks Run** | `CardRunMode__c` | When the user clicks Run (`RUN_ON_REQUEST`) |
| **Reveal Mode** | `CardRevealMode__c` | One by one (`ONE_BY_ONE`) |
| **Passed Checks** | `PassedChecksDisplay__c` | Show each check (`SHOW_EACH_CHECK`) |
| **Skipped Checks** | `SkippedChecksDisplay__c` | Show each check (`SHOW_EACH_CHECK`) |
| **Found/Expected Display** | `FoundExpectedDisplay__c` | On demand (`ON_DEMAND`) |
| **Summary Display** | `SummaryDisplay__c` | Below Checks (`BOTTOM`) |
| **Show Diagnostics** | `ShowDiagnostics__c` | Unchecked (`false`) |
| **Publish User Run Event** | `PublishUserRunEvent__c` | Unchecked (`false`) |
| **Active** | `IsActive__c` | Unchecked until testing is ready |

Confirm every value against [Check Set fields](../reference/custom-metadata/check-set-fields.md). The labels are what
administrators select in Setup; API values are useful for source files and integrations.

The Check Set's **Qualified API Name** is the exact value shown in Setup. An administrator-created
Check Set in your org normally looks like `Account_Handoff_Review`. A Check Set included with the
installed package can look like `rhc__Example_Account_Check_Builder_Guide`. Do not add or remove `rhc__` yourself.

## Step 5: Review the proposed Check

For the Contact example, the important values are:

| Setup field | API field | Example value |
| --- | --- | --- |
| **Label** | `MasterLabel` | Account Has a Contact |
| **Developer Name** | `DeveloperName` | `Has_At_Least_One_Contact` |
| **Check Set** | `Record_Health_Check_Set__c` | `Account_Handoff_Review` |
| **Check Title** | `CheckTitle__c` | Account Has at Least One Contact |
| **Evaluation Type** | `EvaluationType__c` | Verify with a query (`QUERY`) |
| **Source Query** | `SourceQuery__c` | `SELECT COUNT() FROM Contact WHERE AccountId = {!record.Id}` |
| **Source Query Field** | `SourceQueryField__c` | Leave blank for bare `COUNT()` |
| **How To Read Query Results** | `QueryResultHandling__c` | One row or aggregate (`ONE_RESULT`) |
| **Comparison Operator** | `ComparisonOperator__c` | Greater than (`GREATER_THAN`) |
| **Expected Value Comes From** | `ExpectedValueSource__c` | Fixed value (`FIXED_VALUE`) |
| **Expected Value (Fixed)** | `ExpectedFixedValue__c` | `0` |
| **Failure Severity** | `FailureSeverity__c` | Warning (`WARNING`) |
| **Message When Failed** | `FailureMessage__c` | `{!record.Name fallback="This Account"}` needs at least one verified Contact before handoff. |
| **Publish User Result Event** | `PublishUserResultEvent__c` | Unchecked (`false`) |
| **Active** | `IsActive__c` | Unchecked until the Check is ready to test |

Confirm every value against [Check fields](../reference/custom-metadata/check-fields.md) and a matching page in the
[examples library](../examples/README.md).

## Step 6: Check the suggested behavior

Do not approve a draft unless it explains all relevant outcomes:

| Health result | What the Contact example means |
| --- | --- |
| `PASS` | The query counted at least one visible related Contact. |
| `FAIL` | The query completed and counted zero visible related Contacts. |
| `SKIPPED` | This example has no applicability rule or prerequisite, so it should not skip. |
| `UNABLE_TO_EVALUATE` | Configuration or the running user's access prevented a reliable query result. |
| `ERROR` | Record Health Check encountered an unexpected problem. |

Sharing matters. A hidden Contact is not counted. Missing Contact or `AccountId` access can produce
`UNABLE_TO_EVALUATE`. The administrator must decide whether the intended users have the right access
for the business meaning of the Check.

## Step 7: Review Apex suggestions carefully

An AI assistant can outline an Apex Check, but a developer must review, test, and deploy the class.
Do not enter a class name in Check metadata until that exact class exists in your org.

The installed package includes `AccountHasRecentActivityCheck`, documented in
[Recent Account activity](../examples/apex/recent-activity.md). Other Apex example classes, including
`AccountOpenOpportunityHealthCheck` and `AccountStrategicReadinessCheck`, are teaching examples that
your team must create, test, and deploy. They are not installed package classes.

An Apex proposal must explain:

- the exact object and fields queried;
- how it queries all requested record IDs outside record-by-record loops;
- how it respects the running user's access;
- what produces pass, fail, unable-to-evaluate, and error outcomes;
- which JSON parameter names are accepted and their valid ranges;
- how every requested record ID receives exactly one outcome; and
- how tests prove bulk behavior, permissions, limits, and the prohibition on data changes,
  callouts, event publication, or starting asynchronous work.

See the [Apex Check contract](../developer-guides/write-an-apex-check.md) before approving code.

## Step 8: Test the human-approved draft

1. In sandbox Setup, open **Custom Metadata Types → Record Health Check Set → Manage Records →
   New**, then enter the approved Check Set with **Active** unchecked.
2. Open **Custom Metadata Types → Record Health Check → Manage Records → New**, then enter the
   approved Check with **Active** unchecked.
3. Review the saved values in Setup; do not rely on the AI response as the source of truth.
4. Activate the Check and Check Set only for testing.
5. Test a record that should pass.
6. Test a record that should fail.
7. Test every intended skip condition, including prerequisites and zero-row choices.
8. Test as a user with restricted sharing.
9. In a sandbox-only test, remove access to a required field and confirm
   `UNABLE_TO_EVALUATE`. Restore access afterward.
10. Confirm messages and action links remain useful without diagnostics.
11. Obtain the business owner's approval before moving the configuration to production.

## Review checklist

- [ ] The base object and every field and relationship API name were copied from Salesforce Setup.
- [ ] The business owner confirmed pass, fail, skip, and zero-row behavior.
- [ ] The Check uses the simplest Evaluation Type that meets the requirement.
- [ ] The Check Set and Check names are administrator-created names unless the exact installed
  package metadata is intentionally reused.
- [ ] No one added or removed the `rhc__` namespace prefix manually.
- [ ] The proposal distinguishes hidden records from missing object or field access.
- [ ] Failure and fix messages use everyday business language.
- [ ] Platform Event publication remains off unless receiving automation exists and is tested.
- [ ] Any Apex class exists in the org and passed developer review and tests.
- [ ] An intended user tested the configuration in a sandbox.

## When the AI draft is wrong

| Problem | Correct response |
| --- | --- |
| It invents an API name | Stop and copy the exact API name from Salesforce Setup. |
| It prefixes a new Check Set or Check with `rhc__` | Remove the invented namespace. Administrator-owned metadata normally has no managed-package prefix. |
| It chooses a Check included with the package when you need your own rule | Create an administrator-owned Check with a name that normally has no `rhc__` prefix. |
| It assumes zero query rows should pass or fail | Ask the business owner; then configure **If Query Finds No Records** where the Evaluation Type uses it. |
| It recommends Record Health Check to prevent a save | Use a Validation Rule, Flow custom error, or Apex trigger. |
| It recommends an Apex example class that is not installed | Create, test, and deploy the class, or choose a metadata-only Evaluation Type. |
| It says a hidden related record is clean data | Correct the wording: the Check evaluates only records visible to the running user. |
| It omits `UNABLE_TO_EVALUATE` and `ERROR` testing | Add access, configuration, and unexpected-error test cases before approval. |

## Related

- [Configure Check Sets and Checks](./configure-check-sets-and-checks.md)
- [Create your first Check](../step-by-step-guide/create-your-first-check.md)
- [Check Set fields](../reference/custom-metadata/check-set-fields.md)
- [Check fields](../reference/custom-metadata/check-fields.md)
- [Examples library](../examples/README.md)
- [Apex Check contract](../developer-guides/write-an-apex-check.md)
