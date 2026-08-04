# Reference: Apex configuration and validation (L2)

> [!NOTE]
> On this page, look up the L2 classes that load Check Sets and Rules, validate configuration,
> and own Framework constants and reason-code helpers.

This page is part of the [Apex class reference](README.md).

## Configuration and validation (L2)

### `RecordHealthCheckConfigService`

**Role:** Load Check Sets/Rules and runtime validation adapter.
**Type:** Service class · `public with sharing`

Queries Check Set and Rule Custom Metadata, builds Lightning definition responses (including
truncation at `FRAMEWORK_MAX_CHECKS`), reports Check Set availability for an object, resolves a
Rule's parent Check Set, loads Rules for evaluation, and maps the first
`RecordHealthCheckRuleValidator` finding into an `UNABLE_TO_EVALUATE` / `INVALID_CONFIG` result.

**Key members:**

| Member | Purpose |
| --- | --- |
| `ConfigException` (nested) | Exception carrying `reasonCode` |
| `RC_*` | Reason-code string aliases used across load paths - the single source of truth callers compare against, rather than a literal (e.g. `RC_CONFIG_INACTIVE`, `RC_OBJECT_MISMATCH`, `RC_NO_ACTIVE_CHECKS`) |
| `findCheckSetDeveloperName(...)` | Resolve a Rule's parent Check Set |
| `getCheckSetAvailabilityForObject(...)` | Active/inactive Check Sets for an object |
| `getDefinitionResponse(...)` | Build the Lightning definition response |
| `validateRuleForEvaluation(...)` | Map the first validator finding to a result |
| `loadRule(...)` | Load a Rule for evaluation |
| `cachedRulePublicationSettings(...)` | Transaction-cached publication flags |

**Notable behavior:**
- **Gotcha:** `getDefinitionResponse` rejects a blank `CardTitle__c` with `INVALID_CONFIG`; it does
 not substitute Master Label or Developer Name for administrator-authored card text. When active
 Rules for a Check Set exceed `FRAMEWORK_MAX_CHECKS` (25), it logs a `WARN` server-side
 in addition to the truncation metadata the LWC shows as its "First 25 of N shown" badge, so the
 excess is visible in logs too, not only in the UI.

### `RecordHealthCheckRuleValidator`

**Role:** Shared Rule-field validation for every Evaluation Type.
**Type:** Shared validator · `public with sharing`

Returns ordered `Finding` values (`FindingCode` enum) once. Runtime (`ConfigService`) takes the first
finding; deploy-time (`MetadataValidator`) collects all findings. Keeps the decision logic in one
place so the two validators cannot disagree on *what* is invalid - only on how findings are mapped to
messages and field names.

**Notable behavior:**
- **Gotcha:** `MaxQueryRows__c` and `EmptyValueHandling__c` / `NoRowsResult__c` are deliberately
 *excluded* from `queryFindings`/`compareQueriesFindings` - callers run `maxRowsFindings` and
 `nullEmptyFindings` separately, since `ConfigService` applies them only to Query/CompareTwoQueries
 checks while `MetadataValidator` runs them once at the top level for every Evaluation Type; folding
 them into the per-type producers would double-count findings for the collect-all caller. Mutually
 exclusive conditions (operator, `QueryResultHandling__c`, comparison-value source) use `if`/`else
 if` chains for the same reason - so at most one `Finding` is returned per field even by the
 collect-everything path.

### `RecordHealthCheckMetadataValidator`

**Role:** Deploy-time / CI Custom Metadata audit.
**Type:** Service class · `public with sharing`

Validates all active Check Sets and Rules in the org and returns `ValidationIssue` rows (`ERROR` /
`WARNING`) with component name, field, message, and reason code. An empty list means the audit
passed. Use before promoting configuration between orgs.

**Key members:**

| Member | Purpose |
| --- | --- |
| `validate()` | Validate every active Check Set and Rule in the org |
| `validateRecords(...)` | Validate a supplied set of records |

**Notable behavior:**
- **Gotcha:** `validateRecords` treats a Check Set with more active Rules than
 `RecordHealthCheckConstants.FRAMEWORK_MAX_CHECKS` (25) as `WARNING`/`CHECK_LIMIT_EXCEEDED`, not
 `ERROR` - the excess Rules still deploy and are still valid, they simply will not run. It then
 checks whether any *included* Rule's `PrerequisiteRule__c` points outside that first-25 execution
 window and adds a second `WARNING`/`DEPENDENCY_NOT_IN_RUN` for each affected Rule. At runtime,
 Apex and the Lightning component skip a Rule whose Prerequisite Rule was not included.

### `RecordHealthCheckConfigValidator`

**Role:** Shared validation helpers.
**Type:** Shared helper · `public with sharing`

First template token issue, object API name checks, Apex plugin class validation / creation helpers
(`isValidApexPlugin`, `takeValidatedPlugin`), and JSON-object shape checks. Used by both runtime and
deploy-time paths.

**Notable behavior:**
- **Gotcha:** `isValidApexPlugin` creates an instance of the class while validating it, then caches
 that instance in `validatedPluginInstances` by class name; `takeValidatedPlugin` retrieves and
 removes it so `RecordHealthCheckApexEvaluator` can reuse the already-built plugin instead of
 calling `newInstance()` a second time. `isJsonObject` treats a blank string as valid (returns
 `true`) since `ApexParametersJson__c` is optional - only a non-blank value that fails to parse as a
 JSON object is rejected.

### `RecordHealthCheckConstants`

**Role:** Allowed values and numeric limits (single source of truth).
**Type:** Constants holder · `public with sharing`

Owns `FRAMEWORK_MAX_CHECKS` (25), `FRAMEWORK_MAX_ROWS` (2000), and Set accessors that return a copy
for display modes, trigger/reveal modes, Evaluation Types, operators, null/empty behaviors,
severities, applicability modes, and related allowed-value lists. Runtime and deploy-time validators
both read from here so they cannot get out of sync.

**Notable behavior:**
- **Why it exists:** runtime and metadata validation need one approved vocabulary. Every
 `public static Set<String>` accessor here returns a `new Set<String>(...)` copy,
 not the internal set itself, so a caller changing the returned set can never overwrite the
 Framework's official values. The class also owns the Apex-to-LWC value translation
 (`toLwcTriggerMode`, `toLwcSeverity`, `toLwcEvaluatorType`, etc.) that maps metadata API values
 (for example `CRITICAL`) to the card's presentation vocabulary (for example `Error`).

### `RecordHealthCheckReasonCodes`

**Role:** Selected stable reason-code helpers.
**Type:** Constants holder · `public` (no sharing keyword - data-only)

Declares commonly referenced codes (for example applicability and access) and marks which codes are
diagnostics-only (`isDiagnosticsOnly`). Full outcome list lives in
[Reference: Reason Codes](../contracts/reason-codes.md).

**Key members:**

| Member | Purpose |
| --- | --- |
| `isDiagnosticsOnly(reasonCode)` | Whether a reason code should be treated as diagnostics-only |

**Notable behavior:**
- **Example:** `DIAGNOSTICS_ONLY` contains exactly `FIELD_NOT_ACCESSIBLE` and
 `RECORD_NOT_ACCESSIBLE` - the two reason codes that reveal FLS/sharing details an unauthorized
 viewer should not see; `isDiagnosticsOnly(reasonCode)` simply checks whether the code is in that
 pair.

### `RecordHealthCheckSetAvailability`

**Role:** Check Set availability data for setup messaging.
**Type:** Data holder · `public` (no sharing keyword)

Used when the Lightning card has no Check Set selected.

**Key members:**

| Member | Purpose |
| --- | --- |
| `hasActive` | Whether the object has any active Check Sets |
| `hasInactive` | Whether the object has any inactive Check Sets |

**Notable behavior:**
- **Gotcha:** the no-arg constructor sets both `@AuraEnabled` booleans to `false`, so a caller that
 returns early before filling them in (for example `RecordHealthCheckController` on a `null`
 `recordId`) still returns a valid, non-null shape to the LWC.

---

## Related

- [Apex class reference](README.md)
- [Architecture](../framework/architecture.md)
