# Reference: Apex shared evaluation services (L2)

> [!NOTE]
> On this page, look up the L2 shared services for comparison, display formatting, SOQL
> templates, value resolution, describe cache, access checks, and logging.

This page is part of the [Apex class reference](README.md).

## Shared evaluation services (L2)

### `RecordHealthCheckComparisonEngine`

**Role:** Shared comparison operators for Query evaluators.
**Type:** Shared service · `public with sharing`

Implements Equals / NotEquals / Contains / ordered operators, unary blank checks, list operators,
and `EmptyValueHandling__c` / `NoRowsResult__c` resolution. Throws
`RecordHealthCheckEvaluatorException` so both SOQL evaluators map the same reason codes.

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
- Each display method has an overload that takes the Rule's `DisplayValueFormat__c`. The no-format
 overloads render on `Auto`. The rendering itself lives in
 [`RecordHealthCheckDisplayFormat`](#recordhealthcheckdisplayformat); this class owns the operator
 phrasing and the list preview cap.
- **Example:** `formatList` limits the rendered preview to `LIST_PREVIEW_CAP` (`10`) entries and
 appends `… (N total)` beyond that, so a large query result stays readable in the UI. Full
 contract: [Reference: Display value format](../contracts/display-value-format.md).

### `RecordHealthCheckDisplayFormat`

**Role:** Renders Found and Expected values as the text shown on the card chips.
**Type:** Shared service · `public with sharing`

Applies the Rule's **Display: Value Format** (`DisplayValueFormat__c`). On `Auto` a value is
humanized from its Apex type; a named format such as `Currency` or `Raw` overrides that. Formatting
is display only - `RecordHealthCheckComparisonEngine` decides pass and fail from the raw typed
values, so no format can move a check between pass and fail.

**Key members:**

| Member | Purpose |
| --- | --- |
| `render(value, format, isoCode)` | One value rendered for the chosen format and currency |
| `isFormatApiName(format)` | Whether a name is one of the ten official, uppercase format API values |
| `isDisplayedNumberOne(value)` | Whether locale-formatted display text represents exactly one, used when a rendered count needs singular or plural wording |
| `formatForField(...)` / `formatForRow(...)` | The format a field's Setup definition suggests, used when the Rule is on Auto |
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
- Each side of a comparison keeps its own currency: a Compare two queries Rule, and a Query Rule
 whose Expected value comes from a comparison query, read a currency per side rather than sharing
 the Found side's.
- ISO date text that names an impossible date, such as `2026-02-30`, keeps its original spelling.
 `Date.newInstance` rolls out-of-range parts over instead of rejecting them, so the parts are
 checked by round-tripping before the value is treated as a date.
- Aligning an Expected operand to a numeric Found value keeps the leading-zero guard, so `00100`
 stays `00100`.
- A `Time` reads on a 24-hour clock (`17:30`), because Apex can format a time of day only as part of
 a date.
- A named format that cannot apply to a value returns the value with its original spelling rather
 than raising an error - `Currency` on a Salesforce Id stays the Id.
- A `Date` is tested before a `Datetime` everywhere, because Apex reports a `Date` as an instance of
 `Datetime`; checking the other way round would shift a date by the user's time-zone offset.
- An org with more than one currency renders ISO-first (`USD 70,000.00`); a single-currency org uses
 the symbol. `RecordHealthCheckFieldPlanner` loads `CurrencyIsoCode` on the record in a multi-currency org
 so an amount can be shown in the currency its own record uses.
- Full contract: [Reference: Display value format](../contracts/display-value-format.md).

### `RecordHealthCheckSoqlTemplate`

**Role:** Safe preparation of administrator-authored SOQL.
**Type:** Shared service · `public with sharing`

Cleans up admin-authored SOQL with awareness of parenthesis depth: rejects DML keywords and
`WITH SYSTEM_MODE`, requires a single outer SELECT, rewrites bare `COUNT()`, enforces the outer row
limit, and injects `WITH USER_MODE` in a legal clause position. Ignores keywords inside string
literals and nested subqueries so false positives and misplaced injection are avoided.

**Key members:**

| Member | Purpose |
| --- | --- |
| `prepareForExecution(soql, maxRows)` | Main entry point; cleans up and limits admin-authored SOQL |
| `TemplateException` (nested) | Exception carrying `reasonCode` |

**Notable behavior:**
- **Gotcha:** `maskStringLiterals` replaces every character inside a single-quoted literal with a
 space (preserving length and position) rather than stripping it, so later regex match indices
 computed against the masked copy still map back onto the original SOQL string unchanged.
 `injectUserMode` only inserts `WITH USER_MODE` when no outer `WITH` clause already exists, and
 walks `TAIL_CLAUSE_PATTERNS` to find the earliest legal tail-clause position (`GROUP BY`/`ORDER
 BY`/`LIMIT`/etc.) to insert before - an admin query already ending in a tail clause never gets
 `WITH USER_MODE` appended after it, which would be invalid SOQL. `WITH SYSTEM_MODE` is rejected
 outright rather than merely ignored, since it would let an admin-authored query bypass the
 sharing/FLS enforcement the framework guarantees.

### `RecordHealthCheckValueResolver`

**Role:** Value extraction, conversion, and comparison.
**Type:** Shared service · `public with sharing`

Reads fields from rows and `AggregateResult`s (including relationship paths), classifies
`QueryException` messages into access vs template reason codes, and compares numeric / datetime /
string values consistently for both Query evaluators.

**Key members:**

| Member | Purpose |
| --- | --- |
| `traverse(...)` | Read a (possibly relationship-dotted) field path off a row |
| `classifyQueryException(...)` | Map a `QueryException` message to a reason code |
| `ResolverException` (nested) | Exception carrying `reasonCode` |

**Notable behavior:**
- **Gotcha:** `traverse` returns `null` (not an exception) when an intermediate relationship in a
 dotted field path (e.g. `Account.Name`) is itself null, so a broken relationship chain becomes a
 null value rather than an error. `classifyQueryException` inspects the exception message text
 for `access`, `permission`, or `insufficient privileges` to decide `FIELD_NOT_ACCESSIBLE` vs.
 `INVALID_SOQL_TEMPLATE` - it accepts the base `Exception` type specifically because
 `System.QueryException` cannot be constructed with a custom message in a test, so only the message
 is ever inspected, not the exception's runtime type.

### `RecordHealthCheckDescribeCache`

**Role:** Schema describe cache for the current transaction.
**Type:** Shared service · `public with sharing`

Caches global describe, SObject describes, field maps, and field describes so a busy card or bulk
run does not rebuild metadata repeatedly. Production describe lookups should go through this class
rather than calling Schema APIs directly elsewhere in the Framework.

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
- **Gotcha:** `describeField` keys its cache on the `Schema.SObjectField` token itself, not on
 `String.valueOf(field)` - a comment notes that `String.valueOf` returns only the unqualified field
 name, so two same-named fields reached from different objects (for example `Account.Name` vs.
 `Contact.Name` via a relationship traversal) would otherwise collide in the cache and return the
 wrong describe, including a wrong `isAccessible()` result.

### `RecordHealthCheckEvaluatorException`

**Role:** Evaluator exception with a reason code.
**Type:** Custom exception · `public`, extends `Exception`

Thrown by comparison, SOQL template, and value-resolution paths. Evaluators catch it and map
`reasonCode` onto `UNABLE_TO_EVALUATE` results instead of leaking stack traces to users.

**Notable behavior:**
- **Why it exists:** one top-level exception lets shared comparison and query services carry a
 stable reason code that both SOQL evaluators recognize and convert into safe results.

### `RecordHealthCheckAccess`

**Role:** Diagnostics Custom Permission check.
**Type:** Shared service · `public with sharing`

`canViewDetails()` returns whether the running user holds `Record_Health_Check_View_Diagnostics`.
Check Set `ShowDiagnostics__c` still controls *when* troubleshooting fields are attached; this class
only answers *who* may see them.

**Key members:**

| Member | Purpose |
| --- | --- |
| `canViewDetails()` | Whether the running user holds the diagnostics Custom Permission |

**Notable behavior:**
- **Gotcha:** `canViewDetails()` only honors the `@TestVisible` `viewDetailsPermissionOverride` when
 `Test.isRunningTest()` is true - a test override left set can never leak into a non-test
 `FeatureManagement.checkPermission` call, so production behavior always reflects the real Custom
 Permission assignment.

### `RecordHealthCheckLogger`

**Role:** Single logging destination for the Framework.
**Type:** Shared service · `public with sharing`

Every Framework log line goes through this class as structured `[RHC]` output with run id and
running user. Levels: `ERROR`, `WARN`, `INFO`, `DEBUG`. ERROR lines are also held as
`Record_Health_Check_Log__e` and published by `flush()` at the transaction boundary (default on,
opt-out per Check Set through `PublishErrorLogEvent__c`, and subscriber-context guarded). Entry
points call `flush()` so ERROR platform events are not lost when
`System.debug` is off.

**Key members:**

| Member | Purpose |
| --- | --- |
| `normalizeIdentifier(...)` | Length-limited API names used in logs and lookups |
| `flush()` | Publish held `ERROR` events at the transaction boundary |
| `enterSubscriberContext()` | Loop guard for subscriber-context log handling |

**Notable behavior:**
- **Gotcha:** `captureErrorEvent` deliberately never carries field values (actual/expected) into the
 `Record_Health_Check_Log__e` event - only identifying context (run id, Check Set/Rule
 names, record id, exception type/message/stack) - because those raw values belong to Debug Mode's
 admin detail channel, not a platform event any subscriber with object access could read.
 `enterSubscriberContext()` is a one-way loop guard a subscriber processing this same event must
 call first, so an error raised while handling a log event cannot republish onto the same event bus.

**See also:** [Log event metadata](../../metadata/event-log.md)

---

## Related

- [Apex class reference](README.md)
- [Architecture](../framework/architecture.md)
