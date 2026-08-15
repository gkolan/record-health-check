# Shared Apex services (L2)

> [!NOTE]
> Use this page to understand internal package classes that compare values, format results, prepare
> SOQL, read Salesforce fields, check permissions, and write logs.

This page is part of the [Apex class reference](README.md).

## Shared evaluation services (L2)

### `RecordHealthCheckComparisonEngine`

**Role:** Compare Found and Expected values for both Query Evaluation Types.

**Type:** Shared service · `public with sharing`

Implements Equals, Not Equal, Contains, greater-than and less-than comparisons, empty-value checks,
and list comparisons. It also applies **Empty Value Handling** and **No Rows Result** consistently to
Query and Compare two queries Checks.

**Key members:**

| Member | Purpose |
| --- | --- |
| `applySingleValueComparison(...)` | One-value operator comparison |
| `applySingleComparison(...)` | Single-row operator comparison |
| `applyUnaryComparison(...)` | Blank-check style operators |
| `valuesEqual(...)` | Typed equality |
| `resolveEmptyBehavior(...)` | `EmptyValueHandling__c` / `NoRowsResult__c` resolution |
| `formatValue(...)` / `formatList(...)` | Human-readable display formatting |
| `valueForDisplay(...)` / `valuesForDisplay(...)` | Resolve display-only picklist labels from a queried field while leaving comparison values untouched |
| `describeExpected(...)` / `describeExpectedForActual(...)` | Operator phrase plus the formatted operand |

**Notable behavior:**

- Each display method has an overload that takes the Check's `DisplayValueFormat__c`. The no-format
 overloads render on `Auto`. The rendering itself lives in
 [`RecordHealthCheckDisplayFormat`](#recordhealthcheckdisplayformat); this class owns the operator
 phrasing and the list preview cap.
- **Example:** `formatList` limits the rendered preview to `LIST_PREVIEW_CAP` (`10`) entries and
 appends `… (N total)` beyond that, so a large query result stays readable in the UI. Full
 contract: [Reference: Display value format](../contracts/display-value-format.md).

### `RecordHealthCheckDisplayFormat`

**Role:** Format Found and Expected values for the Lightning card and messages.

**Type:** Shared service · `public with sharing`

Applies the Check's **Display: Value Format** (`DisplayValueFormat__c`). **Auto** chooses a format
from the Salesforce data type. A named format such as **Currency** or **Raw** overrides it. Formatting
changes only what a person sees; it cannot change PASS or FAIL.

**Key members:**

| Member | Purpose |
| --- | --- |
| `render(value, format, isoCode)` | One value rendered for the chosen format and currency |
| `isFormatApiName(format)` | Whether a name is one of the ten official, uppercase format API values |
| `isDisplayedNumberOne(value)` | Whether locale-formatted display text represents exactly one, used when a rendered count needs singular or plural wording |
| `formatForField(...)` / `formatForRow(...)` | The format a field's Setup definition suggests, used when the Check is on Auto |
| `valueForDisplay(...)` / `valuesForDisplay(...)` | Picklist labels or raw typed values prepared for one value or a list |
| `currencyIsoCodeFrom(row)` | The currency a row's amounts belong to, in an org with more than one |
| `currencyIsoCodeFor(row, record, fieldPath)` | The same, walking a relationship path when needed and falling back to the card record when the query read that record without selecting `CurrencyIsoCode` |
| `currencyIsoCodesFor(rows, record, fieldPath)` | One currency per row, including related rows, so a list preview labels each entry with its own |
| `alignExpectedToFound(...)` | Keeps a fixed text operand in the same units as a numeric Found value |
| `FORMAT_*` constants | The `DisplayValueFormat__c` API values |

**Notable behavior:**

- Numbers are grouped for the running user's locale: `70000.0` reads `70,000` for an English (US)
 user and `70.000` for a German (Germany) one. The digits are laid out by the class rather than by
 `Decimal.format()`, which keeps only three decimal places; a chip shows up to six, rounded for
 display only.
- An aggregate row such as `SUM(Amount)` is labelled with the org's corporate currency, which is
 what Salesforce converts an aggregate into.
- Each side of a comparison keeps its own currency: a Compare two queries Check, and a Query Check
 whose Expected value comes from a comparison query, read a currency per side rather than sharing
 the Found side's.
- ISO date text that names an impossible date, such as `2026-02-30`, keeps its original spelling.
 `Date.newInstance` rolls out-of-range parts over instead of rejecting them, so the parts are
 checked by round-tripping before the value is treated as a date.
- Aligning an Expected operand to a numeric Found value keeps the leading-zero guard, so `00100`
 stays `00100`.
- A `Time` reads on a 24-hour clock (`17:30`), because Apex can format a time of day only as part of
 a date.
- A named format that cannot apply to a value returns the value with its original spelling instead
  of raising an error. For example, **Currency** applied to a Salesforce ID still displays the ID.
- A `Date` is tested before a `Datetime` everywhere, because Apex reports a `Date` as an instance of
 `Datetime`; checking the other way round would shift a date by the user's time-zone offset.
- An org with more than one currency renders ISO-first (`USD 70,000.00`); a single-currency org uses
 the symbol. `RecordHealthCheckFieldPlanner` loads `CurrencyIsoCode` on the record in a multi-currency org
 so an amount can be shown in the currency its own record uses.
- Full contract: [Reference: Display value format](../contracts/display-value-format.md).

### `RecordHealthCheckSoqlTemplate`

**Role:** Prepare administrator-written SOQL to run safely with user access enforced.

**Type:** Shared service · `public with sharing`

Requires one outer `SELECT`, rejects keywords that can change data, rejects `WITH SYSTEM_MODE`,
rewrites a bare `COUNT()`, applies the configured row limit, and inserts `WITH USER_MODE` in a valid
location. Text inside quotes and nested queries is handled separately so it is not mistaken for an
outer SOQL clause.

**Key members:**

| Member | Purpose |
| --- | --- |
| `prepareForExecution(soql, maxRows)` | Prepare and limit SOQL written by an administrator |
| `rootObject(soql)` | Resolve the outer query root without mistaking a literal or child subquery `FROM` for the root |
| `outerSelectList(soql)` | Return the outer select list while preserving nested query text |
| `hasConjunctiveEqualityFilter(soql, fieldApiName)` | Prove a literal equality only for a conjunctive outer predicate; `OR` and `NOT` fail closed |
| `TemplateException` (nested) | Exception carrying `reasonCode` |

**Notable behavior:**

- The class temporarily replaces characters inside quoted text with spaces while locating SOQL
  clauses, including backslash-escaped quotes. Keeping the same character positions lets it safely
  edit the original query afterward.
- It inserts `WITH USER_MODE` before `GROUP BY`, `ORDER BY`, `LIMIT`, and other ending clauses where
  Salesforce requires it. `WITH SYSTEM_MODE` is rejected because it would bypass the running user's
  record, object, and field access.

### `RecordHealthCheckValueResolver`

**Role:** Read and compare values returned by SOQL.

**Type:** Shared service · `public with sharing`

Reads fields from rows and `AggregateResult`s (including relationship paths), classifies typed
query failures, and compares numeric / datetime / string values consistently for both Query
evaluators.

**Key members:**

| Member | Purpose |
| --- | --- |
| `traverse(...)` | Read a (possibly relationship-dotted) field path off a row |
| `classifyQueryException(...)` | Map a typed execution exception to a reason code without reading localized text |
| `ResolverException` (nested) | Exception carrying `reasonCode` |

**Notable behavior:**

- When a related record in a field path such as `Account.Owner.Name` is missing, `traverse` returns
  `null` instead of throwing an exception.
- Supported flat query schema is describe-validated before execution. A typed
  `System.NoAccessException` maps to `FIELD_NOT_ACCESSIBLE`; remaining execution exceptions map to
  `INVALID_SOQL_TEMPLATE`. No reason code depends on localized exception text.

### `RecordHealthCheckQuerySchemaValidator`

**Role:** Deterministically validate the supported flat-query schema subset before execution.

The root object is validated for every recognizable outer `SELECT ... FROM` query. A comma-separated
list of plain fields and relationship paths is also resolved through the same FieldPlanner describe
rules used for record loading. Aggregate functions, aliases, subqueries, `TYPEOF`, syntax, and bind
validity remain outside this bounded validator and are never guessed from exception messages. A
plain Base64/Blob field is resolved by describe and refused as `FIELD_TYPE_NOT_SUPPORTED` before
query execution so binary data cannot enter comparison, serialization, display, or diagnostics.

### `RecordHealthCheckCurrencySupport`

**Role:** Preserve reachable query-row currency evidence and prevent cross-unit verdicts.

Classifies selected fields through describe metadata, retains row ISO evidence for Query and
Compare two queries comparisons, and refuses a verdict when that evidence contains multiple units.
It also identifies ungrouped aggregates over Currency fields for shared metadata validation.
Aggregate rows, Formula arithmetic, and subscriber-plugin internals do not expose unit evidence to
this service; it never converts values.

### `RecordHealthCheckDescribeCache`

**Role:** Reuse Salesforce object and field descriptions within one transaction.

**Type:** Shared service · `public with sharing`

Keeps Salesforce object and field descriptions after their first use so a Lightning card or bulk
request does not retrieve the same description repeatedly. Other package classes use this service
instead of making duplicate Schema describe calls.

**Key members:**

| Member | Purpose |
| --- | --- |
| `containsObject(...)` | Whether an object exists in the global describe |
| `resolveSObjectType(...)` | Resolve an object API name to its `SObjectType` |
| `getGlobalDescribe(...)` | Cached global describe map |
| `objectApiName(...)` | Cached object API name lookup |
| `describeSObject(...)` | Cached `DescribeSObjectResult` |
| `fieldMap(...)` | Cached field map for an object |
| `describeField(...)` | Cached `DescribeFieldResult` for one field |

**Notable behavior:**

- The cache identifies a field by its `Schema.SObjectField`, not only by a name such as `Name`.
  `Account.Name` and `Contact.Name` therefore cannot overwrite each other's description or field
  access result.

### `RecordHealthCheckEvaluatorException`

**Role:** Carry a safe Reason Code when a comparison or query cannot be evaluated.

**Type:** Custom exception · `public`, extends `Exception`

Comparison, SOQL preparation, and value-reading classes throw this exception. The Evaluation Type
class catches it and returns `UNABLE_TO_EVALUATE` with its Reason Code instead of exposing a stack
trace to the user.

**Notable behavior:**
- **Why it exists:** one top-level exception lets shared comparison and query services carry a
 stable reason code that both SOQL evaluators recognize and convert into safe results.

### `RecordHealthCheckAccess`

**Role:** Check whether the running user can start a health check or view diagnostics.

**Type:** Shared service · `public with sharing`

`canRunChecks()` checks the **Record Health Check Run**
(`rhc__Record_Health_Check_Run`) Custom Permission. `requireCanRunChecks()` stops the request with
`NOT_AUTHORIZED` when that permission is missing.

`canViewDetails()` checks **Record Health Check View Diagnostics**
(`rhc__Record_Health_Check_View_Diagnostics`). The Check Set's **Show Diagnostics** setting still
controls whether troubleshooting details are prepared; the Custom Permission controls who may see
them.

**Key members:**

| Member | Purpose |
| --- | --- |
| `canRunChecks()` | Whether the running user has the Custom Permission required to start a health check |
| `requireCanRunChecks()` | Stop the request with `AuthorizationException` when that permission is missing |
| `canViewDetails()` | Whether the running user holds the diagnostics Custom Permission |

**Notable behavior:**

- `runPermissionOverride` is available only to package tests. Outside an Apex test,
  `canRunChecks()` always uses the real Custom Permission assignment.

### `RecordHealthCheckLogger`

**Role:** Write Record Health Check debug logs and optional Error Log Platform Events.

**Type:** Shared service · `public with sharing`

Every package log line starts with `[RHC]` and includes the run ID and running user. Supported levels
are `ERROR`, `WARN`, `INFO`, and `DEBUG`. The class also holds ERROR entries until `flush()` publishes
them as `Record_Health_Check_Log__e` Platform Events. Error-event publication is on unless the
selected Check Set turns off **Publish Error Log Event**. Package entry points call `flush()` before
their transaction ends.

**Key members:**

| Member | Purpose |
| --- | --- |
| `normalizeIdentifier(...)` | Length-limited API names used in logs and lookups |
| `flush()` | Publish held `ERROR` events at the transaction boundary |
| `enterSubscriberContext()` | Package-internal loop guard; custom Apex in an org that installs the package cannot call it through the `rhc` namespace |

**Notable behavior:**

- Error Log events do not contain Found or Expected values. They contain the run ID, Check Set and
  Check names, record ID, exception type, message, stack trace, and running user ID. This keeps
  checked business values out of an event available to everyone who can read that Platform Event.
- An internal loop guard prevents package-owned event handling from republishing the same type of
  event. A custom Flow or Apex trigger that receives Error Log events must also avoid publishing the
  same event again or starting work that creates a loop.

**See also:** [Log event metadata](../../metadata/event-log.md)

---

## Related

- [Apex class reference](README.md)
- [Architecture](../framework/architecture.md)
