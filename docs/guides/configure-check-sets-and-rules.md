# Configure Check Sets and Rules

> [!NOTE]
> On this page, turn a Salesforce readiness question into a Check Set and ordered Rules whose Evaluation Types, outcomes, display behavior, and troubleshooting choices work together coherently.

Use this guide to turn a business review into a Check Set and ordered Rules on a Salesforce record
page. It explains where each answer can come from, what users see, and what happens when a Rule does
not apply or cannot evaluate.

The guide uses the Framework's **Check Set**, **Rule**, and **Evaluation Type** terminology. The card
is advisory: it reports readiness without blocking saves or changing record data.

**Prerequisites:** Custom Metadata edit access in Setup and a deployed **Record Health Check**
Lightning Web Component.

## What you can accomplish

| Goal | Start with | What you will learn |
| --- | --- | --- |
| Design one card for a business review | [Mental model](#1-mental-model) | Separate card-level Check Set choices from individual Rule decisions |
| Choose how a Rule gets its answer | [What it can check](#2-what-it-can-check) | Select Verify with a formula, Verify with a query, Compare two queries, or Verify with Apex |
| Make results understandable | [Result meanings](#5-result-meanings) | Distinguish business failures, skipped Rules, unavailable answers, and system problems |
| Limit a Rule to the right records | [Applicability and dependencies](#10-applicability-and-dependencies) | Use formula, count-query, or Apex applicability without turning a non-applicable record into a failure |
| Guide users toward a correction | [Configure action links](configure-action-links.md) | Add Fix Message, Action Label, and a safe Action URL to failed Rules |
| Diagnose a problem before release | [Troubleshooting](#13-troubleshooting) | Investigate configuration, access, query, formula, Apex, and component issues |
| Review production readiness | [Review checklist](#14-review-checklist) | Confirm security, behavior, messages, limits, and representative test coverage |

## Contents

| Section | What it covers |
| ------- | -------------- |
| [1. Mental model](#1-mental-model) | Check Set, Rule, and component wiring |
| [2. What it can check](#2-what-it-can-check) | Choosing the right Evaluation Type |
| [3. Check Set fields](#3-check-set-fields) | Link to [Check Set field reference](../metadata/fields-check-set.md) |
| [4. Rule fields](#4-rule-fields) | Link to [Rule field reference](../metadata/fields-check-rule.md) and action links |
| [5. Result meanings](#5-result-meanings) | Status and severity |
| [6. Formula rules](#6-formula-rules) | Record-formula patterns |
| [7. Verify with a query Rules](#7-verify-with-a-query-rules) | Single-query patterns |
| [8. Compare two queries Rules](#8-compare-two-queries-rules) | Dual-query patterns |
| [9. Apex rules](#9-apex-rules) | Custom Apex patterns |
| [10. Applicability and dependencies](#10-applicability-and-dependencies) | Gating and prerequisites |
| [11. Merge tokens](#11-merge-tokens) | `{!record.Field}` in messages and SOQL |
| [12. Security and guardrails](#12-security-and-guardrails) | SOQL safety and permissions |
| [13. Troubleshooting](#13-troubleshooting) | Symptoms, causes, and fixes |
| [14. Review checklist](#14-review-checklist) | Pre-activation validation |
| [15. Runtime and integration](#15-runtime-and-integration) | Where results come from; pointers to architecture and APIs |

For practical patterns, use the [examples library](../examples/README.md).
For Evaluation Type contracts, use [Technical references](../reference/README.md#choose-an-evaluation-type-reference).

For setup, see [Create your first Rule](../installation/03-create-your-first-rule.md). For action-link patterns, see
[Configure action links](configure-action-links.md). For troubleshooting detail, see
[Troubleshoot with Show Diagnostics](troubleshoot-with-show-diagnostics.md).

## 1. Mental model

| Piece | What it means |
| ----- | ------------- |
| Component instance | The Lightning record page component. It points to one Check Set through the **Check Set** picker in App Builder (`checkSetName` in the LWC, stored and sent to Apex as the Check Set's `QualifiedApiName`). |
| Check Set | A group of Rules for one base object (for example, Account). Stored in `Record_Health_Check_Set__mdt`. |
| Rule | One individual check inside a Check Set. Stored in `Record_Health_Check_Rule__mdt`. |
| Evaluation Type | How a Rule checks the record: Formula, Query, Compare Two Queries, or Apex. |
| Result | The outcome shown after a Rule runs. |

Wiring example:

```text
Lightning component Check Set: Example_Account_Relationship_Risk
Check Set DeveloperName: Example_Account_Relationship_Risk
Rule DeveloperName: Example_Customer_Engagement_Current
```

**Where to place the component:** Lightning **record pages** only. The component needs a record context (`recordId`). It is not exposed on App or Home pages.

**App Builder property:** Select a **Check Set** from the dropdown. It lists the active Check Sets whose object matches this record page. The picklist displays the Master Label and stores the `QualifiedApiName`. When the object has exactly one active Check Set, it is selected for you. This is the only property; comparison expanders start collapsed and follow the Check Set's **Found/Expected Display** setting.

## 2. What it can check

| Evaluation Type (Setup label) | API value | Use when |
| -------------------------- | --------- | -------- |
| **Verify with a formula** | `FORMULA` | The answer is on the current record (or a parent field reachable by formula). |
| **Verify with a query** | `QUERY` | One SOQL result must be compared to a static value, formula, second query, or list. |
| **Compare two queries** | `COMPARE_TWO_QUERIES` | Two independent SOQL results must be compared (single value or list). |
| **Verify with Apex** | `APEX` | Logic needs code, such as multi-object date math or a weighted score. Keep external integration work outside the evaluator transaction. |

Representative Account patterns in the [examples library](../examples/README.md):

- Formula: Billing City is required.
- Formula + applicability: Partner Accounts must have Billing Country; others are skipped.
- Query + `ONE_RESULT`: Account has at least one Contact.
- Query + `ANY_ROW_PASSES`: At least one open Opportunity exceeds 10% of Annual Revenue.
- `COMPARE_TWO_QUERIES`: Contact count equals open Opportunity count.
- Dependency: Contact Email checked only after "has Contacts" passes.
- Apex: Recent activity across Tasks and Events.

## 3. Check Set fields

Field tables live in the metadata reference. This guide does not duplicate them.

Every field on `Record_Health_Check_Set__mdt`, including picklist values for **When Checks Run**, **Found/Expected Display**, display modes, and **Show Diagnostics**, is documented in **[Check Set fields](../metadata/fields-check-set.md)**. Use that page when you need Setup labels, API names, defaults, or allowed values.

## 4. Rule fields

Field tables live in the metadata reference. This guide does not duplicate them.

Every field on `Record_Health_Check_Rule__mdt` is documented in **[Rule fields](../metadata/fields-check-rule.md)**. Optional **Category** is metadata-only for now; the current card does not group rows by it. Optional **Fix Message**, **Action Label**, and **Action URL** fields render guidance and navigation on failed checks. Examples: [Configure action links](configure-action-links.md).

## 5. Result meanings

| Status | Meaning | Typical response |
| ------ | ------- | ---------------- |
| `PASS` | Rule ran and passed. Card label: **Pass**. | No action. |
| `FAIL` | Rule ran and found a data issue. Card label: **Failed**, **Warning**, or **Info** by Failure Severity. | Record or process owner. |
| `SKIPPED` | Rule did not apply or dependency did not pass. Card label: **Skipped**. | Review applicability or dependencies if unexpected. |
| `UNABLE_TO_EVALUATE` | Metadata, permissions, SOQL, or data blocked safe evaluation. Card label: **Unable to Check**. Setup fields say **Unable to Evaluate**. | Review configuration, field-level security, and the Reason Code. |
| `ERROR` | Unexpected Framework or Apex exception. Card label: **System Error**. | Review the Apex plugin, Salesforce logs, and the Reason Code. |

| Severity | Use when |
| -------- | -------- |
| Critical (`CRITICAL`) | Important problem to fix. |
| Warning (`WARNING`) | Should be reviewed. |
| Info (`INFO`) | Contextual information. |

Severity applies **only** to `FAIL` results.

## 6. Formula rules

Use Formula when the result is expressible with Salesforce formula syntax on the current record or
its parent relationships. Start with [Seller research readiness](../examples/formula/01-account-research-ready.md); use the
[Formula reference](../reference/evaluation/formula.md) for the complete contract.

| Formula result | Rule status |
| --- | --- |
| `true` | Pass |
| `false` | Fail |
| `null`, including an unavailable parent relationship such as `Parent.Field` with no parent | Unable to Evaluate |

Use this one example as the model for a meaningful Formula Rule. It combines three business
requirements and traverses two parent levels. The Account passes when it has a contact channel, has
a billing country, and its revenue is at least 10% of the top-level portfolio Account's revenue.

<table>
  <thead><tr><th>Setup field</th><th>Value</th></tr></thead>
  <tbody>
    <tr><td>Evaluation Type</td><td><code>FORMULA</code></td></tr>
    <tr><td>Pass Condition</td><td><pre><code>AND(
  OR(NOT(ISBLANK(Phone)), NOT(ISBLANK(Website))),
  NOT(ISBLANK(BillingCountry)),
  AnnualRevenue &gt;= Parent.Parent.AnnualRevenue * 0.10
)</code></pre></td></tr>
    <tr><td>Display Found Formula</td><td><code>AnnualRevenue</code></td></tr>
    <tr><td>Display Expected Formula</td><td><code>Parent.Parent.AnnualRevenue * 0.10</code></td></tr>
    <tr><td>Formula Result Type</td><td><code>NUMBER</code></td></tr>
    <tr><td>Message When Failed</td><td><code>{!record.Name} needs a contact channel, billing country, and revenue equal to at least 10% of its top-level portfolio account.</code></td></tr>
  </tbody>
</table>

If either parent relationship or a required revenue value is unavailable, the Rule cannot reach a
reliable conclusion and returns **Unable to Evaluate**. Use a shallower path when the object model
does not guarantee two Account parents.

### Formula operands can be formula or roll-up fields

| Supported operand | How to use it |
| --- | --- |
| Formula field | Reference its field API name directly. |
| Roll-up summary field | Reference its field API name directly. |
| Formula that depends on another formula | Reference the final field API name; the engine loads the dependency chain. |
| Number, text, date, Boolean, or picklist calculation | Use its normal Salesforce formula type and functions. |

Calculated dependencies can be nested to any depth. Reference the calculated field's API name
directly; the engine loads its dependency chain.

### Showing Found vs Expected (optional)

By default, a Formula check shows only a **Passes when** line containing the unquoted pass/fail
formula and no **Found** value. That line requires `Record_Health_Check_View_Diagnostics`. Other
users see the business message plus any configured Found/Expected chips. For balance and comparison
checks, declare two optional single-value formulas so the row shows readable values on each side:

| Setup field | Effect on pass or fail | Purpose |
| --- | --- | --- |
| Display Found Formula (`DisplayFoundFormula__c`) | Display only | Single-value formula shown as **Found**, representing what the record has. |
| Display Expected Formula (`DisplayExpectedFormula__c`) | Display only | Single-value formula shown as **Expected**, representing the required or target value. |
| Pass Condition (`PassConditionFormula__c`) | Decides pass or fail | Boolean formula that decides the result. |

`PassConditionFormula__c` still decides pass/fail (it must return Boolean); these two are display-only and additive. The engine does not compare Found and Expected to each other: there is no separate "formula comparison operator" setting; the comparison lives inside `PassConditionFormula__c`.

In the example above, a failing row displays the Account's revenue as **Found** and 10% of the
grandparent Account's revenue as **Expected**, while the complete Boolean formula remains the only
pass/fail decision.

> [!CAUTION]
> **Keep Found/Expected consistent with Pass Condition.** Because the engine does not compare the two sides itself, nothing stops you from showing values that disagree with the actual result. If `PassConditionFormula__c` compares A to B, use A for `DisplayFoundFormula__c` and B for `DisplayExpectedFormula__c`. Otherwise a row can **pass while Found ≠ Expected** or fail while the values look equal. A safe habit: copy each side of the comparison in `PassConditionFormula__c` exactly into the matching display formula.

| Situation | Configuration | Display behavior |
| --- | --- | --- |
| Simple presence or condition check, such as `NOT(ISBLANK(Phone))` or `ISPICKVAL(Type, "Partner")` | Leave Display Found Formula and Display Expected Formula blank. | Shows the default Expected value from Pass Condition and no Found value. |
| Balance, threshold, equality, or date comparison | Put the actual value in Display Found Formula and the target value in Display Expected Formula. | Shows both values without changing the pass/fail decision. |
| A display formula cannot be resolved | No configuration change is required. | Silently returns to the default display and never changes pass/fail. |
| Formula type is known | Set Single-Value Formula Return Type to Number, Text, Date, or the matching type. | Avoids unnecessary FormulaEval calls in bulk and Flow runs. |
| Formula type is uncertain | Leave Single-Value Formula Return Type as Auto. | The Framework determines the type. |

### Display: Value Format

**Display: Value Format** (`DisplayValueFormat__c`) controls how Found and Expected values are written
on the card for every Evaluation Type. The default is **Auto**, which chooses a format from the
value's type. Set an explicit format when both sides of a comparison must read in the same units,
for example Currency, Percent, or Ratio as Percent.

A format that cannot apply to a value returns the value with its original spelling. Display format
never changes Pass, Fail, Skipped, Unable to Evaluate, or System Error.

Primary contract: [Display value format](../reference/contracts/display-value-format.md). Field
catalog: [Display: Value Format](../metadata/fields-check-rule.md#display-value-format-displayvalueformat__c).

### Which Evaluation Type compares what?

To have the Framework compare two sides with a **Comparison Operator**, instead of encoding the comparison inside **Pass Condition**, use **Verify with a query**:

| You want to compare… | Evaluation Type | How |
| -------------------- | ------------ | --- |
| A SOQL result vs a **fixed value** | Verify with a query | `ExpectedValueSource__c = FIXED_VALUE`, set `ExpectedFixedValue__c` |
| A SOQL result vs a **record formula** | Verify with a query | `ExpectedValueSource__c = RECORD_FORMULA`, set `ExpectedRecordFormula__c` |
| A SOQL result vs **another SOQL result** | Verify with a query, or Compare two queries | `ExpectedValueSource__c = COMPARISON_QUERY` (or the **Compare two queries** Evaluation Type) |
| Two values **on the record** (formula vs formula, or formula vs fixed value) | Verify with a formula | Encode the comparison in `PassConditionFormula__c`; optionally add Found/Expected to display each side |

## 7. Verify with a query Rules

Use **Verify with a query** when one SOQL result is the primary value. Start with the
[Customer handoff](../examples/query/01-customer-contact.md); use the [Query reference](../reference/evaluation/query.md)
for result modes and edge cases.

### At least one Contact

| Setup field | Value |
| --- | --- |
| Source Query | <code>SELECT COUNT() FROM Contact WHERE AccountId = {!record.Id}</code> |
| How To Read Query Results | `ONE_RESULT` |
| Comparison Operator | `GREATER_THAN` |
| Expected Value Source | `FIXED_VALUE` |
| Expected Fixed Value | `0` |

### Supported aggregate functions

An alias is required except for bare `COUNT()`.

| Aggregate | Example | Result |
| --- | --- | --- |
| `COUNT()` | `SELECT COUNT() FROM Contact` | Number of returned records |
| `COUNT(field)` | `SELECT COUNT(Email) emailCount FROM Contact` | Number of non-null field values |
| `COUNT_DISTINCT(field)` | `SELECT COUNT_DISTINCT(LeadSource) sourceCount FROM Contact` | Number of distinct non-null values |
| `SUM(field)` | `SELECT SUM(Amount) totalAmount FROM Opportunity` | Total numeric value |
| `AVG(field)` | `SELECT AVG(Amount) averageAmount FROM Opportunity` | Average numeric value |
| `MIN(field)` | `SELECT MIN(CloseDate) earliestCloseDate FROM Opportunity` | Lowest value |
| `MAX(field)` | `SELECT MAX(CloseDate) latestCloseDate FROM Opportunity` | Highest value |

### Open pipeline equals 10% of Annual Revenue

| Setup field | Value |
| --- | --- |
| Source Query | <code>SELECT SUM(Amount) totalAmount FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false</code> |
| Source Query Field | `totalAmount` |
| How To Read Query Results | `ONE_RESULT` |
| Comparison Operator | `EQUALS` |
| Expected Value Source | `RECORD_FORMULA` |
| Expected Record Formula | `AnnualRevenue * 0.1` |

## 8. Compare two queries Rules

Use when both sides come from SOQL. Start with the
[Opportunity Contact Role coverage](../examples/compare-two-queries/01-opportunity-contact-role-coverage.md); use the
[Compare two queries reference](../reference/evaluation/compare-two-queries.md) for the complete
contract.

| Result shape | How To Read Query Results | Comparison operators | Matching behavior |
| --- | --- | --- | --- |
| One value from each query | `ONE_RESULT` | Single-value operators | `CONTAINS` and `DOES_NOT_CONTAIN` text comparisons are case-sensitive. |
| A list from each query | `COMPARE_AS_LISTS` | `LISTS_OVERLAP`, `LISTS_CONTAIN_ALL`, `LISTS_MATCH_EXACTLY` | List matching is case-insensitive. |

### Customer contact coverage keeps pace with open pipeline

| Setup field | Value |
| --- | --- |
| Source Query | <code>SELECT COUNT() FROM Contact WHERE AccountId = {!record.Id}</code> |
| Comparison Query | <code>SELECT COUNT() FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false</code> |
| How To Read Query Results | `ONE_RESULT` |
| Comparison Operator | `GREATER_THAN_OR_EQUAL` |

## 9. Apex rules

Use Apex when metadata cannot express the Rule safely. See the
[Apex reference](../reference/evaluation/apex-rule-contract.md), [Recent Account activity](../examples/apex/01-recent-activity.md),
and [Apex examples](../examples/README.md#apex-examples).

The documented Apex class names are examples. Create, test, and deploy your own class before
referencing it in **Apex Class**.

| Setup label | API name | Role |
| ----------- | -------- | ---- |
| Apex Class | `ApexClass__c` | Class implementing `RecordHealthCheckRule` |
| Apex Parameters (JSON) | `ApexParametersJson__c` | Optional configuration values passed as `context.parameters` |

For AI-assisted drafting, see [LLM Configuration Guide: Apex](draft-configuration-with-ai.md#54-apex-evaluationtype__c--apex) and [recent-activity Apex pattern](draft-configuration-with-ai.md#106-recent-taskevent-activity-apex-multi-object).

## 10. Applicability and dependencies

**Applicability**: does this Rule run for this record?

| Mode | When to use |
| ---- | ----------- |
| All records | Universal data quality rules. |
| `FORMULA` | Condition is on the record (for example, `ISPICKVAL(Type, "Partner")`). |
| `SOQL` | Condition needs a related COUNT (for example, at least one open Opportunity exists). |

**Dependencies**: does this Rule wait for another Rule to pass?

Set **Prerequisite Rule** to the prerequisite `DeveloperName`. Use sparingly for checks that are misleading unless a foundation check passed first.

## 11. Merge tokens

Merge tokens let one Rule speak about the record, its configuration, and its result without hard-coding those
values. Use the namespace and property exactly as shown. For the complete namespace, surface,
fallback, and limit contract, see the [Merge-token reference](../reference/contracts/merge-tokens.md).

The fallback is optional. A token without one inserts the resolved value when populated and inserts blank text when
the value is null, empty, or whitespace-only:

`{!rhcRule.checkTitle}`

For example, adding ` needs attention.` after that token produces `Data quality needs attention.` when the Check
Title is `Data quality`. If the Check Title is blank, it produces ` needs attention.`. Check Title is required on
active Rules, but the same blank behavior matters for optional record fields and relationships.

Add a quoted `fallback` attribute when a blank value should produce clear wording instead:

```text
{!record.Parent.Name fallback="Independent account"}
{!record.Owner.Manager.Name fallback="No manager assigned"}
{!rhcResult.foundValue fallback="Not measured"}
```

The fallback is literal text; it is not parsed as another merge token. Without an explicit fallback, display text
keeps the existing graceful behavior and inserts blank text. A URL with a blank token and no fallback is suppressed
instead of producing a broken link. In SOQL, the fallback is converted to the field's type; an invalid number,
date, date/time, time, or Boolean fallback returns `MISSING_BIND_VALUE` rather than running a misleading query.

### `record`: Record fields

Use any readable field API name from the current record. Relationship paths may cross up to five lookups.

<table>
  <thead><tr><th>Merge syntax</th><th>What it inserts</th><th>Example</th></tr></thead>
  <tbody>
    <tr><td><code>{!record.Name}</code></td><td>The current record's Name.</td><td><code>Review {!record.Name} before approval.</code></td></tr>
    <tr><td><code>{!record.FieldApiName}</code></td><td>Any readable field on the current record. Replace <code>FieldApiName</code> with the Salesforce API name. Add a quoted <code>fallback</code> attribute when a blank value needs a substitute.</td><td><code>{!record.Customer_Tier__c fallback="Standard"} customers require an annual review.</code></td></tr>
    <tr><td><code>{!record.Owner.Name}</code></td><td>A field from a related record.</td><td><code>Ask {!record.Owner.Name} to confirm the account details.</code></td></tr>
    <tr><td><code>{!record.Parent.Parent.Name}</code></td><td>A field reached through multiple lookup relationships.</td><td><code>Escalate the review to {!record.Parent.Parent.Name}.</code></td></tr>
  </tbody>
</table>

### `rhcRule`: Current Rule

<table>
  <thead><tr><th>Merge syntax</th><th>What it inserts</th><th>Example</th></tr></thead>
  <tbody>
    <tr><td><code>{!rhcRule.developerName}</code></td><td>The Rule's stable Developer Name.</td><td><code>Give support rule {!rhcRule.developerName}.</code></td></tr>
    <tr><td><code>{!rhcRule.masterLabel}</code></td><td>The Rule label shown in Setup.</td><td><code>Review the configuration for {!rhcRule.masterLabel}.</code></td></tr>
    <tr><td><code>{!rhcRule.checkTitle}</code></td><td>The user-facing Check Title.</td><td><code>{!rhcRule.checkTitle} needs attention.</code></td></tr>
    <tr><td><code>{!rhcRule.checkDescription}</code></td><td>The Check Description.</td><td><code>Requirement: {!rhcRule.checkDescription}.</code></td></tr>
    <tr><td><code>{!rhcRule.category}</code></td><td>The Rule's Category label.</td><td><code>This is a {!rhcRule.category} readiness requirement.</code></td></tr>
    <tr><td><code>{!rhcRule.evaluationType}</code></td><td>The Evaluation Type label.</td><td><code>This requirement uses {!rhcRule.evaluationType}.</code></td></tr>
    <tr><td><code>{!rhcRule.failureSeverity}</code></td><td>The Failure Severity label.</td><td><code>This is a {!rhcRule.failureSeverity} issue.</code></td></tr>
    <tr><td><code>{!rhcRule.evaluationOrder}</code></td><td>The Rule's evaluation order.</td><td><code>This requirement runs at position {!rhcRule.evaluationOrder}.</code></td></tr>
  </tbody>
</table>

### `rhcSet`: Current Check Set

<table>
  <thead><tr><th>Merge syntax</th><th>What it inserts</th><th>Example</th></tr></thead>
  <tbody>
    <tr><td><code>{!rhcSet.developerName}</code></td><td>The Check Set's stable Developer Name.</td><td><code>Give support Check Set {!rhcSet.developerName}.</code></td></tr>
    <tr><td><code>{!rhcSet.masterLabel}</code></td><td>The Check Set label shown in Setup.</td><td><code>Review the configuration for {!rhcSet.masterLabel}.</code></td></tr>
    <tr><td><code>{!rhcSet.cardTitle}</code></td><td>The title users see on the card.</td><td><code>Return to {!rhcSet.cardTitle} after making the correction.</code></td></tr>
    <tr><td><code>{!rhcSet.cardSubtitle}</code></td><td>The subtitle users see on the card.</td><td><code>Review scope: {!rhcSet.cardSubtitle}.</code></td></tr>
    <tr><td><code>{!rhcSet.objectApiName}</code></td><td>The Salesforce object API name configured for the Check Set.</td><td><code>This requirement evaluates a {!rhcSet.objectApiName} record.</code></td></tr>
  </tbody>
</table>

### `rhcResult`: Final Rule result

These values are available after the Rule has been evaluated.

<table>
  <thead><tr><th>Merge syntax</th><th>What it inserts</th><th>Example</th></tr></thead>
  <tbody>
    <tr><td><code>{!rhcResult.status}</code></td><td>The final status, such as Pass, Fail, Skipped, or Unable to Evaluate.</td><td><code>The review returned {!rhcResult.status}.</code></td></tr>
    <tr><td><code>{!rhcResult.foundValue}</code></td><td>The value the Rule found.</td><td><code>Found {!rhcResult.foundValue} open cases.</code></td></tr>
    <tr><td><code>{!rhcResult.foundValuePluralSuffix}</code></td><td>An empty value for one item or <code>s</code> for multiple items.</td><td><code>Found {!rhcResult.foundValue} issue{!rhcResult.foundValuePluralSuffix fallback="s"}.</code></td></tr>
    <tr><td><code>{!rhcResult.expectedValue}</code></td><td>The value the Rule expected.</td><td><code>Expected {!rhcResult.expectedValue}.</code></td></tr>
    <tr><td><code>{!rhcResult.failedRecordCount}</code></td><td>The number of returned records that failed.</td><td><code>{!rhcResult.failedRecordCount} contacts are missing email.</code></td></tr>
    <tr><td><code>{!rhcResult.totalRecordCount}</code></td><td>The total number of returned records evaluated.</td><td><code>Reviewed {!rhcResult.totalRecordCount} related contacts.</code></td></tr>
    <tr><td><code>{!rhcResult.reasonCode}</code></td><td>The diagnostic Reason Code.</td><td><code>The check could not finish because {!rhcResult.reasonCode}.</code></td></tr>
  </tbody>
</table>

### `rhcRun`: Current run

<table>
  <thead><tr><th>Merge syntax</th><th>What it inserts</th><th>Example</th></tr></thead>
  <tbody>
    <tr><td><code>{!rhcRun.runId}</code></td><td>The identifier shared by checks in the same run.</td><td><code>If the problem continues, give support run {!rhcRun.runId}.</code></td></tr>
    <tr><td><code>{!rhcRun.source}</code></td><td>Where the run started, such as the record page, Apex, or Flow.</td><td><code>This review was started from {!rhcRun.source}.</code></td></tr>
    <tr><td><code>{!rhcRun.startedAt}</code></td><td>When the run started.</td><td><code>The review started at {!rhcRun.startedAt}.</code></td></tr>
    <tr><td><code>{!rhcRun.completedAt}</code></td><td>When the run completed.</td><td><code>The review completed at {!rhcRun.completedAt}.</code></td></tr>
    <tr><td><code>{!rhcRun.durationMs}</code></td><td>How many milliseconds the run took.</td><td><code>The review completed in {!rhcRun.durationMs} milliseconds.</code></td></tr>
  </tbody>
</table>

The field determines which contexts are valid:

| Rule field type | Valid token namespaces |
| --- | --- |
| Failure, unable-to-evaluate, not-applicable, fix, action-label, Found-text, and Expected-text fields | `record`, `rhcResult`, `rhcRun`, `rhcRule`, `rhcSet` |
| Action URL | `record`, `rhcRun`, `rhcRule`, `rhcSet`; result tokens are intentionally rejected |
| Source Query, Comparison Query, and applicability Count Query | `record` only |
| Salesforce formula fields | Use Salesforce formula syntax directly; leave merge tokens for message and SOQL fields |

- Use field API names exactly as shown in Setup; custom fields include the `__c` suffix.
- Record tokens support text, ID/reference, number, currency, percent, checkbox, date, date/time, picklist,
  multi-select picklist, email, phone, URL, encrypted-text values, and relationship fields when readable.
- A blank value resolves to blank text. A null relationship makes its record token blank.
- The explicit fallback applies to null, empty, and whitespace-only values. It does not replace `0`, `false`, or a
  populated value.
- Fallback text may contain spaces and pipe characters inside its quoted value.
- Fallback text is inserted once and never recursively expanded.
- Curly braces are reserved for complete merge tokens. Extra, nested, or unmatched braces are rejected as
  `MALFORMED_TOKEN` instead of being rendered as text.
- Quotes, apostrophes, slashes, and additional pipes in a fallback are literal characters; they do not enable
  formulas, Markdown, HTML, nested tokens, or code execution.
- URL token values are URL-encoded automatically.
- SOQL tokens are escaped and typed automatically: strings are quoted; numbers, dates, date/times, and Booleans
  are bound in their native form. An unquoted multi-select token expands to a value tuple for `INCLUDES` or
  `EXCLUDES`; a quoted token preserves its semicolon-delimited text.
- The engine loads token fields before evaluation. If the running user lacks object or field access, the result
  can be `RECORD_NOT_ACCESSIBLE` or `MISSING_BIND_VALUE`.

SOQL examples live in the local [Query](../examples/README.md#query-examples) and
[Compare two queries](../examples/README.md#compare-two-queries-examples) libraries.

## 11a. Multi-line messages

**Message When Failed** and **Message When Unable To Evaluate** support multiple lines. Press **Enter** in Setup to start a new line; each line renders as a separate line on the card. Use a blank line (press Enter twice) to add spacing between paragraphs.

```text
{!record.Name} is out of balance.

Debit total: {!record.Debit_Total__c fallback="0"}
Expected credit net: {!record.Credit_Net__c}

Contact Finance to reconcile.
```

- Merge tokens work on any line.
- Single-line messages are unchanged: no extra spacing is added.
- Messages are always plain text (HTML and links are not rendered), and screen readers announce the lines as one sentence with a pause between them.

## 12. Security and guardrails

- Sharing, CRUD, and field access apply (`WITH USER_MODE` on dynamic SOQL).
- Keep queries narrow: clear `WHERE` clauses, merge tokens instead of hard-coded Ids.
- Editing `Record_Health_Check_Rule__mdt` is a privileged operation: anyone with Rule edit access can run SOQL as the viewing user.
- Keep user-facing messages free of secrets and stack traces.
- Unsafe SOQL (DML keywords, `FOR UPDATE`, `ALL ROWS`) is rejected.

## 13. Troubleshooting

| Symptom | Likely cause | What to check |
| ------- | ------------ | ------------- |
| Health Check Needs Setup / not ready yet | LWC has no Check Set selected | In App Builder, choose a Check Set and save the page. |
| Ask admin to activate a Check Set | Check Sets exist for the object but all are inactive | Activate a Check Set, then choose it in App Builder. |
| Ask admin to set up a Check Set | No Check Set matches the page object | Create and activate a Check Set whose Object matches the page object. |
| Check Set was not found | Selected Check Set was renamed or deleted | Re-open App Builder and choose an active Check Set. |
| Check Set is inactive | Selected Check Set has `IsActive__c = false` | Activate it, or choose another active Check Set. |
| Invalid configuration | Blank/invalid Object, or a bad display setting | Object plus Passed/Skipped Checks Display, Run Checks When, How Checks Appear, Comparison Display. |
| Object mismatch | Check Set `ObjectApiName__c` does not match the page object | Check Set object vs record page object. |
| No active checks | Check Set has no active Rules (inactive Rules may still exist) | Activate an existing Rule, or add a new active Rule. |
| No checks run | Inactive Check Set or Rules | `IsActive__c` on Set and Rules. |
| Rule skipped | Applicability false or required check did not pass | Applicability fields and `PrerequisiteRule__c`. |
| Unable to Check | SOQL, Formula, permissions, or limits | Rule fields, field-level security, Show Diagnostics, and the Reason Code. |
| System Error | Apex or framework exception | Apex class, Salesforce logs, and Show Diagnostics. |
| Stale results after metadata edit | Component not reloaded | Refresh the record page. |
| Stale results after inline edit | No auto-rerun on record save | Click **Rerun** or refresh the page. |
| Prerequisite skipped | Framework run cap | Lower the prerequisite's Evaluation Order so it falls within the configured execution window, or reduce active Rules. |
| Custom automation runs slowly or hits limits | The request includes too many records or the Check Set expands into too much work for the transaction | Keep one request within 200 records and one Check Set within the first 25 active Rules. Use `RecordHealthCheck.evaluate(...)` with a focused Check Set; see [Apex API](../api/apex-api.md) or [Flow actions](../integration/flow-actions.md). |
| Check passes in UI but fails from custom automation | Different running user (FLS) | Automation runs as the integration or invoking user: verify field access. |
| Expected a lifecycle event but none arrived | Publishing is off, the run was automatic page load, or the transaction rolled back | Enable **Publish User Run Event** or **Publish User Result Event**; use explicit Run/Rerun, Apex, or Flow; confirm the transaction committed; see [Platform events](../integration/lifecycle-events.md). |
| Expected an Error Log event but none arrived | The Check Set opted out, subscriber context suppressed a feedback loop, or publication failed | Check **Publish Error Log Event**, subscriber logs, and platform-event allocations; Salesforce debug logging remains independent. |

For Reason Codes, see [Reason Codes](../reference/contracts/reason-codes.md).

Pre-deployment metadata audit:

```apex
for (RecordHealthCheckMetadataValidator.ValidationIssue i :
        new RecordHealthCheckMetadataValidator().validate()) {
    System.debug(i.severity + ' ' + i.componentName + '.' + i.fieldName + ': ' + i.message);
}
```

## 14. Review checklist

Before activating a Check Set:

- [ ] Permission Set `Record_Health_Check_User` assigned to users who run the card (assign `Record_Health_Check_Admin` when Show Diagnostics is needed).
- [ ] Component **Check Set** selection points to the intended active Check Set.
- [ ] `ObjectApiName__c` matches the record page object.
- [ ] Component is on a **record page** (not App/Home).
- [ ] Every active Rule has Check Title, Evaluation Order, Evaluation Type, Failure Severity, and Message When Failed.
- [ ] Longer panels use Category consistently for authoring (UI grouping not implemented yet), or leave it blank to group checks as Uncategorized.
- [ ] Any Fix Message or Action URL are advisory/read-only. They can guide users on failed checks, but Record Health Check does not update records.
- [ ] **Found/Expected Display** matches the amount of Found/Expected detail users need (`ON_DEMAND` for audit-friendly panels, `FAILURES_ONLY` for compact pass checks).
- [ ] **Display: Value Format** is Auto unless a comparison Rule needs an explicit Number, Currency, Percent, Ratio as Percent, Checkbox, Date, Date/Time, Text, or Raw format ([Display value format](../reference/contracts/display-value-format.md)).
- [ ] Verify with a query and Compare two queries Rules have required query fields and **How To Read Query Results** set appropriately.
- [ ] `NoRowsResult__c` is set for `ANY_ROW_PASSES` / `ALL_ROWS_PASS` / `COMPARE_AS_LISTS` Rules.
- [ ] Apex Rules reference deployed `RecordHealthCheckRule` implementations.
- [ ] Dependencies reference active Rules with lower Evaluation Order in the same Check Set.
- [ ] **Show Diagnostics** is off for production unless actively troubleshooting (requires `Record_Health_Check_View_Diagnostics` via `Record_Health_Check_Admin`: see [Troubleshoot with Show Diagnostics](troubleshoot-with-show-diagnostics.md)).
- [ ] Lifecycle publication switches stay off until subscribers and allocations are reviewed; explicitly review the default-on **Publish Error Log Event** setting ([Lifecycle events](../integration/lifecycle-events.md)).
- [ ] Tested on records that pass, fail, skip, and unable-to-evaluate.

## 15. Runtime and integration

Record Health Check evaluates configuration at read time and returns results to the caller. It does
not store card results as Salesforce records.

| Surface | What happens | Full detail |
| --- | --- | --- |
| Lightning record page | The card loads definitions, evaluates Rules, and shows Pass / Fail / Skipped / Unable to Check / System Error | [Lightning component](../integration/lightning-component.md) |
| Apex | `RecordHealthCheck.evaluate(request)` returns a typed response for one Rule or Check Set | [Apex API](../api/apex-api.md) |
| Flow | Packaged actions return status counts and Result JSON | [Flow actions](../integration/flow-actions.md) |
| Lifecycle events | Optional after-commit Set Run / Rule Result events for deliberate runs | [Lifecycle events](../integration/lifecycle-events.md) |

For layers, limits, and class ownership, see [Architecture](../reference/framework/architecture.md).
For SOQL edge cases (empty results, multi-select binds, prerequisites), see the Evaluation Type
references and [§13 Troubleshooting](#13-troubleshooting).

## Related

- [Create your first Rule](../installation/03-create-your-first-rule.md): first install and first Rule
- [Examples library](../examples/README.md): practical patterns by Evaluation Type
- [Architecture](../reference/framework/architecture.md): published Framework architecture and source ownership
- [Check Set fields](../metadata/fields-check-set.md) · [Rule fields](../metadata/fields-check-rule.md)
- [Apex API](../api/apex-api.md) · [Flow actions](../integration/flow-actions.md)