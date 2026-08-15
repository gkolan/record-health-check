# Internal configuration and validation classes (L2)

> [!NOTE]
> On this page, find the internal classes that load Check Sets and Checks, identify invalid
> configuration, and define the allowed values and limits used by the package.

This page is part of the [Apex class reference](README.md).

## Configuration and validation (L2)

### `RecordHealthCheckConfigService`

**Role:** Load Check Sets and Checks and convert configuration problems into health-check results.

**Type:** Service class · `public with sharing`

Queries Check Set and Check Custom Metadata, builds Lightning definition responses (including
limiting a run to `FRAMEWORK_MAX_CHECKS`), reports Check Set availability for a Salesforce object,
resolves a Check's parent Check Set, loads Checks for evaluation, and maps the first
`RecordHealthCheckValidator` finding into an `UNABLE_TO_EVALUATE` / `INVALID_CONFIG` result.

**Key members:**

| Member | Purpose |
| --- | --- |
| `ConfigException` (nested) | Exception carrying `reasonCode` |
| `RC_*` | Shared Reason Code constants, such as `RC_CONFIG_INACTIVE`, `RC_OBJECT_MISMATCH`, and `RC_NO_ACTIVE_CHECKS` |
| `findCheckSetDeveloperName(...)` | Resolve a Check's parent Check Set |
| `getCheckSetAvailabilityForObject(...)` | Active/inactive Check Sets for an object |
| `getDefinitionResponse(...)` | Build the Lightning definition response |
| `validateCheckForEvaluation(...)` | Map the first validator finding to a result |
| `loadCheck(...)` | Load a Check for evaluation |
| `cachedCheckPublicationSettings(...)` | Transaction-cached publication flags |

**Notable behavior:**

- `getDefinitionResponse` rejects a blank `CardTitle__c` with `INVALID_CONFIG`. It does not
  substitute Label or Developer Name for the card title an administrator must provide. When a
  Check Set has more than 25 active Checks, the class records a `WARN` entry and tells the Lightning
  card to show **First 25 of N shown**. Only the first 25 Checks run.
- `loadCheck` selects the complete evaluation contract plus presentation fields such as Category,
  including optional fields that are blank, so downstream consumers do not encounter an
  unqueried-field exception.

### `RecordHealthCheckValidator`

**Role:** Apply the same Check-field rules to every Evaluation Type.

**Type:** Shared validator · `public with sharing`

Returns ordered `Finding` values using the `FindingCode` enum. When a Check runs,
`RecordHealthCheckConfigService` uses the first finding to return one clear configuration result.
The metadata audit collects every finding so package maintainers can correct all configuration
problems together. Both paths therefore use the same validity rules.

**Notable behavior:**

- `MaxQueryRows__c`, `EmptyValueHandling__c`, and `NoRowsResult__c` are checked separately from the
 Query and Compare two queries field groups. This prevents the metadata audit from reporting the
 same field problem twice. Mutually exclusive choices use one decision chain so the audit returns
 at most one finding for a field.

### `RecordHealthCheckMetadataValidator`

**Role:** Audit all active Check Set and Check Custom Metadata before a release.

**Type:** Service class · `public with sharing`

Validates all active Check Sets and Checks in the org and returns `ValidationIssue` rows (`ERROR` /
`WARNING`) with component name, field, message, and Reason Code. An empty list means the audit
passed. Package maintainers use it before promoting configuration between Salesforce orgs.

The class is `public`, not `global`. That means other package classes can call it, but Apex created
in an org that installs Record Health Check cannot call it through the `rhc` namespace.

**Key members:**

| Member | Purpose |
| --- | --- |
| `validate()` | Validate every active Check Set and Check in the org |
| `validateRecords(...)` (private) | Validate Check Set and Check records supplied by `validate()` or package tests |

**Notable behavior:**

- `validateRecords` treats a Check Set with more active Checks than
 `RecordHealthCheckConstants.FRAMEWORK_MAX_CHECKS` (25) as `WARNING`/`CHECK_LIMIT_EXCEEDED`, not
 `ERROR`. Salesforce can save the additional Checks, but only the first 25 run. It then checks
 whether any of those first 25 Checks depends on a Check outside the first 25. For each affected
 Check, it adds `WARNING`/`DEPENDENCY_NOT_IN_RUN`. During a health check, Apex and the Lightning card
 skip a Check when its prerequisite was not included.
- When an automatic card hides Run and Rerun, users cannot publish lifecycle events from the card.
  The audit returns `WARNING`/`USER_RUN_PUBLICATION_UNREACHABLE` when Check Set publication is
  enabled and `WARNING`/`USER_RESULT_PUBLICATION_UNREACHABLE` for each Check whose publication is
  enabled. Apex and Flow can still publish, so these findings are warnings rather than errors. The
  audit reads Custom Metadata and cannot detect a **Hide** override stored on a Lightning page.

### `RecordHealthCheckConfigValidator`

**Role:** Provide validation helpers used by more than one package class.

**Type:** Shared helper · `public with sharing`

Finds the first merge-token issue, checks Salesforce object API names, validates and creates Apex
Check classes with `isValidApexPlugin` and `takeValidatedPlugin`, and confirms that Apex parameters
contain a JSON object. Both the health-check run and the metadata audit use these helpers.

**Notable behavior:**

- `isValidApexPlugin` creates an instance of the class while validating it, then saves
 that instance in `validatedPluginInstances` by class name; `takeValidatedPlugin` retrieves and
 removes it so `RecordHealthCheckApexEvaluator` can reuse the already-built plugin instead of
 calling `newInstance()` a second time. `isJsonObject` treats a blank string as valid (returns
 `true`) because `ApexParametersJson__c` is optional. Only a non-blank value that fails to parse as a
 JSON object is rejected.

### `RecordHealthCheckConstants`

**Role:** Store the package's allowed values and numeric limits in one place.

**Type:** Constants holder · `public with sharing`

Owns `FRAMEWORK_MAX_CHECKS` (25), `FRAMEWORK_MAX_ROWS` (2,000), and Set accessors that return a copy
for display modes, trigger/reveal modes, Evaluation Types, operators, null/empty behaviors,
severities, applicability modes, and related allowed-value lists. The health-check run and metadata
audit both read from here so their allowed values stay aligned.

**Notable behavior:**

- The package needs one approved list of values. Every
 `public static Set<String>` accessor here returns a `new Set<String>(...)` copy,
 not the internal set itself. A caller therefore cannot overwrite the package's official values by
 changing the returned Set. The class also owns the Apex-to-Lightning-card value translation
 (`toLwcTriggerMode`, `toLwcSeverity`, `toLwcEvaluatorType`, etc.) that maps metadata API values
 (for example `CRITICAL`) to the card's presentation terms (for example `Error`).

### `RecordHealthCheckReasonCodes`

**Role:** Identify Reason Codes that contain access details and should appear only in diagnostics.

**Type:** Constants holder · `public` with no sharing keyword because it does not query records

Declares commonly referenced codes, such as applicability and access codes. The
`isDiagnosticsOnly` method identifies codes that should be available for troubleshooting but hidden
from users who are not allowed to see the underlying access details. The full outcome list is in
[Reference: Reason Codes](../contracts/reason-codes.md).

**Key members:**

| Member | Purpose |
| --- | --- |
| `isDiagnosticsOnly(reasonCode)` | Whether a reason code should be treated as diagnostics-only |

**Notable behavior:**

- `DIAGNOSTICS_ONLY` contains exactly `FIELD_NOT_ACCESSIBLE` and
  `RECORD_NOT_ACCESSIBLE`. These Reason Codes can reveal field-access or record-sharing details.
  `isDiagnosticsOnly(reasonCode)` returns `true` for either code.

### `RecordHealthCheckSetAvailability`

**Role:** Tell the Lightning card whether the current object has active or inactive Check Sets.

**Type:** Data holder · `public` with no sharing keyword because it does not query records

Used when the Lightning card has no Check Set selected.

**Key members:**

| Member | Purpose |
| --- | --- |
| `hasActive` | Whether the object has any active Check Sets |
| `hasInactive` | Whether the object has any inactive Check Sets |

**Notable behavior:**

- The constructor with no parameters sets both `@AuraEnabled` Boolean fields to `false`. A caller that
 returns early before filling them in (for example `RecordHealthCheckController` on a `null`
 `recordId`) therefore still returns a valid response to the Lightning card.

---

## Related

- [Apex class reference](README.md)
- [Architecture](../framework/architecture.md)
