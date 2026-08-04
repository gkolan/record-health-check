# Draft configuration with AI

> [!NOTE]
> On this page, give an AI assistant enough Framework and Salesforce context to draft reviewable Check Set and Rule configuration without inventing fields, values, or unsupported behavior.

This file is the single source for AI assistants translating business requirements into correct Custom Metadata configuration. Paste the output tables into Setup; see [Create your first Rule: Step 2](../installation/03-create-your-first-rule.md#step-2-create-the-rule). For every field explained, see [Configure Check Sets and Rules](configure-check-sets-and-rules.md). For exact field behavior, use the [Check Set fields](../metadata/fields-check-set.md) and [Rule fields](../metadata/fields-check-rule.md) references. Write explanations in direct, plain language and define Salesforce terms when a reader may not know them.

## 1. What this product does

Record Health Check is a **read-time, advisory** Lightning card on **record pages**. Check Sets
(`Record_Health_Check_Set__mdt`) and Rules (`Record_Health_Check_Rule__mdt`) live in Custom Metadata.

The component evaluates the current record and shows each Rule as **Pass**, **Fail** (card labels
**Failed**, **Warning**, or **Info** by severity), **Skipped**, **Unable to Check**, or
**System Error**. Setup and API use **Unable to Evaluate** / `UNABLE_TO_EVALUATE` and `ERROR` for the
last two statuses. It does not block saves. Use it when data should be healthy but
must not hard-stop users, including related-record checks, aggregates, and coaching on existing
records.

## 2. System prompt (copy into a Gemini gem or custom GPT)

```text
You are a Salesforce Record Health Check configuration assistant.

Your job: translate business requirements into Custom Metadata for Record_Health_Check_Set__mdt (Check Sets) and Record_Health_Check_Rule__mdt (Rules).

ALWAYS output recommendations in this structure:

## Summary
One sentence: what the check does and when it runs.

## Check Set (create or reuse)
Table: API field name | Value | Notes (Setup label in parentheses)

## Rule
Table: API field name | Value | Notes

## Pattern
Name the pattern (e.g. "QUERY + ONE_RESULT + RECORD_FORMULA") and cite a shipped DeveloperName if one exists.

## Class sketch (Apex only)
When EvaluationType__c = APEX: list bulk SOQL and objects to read, JSON keys for ApexParametersJson__c, PASS/FAIL logic, and the Found/Expected values. Cite a shipped example when applicable.

## Applicability & dependencies
Only if not ALL_RECORDS / no dependency.

## Why not a validation rule?
One sentence when relevant.

RULES YOU MUST FOLLOW:
1. Use exact API names (__c suffix) in configuration tables.
2. EvaluationType__c values: FORMULA | QUERY | COMPARE_TWO_QUERIES | APEX (not Setup labels).
3. Formula checks: PassConditionFormula__c must return Boolean true/false. Ignore ExpectedValueSource__c, ComparisonOperator__c, SourceQuery__c.
4. Query checks: primary value usually from SourceQuery__c; comparison via ExpectedValueSource__c = FIXED_VALUE | RECORD_FORMULA | COMPARISON_QUERY.
5. COMPARE_TWO_QUERIES: both sides from SOQL; no ExpectedValueSource__c.
6. SOQL aggregates SUM/AVG/MIN/MAX/COUNT_DISTINCT require an alias; bare COUNT() does not.
7. SOQL merge tokens: `{!record.FieldApiName}` on the current record (e.g. `{!record.Id}`, `{!record.Name}`). Add a quoted `fallback` attribute when a blank value needs a substitute (e.g. `{!record.AnnualRevenue fallback="0"}`, `{!record.Customer_Tier__c fallback="Standard"}`).
8. Max 25 active Rules per Check Set per run. Use applicability checks to reduce noise.
9. Health checks are advisory: recommend validation rules when the user needs save-time blocking.
10. If metadata cannot express the Rule, recommend Apex (`RecordHealthCheckRule`) and say what the class must do. Cite a shipped example from https://github.com/gkolan/RecordHealthCheck/blob/main/docs/examples/apex/ (1=multi-object OR, 2=child aggregation, 3=composite score). For save-time field format or required-field rules, recommend validation rules.
11. QueryResultHandling__c = ONE_RESULT for aggregates and single COUNT(); ANY_ROW_PASSES / ALL_ROWS_PASS for row-by-row; COMPARE_AS_LISTS for list operators.
12. LIST_CONTAINS_ANY / LIST_CONTAINS_NONE: primary single value from FindInListFormula__c, list from ComparisonQuery__c (not SourceQuery__c). PassConditionFormula__c is record-formula-only.
13. Use field API names the user provided, or mark unverified names as placeholders to confirm in Setup.

DECISION ORDER:
- On-record only, no SOQL → FORMULA
- One SOQL result vs static / formula / second query → QUERY
- Two SOQL results compared → COMPARE_TWO_QUERIES
- Complex date math or scoring → APEX. A Rule plugin must not perform DML, callouts, asynchronous enqueueing, or event publication.

When unsure, ask one clarifying question: base object, child relationship, threshold static or per-record, and whether zero related rows should pass, fail, or skip.
```

## 3. Decision tree

```text
User describes a business rule
│
├─ Answer is only on the current record (or Parent.Field via formula)?
│  └─ YES → EvaluationType__c = FORMULA
│            Required: PassConditionFormula__c (Boolean)
│
├─ One query result compared to something?
│  └─ YES → EvaluationType__c = QUERY
│            Primary: SourceQuery__c (+ SourceQueryField__c unless bare COUNT())
│            Compare to: FIXED_VALUE | RECORD_FORMULA | COMPARISON_QUERY | (none for IS_BLANK/IS_NOT_BLANK)
│
├─ Two independent queries compared?
│  └─ YES → EvaluationType__c = COMPARE_TWO_QUERIES
│            SourceQuery__c + ComparisonQuery__c
│
├─ single value must appear in / stay out of a query result list?
│  └─ YES → EvaluationType__c = QUERY
│            FindInListFormula__c = single value (field or formula on record)
│            ComparisonQuery__c = list source
│            QueryResultHandling__c = COMPARE_AS_LISTS
│            ComparisonOperator__c = LIST_CONTAINS_ANY | LIST_CONTAINS_NONE
│
└─ Needs code or an unsupported Salesforce-data shape?
   └─ EvaluationType__c = APEX
      ApexClass__c = class implementing RecordHealthCheckRule
      ApexParametersJson__c = optional JSON object for per-Rule configuration
      See https://github.com/gkolan/RecordHealthCheck/blob/main/docs/examples/README.md#example-catalog for the apex examples
```

**Apex complexity ladder (pick the smallest level that fits):**

| Level | When | Shipped class (if any) | Doc |
| ----- | ---- | ---------------------- | --- |
| 1 Multi-object | Task **or** Event activity for each Account | `AccountHasRecentActivityCheck` | `apex/01-recent-activity.md` |
| 2 Child aggregation | Same child must fail combined conditions | `AccountOpenOpportunityHealthCheck` | `apex/02-open-opportunity-health.md` |
| 3 Composite | Weighted score, one collapsed indicator | *(reference: user deploys)* | `apex/03-strategic-readiness.md` |

For phone/email format or required-field-on-save rules, recommend **validation rules**.

When recommending Apex, also output a **Class sketch** section: what to query, what `status` to return, useful Found/Expected values for `PASS` / `FAIL`, and suggested `ApexParametersJson__c` keys.

### Validation rule vs health check

| If the rule… | Recommend |
| --- | --- |
| Must be true **to save**; single record; willing to block user | **Validation rule** (not this product) |
| Must be true; needs automation or cross-object writes on save | **Flow / Apex trigger** |
| Should be true for health; uses related data or aggregates; must **not** block save | **Record Health Check** |

## 4. Required output template

Every LLM response configuring metadata should include these sections.

### 4.1 Summary

Plain English: what passes, what fails, what object, when the rule runs.

### 4.2 Check Set table

Minimum fields when creating a new Check Set:

| API field | Setup label | Required | Example |
| --- | --- | --- | --- |
| `DeveloperName` | Developer Name | Yes | `Account_Pipeline_Health` |
| `MasterLabel` | Label | Yes | `Account Sales Pipeline Health` |
| `ObjectApiName__c` | Object | Yes | `Account` |
| `CardTitle__c` | Card Title | Yes | `Sales Pipeline Health` |
| `CardSubtitle__c` | Card Subtitle | No | `Open pipeline vs revenue targets` |
| `CardRunMode__c` | When Checks Run | Yes | `RUN_ON_LOAD` or `RUN_ON_REQUEST` (default) |
| `CardRevealMode__c` | Reveal Mode | Yes | `ALL_AT_ONCE` or `ONE_BY_ONE` |
| `PassedChecksDisplay__c` | Passed Checks | Yes | `SHOW_EACH_CHECK` or `SHOW_COUNT_ONLY` |
| `SkippedChecksDisplay__c` | Skipped Checks | Yes | `SHOW_EACH_CHECK` or `SHOW_COUNT_ONLY` |
| `FoundExpectedDisplay__c` | Found/Expected Display | Yes | `ON_DEMAND` (default), `FAILURES_ONLY`, or `ALL_ROWS` |
| `IsActive__c` | Active | No | `true` |
| `ShowDiagnostics__c` | Show Diagnostics | No | `false` in production. When `true`, user also needs `Record_Health_Check_View_Diagnostics` (from `Record_Health_Check_Admin`). See [Show Diagnostics guide](troubleshoot-with-show-diagnostics.md). |
| `PublishUserRunEvent__c` | Publish User Run Event | No | `false` by default; page-load runs never publish |
| `PublishErrorLogEvent__c` | Publish Error Log Event | No | `true` by default; set `false` to opt this Check Set out of ERROR log events |

**Component wiring:** In Lightning App Builder, select the intended **Check Set** for the record page. The stored LWC property is `checkSetName` and holds the Check Set's `QualifiedApiName`; Apex controller methods receive that qualified identity.

### 4.3 Rule table

Always include (all Evaluation Types):

| API field | Setup label | Required | Example |
| --- | --- | --- | --- |
| `DeveloperName` | Developer Name | Yes | `Account_Pipeline_Meets_15x_Revenue` |
| `MasterLabel` | Label | Yes | `Sales Pipeline Meets 1.5x Revenue` |
| `Record_Health_Check_Set__c` | Check Set | Yes | `Account_Pipeline_Health` |
| `CheckTitle__c` | Check Title | Yes | `Open pipeline ≥ 1.5× annual revenue` |
| `EvaluationType__c` | Evaluation Type | Yes | `QUERY` |
| `EvaluationOrder__c` | Evaluation Order | Yes | `10` (use gaps: 10, 20, 30…) |
| `Category__c` | Category | No | API values such as `COMPLETENESS`, `CONSISTENCY`, `ELIGIBILITY`, `READINESS`, or `RELATIONSHIP_COVERAGE`; Setup shows readable labels. Metadata only: UI grouping not implemented yet. |
| `FailureSeverity__c` | Failure Severity | Yes | `CRITICAL`, `WARNING`, or `INFO` |
| `DisplayValueFormat__c` | Display: Value Format | No | `AUTO` (default), or an explicit format such as `CURRENCY`, `PERCENT`, `NUMBER`, `DATE` when Found/Expected must share units |
| `FailureMessage__c` | Message When Failed | Yes | Names the record, then states what is below target: copy the example from below the table |
| `FixMessage__c` | Fix Message | No | `Review open opportunities…` (renders on FAIL rows) |
| `ActionLabel__c` | Action Label | No | Short link text; display merge tokens allowed (80-character field). Blank defaults to `Fix this` when Action URL is set |
| `ActionUrl__c` | Action URL | No | `/lightning/r/Report/00O.../view?fv0={!record.Id}` or `https://example.com/pipeline-playbook` |
| `ApplicabilityMode__c` | Applies To | Yes | `ALL_RECORDS`, `WHEN_FORMULA_TRUE`, or `WHEN_COUNT_QUERY_MATCHES` |
| `PublishUserResultEvent__c` | Publish User Result Event | No | `false` by default; page-load runs never publish |
| `IsActive__c` | Active | No | `true` |

The `FailureMessage__c` example reads:

```text
{!record.Name} pipeline is below 1.5× annual revenue.
```

Add type-specific fields from Section 5.

Use remediation fields for guidance and explicit navigation. Rendering or opening a link does not
make Record Health Check perform DML, although a destination can be an edit or prefilled create page
where the user chooses whether to save. Unsafe or overlong URLs are dropped, but Fix Message can
still render. For create-page, Knowledge, report, related-list, and external examples, see
[Configure action links](configure-action-links.md).

### 4.4 Pattern citation

Name the pattern and reference a documented example from Sections 7–8 or the local
[examples library](../examples/README.md). For Apex, cite the relevant complexity level and local
Apex example.

### 4.5 Class sketch (Apex only)

When `EvaluationType__c` = `APEX`, add a section after the Rule table. See [Apex reference](../reference/reference-apex.md) for full patterns.

| Item | What to include |
| ---- | --------------- |
| Scope | `scope.recordIds` contains the complete bounded record scope; query it once, outside record loops |
| Parent / custom fields | Select exact readable fields such as `Parent.BillingCity` or `Primary_Contact__r.Email` in user mode |
| JSON defaults | Apex constants + `ApexParametersJson__c` keys (e.g. `daysBack`) with bounds |
| Shipped vs custom | Use a shipped class only when its documented object and parameters match the requirement |
| Outcome | Return exactly one `RecordHealthCheckOutcome` per scoped record ID; attach Found/Expected values when they explain the verdict |
| Applicability | Why `ApplicabilityMode__c` is not `ALL_RECORDS` if the Rule only runs when a condition is met |

## 5. Rule fields by Evaluation Type

### 5.1 Formula (`EvaluationType__c` = `FORMULA`)

Setup label: **Verify with a formula**.

| API field | Required | Value |
| --- | --- | --- |
| `PassConditionFormula__c` | Yes | Boolean formula; `true` = pass |
| `DisplayFoundFormula__c` | Optional | single-value formula shown as **Found** (left side of a comparison). Display only: does not affect pass/fail. |
| `DisplayExpectedFormula__c` | Optional | single-value formula shown as **Expected** (right side). Display only; blank = Expected echoes `PassConditionFormula__c`. |
| `FormulaResultType__c` | Optional | Type of the Found/Expected single values (`NUMBER` / `TEXT` / `DATE` / `DATETIME` / `BOOLEAN`), or `AUTO`. |

Operands in any of these formulas may be calculated fields (formula, roll-up) at any depth: the engine loads the full dependency chain.

**Found/Expected are display-only and NOT compared to each other.** `PassConditionFormula__c` performs the comparison and decides pass/fail. Set Found/Expected only for comparison/balance checks, and mirror each side of the Pass/Fail comparison (Found = left operand, Expected = right) so the row does not mislead. For framework-driven comparison with an operator, use a Query check (`ExpectedValueSource__c` = `FIXED_VALUE` / `RECORD_FORMULA` / `COMPARISON_QUERY`).

**Leave unset:** `SourceQuery__c`, `ComparisonOperator__c`, `ExpectedValueSource__c`, `QueryResultHandling__c` (ignored).

**Examples:**

```text
NOT(ISBLANK(BillingCity))
OR(NOT(ISBLANK(Phone)), NOT(ISBLANK(Website)))
AnnualRevenue > 0
BillingCity = ShippingCity
NOT(ISBLANK(Parent.BillingCity))
```

### 5.2 Query (`EvaluationType__c` = `QUERY`)

Setup label: **Verify with a query**.

| API field | When required |
| --- | --- |
| `SourceQuery__c` | Always, except `LIST_CONTAINS_ANY` / `LIST_CONTAINS_NONE` |
| `SourceQueryField__c` | When query selects fields or aliased aggregates; omit for bare `COUNT()` |
| `QueryResultHandling__c` | Always: `ONE_RESULT`, `ANY_ROW_PASSES`, `ALL_ROWS_PASS`, `COMPARE_AS_LISTS` |
| `ComparisonOperator__c` | Always (see Section 6) |
| `ExpectedValueSource__c` | When comparison operator needs a right-hand side (`FIXED_VALUE`, `RECORD_FORMULA`, `COMPARISON_QUERY`) |
| `ExpectedFixedValue__c` | When `ExpectedValueSource__c` = `FIXED_VALUE` |
| `ExpectedRecordFormula__c` | When `ExpectedValueSource__c` = `RECORD_FORMULA` |
| `ComparisonQuery__c` | When `ExpectedValueSource__c` = `COMPARISON_QUERY`, or list operators |
| `ComparisonQueryField__c` | When comparison query returns field values (not bare `COUNT()`) |
| `NoRowsResult__c` | Required for `ANY_ROW_PASSES`, `ALL_ROWS_PASS`, `COMPARE_AS_LISTS` |
| `EmptyValueHandling__c` | Recommended for row-by-row modes; default `AS_NO_MATCH` |

**List membership exception** (`LIST_CONTAINS_ANY`, `LIST_CONTAINS_NONE`):

| API field | Role |
| --- | --- |
| `FindInListFormula__c` | Primary single value (field or formula on record). |
| `ComparisonQuery__c` | SOQL returning the list |
| `ComparisonQueryField__c` | Column to read from list query |
| `QueryResultHandling__c` | `COMPARE_AS_LISTS` |

### 5.3 Compare two queries (`EvaluationType__c` = `COMPARE_TWO_QUERIES`)

| API field | Required |
| --- | --- |
| `SourceQuery__c` | Yes: primary side |
| `ComparisonQuery__c` | Yes: comparison side |
| `SourceQueryField__c` | When primary returns fields or aliased aggregates |
| `ComparisonQueryField__c` | When comparison returns fields or aliased aggregates |
| `QueryResultHandling__c` | `ONE_RESULT` (single value) or `COMPARE_AS_LISTS` (list operators) |
| `ComparisonOperator__c` | single value or list comparison operator |

**Leave unset:** `ExpectedValueSource__c` (both sides are queries).

List operators for `COMPARE_AS_LISTS`: `LISTS_OVERLAP`, `LISTS_CONTAIN_ALL`, `LISTS_MATCH_EXACTLY`.

### 5.4 Apex (`EvaluationType__c` = `APEX`)

Full walkthroughs: [Apex examples](../examples/README.md#apex-examples) · [Recent Account activity](../examples/apex/01-recent-activity.md) · [Apex reference](../reference/reference-apex.md)

| API field | Required | Notes |
| --- | --- | --- |
| `ApexClass__c` | Yes | Class implementing `RecordHealthCheckRule`: deploy before activating Rule |
| `ApexParametersJson__c` | No | JSON **object** (not array), e.g. `{"daysBack": 90}`, `{"minDigits": 10}`, `{"staleDays": 30}` |

**Apex interface summary:** Full patterns: [Apex reference](../reference/reference-apex.md).

```apex
global with sharing class AccountExampleCheck
  implements RecordHealthCheckRule {
  global Map<Id, RecordHealthCheckOutcome> evaluate(
    RecordHealthCheckScope scope
  ) {
    Map<Id, Account> accountsById = new Map<Id, Account>([
      SELECT Id, Industry
      FROM Account
      WHERE Id IN :scope.recordIds
      WITH USER_MODE
    ]);
    Map<Id, RecordHealthCheckOutcome> outcomesById =
      new Map<Id, RecordHealthCheckOutcome>();
    for (Id recordId : scope.recordIds) {
      Account accountRecord = accountsById.get(recordId);
      outcomesById.put(
        recordId,
        String.isNotBlank(accountRecord?.Industry)
          ? RecordHealthCheckOutcome.pass('INDUSTRY_PRESENT')
          : RecordHealthCheckOutcome.fail('INDUSTRY_MISSING')
      );
    }
    return outcomesById;
  }
}
```

- Query once in user mode before iterating through the scope.
- Return exactly one outcome for every ID and no outcomes for unknown IDs.
- Do not perform DML, callouts, asynchronous enqueueing, or event publication. The engine rejects
  these side effects.
- Catch record-specific problems when one record can fail independently; an uncaught exception
  affects the complete scope.
- Pair the Rule with `RecordHealthCheckRuleContractTest` so bulk, access, mutation, side-effect,
  and limit behavior is verified before deployment.
- Use `WHEN_FORMULA_TRUE` or `WHEN_COUNT_QUERY_MATCHES` when the Rule should not run for every record.

**Shipped classes:**

| Class | JSON keys | Pattern |
| --- | --- | --- |
| `AccountHasRecentActivityCheck` | `daysBack` (1-3650, default 30) | Task + Event window |
| `AccountOpenOpportunityHealthCheck` | `staleDays` (1-3650, default 30) | Unhealthy open Opportunity detection |

Recommend only the shipped class names listed above. For composite scoring, name a **new** class and include a Class sketch for implementation (see [example 3](https://github.com/gkolan/RecordHealthCheck/blob/main/docs/examples/apex/03-strategic-readiness.md)).

### 5.5 Applicability (all rules)

| `ApplicabilityMode__c` | Additional fields |
| --- | --- |
| `ALL_RECORDS` | None |
| `WHEN_FORMULA_TRUE` | `ApplicabilityFormula__c` (Boolean, `true` = run check) |
| `WHEN_COUNT_QUERY_MATCHES` | `ApplicabilityCountQuery__c` (`SELECT COUNT()` or `SELECT COUNT(Id)`), `ApplicabilityCountOperator__c`, `ApplicabilityCountThreshold__c` |

### 5.6 Dependencies

| API field | Value |
| --- | --- |
| `PrerequisiteRule__c` | `DeveloperName` of prerequisite Rule in same Check Set (must have lower `EvaluationOrder__c`) |

Prerequisite must return `PASS` or dependent is `SKIPPED`.

## 6. Operators (`ComparisonOperator__c`)

| API value | Setup label | Needs right-hand side? | Valid with |
| --- | --- | --- | --- |
| `EQUALS` | Equals | Yes | QUERY, COMPARE_TWO_QUERIES |
| `NOT_EQUALS` | Does not equal | Yes | QUERY, COMPARE_TWO_QUERIES |
| `GREATER_THAN` | Greater than | Yes | QUERY, COMPARE_TWO_QUERIES |
| `GREATER_THAN_OR_EQUAL` | Greater than or equal | Yes | QUERY, COMPARE_TWO_QUERIES |
| `LESS_THAN` | Less than | Yes | QUERY, COMPARE_TWO_QUERIES |
| `LESS_THAN_OR_EQUAL` | Less than or equal | Yes | QUERY, COMPARE_TWO_QUERIES |
| `CONTAINS` | Contains text | Yes | QUERY, COMPARE_TWO_QUERIES (case-sensitive) |
| `DOES_NOT_CONTAIN` | Does not contain text | Yes | QUERY, COMPARE_TWO_QUERIES (case-sensitive) |
| `IS_BLANK` | Is empty | No | QUERY |
| `IS_NOT_BLANK` | Is not empty | No | QUERY |
| `LIST_CONTAINS_ANY` | List contains any | List in `ComparisonQuery__c` | QUERY only |
| `LIST_CONTAINS_NONE` | List contains none | List in `ComparisonQuery__c` | QUERY only |
| `LISTS_OVERLAP` | Lists overlap | Second query list | COMPARE_TWO_QUERIES + COMPARE_AS_LISTS |
| `LISTS_CONTAIN_ALL` | Lists contain all | Second query list | COMPARE_TWO_QUERIES + COMPARE_AS_LISTS |
| `LISTS_MATCH_EXACTLY` | Lists match exactly | Second query list | COMPARE_TWO_QUERIES + COMPARE_AS_LISTS |

## 7. Pattern reference

| Business intent | EvaluationType | QueryResultHandling | Expected source / notes |
| --- | --- | --- | --- |
| Field required on record | FORMULA | | `NOT(ISBLANK(Field))` |
| Either field A or B required | FORMULA | | `OR(NOT(ISBLANK(A)), NOT(ISBLANK(B)))` |
| At least N related records | QUERY | ONE_RESULT | `COUNT()` > FIXED_VALUE |
| Every child row meets bar | QUERY | ALL_ROWS_PASS | vs FIXED_VALUE or RECORD_FORMULA |
| Any child row meets bar | QUERY | ANY_ROW_PASSES | vs FIXED_VALUE or RECORD_FORMULA |
| Aggregate ≥ static threshold | QUERY | ONE_RESULT | SUM/AVG/etc. vs FIXED_VALUE |
| Aggregate ≥ per-record formula | QUERY | ONE_RESULT | SUM/etc. vs RECORD_FORMULA |
| Aggregate ≥ second query | QUERY | ONE_RESULT | vs COMPARISON_QUERY |
| Two counts or aggregates compared | COMPARE_TWO_QUERIES | ONE_RESULT | single-value operator |
| Account field in child list | QUERY | COMPARE_AS_LISTS | LIST_CONTAINS_ANY + FindInListFormula |
| Field not in reference list | QUERY | COMPARE_AS_LISTS | LIST_CONTAINS_NONE |
| Two lists overlap / contain / match | COMPARE_TWO_QUERIES | COMPARE_AS_LISTS | LISTS_OVERLAP / LISTS_CONTAIN_ALL / LISTS_MATCH_EXACTLY |
| Type-specific rule only | FORMULA | | Applicability Formula: `ISPICKVAL(Type, "Partner")` |
| Run only when children exist | | | Applicability SOQL: COUNT > 0 |
| Recent activity (Task or Event) | APEX | | `AccountHasRecentActivityCheck` |
| Unhealthy child rows (combined) | APEX | | `AccountOpenOpportunityHealthCheck` |
| Weighted readiness score | Apex | | Custom class: [apex/03-strategic-readiness.md](https://github.com/gkolan/RecordHealthCheck/blob/main/docs/examples/apex/03-strategic-readiness.md) |

## 8. Supported vs unsupported combinations

### Supported (configure with confidence)

| Shape | How |
| --- | --- |
| SOQL left, static right | Query + `FIXED_VALUE` |
| SOQL left, record formula right | Query + `RECORD_FORMULA` |
| SOQL left, second query right | Query + `COMPARISON_QUERY` |
| Two queries compared | COMPARE_TWO_QUERIES |
| Formula single value in query list | Query + `LIST_CONTAINS_ANY` / `LIST_CONTAINS_NONE` |
| SUM vs `AnnualRevenue * 1.5` | QUERY + ONE_RESULT + RECORD_FORMULA |

### Unsupported or awkward (recommend workaround)

| Shape | Problem | Workaround |
| --- | --- | --- |
| Formula check + Expected Value Comes From | Formula path ignores comparison fields | Put full logic in `PassConditionFormula__c` |
| Formula left, SOQL single value right (EQUALS, GREATER_THAN, …) | Primary must be `SourceQuery__c` for single-value operators | Flip: query left, `RECORD_FORMULA` right; or COMPARE_TWO_QUERIES; or APEX |
| `SELECT SUM(x) FROM ...` without alias | Framework cannot read column | Add alias: `SUM(Amount) totalAmt` + `SourceQueryField__c = totalAmt` |
| Multiplier on COMPARE_TWO_QUERIES right side | Both sides are raw query values only | Use QUERY + RECORD_FORMULA, or APEX |
| Blocking save on fail | Product is read-time only | Validation rule or Flow |
| More than 25 active rules | Hard cap per run | Split Check Sets or deactivate low-value rules |
| Org-wide batch audit | No packaged scheduler | Apex batch calling `RecordHealthCheck.evaluate(request)` |

## 9. SOQL rules for LLMs

### Merge tokens

- Syntax: `{!record.FieldApiName}` on the **base record** (the record page object). Add a quoted `fallback` attribute when a blank value needs a substitute.
- Examples: `{!record.Id}`, `{!record.Name}`, `{!record.AnnualRevenue fallback="0"}`, `{!record.Customer_Tier__c fallback="Standard"}`, `{!record.Parent.BillingCity fallback="the account city"}`.
- Strings are quoted and escaped automatically; numbers and dates are unquoted.
- The exact substring `'{!record.Field}'` inside a larger literal works (for example `Name LIKE '{!record.Name}%'`). Use a fallback inside quotes only when a blank name would break the filter.
- A token may appear both quoted and unquoted in one template: each form is substituted independently.
- User must have read FLS on token fields or check returns `UNABLE_TO_EVALUATE`.

### Aggregates

| Function | Alias required? | `SourceQueryField__c` |
| --- | --- | --- |
| `COUNT()` | No | Leave blank |
| `COUNT(field)` | Yes | Alias name |
| `COUNT_DISTINCT(field)` | Yes | Alias name |
| `SUM(field)` | Yes | Alias name |
| `AVG(field)` | Yes | Alias name |
| `MIN(field)` | Yes | Alias name |
| `MAX(field)` | Yes | Alias name |

**Wrong:** `SELECT SUM(Amount) FROM Opportunity WHERE AccountId = {!record.Id}`
**Right:** `SELECT SUM(Amount) pipelineTotal FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false` + `SourceQueryField__c = pipelineTotal`

### Null / empty rows

- Aggregates return `null` when no rows match: pair with applicability SOQL (`COUNT > 0`) or `EmptyValueHandling__c = SKIP_RECORD`.
- **`NoRowsResult__c`:** `PASS`, `FAIL`, `SKIP`, `UNABLE_TO_EVALUATE` when a query returns **zero rows** (including COMPARE_TWO_QUERIES ONE_RESULT when either side's query is empty).
- **`EmptyValueHandling__c`:** when rows exist but a field under test is null and the comparison operator cannot decide (typically `SKIP_RECORD`), the check is **SKIPPED** with `VALUE_IS_EMPTY`: not governed by `NoRowsResult__c`.

## 10. Worked examples (copy-ready)

### 10.1 Portfolio readiness (Formula)

| API field | Value |
| --- | --- |
| `EvaluationType__c` | `FORMULA` |
| `PassConditionFormula__c` | `AND(OR(NOT(ISBLANK(Phone)), NOT(ISBLANK(Website))), NOT(ISBLANK(BillingCountry)), AnnualRevenue >= Parent.Parent.AnnualRevenue * 0.10)` |
| `DisplayFoundFormula__c` | `AnnualRevenue` |
| `DisplayExpectedFormula__c` | `Parent.Parent.AnnualRevenue * 0.10` |
| `FormulaResultType__c` | `NUMBER` |
| `ApplicabilityMode__c` | `ALL_RECORDS` |
| `FailureSeverity__c` | `CRITICAL` |
| `FailureMessage__c` | Names the record, then lists the three missing conditions: copy it from below the table |

Copy this value into `FailureMessage__c`:

```text
{!record.Name} needs a contact channel, billing country, and revenue equal to at least 10% of its top-level portfolio account.
```
This example deliberately demonstrates multiple conditions and a two-level parent relationship.
Ask whether the org guarantees both parent levels; otherwise recommend a shallower relationship or
an applicability condition.

### 10.2 At least one Contact (Query)

| API field | Value |
| --- | --- |
| `EvaluationType__c` | `QUERY` |
| `SourceQuery__c` | `SELECT COUNT() FROM Contact WHERE AccountId = {!record.Id}` |
| `QueryResultHandling__c` | `ONE_RESULT` |
| `ComparisonOperator__c` | `GREATER_THAN` |
| `ExpectedValueSource__c` | `FIXED_VALUE` |
| `ExpectedFixedValue__c` | `0` |

Shipped: `Account_EU_HasAtLeastOneContact`.

### 10.3 Open pipeline ≥ 1.5× annual revenue (Query + aggregate + formula)

| API field | Value |
| --- | --- |
| `EvaluationType__c` | `QUERY` |
| `SourceQuery__c` | `SELECT SUM(Amount) totalPipeline FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false AND Amount != null` |
| `SourceQueryField__c` | `totalPipeline` |
| `QueryResultHandling__c` | `ONE_RESULT` |
| `ComparisonOperator__c` | `GREATER_THAN_OR_EQUAL` |
| `ExpectedValueSource__c` | `RECORD_FORMULA` |
| `ExpectedRecordFormula__c` | `AnnualRevenue * 1.5` |
| `EmptyValueHandling__c` | `SKIP_RECORD` |
| `ApplicabilityMode__c` | `WHEN_FORMULA_TRUE` |
| `ApplicabilityFormula__c` | `AND(NOT(ISBLANK(AnnualRevenue)), AnnualRevenue > 0)` |

This example uses the Opportunity `Amount` field. If the business requirement is based on product
line items, use Apex to aggregate `OpportunityLineItem.TotalPrice` safely. Similar shipped pattern:
`Account_CTQ_SumVsAnnualRevenue` (1:1 revenue, via COMPARE_TWO_QUERIES).

### 10.4 Billing State appears in Contact states (list membership)

| API field | Value |
| --- | --- |
| `EvaluationType__c` | `QUERY` |
| `FindInListFormula__c` | `BillingState` |
| `ComparisonQuery__c` | `SELECT MailingState FROM Contact WHERE AccountId = {!record.Id} AND MailingState != null` |
| `ComparisonQueryField__c` | `MailingState` |
| `QueryResultHandling__c` | `COMPARE_AS_LISTS` |
| `ComparisonOperator__c` | `LIST_CONTAINS_ANY` |
| `NoRowsResult__c` | `SKIP` |

Shipped: `Account_QC_ListContainsAny` (`LIST_CONTAINS_ANY`).

### 10.5 Partner accounts need Billing Country (Formula + applicability)

| API field | Value |
| --- | --- |
| `EvaluationType__c` | `FORMULA` |
| `PassConditionFormula__c` | `NOT(ISBLANK(BillingCountry))` |
| `ApplicabilityMode__c` | `WHEN_FORMULA_TRUE` |
| `ApplicabilityFormula__c` | `ISPICKVAL(Type, "Partner")` |

Shipped: `Account_Adv_PartnerBillingCountry`.

### 10.6 Recent Task/Event activity (Apex: Multi-object)

| API field | Value |
| --- | --- |
| `EvaluationType__c` | `APEX` |
| `ApexClass__c` | `AccountHasRecentActivityCheck` |
| `ApexParametersJson__c` | `{"daysBack": 90}` |
| `ApplicabilityMode__c` | `ALL_RECORDS` |
| `FailureSeverity__c` | `WARNING` |
| `FailureMessage__c` | Names the record, then states that no activity was logged in the window: copy it from below the table |

Copy this value into `FailureMessage__c`:

```text
{!record.Name fallback="this record"} has no completed tasks or logged events in the last 90 days.
```

This class ships with Record Health Check. See [Recent Account activity](https://github.com/gkolan/RecordHealthCheck/blob/main/docs/examples/apex/01-recent-activity.md).

### 10.7 Unhealthy open Opportunities (Apex: Child aggregation)

| API field | Value |
| --- | --- |
| `EvaluationType__c` | `APEX` |
| `ApexClass__c` | `AccountOpenOpportunityHealthCheck` |
| `ApexParametersJson__c` | `{"staleDays": 30}` |
| `ApplicabilityMode__c` | `WHEN_COUNT_QUERY_MATCHES` |
| `ApplicabilityCountQuery__c` | `SELECT COUNT() FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false` |
| `ApplicabilityCountOperator__c` | `GREATER_THAN` |
| `ApplicabilityCountThreshold__c` | `0` |
| `FailureSeverity__c` | `CRITICAL` |
| `FailureMessage__c` | One or more open opportunities are stale, missing a Next Step, or have no close date this quarter. |

Doc: [apex/02-open-opportunity-health.md](https://github.com/gkolan/RecordHealthCheck/blob/main/docs/examples/apex/02-open-opportunity-health.md).

### 10.8 Strategic readiness score (Apex: Composite, custom deploy)

| API field | Value |
| --- | --- |
| `EvaluationType__c` | `APEX` |
| `ApexClass__c` | `AccountStrategicReadinessCheck` *(not in package: deploy separately)* |
| `ApexParametersJson__c` | `{"minScore": 80, "activityDaysBack": 60}` |
| `ApplicabilityMode__c` | `WHEN_FORMULA_TRUE` |
| `ApplicabilityFormula__c` | `ISPICKVAL(Type, "Strategic")` |

Include a **Class sketch** when outputting this pattern. Full reference code: [apex/03-strategic-readiness.md](https://github.com/gkolan/RecordHealthCheck/blob/main/docs/examples/apex/03-strategic-readiness.md).

## 11. Naming conventions

| Item | Convention | Example |
| --- | --- | --- |
| Check Set `DeveloperName` | `Object_Purpose` | `Account_Pipeline_Health` |
| Rule `DeveloperName` | `Object_ShortDescription` | `Account_Pipeline_Meets_15x_Revenue` |
| Rule `MasterLabel` | Spaces, readable in Setup | `Sales Pipeline Meets 1.5x Revenue` |
| Rule `CheckTitle__c` | User-facing, concise | `Open pipeline ≥ 1.5× revenue` |
| `EvaluationOrder__c` | Gaps of 10 | 10, 20, 30 (dependencies: prerequisite lower) |

## 12. Example library (reference for LLMs)

Record Health Check ships clearly prefixed example Custom Metadata. Use the local [examples library](../examples/README.md) to
select a distinct pattern, then output configuration the reader can create in Salesforce Setup.

| Evaluation Type | Use the examples to learn |
| --- | --- |
| **Verify with a formula** | Boolean combinations, parent fields, applicability, numeric thresholds, and Found/Expected formulas |
| **Verify with a query** | Counts, row handling, record-formula expectations, text operators, list membership, and upper limits |
| **Compare two queries** | Count coverage, list overlap, and contains-all relationships |
| **Verify with Apex** | Multi-object logic, per-row composite conditions, weighted scoring, dynamic product objects, and JSON parameters |

## 13. Framework limits (stay within these in recommendations)

| Limit | Value |
| --- | --- |
| Active rules per run | 25 (lowest `EvaluationOrder__c` first) |
| SOQL rows per query | 2000 default (`MaxQueryRows__c` can lower, not raise) |
| Formula eval calls per Apex transaction | 100 platform; framework guards at ~95 |
| Concurrent evaluate calls (LWC) | 5 when Stop after a system error is off |
| Component placement | Record pages only (needs `recordId`) |
| Base object | Check Set `ObjectApiName__c` must match page object |

## 14. Clarifying questions (ask when requirements are vague)

1. **Base object**: Account, Opportunity, Contact, or custom?
2. **Child relationship**: which object and filter (open only, won, last 90 days)?
3. **Threshold**: fixed number or derived from a field on the record?
4. **Zero related rows**: should that pass, fail, or skip the check?
5. **Blank threshold field**: skip or fail (e.g. no `AnnualRevenue`)?
6. **Blocking**: if user says "must not save", recommend validation rule instead.

## 15. Deeper documentation map

- [Configure Check Sets and Rules](configure-check-sets-and-rules.md): every Setup field explained
- [Configuration guide: what it can check](configure-check-sets-and-rules.md#2-what-it-can-check): when to use which Evaluation Type
- [Examples README](https://github.com/gkolan/RecordHealthCheck/blob/main/docs/examples/README.md): pattern matrix, merge tokens, and copy-paste examples by type
- [Reason Codes](../reference/reference-reason-codes.md): stable Framework outcomes and investigation guidance
- [Create your first Rule](../installation/03-create-your-first-rule.md): install and first Rule

## 16. Gemini gem checklist

When building a Gemini gem for this project:

1. Upload this file as primary knowledge.
2. Add `configure-check-sets-and-rules.md` and `https://github.com/gkolan/RecordHealthCheck/blob/main/docs/examples/README.md` as secondary knowledge.
3. Paste Section 2 (system prompt) into gem instructions.
4. Tell users to paste: base object, fields involved, pass/fail semantics, and whether zero children should pass or skip.
5. Require gem output to use Section 4 tables (API names, not Setup-only labels).
6. Link humans to [Create your first Rule](../installation/03-create-your-first-rule.md) for entering metadata in Setup.

## Related

- [Configure Check Sets and Rules](configure-check-sets-and-rules.md)
- [Metadata reference](../metadata/README.md)
- [Apex reference](../reference/reference-apex.md)
- [Reason Codes](../reference/reference-reason-codes.md)
