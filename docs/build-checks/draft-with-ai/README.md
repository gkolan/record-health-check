# Draft Check configuration with AI

> [!NOTE]
> On this page, pick one Evaluation Type prompt, paste it into an approved AI assistant with your
> business requirement, then verify every suggested Salesforce API name before entering anything in
> Setup.

Use this folder as the single place to draft Record Health Check configuration with an AI assistant.
An assistant can organize a requirement and suggest fields. It cannot know your org's fields,
sharing, or approved rules unless you provide them. Treat every answer as a draft.

## What this guide does not authorize

- Do not paste unreviewed AI output into a production org.
- Do not let an AI assistant invent object, field, relationship, Check Set, Check, report, or Apex
  class API names.
- Do not send customer data, credentials, Salesforce session details, or other restricted
  information to an AI service.
- Do not activate a Check until an administrator has tested pass, fail, skipped, access-restricted,
  and unable-to-evaluate cases in a sandbox.

Follow your organization's AI, privacy, security, and change-management policies. Use only an AI
product your organization approves. This guide does not require or endorse a particular vendor.

## How to use this folder

1. Collect the answers in [Before you ask](#before-you-ask-an-ai-assistant).
2. Choose the Evaluation Type in the table below.
3. Open that type's prompt page and copy the single system-prompt block. Each prompt is
   self-contained: it already carries the [shared rules](./shared-rules.md), every Check Set field,
   and every Check field, so an assistant that cannot open links still has the whole surface.
4. Paste a filled [requirement template](./requirement-template.md) after the system prompt.
5. Review the draft against the field references and examples linked from the prompt page.
6. Enter approved values in a sandbox, then follow [Test the human-approved draft](#test-the-human-approved-draft).

## Choose a prompt by Evaluation Type

| Where the answer comes from | Evaluation Type | Copy this prompt | Confirm against |
| --- | --- | --- | --- |
| Fields on the current record or a formula-reachable parent | **Verify with a formula** | [Formula prompt](./prompt-formula.md) | [Formula examples](../../examples/formula/README.md), [Check fields](../../reference/custom-metadata/check-fields.md) |
| Records or a value from one SOQL query | **Verify with a query** | [Query prompt](./prompt-query.md) | [Query examples](../../examples/query/README.md), [Query reference](../../reference/evaluation/query.md) |
| Two separate SOQL query results | **Compare two queries** | [Compare two queries prompt](./prompt-compare-two-queries.md) | [Compare two queries examples](../../examples/compare-two-queries/README.md) |
| Logic that formula and query settings cannot express safely | **Verify with Apex** | [Apex prompt](./prompt-apex.md) | [Apex Check contract](../../developer-guides/write-an-apex-check.md), [Apex examples](../../examples/apex/README.md) |

If the requirement must prevent Salesforce from saving a record, use a Validation Rule,
record-triggered Flow custom error, or Apex trigger instead. Record Health Check never blocks a
save.

## Shared authoring rules

Every prompt repeats the merge-token, Check Set, Check, and safety rules from
[Shared rules](./shared-rules.md) word for word. Change that page when product behavior changes,
then regenerate the four prompts from it. `npm run check:ai-prompts` fails when a prompt drifts
from the shared block, names a field or stored value the Check metadata does not declare, or stops
offering a configurable field to the assistant.

Canonical merge-token examples:

- SOQL: `WHERE AccountId = {!record.Id}`
- Message: `{!record.Name fallback="This Account"} needs at least one verified Contact.`
- Result values in messages or Display Found/Expected Text:
  `Found {!rhcResult.foundValue}; expected {!rhcResult.expectedValue}.`
  `{!rhcResult.failedRecordCount} of {!rhcResult.totalRecordCount} contacts are incomplete.`
- Action URL: `/lightning/r/Account/{!record.Id}/related/Contacts/view`

`rhcResult` properties are `status`, `foundValue`, `foundValuePluralSuffix`, `expectedValue`,
`failedRecordCount`, `totalRecordCount`, and `reasonCode`. Do not put `rhcResult` tokens in SOQL or
Action URL. Do not use Flow/API names such as `evaluation.found` or `actualValue` as merge tokens.

Full token list: [Merge syntax](../../reference/merge-syntax/README.md).

## Before you ask an AI assistant

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
and copy **Field Name**. Do not provide a label such as "Customer Tier" and expect the assistant to
guess whether the API name is `Customer_Tier__c`.

## Review the proposed Check Set and Check

Confirm Check Set values against [Check Set fields](../../reference/custom-metadata/check-set-fields.md).
Confirm Check values against [Check fields](../../reference/custom-metadata/check-fields.md) and a
matching page in the [examples library](../../examples/README.md).

Do not approve a draft unless it explains `PASS`, `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, and
`ERROR`. Sharing matters: a hidden related record is not counted, and missing object or field access
can produce `UNABLE_TO_EVALUATE`.

For Apex drafts, a developer must review, test, and deploy the class before anyone enters the class
name in Check metadata. See the [Apex prompt](./prompt-apex.md) and
[Apex Check contract](../../developer-guides/write-an-apex-check.md).

## Test the human-approved draft

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
- [ ] The Check uses the simplest Evaluation Type that meets the requirement, and
  **Evaluation Type** is set.
- [ ] Every picklist value in the draft is the stored value, not the Setup label.
- [ ] The Check Set and Check names are administrator-created names unless the exact installed
  package metadata is intentionally reused.
- [ ] No one added or removed the `rhc__` namespace prefix manually.
- [ ] The proposal distinguishes hidden records from missing object or field access.
- [ ] SOQL and messages use Record Health Check merge tokens (`{!record.Id}`), not Flow or Apex bind
  syntax.
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
| It uses `{!record.id}`, `{!Id}`, `{!$Record.Id}`, `:recordId`, or quoted `'{!record.Id}'` <!-- rejected-token-fixture --> | Replace with Record Health Check merge tokens only. In SOQL use `{!record.Id}` unquoted; copy field API names from Setup. |
| It puts merge tokens in Pass Condition | Rewrite as a Salesforce formula (`NOT(ISBLANK(BillingCity))`). Merge tokens belong in queries, messages, and Action URLs. |
| It assumes zero query rows should pass or fail | Ask the business owner; then configure **If Query Finds No Records** where the Evaluation Type uses it. |
| It omits **Evaluation Type** | Every Check needs `EvaluationType__c`. There is no default. |
| It stores a Setup label instead of the stored value | Enter the stored value: **Skip** is `SKIP`, and **When a count query matches** is `WHEN_COUNT_QUERY_MATCHES`. Confirm each one in [Check fields](../../reference/custom-metadata/check-fields.md). |
| It recommends Record Health Check to prevent a save | Use a Validation Rule, Flow custom error, or Apex trigger. |
| It recommends an Apex example class that is not installed | Create, test, and deploy the class, or choose a metadata-only Evaluation Type. |
| It says a hidden related record is clean data | Correct the wording: the Check evaluates only records visible to the running user. |
| It omits `UNABLE_TO_EVALUATE` and `ERROR` testing | Add access, configuration, and unexpected-error test cases before approval. |

## Related

- [Shared rules](./shared-rules.md)
- [Requirement template](./requirement-template.md)
- [Configure Check Sets and Checks](../configure-check-sets-and-checks.md)
- [Create your first Check](../../step-by-step-guide/create-your-first-check.md)
- [Merge syntax](../../reference/merge-syntax/README.md)
- [Check Set fields](../../reference/custom-metadata/check-set-fields.md)
- [Check fields](../../reference/custom-metadata/check-fields.md)
- [Examples library](../../examples/README.md)
- [Build Checks](../README.md)
