# Reference: Apex merge-token classes (L2)

> [!NOTE]
> On this page, look up the L2 classes that parse, validate, and resolve namespaced merge
> tokens. For the administrator-facing token syntax contract, see
> [Merge tokens](../contracts/02-merge-tokens.md).

This page is part of the [Apex class reference](README.md).

## Merge tokens (L2)

### `RecordHealthCheckTemplateService`

**Role:** Parse, validate, and resolve merge tokens.
**Type:** Shared service · `public` (no sharing keyword)

Handles namespaced tokens such as `{!record.Name}`, with optional quoted attributes such as
`{!record.Amount format="CURRENCY" fallback="Not available"}`, for display messages, URLs, and SOQL
text.
Enforces max 100 tokens and 20,000 characters of resolved text. Unknown namespaces, unknown
properties, unsupported flat tokens, and stray braces become structured `RecordHealthCheckTokenIssue`s.

**Key members:**

| Member | Purpose |
| --- | --- |
| `SURFACE_DISPLAY`, `SURFACE_URL`, `SURFACE_SOQL` | The three contexts tokens can resolve for |
| `resolveFieldPath(...)` | Resolve a dotted `record.*` token to a field value |
| `applyFoundExpectedText(...)` | Apply administrator Found and Expected wording after evaluator values are formatted |

**Notable behavior:**
- **Important:** `resolveFieldPath` rejects a dotted record token whose relationship depth exceeds 5
 hops (`parts.size() > 6`) with `TOKEN_NOT_AVAILABLE_IN_PHASE`, so a runaway relationship chain in an
 admin-authored template fails immediately rather than describing arbitrarily deep schema. On
 `SURFACE_URL`, a token that resolves blank and has no `fallback` attribute throws `MISSING_TOKEN_VALUE`
 instead of silently substituting an empty string - a blank display value is harmless, but a blank
 URL segment could produce a broken or unintended link. `rhcResult` tokens can only be resolved once
 `context.resultFinalized` is true, since a result's Found/Expected values are not meaningful until
 the evaluator has finished.

**See also:** [Reference: Merge tokens](../contracts/02-merge-tokens.md)

### `RecordHealthCheckTokenRegistry`

**Role:** Allowed list of merge-token namespaces and properties.
**Type:** Constants holder · `public` (no sharing keyword)

Record properties are any non-blank field path; other namespaces use fixed property sets (Developer
Name, status, run id, and so on).

**Key members:**

| Member | Purpose |
| --- | --- |
| `record`, `rhcRule`, `rhcSet`, `rhcResult`, `rhcRun` | The five allowed token namespaces |
| `RESULT_PROPERTIES` | Fixed property set for the `rhcResult` namespace |

**Notable behavior:**
- **Example:** `RESULT_PROPERTIES` is exactly `{status, foundValue, foundValuePluralSuffix,
 expectedValue, failedRecordCount, totalRecordCount, reasonCode}` - `foundValuePluralSuffix` in
 particular exists so a multi-row summary message can render "1 Contact" vs "2 Contacts" without the
 admin hand-authoring a conditional.

### `RecordHealthCheckToken`

**Role:** One parsed merge token.
**Type:** Data holder · `public` (no sharing keyword)

**Key members:**

| Member | Purpose |
| --- | --- |
| `expression` | The full raw token text |
| `namespaceName` | The token's namespace (e.g. `record`, `rhcRule`) |
| `propertyPath` | The property or field path within that namespace |
| `formatName` | Optional official uppercase Display: Value Format API name |
| `fallbackValue` | Optional text from the quoted `fallback` attribute; `null` when omitted |
| `attributeError` | Parser error for unknown, duplicate, unquoted, or otherwise invalid attributes |
| `startIndex` / `endIndex` | Start and end position of the token within the template string |

**Notable behavior:**
- **Note:** a convenience constructor omits `fallbackValue` (defaults to `null`) for callers that
 only need the namespace/property/span.

### `RecordHealthCheckTokenIssue`

**Role:** One merge-token validation failure.
**Type:** Data holder · `public` (no sharing keyword)

**Key members:**

| Member | Purpose |
| --- | --- |
| `RecordHealthCheckTokenIssue(String reasonCode, String token, String message)` | Constructor, for example `('UNSUPPORTED_TOKEN_NAMESPACE', '{!foo.bar}', 'Unsupported token namespace "foo".')` <!-- rejected-token-fixture --> |

### `RecordHealthCheckMergeContext`

**Role:** Values available while resolving merge tokens.
**Type:** Chainable builder · `public` (no sharing keyword)

Chainable `withRecord` / `withRule` / `withResult` / `withRun` builders supply the record, Rule (and
parent Check Set), result, and run context used by token resolution. Also carries optional
failed/total record counts for plural-aware result tokens.

**Key members:**

| Member | Purpose |
| --- | --- |
| `withRecord(...)` | Supply the record for `record.*` tokens |
| `withRule(...)` | Supply the Rule (and derive its parent Check Set) for `rhcRule.*` / `rhcSet.*` tokens |
| `withResult(value, finalized)` | Supply the result for `rhcResult.*` tokens; only usable when `finalized` is true |
| `withRun(...)` | Supply the run context for `rhcRun.*` tokens |

**Notable behavior:**
- **Important:** `withRule` also derives `checkSet` by calling
 `value.getSObject('Record_Health_Check_Set__r')` on the passed-in Rule record - callers never set
 `checkSet` directly, so a Rule query that omits the `Record_Health_Check_Set__r` relationship will
 silently leave `rhcSet.*` tokens unresolved. `resultFinalized` defaults to `false` and is only
 ever set `true` through `withResult(value, finalized)`, which controls when `rhcResult.*` tokens
 become available.
- **Attributes:** raw `record.*` tokens may carry `format="API_NAME"` and `fallback="text"` in
 either order. Values must be double-quoted. Unknown, duplicate, or unquoted attributes produce a
 token issue; result tokens cannot be formatted again because they already contain display text.

---

## Related

- [Apex class reference](README.md)
- [Architecture](../framework/01-architecture.md)
