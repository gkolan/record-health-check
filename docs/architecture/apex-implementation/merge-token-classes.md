# Apex classes that resolve merge tokens (L2)

> [!IMPORTANT]
> **Audience: package contributors and Salesforce developers.** This class-level reference is not a
> Setup or Flow walkthrough. Administrators should use the Flow, configuration, and evaluation
> guides; subscriber developers should use the public Apex API or Apex Check contract.

> [!NOTE]
> Use this page to understand the internal classes that read, validate, and replace merge tokens.
> For the token names and syntax an administrator can use, see
> [Merge tokens](../../reference/merge-syntax/README.md).

This page is part of the [Apex class reference](./README.md).

## Merge-token classes (L2)

### `RecordHealthCheckTemplateService`

**Role:** Validate merge tokens and replace them with Salesforce values.

**Type:** Shared service · `public` (no sharing keyword)

Handles tokens such as `{!record.Name}` in messages, URLs, and SOQL. A token can include quoted
settings, as in `{!record.Amount format="CURRENCY" fallback="Not available"}`. One template can
contain up to 100 tokens, and the completed text can contain up to 20,000 characters. An unknown
token name, property, or setting returns a `RecordHealthCheckTokenIssue` instead of partially
replacing the template.

**Key members:**

| Member | Purpose |
| --- | --- |
| `SURFACE_DISPLAY`, `SURFACE_URL`, `SURFACE_SOQL` | Identify whether the completed text is a message, URL, or SOQL query |
| `resolveFieldPath(...)` | Read the value of a `record.*` field path |
| `applyFoundExpectedText(...)` | Add the administrator's Found Value and Expected Value wording after a Check finishes |

**Important behavior:**

- **Related fields:** a `record.*` token can follow no more than five Salesforce relationships. A
  deeper path returns `TOKEN_NOT_AVAILABLE_IN_PHASE`.
- **URLs:** when a token used in a URL is empty, the token must have a `fallback` value. Otherwise,
  the class returns `MISSING_TOKEN_VALUE` instead of creating a broken or unintended link.
- **Result values:** `rhcResult.*` tokens become available only after the Check has produced its final
  result. Found and Expected values are not reliable before that point. A true Apex `null` resolves
  blank and may activate a fallback; the populated text value `"null"` remains literal text.

**See also:** [Merge tokens](../../reference/merge-syntax/README.md)

### `RecordHealthCheckTokenRegistry`

**Role:** Store the allowed first part and property names for merge tokens.

**Type:** Constants holder · `public` (no sharing keyword)

The first part identifies the source, such as `record` in `{!record.Name}` or `rhcResult` in
`{!rhcResult.status}`. A record token can use a nonblank field path. The other sources have fixed
property lists.

**Key members:**

| Member | Purpose |
| --- | --- |
| `record`, `rhcCheck`, `rhcSet`, `rhcResult`, `rhcRun`, `rhcQuery` | The allowed first parts of a token |
| `RESULT_PROPERTIES` | Allowed properties after `rhcResult.` |
| `QUERY_COUNT_PROPERTIES` | The two row-count properties after `rhcQuery.` |
| `MAX_ROW_INDEX` | The highest row position a token may address |
| `resolve(namespace, property)` | Turns the two parts into a `RecordHealthCheckTokenShape` |

For example, `foundValuePluralSuffix` lets a message display **1 Contact** or **2 Contacts** without
requiring an administrator to write conditional logic.

`resolve` replaced a yes-or-no membership test once `rhcQuery.sourceRows[0].Name` introduced a
property with three parts. Callers read the resolved shape rather than reading the property string
again.

### `RecordHealthCheckToken`

**Role:** Store the parts of one merge token after it has been read.

**Type:** Data holder · `public` (no sharing keyword)

**Key members:**

| Member | Purpose |
| --- | --- |
| `expression` | Complete token text, including `{!` and `}` |
| `namespaceName` | First part, such as `record` or `rhcCheck` |
| `propertyPath` | Property or Salesforce field path after the first part |
| `formatName` | Optional uppercase Value Format API name from `format="..."` |
| `fallbackValue` | Optional text from `fallback="..."`; `null` when omitted |
| `attributeError` | Error for an unknown, repeated, unquoted, or otherwise invalid setting |
| `startIndex` / `endIndex` | Token's location in the complete template |

A shorter constructor omits `fallbackValue` and leaves it `null` for package code that does not need
a fallback.

### `RecordHealthCheckTokenIssue`

**Role:** Describe one invalid merge token.

**Type:** Data holder · `public` (no sharing keyword)

The constructor accepts a Reason Code, the invalid token, and a message. For example:

```apex
new RecordHealthCheckTokenIssue(
  'UNSUPPORTED_TOKEN_NAMESPACE',
  '{!foo.bar}', // rejected-token-fixture
  'Unsupported token namespace "foo".'
);
```

### `RecordHealthCheckMergeContext`

**Role:** Supply the Salesforce values that merge tokens can use.

**Type:** Chainable data holder · `public` (no sharing keyword)

The `withRecord`, `withCheck`, `withResult`, and `withRun` methods supply the record, Check, parent
Check Set, result, and run details used to replace tokens. The class can also supply failed and total
record counts for messages that need singular or plural wording.

**Key members:**

| Member | Purpose |
| --- | --- |
| `withRecord(...)` | Supply the Salesforce record for `record.*` tokens |
| `withCheck(...)` | Supply the Check and its parent Check Set for `rhcCheck.*` and `rhcSet.*` tokens |
| `withResult(value, finalized)` | Supply the result; `rhcResult.*` is available only when `finalized` is `true` |
| `withRun(...)` | Supply the run details for `rhcRun.*` tokens |

**Important behavior:**

- **Check Set tokens:** `withCheck` reads the parent Check Set from the
  `Record_Health_Check_Set__r` relationship on the supplied Check record. Internal package code must
  include that relationship in its Check query or `rhcSet.*` tokens have no value.
- **Result tokens:** `withResult(value, true)` marks the result as complete and makes `rhcResult.*`
  tokens available. They are unavailable by default.
- **Token settings:** raw `record.*` tokens can contain `format="API_NAME"` and `fallback="text"` in
  either order. Values must use double quotes. Unknown, repeated, or unquoted settings produce a
  token issue. Result tokens cannot use `format` because they already contain display text.

---

### `RecordHealthCheckTokenShape`

**Role:** Store what one merge token turned out to address, resolved once.

**Type:** Data holder · `public` (no sharing keyword)

A query row token carries three parts, and several consumers need all of them. Parsing the
property string separately in each consumer is how they drift apart, so the registry parses it once
into this shape and every consumer downstream reads typed fields.

**Key members:**

| Member | Purpose |
| --- | --- |
| `kind` | `KIND_PROPERTY` for a named value, or one of the two query row kinds |
| `collection` | `sourceRows` or `comparisonRows` for a query token |
| `rowIndex` | The zero-based row index a query token addresses |
| `fieldPath` | The terminal field or relationship path the token reads |
| `isTypedField` | Whether Salesforce still knows the value's data type, which is what `format` needs |
| `reasonCode`, `message` | Why the token is unusable, and the change that fixes it |

An unusable token is described rather than thrown, so the caller decides whether it is an authoring
finding or a runtime configuration error.

### `RecordHealthCheckTokenSurfaces`

**Role:** Declare which merge tokens each configuration field accepts.

**Type:** Constants holder · `public` (no sharing keyword)

These rules used to be a chain of comparisons inside the validator, so every new namespace added a
branch and every rule was written wherever it happened to be needed. They are a small table
instead. The broad surfaces existing callers pass are still named on
`RecordHealthCheckTemplateService` as `SURFACE_SOQL`, `SURFACE_DISPLAY`, and `SURFACE_URL`, and
appear here as rows; the named surfaces describe one configuration field each, which is what lets a
query row token be accepted in the failure message and refused in the not-applicable message.

**Key members:**

| Member | Purpose |
| --- | --- |
| `FAILURE_MESSAGE`, `UNABLE_MESSAGE`, `NOT_APPLICABLE_MESSAGE`, `FIX_MESSAGE` | One surface per message field |
| `ACTION_LABEL`, `ACTION_URL` | The two action fields |
| `DISPLAY_FOUND`, `DISPLAY_EXPECTED` | The two Found/Expected text fields |
| `allows(surface, namespace)` | Whether that field accepts tokens from that namespace |
| `allowsFormat(surface)` | Whether a `format` attribute means anything on that field |

### `RecordHealthCheckQueryProjection`

**Role:** Describe what a Check's SOQL actually returns, in one place.

**Type:** Analyzer · `public with sharing`

`RecordHealthCheckQueryTokenRules` reads it to decide whether a query row token addresses something
the query actually returns. That consumer carries a security obligation, because a row addressed by
position must be the row the executor returns, so the `SELECT` list is split here once rather than
by each caller's own pattern.

The analysis fails closed. Anything this class cannot resolve into named, addressable columns
leaves `isFullyAnalyzable` false, and a caller that must prove a field was selected refuses rather
than assuming.

**Key members:**

| Member | Purpose |
| --- | --- |
| `selectedPaths`, `aliases` | Every name the query projects, in source order |
| `orderPaths` | The depth-zero `ORDER BY` field paths. Direction and null handling are not kept: only the fields an order names decide whether it can tie |
| `isFullyAnalyzable` | False forbids any conclusion about what the query did not select |
| `hasStableRowOrder()` | Whether repeating the query returns rows in the same order every time |
| `projects(name)` | Whether the query projects an addressable column under that name |
| `addressableNames()` | Every name a merge token may read on a row of this query |

`hasStableRowOrder()` requires an `ORDER BY` that names `Id`. Salesforce promises no order without
`ORDER BY`, and no order between rows that tie on every named key; `Id` is unique, so no two rows
can tie once it takes part.

### `RecordHealthCheckIgnoredConfig`

**Role:** Warn about Check configuration the Framework will never read.

**Type:** Validator · `public with sharing`

Every other validator asks whether a Check is missing something it needs. This one asks the
opposite question, which is the one administrators actually hit: a Custom Metadata Type shows all
of its fields to every record, so a Formula Check offers a Source Query and an Apex Check offers a
Comparison Operator, and filling either in does nothing. Nothing fails and nothing is reported, and
the Check quietly does not behave the way its configuration reads.

Every issue it returns is a `WARNING` with the reason code `CONFIGURATION_IGNORED`. Ignored
configuration is confusing rather than invalid, and a half-finished Check an administrator is still
editing must keep deploying.

Display: Found Text and Display: Expected Text on an Apex Check are the one case already covered
elsewhere, as `APEX_DISPLAY_TEXT_IGNORED`.


### `RecordHealthCheckQueryTokenRules`

**Role:** Everything a `{!rhcQuery...}` token must satisfy before a Check can run.

**Type:** Validator · `public with sharing`

These rules sit apart from the rest of configuration validation because they all answer one
question the other rules never ask: does this token address something the Check's own query can
actually produce? Each exists because the alternative was a Check that validated cleanly and then
rendered a sentence with a hole in it, or worse, a plausible wrong number.

**Refusals:**

| Reason code | Refused when |
| --- | --- |
| `TOKEN_NOT_ALLOWED_ON_SURFACE` | The Check is Formula or Apex, so it runs no query |
| `QUERY_ROLE_NOT_AVAILABLE` | A `comparisonRows` token with no Comparison Query, or a row count against a query that counts rather than returns |
| `QUERY_FIELD_NOT_SELECTED` | The `SELECT` omits the field; the message lists what it does select |
| `QUERY_ORDER_NOT_DETERMINISTIC` | No `ORDER BY` naming `Id`. Grouped queries get a message that does not suggest one, because SOQL would reject it |
| `QUERY_PROJECTION_NOT_ANALYZABLE` | The `SELECT` list cannot be fully read, so nothing can be proven about what it omitted |
| `TOKEN_ROW_INDEX_INVALID` | The index exceeds the query's own `LIMIT`, the Check's Max Query Rows, or the single row a One Result Check or ungrouped aggregate can return |
| `FIELD_TYPE_NOT_SUPPORTED` | The field is Classic encrypted |
| `FIXED_CURRENCY_BASIS_MISSING` | A currency-rendered row amount in a multi-currency org whose query did not select the matching `CurrencyIsoCode` |

Two exemptions are deliberate and each prevents advice SOQL would reject. An ungrouped aggregate
returns exactly one row, so it needs no `ORDER BY`, and Salesforce refuses a bare `CurrencyIsoCode`
beside it, so it is not asked for one. A row count reads no column and no order, so it needs
neither a readable projection nor a stable order.

## Related

- [Apex class reference](./README.md)
- [Merge tokens](../../reference/merge-syntax/README.md)
