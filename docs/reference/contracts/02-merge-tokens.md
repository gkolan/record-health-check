# Reference: Merge tokens

> [!NOTE]
> On this page, learn the namespaced merge-token syntax Record Health Check uses in display text
> (including Action Label), Action URLs, and administrator-authored SOQL, including which namespaces
> are available, when a fallback helps, and which Reason Codes apply.
>
> **Reference**
>
> - This page is the source of truth for merge-token behavior; configuration guides and examples
>   link here rather than restating the full contract.
> - For field-level Setup examples, use the [Rule field reference](../../metadata/02-fields-check-rule.md).
>   For Action URL patterns, use [Configure action links](../../guides/04-configure-action-links.md).

A merge token is a placeholder in a failure message, Fix Message, Action Label, Action URL, Found
or Expected display text, or SOQL template. When the Rule runs, Record Health Check replaces the
placeholder with a live value from the current record, Rule, Check Set, result, or run.

Merge tokens use a namespace and property:

```text
{!record.Name}
```

| Part | Meaning |
| --- | --- |
| Namespace | Where the value comes from: `record`, `rhcRule`, `rhcSet`, `rhcResult`, or `rhcRun` |
| Property | Which field or metadata value to insert, such as `Name` or `checkTitle` |

Raw record-field tokens also support quoted `format` and `fallback` attributes:

```text
{!record.Amount format="CURRENCY" fallback="Not available"}
```

Format values are official, case-sensitive API names: `CURRENCY` is valid; `currency` and the
Setup label `Currency` are not. Supported names are `AUTO`, `NUMBER`, `CURRENCY`, `PERCENT`,
`RATIO_PERCENT`, `BOOLEAN`, `DATE`, `DATETIME`, `TEXT`, and `RAW`. `format` is allowed only on
`record.*` tokens because those tokens retain a raw typed value. Result tokens already contain
completed display text and cannot be formatted again. Attributes may appear in either order;
attribute names are lower-case, values must be double-quoted, and duplicate or unknown attributes
are configuration errors. Attribute values must use the quoted syntax shown above.

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

### Examples by namespace

Most messages and queries use the current record:

```text
{!record.Name}
{!record.Owner.Name}
{!record.BillingCountry}
```

After the Rule finishes, use result and run values in the completed message:

```text
{!rhcResult.foundValue}
{!rhcResult.expectedValue}
{!rhcRun.runId}
```

Use Rule and Check Set tokens when the message should name the check or card:

```text
{!rhcRule.checkTitle}
{!rhcSet.cardTitle}
```

Unknown namespaces and properties are configuration errors. Every token must include one of the
documented namespaces; `{!Id}` is therefore rejected. <!-- rejected-token-fixture -->

Blank tokens behave differently in display text (including Action Label), Action URLs, and SOQL. See
[Fallbacks](#fallbacks).

## Surfaces

| Surface | Where it appears | Allowed namespaces |
| --- | --- | --- |
| Display text | **Message When Failed**, **Message When Unable To Evaluate**, **Message When Not Applicable**, **Fix Message**, **Action Label** (80 characters; defaults to `Fix this` when blank and Action URL is valid), **Display: Found Text**, and **Display: Expected Text** | `record`, `rhcRule`, `rhcSet`, `rhcResult`, `rhcRun` when that data exists in the current phase |
| Action URL | **Action URL** on a Rule | `record`, `rhcRule`, `rhcSet`, `rhcRun` (result tokens are not allowed); each inserted value is URL-encoded before the URL safety check |
| SOQL | Source Query, Comparison Query, and applicability count queries | `record` only |

## Namespaces and properties

| Namespace | Source | Properties |
| --- | --- | --- |
| `record` | Current Salesforce record | Any readable field API path, such as `Name`, `AnnualRevenue`, or `Owner.Name` |
| `rhcRule` | Current Rule metadata | `developerName`, `masterLabel`, `checkTitle`, `checkDescription`, `category`, `evaluationType`, `failureSeverity`, `evaluationOrder` |
| `rhcSet` | Current Check Set metadata | `developerName`, `masterLabel`, `cardTitle`, `cardSubtitle`, `objectApiName` |
| `rhcResult` | Finalized Rule result; available after the evaluator finishes | `status`, `foundValue`, `foundValuePluralSuffix`, `expectedValue`, `failedRecordCount`, `totalRecordCount`, `reasonCode` |
| `rhcRun` | Current run context | `runId`, `source`, `startedAt`, `completedAt`, `durationMs` |

`foundValuePluralSuffix` exists so a multi-row summary can render "1 Contact" versus "2 Contacts"
without a separate conditional.

## Fallbacks

How a blank token behaves depends on the surface:

| Surface | Blank token, no fallback | Blank token with fallback |
| --- | --- | --- |
| Display text | Inserts blank text | Inserts the fallback text |
| Action URL | Suppresses the link (`MISSING_TOKEN_VALUE`) | Uses the fallback text in the URL |
| SOQL | Leaves a blank bind; an invalid typed bind may return `MISSING_BIND_VALUE` | Converts the fallback to the field's type and binds it |

Use a fallback when a blank value would produce unclear wording or an unsafe bind. These fields are
often blank, so a substitute helps:

```text
{!record.Parent.Name fallback="Independent account"}
{!record.Owner.Manager.Name fallback="No manager assigned"}
```

In SOQL, use a typed fallback only when the bound field can be blank and a blank bind would be
wrong:

```text
{!record.AnnualRevenue fallback="0"}
{!record.Industry fallback="Technology"}
```

When a Rule evaluates a record, `{!record.Id}` already has a value, so SOQL and Action URLs use
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
fallbacks in SOQL return `MISSING_BIND_VALUE` rather than running a misleading query.

## Tokens in SOQL

- Only `record.*` tokens are valid in SOQL templates.
- Strings are quoted and escaped automatically; numbers, dates, and Booleans are unquoted.
- A multi-select picklist token expands differently when quoted versus unquoted: quoted keeps
  `'A;B;C'`, unquoted expands to an `INCLUDES (...)` list.
- The same field may appear both quoted and unquoted in one template; each form is substituted
  independently.
- The running user must be able to read every token field, or the Rule returns
  `UNABLE_TO_EVALUATE`.

## Related Reason Codes

| Reason code | Typical cause |
| --- | --- |
| `TOKEN_NAMESPACE_REQUIRED` | Token such as `{!Id}` omits a required namespace <!-- rejected-token-fixture --> |
| `UNSUPPORTED_TOKEN_NAMESPACE` | Namespace is not on the allowed list |
| `MISSING_TOKEN_VALUE` | URL token resolved blank with no fallback |
| `MISSING_BIND_VALUE` | SOQL fallback could not be converted to the field type |
| `TOKEN_LIMIT_EXCEEDED` | More than 100 tokens in one template |
| `RESOLVED_TEMPLATE_TOO_LONG` | Resolved text exceeded 20,000 characters |
| `TOKEN_NOT_AVAILABLE_IN_PHASE` | `rhcResult` used before the evaluator finishes, or a record relationship path exceeds five parent lookups |

When **Action URL** resolves to more than 2,000 characters, the link is suppressed and Fix Message
can still render. URL scheme and path rules live in
[Configure action links](../../guides/04-configure-action-links.md#allowed-url-formats).

Full outcome list lives in [Reason Codes](01-reason-codes.md).

## Related

- [Configure Check Sets and Rules: Merge tokens](../../guides/03-configure-check-sets-and-rules.md#11-merge-tokens)
- [Configure action links](../../guides/04-configure-action-links.md)
- [Rule fields](../../metadata/02-fields-check-rule.md)
- [Query reference](../evaluation/02-query.md)
- [Field limits](04-field-limits.md)
- [Reason Codes](01-reason-codes.md)
