# Use merge tokens

> [!NOTE]
> Use this page to insert Salesforce record, Check, Check Set, result, or run values into messages,
> Action Labels, Action URLs, and SOQL. It explains the exact token names, when to provide a fallback,
> and what happens when a token is invalid or empty.
>
> **Reference**
>
> - Use the tables on this page as the complete list of supported token names and locations.
> - For field-level Setup examples, use the [Check field reference](../../metadata/fields-check.md).
>   For Action URL patterns, use [Configure action links](../../guides/configure-action-links.md).

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
`RATIO_PERCENT`, `BOOLEAN`, `DATE`, `DATETIME`, `TEXT`, and `RAW`. `format` is allowed only on
`record.*` tokens because Salesforce still knows those fields' data types. Result tokens already
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
| Display text | **Message When Failed**, **Message When Unable To Evaluate**, **Message When Not Applicable**, **Fix Message**, **Action Label** (80 saved characters; defaults to `Fix this` when blank and Action URL is valid), **Display: Found Text**, and **Display: Expected Text** | `record`, `rhcCheck`, `rhcSet`, `rhcResult`, and `rhcRun` when that value is available at that point in the run |
| Action URL | **Action URL** on a Check | `record`, `rhcCheck`, `rhcSet`, `rhcRun` (result tokens are not allowed); each inserted value is URL-encoded before the URL safety check |
| SOQL | Source Query, Comparison Query, and applicability count queries | `record` only |

## Value sources and properties

| First part | Value source | Allowed property after the period |
| --- | --- | --- |
| `record` | Current Salesforce record | Any readable field API path, such as `Name`, `AnnualRevenue`, or `Owner.Name` |
| `rhcCheck` | Current Check metadata | `developerName`, `masterLabel`, `checkTitle`, `checkDescription`, `category`, `evaluationType`, `failureSeverity`, `evaluationOrder` |
| `rhcSet` | Current Check Set metadata | `developerName`, `masterLabel`, `cardTitle`, `cardSubtitle`, `objectApiName` |
| `rhcResult` | Completed Check result; available after the Evaluation Type finishes | `status`, `foundValue`, `foundValuePluralSuffix`, `expectedValue`, `failedRecordCount`, `totalRecordCount`, `reasonCode` |
| `rhcRun` | Current run context | `runId`, `source`, `startedAt`, `completedAt`, `durationMs` |

`foundValuePluralSuffix` exists so a multi-row summary can render "1 Contact" versus "2 Contacts"
without a separate conditional.

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
[Configure action links](../../guides/configure-action-links.md#allowed-url-formats).

Full outcome list lives in [Reason Codes](reason-codes.md).

## Related

- [Configure Check Sets and Checks: Merge tokens](../../guides/configure-check-sets-and-checks.md#step-13-learn-the-merge-token-options)
- [Configure action links](../../guides/configure-action-links.md)
- [Check fields](../../metadata/fields-check.md)
- [Query reference](../evaluation/query.md)
- [Field limits](field-limits.md)
- [Reason Codes](reason-codes.md)
