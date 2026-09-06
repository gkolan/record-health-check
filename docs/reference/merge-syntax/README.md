# Merge syntax

This page lists the tokens available in Check configuration.

> [!NOTE]
> Use this page to insert Salesforce record, Check, Check Set, result, or run values into messages,
> Action Labels, Action URLs, and SOQL. It explains the exact token names, when to provide a fallback,
> and what happens when a token is invalid or empty.
>
> **Reference**
>
> - Use the tables on this page as the complete list of supported token names and locations.
> - For field-level Setup examples, use the [Check field reference](../custom-metadata/check-fields.md).
>   For Action URL patterns, use [Configure action links](../../build-checks/add-fix-link.md).

A merge token is a placeholder in a failure message, Fix Message, Action Label, Action URL, Found
or Expected display text, or SOQL template. When the Check runs, Record Health Check replaces the
placeholder with a live value from the current record, Check, Check Set, result, or run.

Every merge token has two parts separated by a period:

```text
{!record.Name}
```

| Part | Meaning |
| --- | --- |
| Namespace | The first part, which says where the value comes from: `record`, `rhcCheck`, `rhcSet`, `rhcResult`, or `rhcRun` |
| Property | Which field or metadata value to insert, such as `Name` or `checkTitle` |

Record-field tokens can also contain quoted `format` and `fallback` settings:

```text
{!record.Amount format="CURRENCY" fallback="Not available"}
```

Format values are official, case-sensitive API names: `CURRENCY` is valid; `currency` and the
Setup label `Currency` are not. Supported names are `AUTO`, `NUMBER`, `CURRENCY`, `PERCENT`,
`RATIO_PERCENT`, `BOOLEAN`, `DATE`, `DATETIME`, `TEXT`, and `RAW`. `format` is allowed only on tokens that name a Salesforce field, which is `record.*` and
`rhcQuery.*` row fields, because only there does Salesforce still know the field's data type. Result tokens already
contain completed display text and cannot be formatted again. The two settings may appear in either
order. Their names are lowercase, their values must use double quotes, and repeated, unknown, or
unquoted settings are configuration errors.

Use a fallback when the value might be blank and empty wording would confuse the reader. A bare
token is enough when no substitute is needed or the value is always present, such as
`{!record.Id}`.

For example:

```text
Review {!record.Name fallback="this record"} before approval.
```

| Live `Name` | Completed text |
| --- | --- |
| `Acme` | `Review Acme before approval.` |
| blank | `Review this record before approval.` |

The same token without a fallback (`{!record.Name}`) still becomes `Acme` when Name has a value.
When Name is blank, it inserts nothing, so the sentence reads `Review  before approval.`

### Examples by value source

Most messages and queries use the current record:

```text
{!record.Name}
{!record.Owner.Name}
{!record.BillingCountry}
```

After the Check finishes, use result and run values in the completed message:

```text
{!rhcResult.foundValue}
{!rhcResult.expectedValue}
{!rhcRun.runId}
```

Use Check and Check Set tokens when the message should name the check or card:

```text
{!rhcCheck.checkTitle}
{!rhcSet.cardTitle}
```

An unknown first part or property is a configuration error. Every token must include one of the
documented value sources; `{!Id}` is therefore rejected. <!-- rejected-token-fixture -->

Empty tokens behave differently in display text (including Action Label), Action URLs, and SOQL. See
[Fallbacks](#fallbacks).

## Where merge tokens can be used

| Location | Where it appears | Allowed value sources |
| --- | --- | --- |
| Display text | **Message When Failed**, **Message When Unable To Evaluate**, **Message When Not Applicable**, **Fix Message**, **Action Label** (80 saved characters; defaults to `Fix this` when blank and Action URL is valid), **Display: Found Text**, and **Display: Expected Text** | `record`, `rhcCheck`, `rhcSet`, `rhcResult`, and `rhcRun` when that value is available at that point in the run. `rhcQuery` everywhere except **Message When Not Applicable**, where the Check's queries never ran |
| Action URL | **Action URL** on a Check | `record`, `rhcCheck`, `rhcSet`, `rhcRun`, `rhcQuery` (result tokens are not allowed); each inserted value is URL-encoded before the URL safety check |
| SOQL | Source Query, Comparison Query, and applicability count queries | `record` only |

## Value sources and properties

| First part | Value source | Allowed property after the period |
| --- | --- | --- |
| `record` | Current Salesforce record | Any readable field API path, such as `Name`, `AnnualRevenue`, or `Owner.Name` |
| `rhcCheck` | Current Check metadata | `developerName`, `masterLabel`, `checkTitle`, `checkDescription`, `category`, `evaluationType`, `failureSeverity`, `evaluationOrder` |
| `rhcSet` | Current Check Set metadata | `developerName`, `masterLabel`, `cardTitle`, `cardSubtitle`, `objectApiName` |
| `rhcResult` | Completed Check result; available after the Evaluation Type finishes | `status`, `foundValue`, `foundValuePluralSuffix`, `expectedValue`, `failedRecordCount`, `totalRecordCount`, `reasonCode` |
| `rhcRun` | Current run context | `runId`, `source`, `startedAt`, `completedAt`, `durationMs` |
| `rhcQuery` | Rows this Check's own queries returned; Query and Compare Two Queries Checks only | `sourceRows[n].Field`, `comparisonRows[n].Field`, `sourceRowCount`, `comparisonRowCount` |

`foundValuePluralSuffix` exists so a multi-row summary can render "1 Contact" versus "2 Contacts"
without a separate conditional.

## Query row values

A Query or Compare Two Queries Check can read the rows its own query returned:

```text
{!rhcQuery.sourceRows[1].Name}
{!rhcQuery.sourceRows[2].Email}
{!rhcQuery.sourceRows[1].Account.Name}
{!rhcQuery.sourceRowCount}
{!rhcQuery.comparisonRows[1].Id}
{!rhcQuery.comparisonRowCount}
```

Row numbers start at 1 and count the rows the query returned.

### Reaching a related record

To show something about a related record, **query that object**, not its parent. `sourceRows` is
whatever the Check's own query returned, so querying Contact makes the contacts the rows:

```text
Source Query:  SELECT Id, LastName, Email, Account.Name FROM Contact
               WHERE AccountId = {!record.Id} ORDER BY Id
Message:       Second contact is {!rhcQuery.sourceRows[2].Email fallback="not listed"}
```

A subquery on the parent, such as `SELECT Id, (SELECT Email FROM Contacts) FROM Account`, does not
work and is refused when a row token is used with it.

### What a Check must satisfy

Setup reports each of these when the Check is saved or audited, so a row token either works or is
explained.

| Requirement | Why |
| --- | --- |
| The Check runs a query | Formula and Apex Checks have no rows |
| The field is in the `SELECT` list | Selecting `Id` does not authorize `Name`, and selecting `Owner.Name` does not authorize `Owner.Email` |
| The query has an `ORDER BY` naming `Id` | Row 2 only means something if the query returns rows in the same order every time |
| The row number is within reach | It cannot exceed the query's own `LIMIT`, the Check's Max Query Rows, or the single row a One Result Check returns |
| A `comparisonRows` token has a Comparison Query | Otherwise the Check produces no comparison rows |
| A currency-formatted amount has its currency | In a multi-currency org, select `CurrencyIsoCode` beside the amount |

Two shapes need less. An ungrouped aggregate such as `SELECT COUNT(Id) total FROM Contact` returns
exactly one row, so it needs no `ORDER BY` and row 1 is always addressable. A row count reads no
column and no order, so it needs neither.

`SELECT COUNT()` is the exception in the other direction: it returns one row holding the total, so
`sourceRowCount` there would always be 1. Use `{!rhcResult.foundValue}` for the number counted, or
alias the aggregate as `SELECT COUNT(Id) total` and read `{!rhcQuery.sourceRows[1].total}`.

### When the value is not there

A row the query never returned, and a selected field that is null, are both empty and use the
fallback. In an Action URL an empty value with no fallback removes the link rather than building a
broken one. Values are always inserted as text: a row value cannot add a parameter or a path
segment to a URL, and never becomes a link inside a message.

### What it costs

A query that only needs `ORDER BY Id` keeps working in list views and batch runs. Ordering by
anything else, or using `LIMIT` above 1, means the Check runs one record at a time; Setup reports
that separately on the Check.

The raw query rows and unused columns stay transient on the server and are never serialized on the
result or published in an event. A field selected by a token is intentionally copied into the
completed message, label, or URL, so that rendered text follows its normal output surface: it can
reach the browser or API caller and, when diagnostics are enabled, diagnostic logs. Treat every row
field referenced by a token as user-visible and choose fields appropriate for the result's audience.
No token causes an extra query.

## Four names for Found, and which one you are reading

The same English idea appears under different names depending on which surface you are looking at.
They are not interchangeable, and the differences are the whole reason a Check can look right and
report something else.

| Name | Where it appears | What it holds |
| --- | --- | --- |
| `found` / `expected` | The evaluation result a Flow, Apex, or REST caller receives | The **operand**: the value compared, with no comparison wording. Empty when the operator compares against nothing, such as Is Not Blank |
| `comparisonOperator` | The same evaluation result | The operator, in its own field, so it is never mixed into the value |
| `{!rhcResult.foundValue}` / `{!rhcResult.expectedValue}` | Merge tokens in messages, labels, and display text | What the framework computed, rendered for a reader. Unaffected by Display: Found Text |
| `foundDisplayValue` / `expectedDisplayValue` | The display half of a result, and the card | Exactly what the card reads, including Display: Found Text and the comparison wording |

So for a Check comparing Industry to `Manufacturing`:

```text
evaluation.found              Technology
evaluation.expected           Manufacturing
evaluation.comparisonOperator EQUALS
card / expectedDisplayValue   to equal Manufacturing
```

If you are building an automation, read `found`, `expected`, and `comparisonOperator`. If you are
writing a message, use the merge tokens. The card's wording is never the value.

## Display: Found Text and Display: Expected Text

These two fields change **what the card reads**. They do not change what the Check found.

```text
Check found:             003AB000001XyZaQAK
Display: Found Text      An IPS breakdown is available

Card shows:              An IPS breakdown is available
{!rhcResult.foundValue}  003AB000001XyZaQAK
Flow, Apex, saved
results, events          003AB000001XyZaQAK
```

So a Check whose Found value is a record Id still reports that Id everywhere a value is asked for,
while the card reads the sentence you wrote. Wording is presentation; it never becomes the answer
the Check gives.

Inside the two templates, `{!rhcResult.foundValue}` and `{!rhcResult.expectedValue}` read the values
the framework computed. Each template can quote the original, and the Expected template never sees
the Found template's replacement, so the two cannot chain into one another:

```text
Framework computed:      Found 3, Expected 0
Display: Found Text      {!rhcResult.foundValue} contacts without email
Display: Expected Text   none; Found was {!rhcResult.foundValue}

Card shows:  Found    "3 contacts without email"
             Expected "none; Found was 3"
```

Setting Display: Expected Text also clears the framework's own caption for that value, because the
caption described the value that is no longer displayed.

Display: Found Text and Display: Expected Text are ignored on Apex Checks, which supply their own
values; Setup reports that as `APEX_DISPLAY_TEXT_IGNORED`.

## Fallbacks

What happens when a token's Salesforce value is empty depends on where the token is used:

| Location | Empty token without a fallback | Empty token with a fallback |
| --- | --- | --- |
| Display text | Inserts blank text | Inserts the fallback text |
| Action URL | Suppresses the link (`MISSING_TOKEN_VALUE`) | Uses the fallback text in the URL |
| SOQL | Uses an empty query value; a value that cannot be converted to the field's data type can return `MISSING_BIND_VALUE` | Converts the fallback to the field's data type and uses it in the query |

Use a fallback when an empty value would produce unclear wording or an unsafe SOQL value. These fields are
often blank, so a substitute helps:

```text
{!record.Parent.Name fallback="Independent account"}
{!record.Owner.Manager.Name fallback="No manager assigned"}
```

In SOQL, use a fallback only when the record field can be empty and an empty query value would be
wrong:

```text
{!record.AnnualRevenue fallback="0"}
{!record.Industry fallback="Technology"}
```

When a Check evaluates a record, `{!record.Id}` already has a value, so SOQL and Action URLs use
the bare token:

```sql
SELECT COUNT() FROM Contact WHERE AccountId = {!record.Id}
```

```text
/lightning/r/Account/{!record.Id}/view
```

Optional parent lookups can be blank, so a typed Id fallback is useful there:

```sql
SELECT AnnualRevenue FROM Account WHERE Id = {!record.ParentId fallback="001000000000000AAA"}
```

Fallback text is literal. It is not parsed as another merge token. A pipe inside the quoted
fallback is ordinary text. Invalid number, date, date/time, time, or Boolean
fallbacks in SOQL return `MISSING_BIND_VALUE` instead of running a misleading query.

## Tokens in SOQL

- Only `record.*` tokens are valid in SOQL templates.
- Strings are quoted and escaped automatically; numbers, dates, and Booleans are unquoted.
- A multi-select picklist token expands differently when quoted versus unquoted: quoted keeps
  `'A;B;C'`, unquoted expands to an `INCLUDES (...)` list.
- The same field may appear both quoted and unquoted in one template; each form is substituted
  independently.
- The running user must be able to read every token field, or the Check returns
  `UNABLE_TO_EVALUATE`.

## Related Reason Codes

| Reason code | Typical cause |
| --- | --- |
| `TOKEN_NAMESPACE_REQUIRED` | Token such as `{!Id}` omits the required first part <!-- rejected-token-fixture --> |
| `UNSUPPORTED_TOKEN_NAMESPACE` | First part is not on the allowed list |
| `MISSING_TOKEN_VALUE` | URL token resolved blank with no fallback |
| `MISSING_BIND_VALUE` | SOQL fallback could not be converted to the Salesforce field's data type |
| `TOKEN_LIMIT_EXCEEDED` | More than 100 tokens in one template |
| `RESOLVED_TEMPLATE_TOO_LONG` | Resolved text exceeded 20,000 characters |
| `TOKEN_NOT_AVAILABLE_IN_PHASE` | `rhcResult` is used before the Check finishes, or a record field path follows more than five parent relationships |

When **Action URL** resolves to more than 2,000 characters, the link is suppressed and Fix Message
can still render. URL scheme and path checks live in
[Configure action links](../../build-checks/add-fix-link.md#allowed-url-formats).

Full outcome list lives in [Reason Codes](../results/reason-codes.md).

## Related

- [Configure Check Sets and Checks: Merge tokens](../../build-checks/configure-check-sets-and-checks.md#step-13-learn-the-merge-token-options)
- [Configure action links](../../build-checks/add-fix-link.md)
- [Check fields](../custom-metadata/check-fields.md)
- [Query reference](../evaluation/query.md)
- [Field limits](../configuration/field-limits.md)
- [Reason Codes](../results/reason-codes.md)
