# Apex result, Lightning, and plugin types (L1)

> [!IMPORTANT]
> **Audience: package maintainers and Salesforce developers.** This class-level reference is not a
> Setup or Flow walkthrough. Administrators should use the Flow, configuration, and evaluation
> guides; subscriber developers should use the public Apex API or Apex Check contract.

> [!NOTE]
> Use this page to understand the objects returned by the Apex API, the data sent to the Lightning
> card, the interface implemented by a custom Apex Check, and the examples included in the
> repository.

This page is part of the [Apex class reference](README.md). For writing a plugin, see
[Apex Check contract](../evaluation/apex-check-contract.md) and
[Plugin verification](plugin-verification.md).

## Results, definitions, and plugin interface (L1)

### `RecordHealthCheckEvaluationResult` / `RecordHealthCheckResultDisplay`

**Role:** Keep values used by automation separate from text formatted for a person.

**Type:** Global data holders

`RecordHealthCheckEvaluationResult` contains Status, the Check Qualified API Name, Reason Code,
Severity, and Found and Expected values in their Salesforce data types.
`RecordHealthCheckResultDisplay` contains labels, messages, links, and formatted values only when the
request asks for display content.

### `RecordHealthCheckResponse` / `RecordHealthCheckResultItem`

**Role:** Return results for either one Check or a complete Check Set.

**Type:** Global data holders

The response keeps the input record order and selected Check order. Each item contains one
evaluation and, when requested, its display content. The summary contains the number of PASS, FAIL,
SKIPPED, UNABLE_TO_EVALUATE, and ERROR results.

**See also:** [Apex API response contract](../../api/apex-api.md#response-contract)

### `RecordHealthCheckDefinition` / `RecordHealthCheckDefinitionResponse`

**Role:** Tell the Lightning card which Checks and display settings to use.

**Type:** Data holders (`@AuraEnabled`) · `public` (no sharing keyword)

**Key members:**

| Member | Purpose |
| --- | --- |
| `RecordHealthCheckDefinition.developerName` / `label` / `description` / `priority` | One Check's identity and display fields |
| `RecordHealthCheckDefinition.dependsOnCheckDeveloperName` | `null` when the Check has no `PrerequisiteCheck__c` dependency |
| `RecordHealthCheckDefinitionResponse` title/trigger/reveal/display fields | Check Set card settings (title, trigger/reveal modes, passed/skipped/comparison display, stop-on-first-error) |
| `RecordHealthCheckDefinitionResponse.checksOmittedByLimit` | Truncation metadata for the "First 25 of N shown" badge |
| `RecordHealthCheckDefinitionResponse.inactiveCheckLabels` | Diagnostics-only detail behind `inactiveCheckCount` |
| `RecordHealthCheckDefinitionResponse.showDiagnostics` / `checks` | Diagnostics visibility flag and the ordered Check definitions |

**Notable behavior:**

- `inactiveCheckLabels` contains the names of inactive Checks, not only their count. The Lightning
  card uses this information only when an authorized administrator opens diagnostics.

### `RecordHealthCheckAdminDetail`

**Role:** Hold troubleshooting details shown only to users allowed to view diagnostics.

**Type:** Data holder (`@AuraEnabled`) · `public` (no sharing keyword)

Left blank on a normal business response.

**Key members:**

| Member | Purpose |
| --- | --- |
| `containsRestrictedDetail` | Whether the diagnostic object contains access-sensitive details |
| `reasonCode` | Diagnostics reason code |
| `message` | Diagnostics message text |

**Notable behavior:**

- All three fields are `@AuraEnabled` and are assigned individually by package code.
- The current Platform Event publisher always sets `ContainsRestrictedDetail__c` to `false`; it does
  not copy `containsRestrictedDetail` from this object into an event.

### `RecordHealthCheckValueSource`

**Role:** Build readable notes explaining where a Found or Expected value came from.

**Type:** Data holder · `public` (no sharing keyword)

**Key members:**

| Member | Purpose |
| --- | --- |
| `Detail` (nested: `sourceLabel`, `rawValueLabel`, `coercionLabel`) | Structured pieces of one diagnostic note |
| `render(Detail)` | Turns a `Detail` into the single human-readable note shown as `actualValueDetail` / `expectedValueDetail` |
| `rowCount(...)` | Formats pluralized row counts |

**Notable behavior:**

- `render` returns `null`, not an empty string, when every part is blank. The Lightning card
  therefore does not show an empty pair of parentheses.
- `rowCount` produces natural wording: **1 row**, **2 rows**, and **0 rows** when the count is `null`.

### `RecordHealthCheckPlugin` (interface)

**Role:** Define the method every custom Apex Check must provide.

**Type:** Interface · `global`

```apex
global interface RecordHealthCheckPlugin {
  Map<Id, RecordHealthCheckOutcome> evaluate(RecordHealthCheckScope scope);
}
```

The package calls `evaluate` once with all record IDs in the current request. A plugin should query
for all IDs together, create one initial outcome for every requested ID, apply the facts returned by
the query, and handle a record-specific conversion problem inside the record loop.

**Notable behavior:**

- The method signature cannot prove that a plugin queries efficiently or respects the running
  user's access. Package code rejects missing or extra result IDs and prohibited database changes.
  The supplied contract test checks behavior with 1, 10, 50, and 200 records. A human must still
  review each SOQL query's access mode.

### `RecordHealthCheckScope`

**Role:** Supply the records and configuration to `RecordHealthCheckPlugin.evaluate`.

**Type:** Read-only global data holder

**Key members:**

| Member | Purpose |
| --- | --- |
| `objectApiName` | Object API name (for example `Account`) |
| `recordIds` | Copy of every record ID in the request |
| `parameters` | Copy of the JSON object from `ApexParametersJson__c`, converted to an Apex map |
| `checkQualifiedApiName` | Qualified Check identity |
| `checkSetQualifiedApiName` | Qualified parent Check Set identity |
| `runId` | ID that connects logs and events from the same request |

**Notable behavior:**

- The getters return copies of the record IDs and parameters. Changing those returned collections
  cannot change the package's original request.

**See also:** [Reference: Apex](../evaluation/apex-check-contract.md)

---


## Apex plugin examples

These classes implement `RecordHealthCheckPlugin`. They show how a custom Apex Check works. Formula,
Query, and Compare two queries Checks do not depend on them.

### `AccountHasRecentActivityCheck`

**Role:** Example that checks recent Account Task or Event activity.

**Type:** Example plugin (implements `RecordHealthCheckPlugin`) · `global with sharing`

This class is included with the installed Record Health Check package. It returns PASS when an
Account has at least one closed Task or one Event dated on or after the calculated cutoff date. Use
`{"daysBack": 90}` in **Apex Parameters JSON** to check the previous 90 days. The default is 30; the
allowed range is 1 through 3,650. The Check Custom Metadata supplies the label, severity, and failure
message.

**Key members:**

| Member | Purpose |
| --- | --- |
| `DEFAULT_DAYS_BACK` (`30`) | Look-back window only when `daysBack` is omitted |
| `MIN_DAYS_BACK` / `MAX_DAYS_BACK` (`1` / `3650`) | Valid bounds for `daysBack` |
| `resolveDaysBack(...)` | Parses and bounds-checks the `daysBack` parameter |

**Notable behavior:**

- When `daysBack` is omitted, the class uses 30. A nonnumeric value or a number outside 1 through
  3,650 returns `UNABLE_TO_EVALUATE`/`INVALID_CONFIG`.
- Both queries use `WITH USER_MODE`, so the result respects the running user's record, object, and
  field access.

**See also:** [Recent Account activity example](../../examples/apex/recent-activity.md)

### Integration-test plugins

These live under `integration-tests/main/default/classes/`. Installing Record Health Check does not
install them. They become available only if your team deliberately deploys that folder.

| Class | What it checks | Typical JSON parameters |
| --- | --- | --- |
| `AccountOpenOpportunityHealthCheck` | Open Opportunities that are stale, missing Next Step, and not closing this quarter | `{"staleDays": 30}` |
| `AccountStrategicReadinessCheck` | Weighted readiness score (contacts, pipeline, activity, billing) | `{"minScore": 80, "activityDaysBack": 60}` |
| `ApprovalInactiveApproverCheck` | Pending approval steps assigned to inactive users (dynamic object/field names for Advanced Approvals) | Object/field/status overrides; returns `UNABLE_TO_EVALUATE` when the approval object is absent |

**See also:** [Apex examples](../../examples/apex/README.md)

---


## Package test helpers

| Class | Note |
| --- | --- |
| `RecordHealthCheckTestDataFactory` | `@isTest` factory for Accounts, Contacts, and related test records; health checks do not use it |
| `*Test.cls` / coverage classes | Package tests; custom Apex should not call them as a supported API |

---

## Related

- [Apex class reference](README.md)
- [Architecture](../framework/architecture.md)
