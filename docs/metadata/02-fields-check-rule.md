# Rule fields (`Record_Health_Check_Rule__mdt`)

This page preserves the exact contract for every Rule field: the label shown in Setup, API name,
type, default, allowed values, runtime behavior, and an example. Use the decision path first, then
open an individual field when you need the full detail.

## Build a Rule in the order it runs

| Stage | Decision | Start with |
| --- | --- | --- |
| 1. Place the Rule | Which Check Set owns it, when does it run, and is it active? | [Check Set](#check-set-record_health_check_set__c), [Evaluation Order](#evaluation-order-evaluationorder__c), and [Active](#active-isactive__c) |
| 2. Decide whether it applies | Does it run for every record, only when a formula or query matches, or only after another Rule passes? | [Applies To](#applies-to-applicabilitymode__c) and [Prerequisite Rule](#prerequisite-rule-prerequisiterule__c) |
| 3. Choose how it evaluates | Can Salesforce formula or SOQL express the check, or is Apex required? | [Evaluation Type](#evaluation-type-evaluationtype__c) |
| 4. Define the decision | What value is found, what is expected, and how are they compared? | The Evaluation Type table below |
| 5. Explain the result | What should someone understand and do after a failure or an unable result? | [Check Title](#check-title-checktitle__c), [Message When Failed](#message-when-failed-failuremessage__c), and [Fix Message](#fix-message-fixmessage__c) |
| 6. Add a next action | Would a safe same-org destination help resolve the result? | [Action Label](#action-label-actionlabel__c) and [Action URL](#action-url-actionurl__c) |
| 7. Publish when needed | Does another process need the finalized Rule outcome? | [Publish User Result Event](#publish-user-result-event-publishuserresultevent__c) |

| What the Rule must verify | Evaluation Type | Start with |
| --- | --- | --- |
| Fields on the current Salesforce record | **Verify with a formula** (`FORMULA`) | [Pass Condition](#pass-condition-passconditionformula__c) |
| Records or an aggregate returned by one SOQL query | **Verify with a query** (`QUERY`) | [Source Query](#source-query-sourcequery__c) and [Comparison Operator](#comparison-operator-comparisonoperator__c) |
| One SOQL result against another SOQL result | **Compare two queries** (`COMPARE_TWO_QUERIES`) | [Source Query](#source-query-sourcequery__c) and [Comparison Query](#comparison-query-comparisonquery__c) |
| Logic implemented in a package or org Apex class | **Verify with Apex** (`APEX`) | [Apex Class](#apex-class-apexclass__c) |

For complete configurations, choose an [example by Evaluation Type](../examples/README.md). For text
that adapts to the record and result, use [Merge Syntax](../guides/03-configure-check-sets-and-rules.md#11-merge-tokens):
`record.*`, `rhcResult.*`, `rhcRun.*`, `rhcRule.*`, and `rhcSet.*`.

## Field index

| Setup label | API name | Group |
| --- | --- | --- |
| [Developer Name](#developer-name-developername) | `DeveloperName` | Identity and execution |
| [Label](#label-masterlabel) | `MasterLabel` | Identity and execution |
| [Check Set](#check-set-record_health_check_set__c) | `Record_Health_Check_Set__c` | Identity and execution |
| [Evaluation Order](#evaluation-order-evaluationorder__c) | `EvaluationOrder__c` | Identity and execution |
| [Active](#active-isactive__c) | `IsActive__c` | Identity and execution |
| [Check Title](#check-title-checktitle__c) | `CheckTitle__c` | What users see |
| [Check Description](#check-description-checkdescription__c) | `CheckDescription__c` | What users see |
| [Category](#category-category__c) | `Category__c` | What users see |
| [Failure Severity](#failure-severity-failureseverity__c) | `FailureSeverity__c` | What users see |
| [Message When Failed](#message-when-failed-failuremessage__c) | `FailureMessage__c` | What users see |
| [Message When Unable To Evaluate](#message-when-unable-to-evaluate-unabletoevaluatemessage__c) | `UnableToEvaluateMessage__c` | What users see |
| [Fix Message](#fix-message-fixmessage__c) | `FixMessage__c` | What users see |
| [Action Label](#action-label-actionlabel__c) | `ActionLabel__c` | What users see |
| [Action URL](#action-url-actionurl__c) | `ActionUrl__c` | What users see |
| [Evaluation Type](#evaluation-type-evaluationtype__c) | `EvaluationType__c` | Check type and value display |
| [Display: Value Format](#display-value-format-displayvalueformat__c) | `DisplayValueFormat__c` | Check type and value display |
| [Pass Condition](#pass-condition-passconditionformula__c) | `PassConditionFormula__c` | Check fields on this record (`FORMULA`) |
| [Display: Found Formula](#display-found-formula-displayfoundformula__c) | `DisplayFoundFormula__c` | Check fields on this record (`FORMULA`) |
| [Display: Expected Formula](#display-expected-formula-displayexpectedformula__c) | `DisplayExpectedFormula__c` | Check fields on this record (`FORMULA`) |
| [Formula Result Type](#formula-result-type-formularesulttype__c) | `FormulaResultType__c` | Check fields on this record (`FORMULA`) |
| [Source Query](#source-query-sourcequery__c) | `SourceQuery__c` | Query sources (`QUERY` / `COMPARE_TWO_QUERIES`) |
| [Source Query Field](#source-query-field-sourcequeryfield__c) | `SourceQueryField__c` | Query sources (`QUERY` / `COMPARE_TWO_QUERIES`) |
| [Comparison Query](#comparison-query-comparisonquery__c) | `ComparisonQuery__c` | Query sources (`QUERY` / `COMPARE_TWO_QUERIES`) |
| [Comparison Query Field](#comparison-query-field-comparisonqueryfield__c) | `ComparisonQueryField__c` | Query sources (`QUERY` / `COMPARE_TWO_QUERIES`) |
| [Value to find in the list (formula)](#value-to-find-in-the-list-formula-findinlistformula__c) | `FindInListFormula__c` | Query sources (`QUERY` / `COMPARE_TWO_QUERIES`) |
| [Comparison Operator](#comparison-operator-comparisonoperator__c) | `ComparisonOperator__c` | Query comparison |
| [Expected Value Comes From](#expected-value-comes-from-expectedvaluesource__c) | `ExpectedValueSource__c` | Query comparison |
| [Expected Value (Fixed)](#expected-value-fixed-expectedfixedvalue__c) | `ExpectedFixedValue__c` | Query comparison |
| [Expected Value (Formula)](#expected-value-formula-expectedrecordformula__c) | `ExpectedRecordFormula__c` | Query comparison |
| [How To Read Query Results](#how-to-read-query-results-queryresulthandling__c) | `QueryResultHandling__c` | Advanced query behavior |
| [If Query Finds No Records](#if-query-finds-no-records-norowsresult__c) | `NoRowsResult__c` | Advanced query behavior |
| [If Field Value Is Empty](#if-field-value-is-empty-emptyvaluehandling__c) | `EmptyValueHandling__c` | Advanced query behavior |
| [Max Query Rows (1-2000)](#max-query-rows-1-2000-maxqueryrows__c) | `MaxQueryRows__c` | Advanced query behavior |
| [Display: Found Text](#display-found-text-displayfoundtext__c) | `DisplayFoundText__c` | Advanced display text |
| [Display: Expected Text](#display-expected-text-displayexpectedtext__c) | `DisplayExpectedText__c` | Advanced display text |
| [Applies To](#applies-to-applicabilitymode__c) | `ApplicabilityMode__c` | When this check applies |
| [Applies When (Formula)](#applies-when-formula-applicabilityformula__c) | `ApplicabilityFormula__c` | When this check applies |
| [Applies When (Count Query)](#applies-when-count-query-applicabilitycountquery__c) | `ApplicabilityCountQuery__c` | When this check applies |
| [Message When Not Applicable](#message-when-not-applicable-applicabilitynotmetmessage__c) | `ApplicabilityNotMetMessage__c` | Friendly explanation for a skipped check |
| [Count Must Be](#count-must-be-applicabilitycountoperator__c) | `ApplicabilityCountOperator__c` | When this check applies |
| [Count Value](#count-value-applicabilitycountthreshold__c) | `ApplicabilityCountThreshold__c` | When this check applies |
| [Prerequisite Rule](#prerequisite-rule-prerequisiterule__c) | `PrerequisiteRule__c` | When this check applies |
| [Apex Class](#apex-class-apexclass__c) | `ApexClass__c` | Custom Apex (`APEX`) |
| [Apex Parameters (JSON)](#apex-parameters-json-apexparametersjson__c) | `ApexParametersJson__c` | Custom Apex (`APEX`) |
| [Publish User Result Event](#publish-user-result-event-publishuserresultevent__c) | `PublishUserResultEvent__c` | Lifecycle events |

## Read an individual field

| If you need to know… | Read these rows |
| --- | --- |
| What Salesforce calls it | Setup label and API name |
| Whether you must configure it | Required for and Default |
| What you can enter | Type, Capacity, and Allowed values |
| When it affects evaluation | Used when |
| What users or the Framework experience | Description, Help text, and Runtime behavior |
| What a realistic value looks like | Example |

## 1. Identity and execution

### Developer Name (`DeveloperName`)

| Attribute | Value |
| --- | --- |
| Setup label | **Developer Name** |
| API name | `DeveloperName` |
| Type | Text |
| Capacity | 40 characters |
| Always required | Yes |
| Default | No default |
| Used when | Every Rule; dependencies and programmatic calls use this stable name. |
| Description | Stable API identifier for the Custom Metadata record. |
| Help text | Referenced by dependencies and programmatic Rule execution. |
| Allowed values | Any value valid for the field type |
| Example | `Account_Pipeline_Readiness` |

### Label (`MasterLabel`)

| Attribute | Value |
| --- | --- |
| Setup label | **Label** |
| API name | `MasterLabel` |
| Type | Text |
| Capacity | 80 characters |
| Always required | Yes |
| Default | No default |
| Used when | Every Rule; identifies the Custom Metadata record in Setup. |
| Description | Setup list label for the Custom Metadata record. |
| Help text | This is not the user-facing card row title; use Check Title for that. |
| Allowed values | Any value valid for the field type |
| Example | `Account pipeline readiness` |

### Check Set (`Record_Health_Check_Set__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Check Set** |
| API name | `Record_Health_Check_Set__c` |
| Type | Metadata Relationship |
| Capacity | MetadataRelationship |
| Always required | Yes |
| Default | No default |
| Used when | Every Rule; assigns the Rule to one Check Set. |
| Description | <p>The parent Check Set this check belongs to. Required - every check must belong to exactly one Check Set.</p><p>The Check Set defines the object the checks run on and how the card behaves.</p> |
| Help text | <p>Required. The Check Set this check belongs to. Each check belongs to exactly one Check Set.</p> |
| Allowed values | Any value valid for the field type |
| Example | `Account_Data_Quality` from the integration-test metadata |

### Evaluation Order (`EvaluationOrder__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Evaluation Order** |
| API name | `EvaluationOrder__c` |
| Type | Number |
| Capacity | 4 digits, 0 decimal places |
| Always required | No |
| Default | `100` |
| Used when | Every Rule; controls execution and display order. |
| Description | <p>Controls the order in which checks run and appear on the card - lower numbers run and display first. Ties are broken alphabetically by the record's Name (DeveloperName).</p><p>This order also governs prerequisites: a check named in another check's "Prerequisite Rule" must have a lower "Evaluation Order". Defaults to 100.</p> |
| Help text | <p>Lower number runs and shows first (default 100). Tip: use 10, 20, 30... so you can insert new checks between existing ones later.</p><p>A prerequisite check must have a lower number than the check that requires it.</p> |
| Allowed values | Any value valid for the field type |
| Example | `100` |

### Active (`IsActive__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Active** |
| API name | `IsActive__c` |
| Type | Checkbox |
| Capacity | Checkbox |
| Always required | No |
| Default | **Checked**: `true` |
| Used when | Every Rule; uncheck to exclude the Rule from evaluation. |
| Description | <p>When checked, this check is included whenever its Check Set runs. When unchecked, the check is ignored during evaluation - a way to disable it temporarily without deleting the record.</p> |
| Help text | <p>Checked = the check runs as part of its Check Set. Uncheck to disable it without deleting it.</p> |
| Allowed values | **Checked**: `true`<br>**Unchecked**: `false` |


## 2. What users see

### Check Title (`CheckTitle__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Check Title** |
| API name | `CheckTitle__c` |
| Type | Text |
| Capacity | 255 characters |
| Always required | Yes |
| Default | No default |
| Used when | Every Rule; displayed as the check title on the card. |
| Description | <p>The name end users see for this check in the card row on the record page. Required on every check.</p><p>This is the friendly, user-facing title only - it is NOT the record's Label or Record Name (DeveloperName) shown in Setup. Keep it short, specific, and plain-language so a user immediately understands what was checked, e.g. "Billing City present".</p> |
| Help text | <p>Required. The title users see for this check on the record page, e.g. "Billing City present". Keep it short and plain.</p><p>Separate from the record's Setup Name/Label.</p> |
| Allowed values | Any value valid for the field type |
| Example | `Pipeline readiness` |

### Check Description (`CheckDescription__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Check Description** |
| API name | `CheckDescription__c` |
| Type | Text |
| Capacity | 255 characters |
| Always required | No |
| Default | No default |
| Used when | Optional for every Evaluation Type; displayed on title hover or keyboard focus. |
| Description | <p>Optional extra context shown when a user hovers over (or keyboard-focuses) the "Check Title" on the record page. Use it to explain, in plain language, what the check looks at and why it matters.</p><p>It is shown only on hover/focus - never inline on the row.</p> |
| Help text | <p>Optional. Extra context shown on hover over the check's title. Explain what the check looks at, in plain language.</p> |
| Allowed values | Any value valid for the field type |
| Example | `Checks open Opportunity count and pipeline amount.` |

### Category (`Category__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Category** |
| API name | `Category__c` |
| Type | Picklist |
| Capacity | Restricted picklist |
| Always required | No |
| Default | No default |
| Used when | Optional for every Evaluation Type; classification only in the current card. |
| Description | <p>Optional classification for the business outcome protected by this Rule, such as Completeness, Readiness, Risk, or Compliance. Use it to make metadata easier to find, report on, and reuse.</p><p>The current card does not group checks by Category. This choice does not change evaluation, severity, order, or the result shown to users.</p> |
| Help text | <p>Optional business-outcome classification. The current card does not group checks by this value, and it does not affect the result.</p> |
| Allowed values | **Completeness**: `COMPLETENESS`<br>**Consistency**: `CONSISTENCY`<br>**Timeliness**: `TIMELINESS`<br>**Eligibility**: `ELIGIBILITY`<br>**Readiness**: `READINESS`<br>**Risk**: `RISK`<br>**Compliance**: `COMPLIANCE`<br>**Relationship coverage**: `RELATIONSHIP_COVERAGE` |

### Failure Severity (`FailureSeverity__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Failure Severity** |
| API name | `FailureSeverity__c` |
| Type | Picklist |
| Capacity | Restricted picklist |
| Always required | No |
| Default | **Warning**: `WARNING` |
| Used when | Every Rule; displayed only for a `FAIL` result. |
| Description | <p>The business-impact level shown only when this check results in Fail: "Critical" shows red, "Warning" shows amber, "Info" shows blue. It has no effect on Pass, Skipped, Unable to Evaluate, or system-error outcomes.</p><p>Defaults to "Warning". Severity is deliberately separate from the engine's system-error status, which is why there is no "Error" choice.</p> |
| Help text | <p>Sets the color/level when the check fails: "Critical" = red, "Warning" = amber (default), "Info" = blue. No effect on non-fail outcomes.</p> |
| Allowed values | **Critical**: `CRITICAL`<br>**Warning**: `WARNING`<br>**Info**: `INFO` |

### Message When Failed (`FailureMessage__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Message When Failed** |
| API name | `FailureMessage__c` |
| Type | Long Text Area |
| Capacity | 32768 characters |
| Always required | No |
| Default | No default |
| Used when | Optional for every Evaluation Type; displayed for `FAIL`. Apex plugins return evaluation data, while metadata owns user-facing guidance. |
| Description | <p>The message users see when this check results in Fail. It supports the display merge tokens documented in the <a href="../guides/03-configure-check-sets-and-rules.md#11-merge-tokens">merge-token guide</a>.</p><p>Press Enter to start a new line; each line is shown as a separate line on the card.</p> |
| Help text | <p>Shown when the check fails. Merge tokens can insert record and Framework values with optional fallback text.</p><p>Press Enter for a new line.</p> |
| Allowed values | Any value valid for the field type |

Examples:

```text
{!record.Name} has {!record.NumberOfEmployees fallback="no recorded"} employees and is owned by {!record.Owner.Name}.

{!rhcRule.checkTitle} found a {!rhcRule.failureSeverity} {!rhcRule.category} issue for {!record.Name}.

{!record.Name} does not meet the requirements in {!rhcSet.cardTitle}.

Found {!rhcResult.foundValue}; expected {!rhcResult.expectedValue}.

{!rhcResult.failedRecordCount} of {!rhcResult.totalRecordCount} contacts for {!record.Name} are missing email.

The check returned {!rhcResult.status}. If you need help, reference run {!rhcRun.runId}.
```

### Message When Unable To Evaluate (`UnableToEvaluateMessage__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Message When Unable To Evaluate** |
| API name | `UnableToEvaluateMessage__c` |
| Type | Long Text Area |
| Capacity | 32768 characters |
| Always required | No |
| Default | No default |
| Used when | Optional for every Evaluation Type; replaces the default `UNABLE_TO_EVALUATE` message. |
| Description | <p>Optional. Replaces the default message users see when a check cannot be evaluated - for example a bad query or formula (the "Unable to Evaluate" outcome). It supports the display merge tokens documented in the <a href="../guides/03-configure-check-sets-and-rules.md#11-merge-tokens">merge-token guide</a>. Keep it user-friendly; never include SOQL, errors, or technical detail.</p><p>Press Enter to start a new line; each line is shown as a separate line on the card.</p> |
| Help text | <p>Optional. Friendly text shown when the check can't run (Unable to Evaluate). Don't include technical details.</p><p>Press Enter for a new line.</p> |
| Allowed values | Any value valid for the field type |

Examples:

```text
We could not evaluate {!record.Name} for parent account {!record.Parent.Name fallback="not assigned"}.

{!rhcRule.checkTitle} could not be completed in {!rhcSet.cardTitle}.

We could not confirm the requirement for {!record.Name} ({!rhcResult.reasonCode}).

Try again later. If the problem continues, give support run {!rhcRun.runId}, started at {!rhcRun.startedAt}.
```

### Fix Message (`FixMessage__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Fix Message** |
| API name | `FixMessage__c` |
| Type | Long Text Area |
| Capacity | 32768 characters |
| Always required | No |
| Default | No default |
| Used when | Optional for every Evaluation Type; displayed in failed-check details. |
| Description | <p>Optional next-step guidance displayed in the detail for a failed check. It supports the display merge tokens documented in the <a href="../guides/03-configure-check-sets-and-rules.md#11-merge-tokens">merge-token guide</a>. Tell the user what to review or change, using language that is specific to the failed requirement.</p><p>Pair it with an Action URL when a useful page, record, report, or playbook can take the user directly to that next step.</p> |
| Help text | <p>Optional guidance shown after a failure. Give the user a specific next step, such as "Review open Opportunities and their Amount values."</p> |
| Allowed values | Any value valid for the field type |

Examples:

```text
Ask {!record.Owner.Name} to update the phone number for {!record.Name}; the current value is {!record.Phone fallback="not provided"}.

Change the found value of {!rhcResult.foundValue} to the expected value of {!rhcResult.expectedValue}.

Resolve the {!rhcRule.failureSeverity} issue identified by {!rhcRule.checkTitle}.

Complete this correction, then rerun {!rhcSet.cardTitle}.

If the values still look wrong, contact Operations with run {!rhcRun.runId}.
```

### Action Label (`ActionLabel__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Action Label** |
| API name | `ActionLabel__c` |
| Type | Text |
| Capacity | 80 characters |
| Always required | No |
| Default | No default |
| Used when | Optional when Action URL is set; blank defaults to **Fix this**. |
| Description | <p>Optional user-facing text for the action link displayed when this Rule fails. Use a short verb phrase that describes the destination.</p><p>It supports the display merge tokens documented in the <a href="../guides/03-configure-check-sets-and-rules.md#11-merge-tokens">merge-token guide</a> (same rules as Fix Message). The field is 80 characters, so keep labels short.</p><p>Action URL controls whether the link appears. When Action URL is set and this field is blank, the link is labeled "Fix this".</p> |
| Help text | <p>Optional text for the failure action link. Supports merge tokens with optional fallback text. Requires Action URL; blank uses "Fix this".</p> |
| Allowed values | Any value valid for the field type |

Examples:

```text
Review {!record.Name}
Contact {!record.Owner.Name}
Fix {!rhcRule.checkTitle}
Return to {!rhcSet.cardTitle}
Correct {!rhcResult.foundValue} open case{!rhcResult.foundValuePluralSuffix fallback="s"}
Review run {!rhcRun.runId}
```

### Action URL (`ActionUrl__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Action URL** |
| API name | `ActionUrl__c` |
| Type | Long Text Area |
| Capacity | 32768 characters |
| Always required | No |
| Default | No default |
| Used when | Optional for every Evaluation Type; displayed only for `FAIL` when the resolved URL is safe. |
| Description | <p>Optional destination displayed as an action link when this Rule fails. Link to a Salesforce record, edit or create page, related list, report, Knowledge article, or HTTPS playbook.</p><p>It supports URL-safe record, Rule, Check Set, and run tokens documented in the <a href="../guides/03-configure-check-sets-and-rules.md#11-merge-tokens">merge-token guide</a>; result tokens are not allowed in URLs. Token values are URL-encoded automatically. Blank, unsafe, or overlong resolved URLs are hidden.</p><p>Action Label is optional and defaults to "Fix this".</p> |
| Help text | <p>Optional failure-action destination. Use a same-org path or HTTPS URL. Merge tokens with optional fallback text are supported.</p><p>Action Label is optional.</p> |
| Allowed values | Any value valid for the field type |

Examples:

```text
/lightning/r/Account/{!record.Id}/view
/lightning/r/Account/{!record.Id}/edit
/lightning/r/Account/{!record.Id}/related/Contacts/view
/lightning/o/Contact/new?defaultFieldValues=AccountId={!record.Id},LastName=New%20contact
```

```text
/lightning/o/Case/new?defaultFieldValues=AccountId={!record.Id},Subject=Review%20{!record.Name fallback="this account"},Origin=Web,Description=Rule%20{!rhcRule.developerName}%20in%20{!rhcSet.developerName}
```


## 3. Check type and value display

### Evaluation Type (`EvaluationType__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Evaluation Type** |
| API name | `EvaluationType__c` |
| Type | Picklist |
| Capacity | Restricted picklist |
| Always required | No |
| Default | No default |
| Used when | Every Rule; selects the Formula, Query, Compare two queries, or Apex evaluator. |
| Description | <p>How this check decides pass or fail. Required - there is no default, so you must choose one, and your choice determines which other fields you fill in (complete only the matching section).</p><ul><li>"Verify with a formula" evaluates a true/false formula on the current record - fill in "Pass Condition".</li><li>"Verify with a query" runs one SOQL query and compares its result - fill in "Source Query", "Comparison Operator", and "Expected Value Comes From".</li><li>"Compare two queries" compares the results of two SOQL queries - fill in "Source Query" and "Comparison Query".</li><li>"Verify with Apex" runs your own Apex class - fill in "Apex Class".</li></ul> |
| Help text | Required. Choose Formula for record fields, Query for related or aggregate data, Compare two queries for two result sets, or Apex for logic the other options cannot express. |
| Allowed values | **Verify with a formula**: `FORMULA`<br>**Verify with a query**: `QUERY`<br>**Compare two queries**: `COMPARE_TWO_QUERIES`<br>**Verify with Apex**: `APEX` |

### Display: Value Format (`DisplayValueFormat__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Display: Value Format** |
| API name | `DisplayValueFormat__c` |
| Type | Picklist |
| Capacity | Restricted picklist |
| Always required | No |
| Default | **Auto**: `AUTO` |
| Used when | Optional on any Rule. Apex Rules use the same formatter with the typed values returned by the plugin. |
| Description | <p>Display only. Controls how Found and Expected are written, including separate Salesforce Percent and Ratio as Percent semantics. Both sides use the same format, and formatting never changes pass or fail.</p><p>Leave "Auto" unless you want a specific look, such as showing Annual Revenue as currency, a fraction as a percentage, or an external Id as raw text.</p> |
| Help text | <p>Display only. Does not change pass or fail. Sets how Found and Expected are written, such as "Currency" for Annual Revenue, "Number" for an employee count, or "Raw" for an external Id.</p><p>Leave "Auto" unless you need a specific look.</p> |
| Allowed values | **Auto**: `AUTO`<br>**Number**: `NUMBER`<br>**Currency**: `CURRENCY`<br>**Percent**: `PERCENT`<br>**Ratio as Percent**: `RATIO_PERCENT`<br>**Checkbox**: `BOOLEAN`<br>**Date**: `DATE`<br>**Date/Time**: `DATETIME`<br>**Text**: `TEXT`<br>**Raw**: `RAW` |

This is a different setting from [Formula Result Type](#formula-result-type-formularesulttype__c),
which declares the type a formula returns so the Rule can calculate with it. A Formula Rule can set
Formula Result Type to **Number** and Display: Value Format to **Currency** at the same time.

Naming a format that cannot apply to a value is not an error - the value keeps its original
spelling. Full contract:
[Reference: Display value format](../reference/contracts/03-display-value-format.md).


## 4. Check fields on this record (`FORMULA`)

### Pass Condition (`PassConditionFormula__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Pass Condition** |
| API name | `PassConditionFormula__c` |
| Type | Long Text Area |
| Capacity | 32768 characters |
| Always required | No |
| Default | No default |
| Used when | Required when Evaluation Type is **Verify with a formula** (`FORMULA`). |
| Description | <p>A Salesforce formula that returns true (pass) or false (fail), evaluated against the current record. Required when "Evaluation Type" is "Verify with a formula"; not used by any other Evaluation Type.</p><p>Formula syntax only. Example: NOT(ISBLANK(BillingCity)).</p><p>For list-membership checks use "Value to find in the list (formula)" instead.</p> |
| Help text | <p>Required for "Verify with a formula". Return true (pass) or false (fail), e.g. NOT(ISBLANK(BillingCity)).</p><p>Not used for query or Apex checks.</p> |
| Allowed values | Any value valid for the field type |

Examples:

| Formula | What passes |
| --- | --- |
| `TRUE` | Every evaluated record |
| `NOT(ISBLANK(BillingCity))` | Billing City is populated |
| `OR(NOT(ISBLANK(Phone)), NOT(ISBLANK(Website)))` | Phone or Website is populated |
| `AnnualRevenue >= 100000` | Annual Revenue is at least 100,000 |
| `ISPICKVAL(Type, "Customer")` | Type is Customer |
| `NOT(ISBLANK(ParentId))` | A Parent Account is assigned |

### Display: Found Formula (`DisplayFoundFormula__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Display: Found Formula** |
| API name | `DisplayFoundFormula__c` |
| Type | Long Text Area |
| Capacity | 32768 characters |
| Always required | No |
| Default | No default |
| Used when | Optional for Formula Rules; display only. |
| Description | <p>Optional and display only - it never affects pass/fail. A formula, evaluated on the current record, whose result is shown as the "Found" value on the result row (the left side of the comparison - what the record has).</p><p>Write fixed values in formula syntax: text in double quotes ("Cold"), numbers bare (100), TRUE or FALSE, dates as DATE(2025,1,31). Its return type is set by "Formula Result Type".</p><p>Leave blank for no Found value. Example: BLANKVALUE(`Debit_Total__c`, 0).</p> |
| Help text | <p>Display only (not pass/fail). Formula for the "Found" value shown on the row, e.g. BLANKVALUE(`Debit_Total__c`, 0).</p><p>Fixed values use formula syntax ("Cold", 100, TRUE). Blank = no Found value.</p> |
| Allowed values | Any value valid for the field type |

Examples:

| Formula | Formula Result Type | Displayed value |
| --- | --- | --- |
| `"Hello"` | **Text** | `Hello` |
| `Name` | **Text** | The current record's Name |
| `Parent.Name` | **Text** | The parent Account's Name |
| `Name & " - " & TEXT(Type)` | **Text** | A combined value such as `Acme - Customer` |
| `IF(ISBLANK(Phone), "Missing", Phone)` | **Text** | `Missing` or the current Phone |
| `BLANKVALUE(NumberOfEmployees, 0)` | **Number** | Employee count, with blank shown as `0` |
| `AnnualRevenue` | **Number** | Current Annual Revenue |
| `TODAY()` | **Date** | The current date |
| `NOW()` | **Date/Time** | The current date and time |
| `NOT(ISBLANK(Website))` | **Checkbox** | `true` when Website is populated |

### Display: Expected Formula (`DisplayExpectedFormula__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Display: Expected Formula** |
| API name | `DisplayExpectedFormula__c` |
| Type | Long Text Area |
| Capacity | 32768 characters |
| Always required | No |
| Default | No default |
| Used when | Optional for Formula Rules; display only. |
| Description | <p>Optional and display only - it never affects pass/fail. A formula, evaluated on the current record, whose result is shown as the "Expected" value on the result row (the right side of the comparison - what the record should have had).</p><p>Write fixed values in formula syntax, the same way as "Display: Found Formula". Its return type is set by "Formula Result Type".</p><p>Leave blank to show the default "Passes when..." line echoing the "Pass Condition".</p> |
| Help text | <p>Display only (not pass/fail). Formula for the "Expected" value shown on the row.</p><p>Fixed values use formula syntax. Blank = shows the default "Pass Condition" line.</p> |
| Allowed values | Any value valid for the field type |

Examples:

| Formula | Formula Result Type | Displayed value |
| --- | --- | --- |
| `"Complete"` | **Text** | `Complete` |
| `BillingCountry` | **Text** | The current Billing Country |
| `Parent.BillingCountry` | **Text** | The parent Account's Billing Country |
| `"City, State, and Country populated"` | **Text** | A readable target statement |
| `10` | **Number** | `10` |
| `AnnualRevenue / 10` | **Number** | Ten percent of Annual Revenue |
| `DATE(YEAR(TODAY()), 12, 31)` | **Date** | The final day of the current year |
| `NOW() + 7` | **Date/Time** | Seven days from the current time |
| `TRUE` | **Checkbox** | `true` |

### Formula Result Type (`FormulaResultType__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Formula Result Type** |
| API name | `FormulaResultType__c` |
| Type | Picklist |
| Capacity | Restricted picklist |
| Always required | No |
| Default | **Auto**: `AUTO` |
| Used when | Optional when the Rule uses a record formula; `AUTO` is valid for all supported formula result types. |
| Description | <p>Declares the data type your formulas return. It applies to all single-value formulas in this check - "Value to find in the list (formula)" and "Expected Value (Formula)", which affect pass/fail, as well as "Display: Found Formula" and "Display: Expected Formula", which are display only.</p><p>Leave "Auto" unless you know the return type; declaring it saves formula calls, but "Auto" always resolves correctly. Choices: "Auto", "Checkbox", "Number", "Date", "Date/Time", "Text".</p> |
| Help text | <p>The type your formulas return. Applies to every formula in the check (the list/expected value formulas and the display formulas).</p><p>Leave "Auto" unless you know the type - "Auto" always works but uses more formula calls.</p> |
| Allowed values | **Auto**: `AUTO`<br>**Checkbox**: `BOOLEAN`<br>**Number**: `NUMBER`<br>**Date**: `DATE`<br>**Date/Time**: `DATETIME`<br>**Text**: `TEXT` |


## 5. Query sources (`QUERY` / `COMPARE_TWO_QUERIES`)

### Source Query (`SourceQuery__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Source Query** |
| API name | `SourceQuery__c` |
| Type | Long Text Area |
| Capacity | 32768 characters |
| Always required | No |
| Default | No default |
| Used when | Required for Query and Compare two queries Rules, except Query list-membership mode uses Comparison Query as its list source. |
| Description | <p>The primary SOQL query that fetches what you are checking. Required when "Evaluation Type" is "Verify with a query" or "Compare two queries".</p><p>Use record merge tokens to insert typed values from the current record, and COUNT() for "how many" checks. Leave blank only for the list-membership operators "List contains any" / "List contains none", which read the record value from "Value to find in the list (formula)" and the list from "Comparison Query".</p> |
| Help text | <p>Required for "Verify with a query" and "Compare two queries". SOQL returning the data to check; record merge tokens support optional typed fallbacks.</p><p>Use COUNT() for "how many" checks.</p> |
| Allowed values | Any value valid for the field type |

Examples:

```sql
SELECT COUNT() FROM Contact WHERE AccountId = {!record.Id}
SELECT Id FROM Account WHERE Industry = {!record.Industry fallback="Technology"}
SELECT Id FROM Opportunity WHERE AccountId = {!record.Id} AND OwnerId = {!record.Owner.ManagerId}
SELECT Id FROM Opportunity WHERE AccountId = {!record.Id} AND Amount >= {!record.AnnualRevenue fallback="0"}
SELECT Id FROM Opportunity WHERE AccountId = {!record.Id} AND CreatedDate >= {!record.CreatedDate}
SELECT Id FROM Account WHERE IsDeleted = {!record.IsDeleted}
SELECT Id FROM Account WHERE Name LIKE '{!record.Name}%'
```

### Source Query Field (`SourceQueryField__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Source Query Field** |
| API name | `SourceQueryField__c` |
| Type | Text |
| Capacity | 255 characters |
| Always required | No |
| Default | No default |
| Used when | Set when Source Query returns a selected field or an aliased aggregate; leave blank only for bare `COUNT()`. |
| Description | <p>The API name of the field or aggregate alias to read from the "Source Query" result.</p><p>Leave blank only for bare `COUNT()`. For `SUM()`, `MIN()`, `MAX()`, `AVG()`, `COUNT(field)`, or `COUNT_DISTINCT(field)`, give the expression an alias and enter that alias here.</p> |
| Help text | <p>Column or aggregate alias to read, such as `MailingCity` or `totalAmount`. Leave blank only for bare `COUNT()`.</p> |
| Allowed values | Any value valid for the field type |

Example: use `totalAmount` for the aliased aggregate below. Leave this field blank for bare `COUNT()`.

```sql
SELECT SUM(Amount) totalAmount FROM Opportunity WHERE AccountId = {!record.Id}
```

### Comparison Query (`ComparisonQuery__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Comparison Query** |
| API name | `ComparisonQuery__c` |
| Type | Long Text Area |
| Capacity | 32768 characters |
| Always required | No |
| Default | No default |
| Used when | Required for Compare two queries, comparison-query expected values, and Query list-membership operators. |
| Description | <p>The second SOQL query. Used when "Expected Value Comes From" is "Comparison query", for a "Compare two queries" check, or as the list source for the "List contains any" / "List contains none" operators.</p><p>Supports record merge tokens with optional typed fallbacks. Read a specific column from it with "Comparison Query Field".</p> |
| Help text | The second SOQL query - for "Comparison query" comparisons, "Compare two queries" checks, or the list for "List contains any"/"List contains none". |
| Allowed values | Any value valid for the field type |

Examples:

```sql
SELECT COUNT() FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false
SELECT AnnualRevenue FROM Account WHERE Id = {!record.ParentId fallback="001000000000000AAA"}
SELECT EndDate FROM Contract WHERE AccountId = {!record.Id} AND Status = 'Activated' ORDER BY EndDate LIMIT 1
SELECT MailingState FROM Contact WHERE AccountId = {!record.Id} AND MailingState != null
```

### Comparison Query Field (`ComparisonQueryField__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Comparison Query Field** |
| API name | `ComparisonQueryField__c` |
| Type | Text |
| Capacity | 255 characters |
| Always required | No |
| Default | No default |
| Used when | Set when Comparison Query returns a selected field or an aliased aggregate; leave blank only for bare `COUNT()`. |
| Description | <p>The API name of the field or aggregate alias to read from the "Comparison Query" result.</p><p>Leave blank only for bare `COUNT()`. Other aggregate expressions require an alias entered here.</p> |
| Help text | <p>Column or aggregate alias to read, such as `Country_Code__c` or `comparisonTotal`. Leave blank only for bare `COUNT()`.</p> |
| Allowed values | Any value valid for the field type |

Example: use `comparisonTotal` for the aliased aggregate below.

```sql
SELECT SUM(Amount) comparisonTotal FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false
```

### Value to find in the list (formula) (`FindInListFormula__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Value to find in the list (formula)** |
| API name | `FindInListFormula__c` |
| Type | Long Text Area |
| Capacity | 32768 characters |
| Always required | No |
| Default | No default |
| Used when | Required for Query Rules using **List contains any** or **List contains none**. |
| Description | <p>Required when "Evaluation Type" is "Verify with a query" and "Comparison Operator" is "List contains any" or "List contains none" (also set "How To Read Query Results" to "Compare as lists"). Enter a Salesforce formula, evaluated on the current record, whose result is the single value searched for in the list returned by "Comparison Query" - the list is the query, not this field.</p><p>A bare field name is the simplest formula, e.g. BillingCountry; a literal is written in formula syntax, e.g. "US". Leave blank for every other Evaluation Type and operator.</p> |
| Help text | <p>For "Verify with a query" with "List contains any"/"List contains none". A formula on the record giving the value to look for in the "Comparison Query" list, e.g. BillingCountry (a bare field) or "US" (a literal).</p><p>Leave blank otherwise.</p> |
| Allowed values | Any value valid for the field type |
| Example | `BillingCity` |


## 6. Query comparison

### Comparison Operator (`ComparisonOperator__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Comparison Operator** |
| API name | `ComparisonOperator__c` |
| Type | Picklist |
| Capacity | Restricted picklist |
| Always required | No |
| Default | No default |
| Used when | Required for Query and Compare two queries Rules. |
| Description | <p>How the value from the "Source Query" is compared to the expected value. Required for "Verify with a query" and "Compare two queries"; not used for "Verify with a formula". No default, so you must choose one.</p><p>"Is empty" and "Is not empty" need nothing to compare against. The list operators split into two groups:</p><ul><li>"List contains any" and "List contains none" work with "Verify with a query" and "How To Read Query Results" set to "Compare as lists" - the record value comes from "Value to find in the list (formula)" and the list comes from "Comparison Query".</li><li>"Lists overlap", "Lists contain all", and "Lists match exactly" work only with "Compare two queries" and "How To Read Query Results" set to "Compare as lists" - both lists come from the two queries.</li></ul> |
| Help text | <p>Required for query checks. Choose how Found is compared with Expected.</p><p>Empty operators need no Expected value; list operators require "Compare as lists".</p> |
| Allowed values | **Equals**: `EQUALS`<br>**Does not equal**: `NOT_EQUALS`<br>**Greater than**: `GREATER_THAN`<br>**Greater than or equal**: `GREATER_THAN_OR_EQUAL`<br>**Less than**: `LESS_THAN`<br>**Less than or equal**: `LESS_THAN_OR_EQUAL`<br>**Contains text**: `CONTAINS`<br>**Does not contain text**: `DOES_NOT_CONTAIN`<br>**Is empty**: `IS_BLANK`<br>**Is not empty**: `IS_NOT_BLANK`<br>**List contains any**: `LIST_CONTAINS_ANY`<br>**List contains none**: `LIST_CONTAINS_NONE`<br>**Lists overlap**: `LISTS_OVERLAP`<br>**Lists contain all**: `LISTS_CONTAIN_ALL`<br>**Lists match exactly**: `LISTS_MATCH_EXACTLY` |

### Expected Value Comes From (`ExpectedValueSource__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Expected Value Comes From** |
| API name | `ExpectedValueSource__c` |
| Type | Picklist |
| Capacity | Restricted picklist |
| Always required | No |
| Default | No default |
| Used when | Set for Query Rules when the operator needs a right-side value; omit for empty-value operators and Compare two queries. |
| Description | <p>For a "Verify with a query" check, this says where the expected value comes from. No default.</p><ul><li>"Fixed value" - type it in "Expected Value (Fixed)".</li><li>"Record formula" - enter it in "Expected Value (Formula)".</li><li>"Comparison query" - the expected value comes from the "Comparison Query" result.</li></ul><p>Leave unset for "Compare two queries" (both sides are queries) and for the operators "Is empty" / "Is not empty".</p> |
| Help text | <p>Where the expected value comes from (query checks).</p><ul><li>"Fixed value" -> "Expected Value (Fixed)".</li><li>"Record formula" -> "Expected Value (Formula)".</li><li>"Comparison query" -> "Comparison Query".</li></ul><p>Leave unset for Compare two queries and "Is empty"/"Is not empty".</p> |
| Allowed values | **Fixed value**: `FIXED_VALUE`<br>**Record formula**: `RECORD_FORMULA`<br>**Comparison query**: `COMPARISON_QUERY` |

### Expected Value (Fixed) (`ExpectedFixedValue__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Expected Value (Fixed)** |
| API name | `ExpectedFixedValue__c` |
| Type | Text |
| Capacity | 255 characters |
| Always required | No |
| Default | No default |
| Used when | Required when Expected Value Comes From is **Fixed value**. |
| Description | <p>The fixed value to compare against - a plain value, not a formula. Used only when "Expected Value Comes From" is "Fixed value".</p><p>Enter it literally, with no formula syntax or quotes: text as Approved, a number as 0 / 5 / 100000, a date as 2025-01-31.</p> |
| Help text | <p>A plain fixed value (not a formula) - enter literally with no quotes, e.g. Approved, 5, or 2025-01-31. Only used when "Expected Value Comes From" = "Fixed value".</p> |
| Allowed values | Any value valid for the field type |
| Example | `0` |

### Expected Value (Formula) (`ExpectedRecordFormula__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Expected Value (Formula)** |
| API name | `ExpectedRecordFormula__c` |
| Type | Long Text Area |
| Capacity | 32768 characters |
| Always required | No |
| Default | No default |
| Used when | Required when Expected Value Comes From is **Record formula**. |
| Description | <p>A Salesforce formula, evaluated on the current record, that produces the value to compare against. Used only when "Expected Value Comes From" is "Record formula".</p><p>Formula syntax only - not Apex or SOQL.</p> |
| Help text | <p>Salesforce formula giving the value to compare against. It may return literal text, a field, a relationship field, or a calculated value. Used when "Expected Value Comes From" = "Record formula".</p> |
| Allowed values | Any value valid for the field type |

Examples:

| Formula | Formula Result Type | Value used for comparison |
| --- | --- | --- |
| `"Approved"` | **Text** | The literal text `Approved` |
| `BillingCity` | **Text** | The current record's Billing City |
| `Parent.BillingCity` | **Text** | The parent Account's Billing City |
| `5` | **Number** | The number `5` |
| `BLANKVALUE(Parent.AnnualRevenue, 0)` | **Number** | The parent Account's Annual Revenue, with blank shown as `0` |
| `DATE(YEAR(TODAY()), 12, 31)` | **Date** | The final day of the current year |
| `NOW() + 7` | **Date/Time** | Seven days from the current time |
| `TRUE` | **Checkbox** | `true` |


## 7. Advanced query behavior

### How To Read Query Results (`QueryResultHandling__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **How To Read Query Results** |
| API name | `QueryResultHandling__c` |
| Type | Picklist |
| Capacity | Restricted picklist |
| Always required | No |
| Default | **One row or aggregate**: `ONE_RESULT` |
| Used when | Required for Query and Compare two queries Rules. |
| Description | <p>Tells the engine how to read the "Source Query" result. Required for "Verify with a query" and "Compare two queries".</p><ul><li>"One row or aggregate" expects a single row or an aggregate such as COUNT() or SUM().</li><li>"Any record passes" passes if at least one returned record passes.</li><li>"Every record passes" passes only if all returned records pass.</li><li>"Compare as lists" treats results as lists - required for every list operator (both the "List contains any/none" membership checks and the "Lists overlap / contain all / match exactly" comparisons).</li></ul><p>Defaults to "One row or aggregate".</p> |
| Help text | <p>How to read the query result.</p><ul><li>"One row or aggregate" = one row, COUNT(), or SUM().</li><li>"Any record passes" = one passing record is enough.</li><li>"Every record passes" = all must pass.</li><li>"Compare as lists" = required for every list operator.</li></ul> |
| Allowed values | **One row or aggregate**: `ONE_RESULT`<br>**Any record passes**: `ANY_ROW_PASSES`<br>**Every record passes**: `ALL_ROWS_PASS`<br>**Compare as lists**: `COMPARE_AS_LISTS` |

### If Query Finds No Records (`NoRowsResult__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **If Query Finds No Records** |
| API name | `NoRowsResult__c` |
| Type | Picklist |
| Capacity | Restricted picklist |
| Always required | No |
| Default | No default |
| Used when | Required for multi-row and list query modes; not used by Formula or Apex Rules. |
| Description | <p>What the check should do when the "Source Query" returns no records. No default - you must choose, because Pass versus Fail can invert the meaning of a check.</p><p>Required when "How To Read Query Results" is "Any record passes", "Every record passes", or "Compare as lists". Choices: "Pass" (no records is healthy), "Fail" (no records is a problem), "Skip" (not applicable here), or "Unable to evaluate" (cannot tell).</p><p>Example: a query for open high-priority cases finding none usually means the record is healthy, so choose "Pass".</p> |
| Help text | <p>Required for multi-row and list checks. Choose the business meaning of no matching records: Pass, Fail, Skip, or Unable to evaluate.</p> |
| Allowed values | **Pass**: `PASS`<br>**Fail**: `FAIL`<br>**Skip**: `SKIP`<br>**Unable to evaluate**: `UNABLE_TO_EVALUATE` |

### If Field Value Is Empty (`EmptyValueHandling__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **If Field Value Is Empty** |
| API name | `EmptyValueHandling__c` |
| Type | Picklist |
| Capacity | Restricted picklist |
| Always required | No |
| Default | **Treat as not matching**: `AS_NO_MATCH` |
| Used when | Optional for non-aggregate Query and Compare two queries comparisons. |
| Description | <p>How to handle an empty field value while comparing query results. Applies to "Verify with a query" and "Compare two queries"; ignored for "Verify with a formula", "Verify with Apex", and pure aggregate queries.</p><ul><li>"Ignore the record" leaves records with an empty value out of the comparison.</li><li>"Treat as blank" compares the empty value as blank text.</li><li>"Treat as not matching" makes an empty value always fail the comparison.</li></ul><p>Defaults to "Treat as not matching", so an empty value does not silently pass a data-quality check.</p> |
| Help text | <p>How empty field values are compared.</p><ul><li>"Ignore the record" = leave them out.</li><li>"Treat as blank" = compare as blank text.</li><li>"Treat as not matching" (default) = an empty value fails the comparison.</li></ul> |
| Allowed values | **Ignore the record**: `SKIP_RECORD`<br>**Treat as blank**: `AS_BLANK`<br>**Treat as not matching**: `AS_NO_MATCH` |

### Max Query Rows (1-2000) (`MaxQueryRows__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Max Query Rows (1-2000)** |
| API name | `MaxQueryRows__c` |
| Type | Number |
| Capacity | 4 digits, 0 decimal places |
| Always required | No |
| Default | `200` |
| Used when | Applies to Query and Compare two queries Rules; aggregate queries still follow Salesforce limits. |
| Description | <p>The maximum number of rows this Rule's query may return, from 1 to 2000. Defaults to 200.</p><p>The Framework applies the cap because every returned row consumes Salesforce query-row, heap, comparison, and response-building resources in the current transaction. A bounded result also prevents one broadly filtered Rule from crowding out other Rules in the Check Set.</p><p>Keep the smallest value that can answer the business question. Raise it only when a tested Rule genuinely needs more than 200 rows; narrowing the SOQL filter is usually safer than increasing the cap.</p> |
| Help text | <p>Maximum rows returned for this Rule, from 1 to 2000 (default 200). Keep it as low as the business decision allows.</p> |
| Allowed values | Any value valid for the field type |
| Example | `500` when the Rule intentionally needs more than the default 200 rows |


## 8. Advanced display text

### Display: Found Text (`DisplayFoundText__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Display: Found Text** |
| API name | `DisplayFoundText__c` |
| Type | Text |
| Capacity | 255 characters |
| Always required | No |
| Default | No default |
| Used when | Optional on any Evaluation Type whose Found line the Framework writes - Query, Formula, and Compare two queries; display only. An Apex Rule writes its own Found value, so this field does not apply there. |
| Description | <p>Optional and display only. Plain text (not a formula) that replaces the Found line the Framework writes: the auto-generated "N of M records did not pass" summary on a multi-row ("Every record passes") query check, and the Found value on any other Query, Formula, or Compare two queries Rule.</p><p>It supports the display merge tokens documented in the <a href="../guides/03-configure-check-sets-and-rules.md#11-merge-tokens">merge-token guide</a>, including <code>{!rhcResult.foundValue}</code> for the value it replaces.</p> |
| Help text | <p>Display only. Plain text (not a formula) for the "Found" line. Supports record and result merge tokens with optional fallback text.</p> |
| Allowed values | Any value valid for the field type |

Examples:

```text
{!rhcResult.failedRecordCount} of {!rhcResult.totalRecordCount} contacts for {!record.Name} are missing email.

{!rhcRule.checkTitle} found {!rhcResult.foundValue} issue{!rhcResult.foundValuePluralSuffix fallback="s"}.

{!rhcSet.cardTitle}: {!rhcResult.failedRecordCount} related records need attention.

Found during run {!rhcRun.runId}.
```

### Display: Expected Text (`DisplayExpectedText__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Display: Expected Text** |
| API name | `DisplayExpectedText__c` |
| Type | Text |
| Capacity | 255 characters |
| Always required | No |
| Default | No default |
| Used when | Optional on any Evaluation Type whose Expected line the Framework writes - Query, Formula, and Compare two queries; display only. An Apex Rule writes its own Expected value, so this field does not apply there. |
| Description | <p>Optional and display only. Plain text (not a formula) that replaces the Expected line the Framework writes, on a multi-row ("Every record passes") query check and on any other Query, Formula, or Compare two queries Rule. On a Formula Rule it replaces the "Passes when" echo of the pass condition, and the row goes back to the plain Expected caption.</p><p>It supports the display merge tokens documented in the <a href="../guides/03-configure-check-sets-and-rules.md#11-merge-tokens">merge-token guide</a>, including <code>{!rhcResult.expectedValue}</code> for the value it replaces.</p> |
| Help text | <p>Display only. Plain text (not a formula) for the "Expected" line. Supports record and result merge tokens with optional fallback text.</p> |
| Allowed values | Any value valid for the field type |

Examples:

```text
Expected {!rhcResult.expectedValue} for every contact related to {!record.Name}.

All {!rhcResult.totalRecordCount} contacts should have an email address.

{!rhcRule.checkTitle} expects every related record to pass.

Meet the standard defined by {!rhcSet.cardTitle}.

Expectation evaluated from {!rhcRun.source} run {!rhcRun.runId}.
```


## 9. When this check applies

### Applies To (`ApplicabilityMode__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Applies To** |
| API name | `ApplicabilityMode__c` |
| Type | Picklist |
| Capacity | Restricted picklist |
| Always required | No |
| Default | **All records**: `ALL_RECORDS` |
| Used when | Every Rule; defaults to all records. |
| Description | <p>Decides whether this check applies to the current record before it runs.</p><ul><li>"All records" runs it on every record.</li><li>"When a formula is true" runs it only when the formula in "Applies When (Formula)" returns true.</li><li>"When a count query matches" runs it only when the count from "Applies When (Count Query)" satisfies "Count Must Be" and "Count Value".</li></ul><p>When the condition is not met, the check is marked Skipped (not Failed). Defaults to "All records".</p> |
| Help text | <p>Chooses whether the check applies to this record.</p><ul><li>"All records" = always.</li><li>"When a formula is true" = gate on "Applies When (Formula)".</li><li>"When a count query matches" = gate on "Applies When (Count Query)".</li></ul><p>If the gate isn't met, the check is Skipped.</p> |
| Allowed values | **All records**: `ALL_RECORDS`<br>**When a formula is true**: `WHEN_FORMULA_TRUE`<br>**When a count query matches**: `WHEN_COUNT_QUERY_MATCHES` |

### Message When Not Applicable (`ApplicabilityNotMetMessage__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Message When Not Applicable** |
| API name | `ApplicabilityNotMetMessage__c` |
| Type | Long Text Area |
| Capacity | 32768 characters |
| Always required | No |
| Default | No default |
| Used when | Optional when Applies To is conditional; displayed when the applicability condition is not met. |
| Description | <p>Optional explanation shown when a Rule is skipped because its applicability condition is not met.</p><p>It supports the display merge tokens documented in the <a href="../guides/03-configure-check-sets-and-rules.md#11-merge-tokens">merge-token guide</a>.</p> |
| Help text | <p>Explain why this check does not apply to the current record. Supports merge tokens with optional fallback text.</p> |
| Allowed values | Any value valid for the field type |

Examples:

```text
{!record.Name} is a {!record.Type} account; this requirement applies only to channel partners.

{!record.Name} belongs to {!record.Parent.Name fallback="no parent account"}; this check runs only for independent accounts.

{!rhcRule.checkTitle} in {!rhcSet.cardTitle} does not apply to this segment.

The applicability condition was not met during {!rhcRun.source} run {!rhcRun.runId}.
```

### Applies When (Formula) (`ApplicabilityFormula__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Applies When (Formula)** |
| API name | `ApplicabilityFormula__c` |
| Type | Long Text Area |
| Capacity | 32768 characters |
| Always required | No |
| Default | No default |
| Used when | Required when Applies To is **When a formula is true**. |
| Description | <p>A Salesforce formula returning true or false, evaluated against the current record. Required when "Applies To" is "When a formula is true".</p><p>True means the check applies and runs; false means it is Skipped. Leave blank for any other "Applies To" choice.</p><p>Formula syntax only - not Apex or SOQL.</p> |
| Help text | <p>Required when "Applies To" = "When a formula is true". Salesforce formula returning true/false, e.g. ISPICKVAL(Type, "Partner").</p><p>True = run the check; false = Skipped.</p> |
| Allowed values | Any value valid for the field type |
| Example | `ISPICKVAL(Type, "Customer")` |

### Applies When (Count Query) (`ApplicabilityCountQuery__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Applies When (Count Query)** |
| API name | `ApplicabilityCountQuery__c` |
| Type | Long Text Area |
| Capacity | 32768 characters |
| Always required | No |
| Default | No default |
| Used when | Required when Applies To is **When a count query matches**. |
| Description | <p>A COUNT() SOQL query used only to decide whether this check applies - it is not part of the pass/fail logic. Required when "Applies To" is "When a count query matches".</p><p>Its returned count is compared using "Count Must Be" and "Count Value"; the check runs only when that comparison is true, otherwise it is Skipped. Supports record merge tokens with optional typed fallbacks.</p><p>Leave blank for any other "Applies To" choice.</p> |
| Help text | <p>Required when "Applies To" = "When a count query matches". Enter a COUNT() query and compare it using "Count Must Be" and "Count Value".</p> |
| Allowed values | Any value valid for the field type |

Examples:

```sql
SELECT COUNT() FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false
SELECT COUNT() FROM Opportunity WHERE AccountId = {!record.Id} AND Owner.ManagerId = {!record.Owner.ManagerId fallback="005000000000000AAA"}
SELECT COUNT() FROM Contract WHERE AccountId = {!record.Id} AND EndDate <= {!record.LastActivityDate fallback="2099-12-31"}
SELECT COUNT() FROM Case WHERE AccountId = {!record.Id} AND Priority = 'High' AND CreatedDate >= {!record.CreatedDate fallback="2026-01-01T00:00:00Z"}
SELECT COUNT() FROM Contact WHERE AccountId = {!record.Id} AND MailingState = {!record.BillingState fallback="Illinois"}
```

### Count Must Be (`ApplicabilityCountOperator__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Count Must Be** |
| API name | `ApplicabilityCountOperator__c` |
| Type | Picklist |
| Capacity | Restricted picklist |
| Always required | No |
| Default | No default |
| Used when | Required when Applies To is **When a count query matches**. |
| Description | <p>Part of the applicability gate only - not the main pass/fail check. Sets how the count from "Applies When (Count Query)" is compared to "Count Value"; the check runs only when this comparison is true.</p><p>Required when "Applies To" is "When a count query matches". Choices: "Equal to", "Not equal to", "Greater than", "At least" (greater than or equal), "Less than", "At most" (less than or equal).</p> |
| Help text | <p>Applicability gate only. How the count is compared to "Count Value", e.g. "Greater than" with a "Count Value" of 0 runs the check only when at least one row matches.</p><p>Required when "Applies To" = "When a count query matches".</p> |
| Allowed values | **Equal to**: `EQUALS`<br>**Not equal to**: `NOT_EQUALS`<br>**Greater than**: `GREATER_THAN`<br>**At least**: `GREATER_THAN_OR_EQUAL`<br>**Less than**: `LESS_THAN`<br>**At most**: `LESS_THAN_OR_EQUAL` |

### Count Value (`ApplicabilityCountThreshold__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Count Value** |
| API name | `ApplicabilityCountThreshold__c` |
| Type | Number |
| Capacity | 4 digits, 0 decimal places |
| Always required | No |
| Default | No default |
| Used when | Required when Applies To is **When a count query matches**. |
| Description | <p>Part of the applicability gate only - not the main pass/fail check. The number the count from "Applies When (Count Query)" is compared against, using "Count Must Be".</p><p>The check runs only when that comparison is true; otherwise it is Skipped. Required when "Applies To" is "When a count query matches".</p> |
| Help text | <p>Applicability gate only. The number compared to the count, e.g. 0 with "Greater than" runs the check only when the count query returns at least one row.</p><p>Required when "Applies To" = "When a count query matches".</p> |
| Allowed values | Any value valid for the field type |
| Example | `1` |

### Prerequisite Rule (`PrerequisiteRule__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Prerequisite Rule** |
| API name | `PrerequisiteRule__c` |
| Type | Text |
| Capacity | 255 characters |
| Always required | No |
| Default | No default |
| Used when | Optional for every Evaluation Type; names an earlier active Rule in the same Check Set. |
| Description | <p>Optional. Enter the Record Name (API Name / DeveloperName, shown in the Name column in Setup - NOT the "Check Title" users see) of another active check in the same Check Set that must PASS before this check runs. The prerequisite must have a lower "Evaluation Order".</p><p>If the prerequisite does not pass, this check is Skipped. A value that does not match a check in the same Check Set also Skips this check silently at runtime; the mismatch is reported only when the Check Set configuration is validated, not when you save this record.</p> |
| Help text | <p>Optional. The Record Name (API Name in Setup, not the "Check Title") of an earlier check (lower "Evaluation Order") in the same Check Set that must pass first. If it fails or the name doesn't match, this check is Skipped.</p> |
| Allowed values | Any value valid for the field type |
| Example | `Account_DQ_Phone` from the integration-test metadata; use the Developer Name of an earlier active Rule in the same Check Set |


## 10. Custom Apex (`APEX`)

### Apex Class (`ApexClass__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Apex Class** |
| API name | `ApexClass__c` |
| Type | Text |
| Capacity | 255 characters |
| Always required | No |
| Default | No default |
| Used when | Required when Evaluation Type is **Verify with Apex** (`APEX`). |
| Description | <p>The API name of the Apex class to run for this check. Required when "Evaluation Type" is "Verify with Apex".</p><p>The class must implement the RecordHealthCheckRule interface. Example: AccountApprovalHealthCheck.</p> |
| Help text | <p>Required for "Verify with Apex". The Apex class name to run, e.g. AccountApprovalHealthCheck.</p><p>It must implement RecordHealthCheckRule.</p> |
| Allowed values | Any value valid for the field type |
| Example | `AccountHasRecentActivityCheck` |

### Apex Parameters (JSON) (`ApexParametersJson__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Apex Parameters (JSON)** |
| API name | `ApexParametersJson__c` |
| Type | Long Text Area |
| Capacity | 32768 characters |
| Always required | No |
| Default | No default |
| Used when | Optional for Apex Rules; passed to the plugin as `scope.parameters`. |
| Description | <p>Optional JSON parameters passed to the class named in "Apex Class". Must be valid JSON; invalid JSON makes the check report that it cannot run (reason INVALID_APEX_PARAMETERS).</p><p>These are per-check parameters, not org-wide settings. Leave blank if the class needs none.</p> |
| Help text | <p>Optional. Valid JSON passed to your Apex class, e.g. {"threshold": 5}. Leave blank if the class needs no parameters.</p> |
| Allowed values | Any value valid for the field type |
| Example | `{"daysBack": 90}` for `AccountHasRecentActivityCheck` |


## Lifecycle events

### Publish User Result Event (`PublishUserResultEvent__c`)

| Attribute | Value |
| --- | --- |
| Setup label | **Publish User Result Event** |
| API name | `PublishUserResultEvent__c` |
| Type | Checkbox |
| Capacity | Checkbox |
| Always required | No |
| Default | **Unchecked**: `false` |
| Used when | Optional for every Evaluation Type; affects deliberate runs only and defaults off. |
| Description | <p>Publishes this finalized Rule result after a deliberately initiated run. Page-load runs never publish because ordinary record-page navigation could otherwise consume event allocations and repeatedly trigger subscriber automation.</p><p>Leave unchecked unless a reviewed subscriber needs this Rule's individual status, reason, and severity. Enable only the Rules the subscriber uses; per-Rule publication can create many more events than one Check Set Run summary.</p> |
| Help text | <p>Publish this Rule's result for deliberate API, Flow, scheduled, batch, or user-requested runs. Page-load runs never publish.</p> |
| Allowed values | **Checked**: `true`<br>**Unchecked**: `false` |

## Related

- [Check type examples](../examples/README.md)
- [Check Set fields](01-fields-check-set.md)
- [Configure Check Sets and Rules](../guides/03-configure-check-sets-and-rules.md)
