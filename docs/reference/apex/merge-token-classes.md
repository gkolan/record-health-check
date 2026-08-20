# Apex classes that resolve merge tokens (L2)

> [!IMPORTANT]
> **Audience: package maintainers and Salesforce developers.** This class-level reference is not a
> Setup or Flow walkthrough. Administrators should use the Flow, configuration, and evaluation
> guides; subscriber developers should use the public Apex API or Apex Check contract.

> [!NOTE]
> Use this page to understand the internal classes that read, validate, and replace merge tokens.
> For the token names and syntax an administrator can use, see
> [Merge tokens](../contracts/merge-tokens.md).

This page is part of the [Apex class reference](README.md).

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

**See also:** [Merge tokens](../contracts/merge-tokens.md)

### `RecordHealthCheckTokenRegistry`

**Role:** Store the allowed first part and property names for merge tokens.

**Type:** Constants holder · `public` (no sharing keyword)

The first part identifies the source, such as `record` in `{!record.Name}` or `rhcResult` in
`{!rhcResult.status}`. A record token can use a nonblank field path. The other sources have fixed
property lists.

**Key members:**

| Member | Purpose |
| --- | --- |
| `record`, `rhcCheck`, `rhcSet`, `rhcResult`, `rhcRun` | The five allowed first parts of a token |
| `RESULT_PROPERTIES` | Allowed properties after `rhcResult.` |

For example, `foundValuePluralSuffix` lets a message display **1 Contact** or **2 Contacts** without
requiring an administrator to write conditional logic.

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

## Related

- [Apex class reference](README.md)
- [Merge tokens](../contracts/merge-tokens.md)
