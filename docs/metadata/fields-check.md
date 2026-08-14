# Record Health Check fields

> [!NOTE]
> On this page, look up every Check field by its Setup label or API name. Each field explains when
> to use it, what to enter, and what happens when the Check runs.

| Setup value | Name |
| --- | --- |
| Custom Metadata Type label | Record Health Check |
| Custom Metadata Type API name | `Record_Health_Check__mdt` |

Use this page while creating or reviewing a Check in **Setup → Custom Metadata Types → Record
Health Check → Manage Records**. Start with the decision tables below. Open an individual field
only when that field applies to the Evaluation Type you chose.

## Build a Check in the order it runs

| Stage | Decision | Start with |
| --- | --- | --- |
| 1. Place the Check | Which Check Set owns it, when does it run, and is it active? | [Check Set](#check-set-record_health_check_set__c), [Evaluation Order](#evaluation-order-evaluationorder__c), and [Active](#active-isactive__c) |
| 2. Decide whether it applies | Does it run for every record, only when a formula or query matches, or only after another Check passes? | [Applies To](#applies-to-applicabilitymode__c) and [Prerequisite Check](#prerequisite-check-prerequisitecheck__c) |
| 3. Choose how it evaluates | Can Salesforce formula or SOQL express the check, or is Apex required? | [Evaluation Type](#evaluation-type-evaluationtype__c) |
| 4. Define the decision | What value is found, what is expected, and how are they compared? | The Evaluation Type table below |
| 5. Explain the result | What should someone understand and do after a failure or an unable result? | [Check Title](#check-title-checktitle__c), [Message When Failed](#message-when-failed-failuremessage__c), and [Fix Message](#fix-message-fixmessage__c) |
| 6. Add a next action | Would a safe same-org destination help resolve the result? | [Action Label](#action-label-actionlabel__c) and [Action URL](#action-url-actionurl__c) |
| 7. Publish when needed | Does another process need the finalized Check outcome? | [Publish User Result Event](#publish-user-result-event-publishuserresultevent__c) |

| What the Check must verify | Evaluation Type | Start with |
| --- | --- | --- |
| Fields on the current Salesforce record | **Verify with a formula** (`FORMULA`) | [Pass Condition](#pass-condition-passconditionformula__c) |
| Records or an aggregate returned by one SOQL query | **Verify with a query** (`QUERY`) | [Source Query](#source-query-sourcequery__c) and [Comparison Operator](#comparison-operator-comparisonoperator__c) |
| One SOQL result against another SOQL result | **Compare two queries** (`COMPARE_TWO_QUERIES`) | [Source Query](#source-query-sourcequery__c) and [Comparison Query](#comparison-query-comparisonquery__c) |
| Logic implemented in a package or org Apex class | **Verify with Apex** (`APEX`) | [Apex Class](#apex-class-apexclass__c) |

For complete configurations, choose an [example by Evaluation Type](../examples/README.md). For text
that adapts to the record and result, use [Merge Syntax](../guides/configure-check-sets-and-checks.md#11-merge-tokens):
`record.*`, `rhcResult.*`, `rhcRun.*`, `rhcCheck.*`, and `rhcSet.*`.

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
| [Expected Currency ISO Code](#expected-currency-iso-code-expectedcurrencyisocode__c) | `ExpectedCurrencyIsoCode__c` | Query comparison |
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
| [Prerequisite Check](#prerequisite-check-prerequisitecheck__c) | `PrerequisiteCheck__c` | When this check applies |
| [Apex Class](#apex-class-apexclass__c) | `ApexClass__c` | Custom Apex (`APEX`) |
| [Apex Parameters (JSON)](#apex-parameters-json-apexparametersjson__c) | `ApexParametersJson__c` | Custom Apex (`APEX`) |
| [Publish User Result Event](#publish-user-result-event-publishuserresultevent__c) | `PublishUserResultEvent__c` | Lifecycle events |

## 1. Identity and execution

### Developer Name (`DeveloperName`)

Required Text(40). This is the stable name Salesforce uses for the Custom Metadata record. A
prerequisite Check refers to this value, not the Check Title shown on the card. Example:
`Account_Pipeline_Readiness`.

After saving, Setup shows the complete **Qualified API Name**. A Check created by an administrator
in your org normally has a name such as `Account_Pipeline_Readiness`. A Check included with the
installed package can have a name such as `rhc__Account_Has_Recent_Activity`. Copy the exact value
from Setup; do not add or remove `rhc__`.

### Label (`MasterLabel`)

Required Text(80). This identifies the Custom Metadata record in Setup. It is not the title users
see on the card; configure that in **Check Title**. Example: `Account pipeline readiness`.

### Check Set (`Record_Health_Check_Set__c`)

Required Metadata Relationship. Select the Check Set that owns this Check. Each Check belongs to
one Check Set, and that Check Set determines the Salesforce object and card behavior.

For example, select your `Account_Readiness` Check Set for a Check that evaluates Account records.

### Evaluation Order (`EvaluationOrder__c`)

Optional Number(4,0). The default is `100`. Checks with lower numbers run and appear first. When
two Checks have the same number, Salesforce orders them by Developer Name.

Use values such as `10`, `20`, and `30` so a new Check can be inserted later. A prerequisite Check
must have a lower Evaluation Order than the Check that depends on it.

### Active (`IsActive__c`)

Checkbox, selected by default. Clear it to stop this Check from running without deleting its Custom
Metadata record. Other active Checks in the Check Set continue to run.


## 2. What users see

### Check Title (`CheckTitle__c`)

Required Text(255). This is the title users see for the Check on the card. Use a short statement
that makes the requirement obvious, such as `Billing City is present` or `Account has an active
Contact`. This is separate from Label and Developer Name, which identify the record in Setup.

### Check Description (`CheckDescription__c`)

Optional Text(255). This additional explanation appears when a user hovers over the Check Title or
moves keyboard focus to it. Explain what is checked and why it matters. It does not appear inline in
the row. Example: `Checks open Opportunity count and pipeline amount.`

### Category (`Category__c`)

Optional restricted picklist. Category classifies the business purpose of a Check. It does not
change the result, severity, order, or current card layout.

| Setup choice | Stored value |
| --- | --- |
| Completeness | `COMPLETENESS` |
| Consistency | `CONSISTENCY` |
| Timeliness | `TIMELINESS` |
| Eligibility | `ELIGIBILITY` |
| Readiness | `READINESS` |
| Risk | `RISK` |
| Compliance | `COMPLIANCE` |
| Relationship coverage | `RELATIONSHIP_COVERAGE` |

### Failure Severity (`FailureSeverity__c`)

Optional restricted picklist. It applies only when the result is `FAIL`; it does not change `PASS`,
`SKIPPED`, `UNABLE_TO_EVALUATE`, or `ERROR`.

| Setup choice | Stored value | Card color |
| --- | --- | --- |
| Critical | `CRITICAL` | Red |
| Warning | `WARNING` | Amber; default |
| Info | `INFO` | Blue |

Choose the business impact of failing the requirement. `ERROR` is not a severity choice because it
is a separate result that means Record Health Check encountered a technical problem.

### Message When Failed (`FailureMessage__c`)

Optional Long Text Area(32,768), shown for `FAIL`. Explain what requirement was not met in language
the card user understands. Do not include SOQL, formulas, or exception details.

This field supports [merge tokens](../guides/configure-check-sets-and-checks.md#11-merge-tokens).
Press Enter for a new line on the card.

Choose the shortest useful example for the Check:

```text
Found {!rhcResult.foundValue}; expected {!rhcResult.expectedValue}.

{!rhcResult.failedRecordCount} of {!rhcResult.totalRecordCount} contacts for {!record.Name} are missing email.
```

### Message When Unable To Evaluate (`UnableToEvaluateMessage__c`)

Optional Long Text Area(32,768). It replaces the standard message for `UNABLE_TO_EVALUATE`.
Explain that Salesforce could not determine the result and what the user should do next. Do not
show a query, formula, or technical error on the card. Merge tokens and line breaks are supported.

Examples:

```text
We could not confirm the requirement for {!record.Name} ({!rhcResult.reasonCode}).

Try again later. If the problem continues, give support run {!rhcRun.runId}, started at {!rhcRun.startedAt}.
```

### Fix Message (`FixMessage__c`)

Optional Long Text Area(32,768), shown in failed-Check details. Tell the user exactly what to review
or change. Pair it with Action URL when Salesforce can take the user directly to the relevant
record, related list, report, or instructions. Merge tokens are supported.

Examples:

```text
Ask {!record.Owner.Name} to update the phone number for {!record.Name}; the current value is {!record.Phone fallback="not provided"}.

Review the open Opportunities and correct their Amount values, then rerun {!rhcSet.cardTitle}.
```

### Action Label (`ActionLabel__c`)

Optional Text(80) for the failure action link. Use a short verb phrase that describes where the link
goes, such as `Edit Account`, `Review Contacts`, or `Open playbook`. It supports merge tokens.

Action URL controls whether the link appears. When a URL is present and Action Label is blank, the
card uses **Fix this**.

Examples:

```text
Review {!record.Name}
Review Contacts
```

### Action URL (`ActionUrl__c`)

Optional Long Text Area(32,768), displayed only for `FAIL`. Use a Salesforce path beginning with
`/` or an approved `https://` address. You can link to a record, edit page, related list, report,
Knowledge article, or external playbook.

Record, Check, Check Set, and run tokens are supported and URL-encoded automatically. Result tokens
are not allowed in URLs. The card hides blank, unsafe, or overlong resolved URLs.

Examples:

```text
/lightning/r/Account/{!record.Id}/view
/lightning/r/Account/{!record.Id}/edit
/lightning/r/Account/{!record.Id}/related/Contacts/view
/lightning/o/Contact/new?defaultFieldValues=AccountId={!record.Id},LastName=New%20contact
```

```text
/lightning/o/Case/new?defaultFieldValues=AccountId={!record.Id},Subject=Review%20{!record.Name fallback="this account"},Origin=Web,Description=Check%20{!rhcCheck.developerName}%20in%20{!rhcSet.developerName}
```


## 3. Check type and value display

### Evaluation Type (`EvaluationType__c`)

Required restricted picklist with no default. Choose one Evaluation Type, then complete only the
fields that type uses.

| Setup choice | Stored value | Use it when |
| --- | --- | --- |
| Verify with a formula | `FORMULA` | A true/false Salesforce formula can check fields on the current record. Configure **Pass Condition**. |
| Verify with a query | `QUERY` | One SOQL query can return the related records, count, total, or value to compare. |
| Compare two queries | `COMPARE_TWO_QUERIES` | The result from one SOQL query must be compared with another query result. |
| Verify with Apex | `APEX` | The requirement needs Apex logic that the other types cannot express. Configure **Apex Class**. |

### Display: Value Format (`DisplayValueFormat__c`)

Optional restricted picklist, default **Auto** (`AUTO`). It changes only how Found and Expected
values appear; it never changes whether the Check passes.

| Setup choice | Stored value | Example use |
| --- | --- | --- |
| Auto | `AUTO` | Let Record Health Check choose from the value type. |
| Number | `NUMBER` | Employee count |
| Currency | `CURRENCY` | Annual Revenue |
| Percent | `PERCENT` | A Salesforce Percent field |
| Ratio as Percent | `RATIO_PERCENT` | Show `0.25` as `25%` |
| Checkbox | `BOOLEAN` | True or false |
| Date | `DATE` | A date without time |
| Date/Time | `DATETIME` | A date and time |
| Text | `TEXT` | A name or description |
| Raw | `RAW` | An external ID without display formatting |

This is a different setting from [Formula Result Type](#formula-result-type-formularesulttype__c),
which declares the type a formula returns so the Check can calculate with it. A Formula Check can set
Formula Result Type to **Number** and Display: Value Format to **Currency** at the same time.

Naming a format that cannot apply to a value is not an error. The value keeps its original
spelling. Full contract:
[Reference: Display value format](../reference/contracts/display-value-format.md).


## 4. Check fields on this record (`FORMULA`)

### Pass Condition (`PassConditionFormula__c`)

Long Text Area(32,768), required only for **Verify with a formula**. Enter a Salesforce formula that
returns `true` to pass or `false` to fail. Do not enter Apex or SOQL.

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

Optional Long Text Area(32,768) for Formula Checks. This formula supplies the Found value shown on
the card; it does not affect pass or fail. Leave it blank when the card does not need a Found value.

Enter a formula evaluated on the current record. Fixed text uses double quotes, numbers are
unquoted, and Boolean values use `TRUE` or `FALSE`. **Formula Result Type** declares the returned
type.

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

Optional Long Text Area(32,768) for Formula Checks. It supplies the Expected value shown on the
card and never changes pass or fail. Leave it blank to show the generated **Passes when...** text
based on Pass Condition.

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

Optional restricted picklist. It declares the return type for every single-value formula in this
Check, including Found, Expected, record-formula expected values, and list-search values.

| Setup choice | Stored value |
| --- | --- |
| Auto | `AUTO` (default) |
| Checkbox | `BOOLEAN` |
| Number | `NUMBER` |
| Date | `DATE` |
| Date/Time | `DATETIME` |
| Text | `TEXT` |

Leave **Auto** when you are unsure. Choosing the exact type can reduce formula evaluations, but all
formulas in this Check that use this setting must return that type.


## 5. Query sources (`QUERY` / `COMPARE_TWO_QUERIES`)

### Source Query (`SourceQuery__c`)

Long Text Area(32,768). This is normally the first SOQL query for **Verify with a query** and
**Compare two queries**. Use `COUNT()` when the business question asks “how many?” and use record
merge tokens to filter for the current record.

Leave Source Query blank only for a one-query **List contains any** or **List contains none** Check.
That pattern takes the value to search for from **Value to find in the list (formula)** and the list
from **Comparison Query**.

Examples:

```sql
SELECT COUNT() FROM Contact WHERE AccountId = {!record.Id}
SELECT SUM(Amount) totalAmount FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false
```

### Source Query Field (`SourceQueryField__c`)

Optional Text(255). Enter the field API name or aggregate alias whose value Record Health Check
must read from Source Query. For example, enter `MailingCity` for `SELECT MailingCity ...`, or
`totalAmount` for the aliased `SUM(Amount)` query below.

Leave this field blank only when Source Query uses bare `COUNT()`. Give `SUM()`, `MIN()`, `MAX()`,
`AVG()`, `COUNT(field)`, and `COUNT_DISTINCT(field)` an alias and enter that alias here.

Example: use `totalAmount` for the aliased aggregate below. Leave this field blank for bare `COUNT()`.

```sql
SELECT SUM(Amount) totalAmount FROM Opportunity WHERE AccountId = {!record.Id}
```

### Comparison Query (`ComparisonQuery__c`)

Long Text Area(32,768). This is the second SOQL query when:

- Evaluation Type is **Compare two queries**;
- **Expected Value Comes From** is **Comparison query**; or
- a one-query Check uses **List contains any** or **List contains none**.

Use **Comparison Query Field** to identify the selected field or aggregate alias to read.

Examples:

```sql
SELECT COUNT() FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false
SELECT AnnualRevenue FROM Account WHERE Id = {!record.ParentId fallback="001000000000000AAA"}
SELECT EndDate FROM Contract WHERE AccountId = {!record.Id} AND Status = 'Activated' ORDER BY EndDate LIMIT 1
SELECT MailingState FROM Contact WHERE AccountId = {!record.Id} AND MailingState != null
```

### Comparison Query Field (`ComparisonQueryField__c`)

Optional Text(255). It follows the same rule as Source Query Field: enter the selected field API
name or aggregate alias, and leave it blank only for bare `COUNT()`.

Example: use `comparisonTotal` for the aliased aggregate below.

```sql
SELECT SUM(Amount) comparisonTotal FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false
```

### Value to find in the list (formula) (`FindInListFormula__c`)

Long Text Area(32,768), required only for a **Verify with a query** Check using **List contains any**
or **List contains none**. Enter a Salesforce formula that returns the one value to search for. The
Comparison Query returns the list.

For example, enter `BillingCity` to look for the Account's Billing City, or `"Chicago"` to look for
fixed text. Also set **How To Read Query Results** to **Compare as lists**. Leave this field blank for
all other operators.


## 6. Query comparison

### Comparison Operator (`ComparisonOperator__c`)

Required restricted picklist with no default for Query and Compare two queries Checks.

| Setup choice | Stored value | Used with |
| --- | --- | --- |
| Equals | `EQUALS` | One value or aggregate |
| Does not equal | `NOT_EQUALS` | One value or aggregate |
| Greater than | `GREATER_THAN` | One value or aggregate |
| Greater than or equal | `GREATER_THAN_OR_EQUAL` | One value or aggregate |
| Less than | `LESS_THAN` | One value or aggregate |
| Less than or equal | `LESS_THAN_OR_EQUAL` | One value or aggregate |
| Contains text | `CONTAINS` | Text value |
| Does not contain text | `DOES_NOT_CONTAIN` | Text value |
| Is empty | `IS_BLANK` | No Expected value needed |
| Is not empty | `IS_NOT_BLANK` | No Expected value needed |
| List contains any | `LIST_CONTAINS_ANY` | One-query list search |
| List contains none | `LIST_CONTAINS_NONE` | One-query list search |
| Lists overlap | `LISTS_OVERLAP` | Compare two query result lists |
| Lists contain all | `LISTS_CONTAIN_ALL` | Compare two query result lists |
| Lists match exactly | `LISTS_MATCH_EXACTLY` | Compare two query result lists |

Every list operator requires **How To Read Query Results = Compare as lists**.

### Expected Value Comes From (`ExpectedValueSource__c`)

Use this restricted picklist for a **Verify with a query** Check when its operator needs an Expected
value. There is no default.

| Setup choice | Stored value | Complete this field |
| --- | --- | --- |
| Fixed value | `FIXED_VALUE` | Expected Value (Fixed) |
| Record formula | `RECORD_FORMULA` | Expected Value (Formula) |
| Comparison query | `COMPARISON_QUERY` | Comparison Query and, when needed, Comparison Query Field |

Leave it blank for **Is empty**, **Is not empty**, and **Compare two queries**.

### Expected Value (Fixed) (`ExpectedFixedValue__c`)

Text(255), required when **Expected Value Comes From** is **Fixed value**. Enter a plain value with no
formula syntax or quotation marks: `Approved`, `5`, or `2025-01-31`.

### Expected Currency ISO Code (`ExpectedCurrencyIsoCode__c`)

Optional Text(3), except that it is required in a multi-currency org when a Query Check compares a
Currency field with a fixed value. Enter the fixed value's ISO unit, such as `USD` or `EUR`. This
declaration lets Record Health Check refuse a cross-unit comparison; it never converts a value.
Leave it blank in single-currency orgs, for non-Currency fields, and for expected values that do not
come from **Fixed value**.

### Expected Value (Formula) (`ExpectedRecordFormula__c`)

Long Text Area(32,768), required when **Expected Value Comes From** is **Record formula**. Enter a
Salesforce formula evaluated on the current record. It can return fixed text, a field,
relationship field, or calculated value. Do not enter Apex or SOQL.

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

Required restricted picklist for Query and Compare two queries Checks.

| Setup choice | Stored value | Meaning |
| --- | --- | --- |
| One row or aggregate | `ONE_RESULT` | Read one row, `COUNT()`, `SUM()`, or another aggregate. This is the default. |
| Any record passes | `ANY_ROW_PASSES` | The Check passes when at least one returned record matches. |
| Every record passes | `ALL_ROWS_PASS` | The Check passes only when every returned record matches. |
| Compare as lists | `COMPARE_AS_LISTS` | Treat query results as lists. Required for every list operator. |

### If Query Finds No Records (`NoRowsResult__c`)

Required with **Any record passes**, **Every record passes**, and **Compare as lists**. There is no
default because no records can have different business meanings.

| Setup choice | Stored value | Use it when no records means... |
| --- | --- | --- |
| Pass | `PASS` | The requirement is satisfied. For example, no open high-priority Cases is healthy. |
| Fail | `FAIL` | A required related record is missing. |
| Skip | `SKIP` | The Check does not apply. |
| Unable to evaluate | `UNABLE_TO_EVALUATE` | The available data cannot answer the question. |

### If Field Value Is Empty (`EmptyValueHandling__c`)

Optional restricted picklist for non-aggregate Query and Compare two queries Checks.

| Setup choice | Stored value | Behavior |
| --- | --- | --- |
| Ignore the record | `SKIP_RECORD` | Leave that returned record out of the comparison. |
| Treat as blank | `AS_BLANK` | Compare the value as blank text. |
| Treat as not matching | `AS_NO_MATCH` | The empty value does not match. This is the default. |

Formula Checks, Apex Checks, and aggregate queries ignore this field.

### Max Query Rows (1-2000) (`MaxQueryRows__c`)

Optional Number(4,0) from `1` through `2000`; default `200`. It limits rows returned by this Check's
Query or Compare two queries SOQL.

Keep it as low as the business question allows because each row uses Salesforce query rows, memory,
and processing time in the current transaction. Narrow the SOQL before increasing this number. If
more than 200 rows are genuinely required, test the real Check and realistic records in a sandbox.


## 8. Advanced display text

### Display: Found Text (`DisplayFoundText__c`)

Optional Text(255) that replaces the Found line for Formula, Query, and Compare two queries Checks.
It changes only the displayed text, not the result. For an **Every record passes** query, it replaces
the generated “N of M records did not pass” summary.

Merge tokens are supported, including `{!rhcResult.foundValue}` for the original value. Apex Checks
return their own Found value, so this field is ignored for Apex and validation reports
`APEX_DISPLAY_TEXT_IGNORED`.

Examples:

```text
{!rhcResult.failedRecordCount} of {!rhcResult.totalRecordCount} contacts for {!record.Name} are missing email.
```

### Display: Expected Text (`DisplayExpectedText__c`)

Optional Text(255) that replaces the Expected line for Formula, Query, and Compare two queries
Checks. It changes only the displayed text. On a Formula Check, it replaces the generated **Passes
when** text.

Merge tokens are supported, including `{!rhcResult.expectedValue}` for the original value. Apex
Checks return their own Expected value, so this field is ignored for Apex and validation reports
`APEX_DISPLAY_TEXT_IGNORED`.

Examples (choose one that fits the Check):

```text
Expected {!rhcResult.expectedValue} for every contact related to {!record.Name}.

All {!rhcResult.totalRecordCount} contacts should have an email address.
```


## 9. When this check applies

### Applies To (`ApplicabilityMode__c`)

Optional restricted picklist. It decides whether the Check applies before Record Health Check runs
its pass/fail logic. When the condition is not met, the result is `SKIPPED`, not `FAIL`.

| Setup choice | Stored value | Configure next |
| --- | --- | --- |
| All records | `ALL_RECORDS` | Nothing; this is the default. |
| When a formula is true | `WHEN_FORMULA_TRUE` | Applies When (Formula) |
| When a count query matches | `WHEN_COUNT_QUERY_MATCHES` | Applies When (Count Query), Count Must Be, and Count Value |

### Message When Not Applicable (`ApplicabilityNotMetMessage__c`)

Optional Long Text Area(32,768). Explain why a conditional Check was skipped. It supports
[merge tokens](../guides/configure-check-sets-and-checks.md#11-merge-tokens).

Examples:

```text
{!record.Name} is a {!record.Type} account; this requirement applies only to channel partners.

This Check applies only to channel-partner Accounts.
```

### Applies When (Formula) (`ApplicabilityFormula__c`)

Long Text Area(32,768), required when **Applies To** is **When a formula is true**. Enter a
Salesforce formula evaluated on the current record. `true` runs the Check; `false` produces
`SKIPPED`. Example: `ISPICKVAL(Type, "Customer")`.

### Applies When (Count Query) (`ApplicabilityCountQuery__c`)

Long Text Area(32,768), required when **Applies To** is **When a count query matches**. Enter a
`COUNT()` SOQL query. Record Health Check compares the returned count with **Count Must Be** and
**Count Value**. A matching count runs the Check; a nonmatching count produces `SKIPPED`.

This query decides only whether the Check applies. It does not decide pass or fail.

Examples:

```sql
SELECT COUNT() FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false
```

### Count Must Be (`ApplicabilityCountOperator__c`)

Required restricted picklist when **Applies To** is **When a count query matches**.

| Setup choice | Stored value |
| --- | --- |
| Equal to | `EQUALS` |
| Not equal to | `NOT_EQUALS` |
| Greater than | `GREATER_THAN` |
| At least | `GREATER_THAN_OR_EQUAL` |
| Less than | `LESS_THAN` |
| At most | `LESS_THAN_OR_EQUAL` |

### Count Value (`ApplicabilityCountThreshold__c`)

Number(4,0), required when **Applies To** is **When a count query matches**. This is the number used
with Count Must Be. For example, **Greater than** and `0` runs the Check only when the query finds at
least one record.

### Prerequisite Check (`PrerequisiteCheck__c`)

Optional Text(255). Enter the **Developer Name** shown in Setup, not the Check Title, of another
active Check in the same Check Set. That Check must have a lower Evaluation Order and must return
`PASS` before this Check can run.

If the prerequisite returns any other result, this Check is `SKIPPED`. A misspelled or unmatched
name also produces `SKIPPED`; run Check Set validation to find the configuration error. Example:
`Account_Phone_Is_Present`.


## 10. Custom Apex (`APEX`)

### Apex Class (`ApexClass__c`)

Text(255), required for **Verify with Apex**. Enter the API name of an Apex class that implements
`rhc.RecordHealthCheckPlugin`.

For example, `AccountHasRecentActivityCheck` is included with the installed Record Health Check
package. A class created by your development team might be named `MyAccountApprovalCheck`. See the
[Apex Check examples](../examples/apex/README.md) for the complete class contract and tests.

### Apex Parameters (JSON) (`ApexParametersJson__c`)

Optional Long Text Area(32,768) for Apex Checks. Enter valid JSON required by the class, such as
`{"daysBack": 90}` for `AccountHasRecentActivityCheck`. Leave it blank when the class has no
parameters.

The values belong only to this Check. Invalid JSON produces `UNABLE_TO_EVALUATE` with reason code
`INVALID_APEX_PARAMETERS`.


## Lifecycle events

### Publish User Result Event (`PublishUserResultEvent__c`)

Checkbox, cleared by default. It applies only when a person clicks Run or Rerun on the Lightning
card.

Select this field only when a Platform Event-triggered Flow, Apex trigger, or integration must
receive this individual Check result after a person clicks **Run** or **Rerun** on the Lightning
card. An automatic page-load check does not publish it.

This checkbox does not control Flow, Apex, Batch, Queueable, Future, Scheduled Apex, or agent runs.
Those callers choose `NONE`, `ACTIONABLE`, or `ALL` when they start the health check. For example,
`ALL` publishes every result even when this checkbox is cleared.

Leave it cleared when nothing receives the event. Select it only for the individual Checks the
receiving automation uses; publishing one event per Check can create considerably more Platform
Events than publishing one Check Set summary. See
[Choose whether to publish result events](../integration/lifecycle-events.md).

## Related

- [Check type examples](../examples/README.md)
- [Check Set fields](fields-check-set.md)
- [Configure Check Sets and Checks](../guides/configure-check-sets-and-checks.md)
