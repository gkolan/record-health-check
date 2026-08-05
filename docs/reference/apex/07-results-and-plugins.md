# Reference: Apex results, definitions, and plugins (L1)

> [!NOTE]
> On this page, look up the L1 result and definition types, the `RecordHealthCheckRule` plugin
> interface, shipped example plugins, and test helpers that are not runtime entry points.

This page is part of the [Apex class reference](README.md). For writing a plugin, see
[Apex Rule contract](../evaluation/04-apex-rule-contract.md) and
[Plugin verification](08-plugin-verification.md).

## Results, definitions, and plugin interface (L1)

### `RecordHealthCheckEvaluationResult` / `RecordHealthCheckResultDisplay`

**Role:** Separate stable machine data from optional human-facing rendering.
**Type:** Global data holders

`RecordHealthCheckEvaluationResult` carries status, qualified Rule identity, reason code, severity,
and typed Found/Expected values. `RecordHealthCheckResultDisplay` carries labels, messages, links,
and formatted values only when the selected result mode requests display content.

### `RecordHealthCheckResponse` / `RecordHealthCheckResultItem`

**Role:** Common response shape for both Rule and Check Set requests.
**Type:** Global data holders

The response preserves the detached input record order and selected Rule order. Each result item
contains one evaluation plus optional display content; the summary holds terminal status totals.

**See also:** [Apex API response contract](../../api/01-apex-api.md#response-contract)

### `RecordHealthCheckDefinition` / `RecordHealthCheckDefinitionResponse`

**Role:** Lightning definition response (not evaluation results).
**Type:** Data holders (`@AuraEnabled`) · `public` (no sharing keyword)

**Key members:**

| Member | Purpose |
| --- | --- |
| `RecordHealthCheckDefinition.developerName` / `label` / `description` / `priority` | One Rule's identity and display fields |
| `RecordHealthCheckDefinition.dependsOnRuleDeveloperName` | `null` when the Rule has no `PrerequisiteRule__c` dependency |
| `RecordHealthCheckDefinitionResponse` title/trigger/reveal/display fields | Check Set card settings (title, trigger/reveal modes, passed/skipped/comparison display, stop-on-first-error) |
| `RecordHealthCheckDefinitionResponse.checksOmittedByLimit` | Truncation metadata for the "First 25 of N shown" badge |
| `RecordHealthCheckDefinitionResponse.inactiveRuleLabels` | Diagnostics-only detail behind `inactiveRuleCount` |
| `RecordHealthCheckDefinitionResponse.showDiagnostics` / `checks` | Diagnostics visibility flag and the ordered Rule definitions |

**Notable behavior:**
- **Note:** `inactiveRuleLabels` - the list of names, not just the count - is only meaningful to an
 admin auditing why a Rule did not run.

### `RecordHealthCheckAdminDetail`

**Role:** Structured diagnostics for authorized Show Diagnostics viewers.
**Type:** Data holder (`@AuraEnabled`) · `public` (no sharing keyword)

Left blank on a normal business response.

**Key members:**

| Member | Purpose |
| --- | --- |
| `containsRestrictedDetail` | Whether restricted detail is present; read by `RecordHealthCheckLifecyclePublisher` to set `ContainsRestrictedDetail__c` on the outgoing event |
| `reasonCode` | Diagnostics reason code |
| `message` | Diagnostics message text |

**Notable behavior:**
- **Note:** all three fields are `@AuraEnabled` with no constructor - callers set them field by
 field.

### `RecordHealthCheckValueSource`

**Role:** Structured Found/Expected diagnostic detail.
**Type:** Data holder · `public` (no sharing keyword)

**Key members:**

| Member | Purpose |
| --- | --- |
| `Detail` (nested: `sourceLabel`, `rawValueLabel`, `coercionLabel`) | Structured pieces of one diagnostic note |
| `render(Detail)` | Turns a `Detail` into the single human-readable note shown as `actualValueDetail` / `expectedValueDetail` |
| `rowCount(...)` | Formats pluralized row counts |

**Notable behavior:**
- **Important:** `render` returns `null` - not an empty string - when every part of the `Detail` is
 blank, so the engine can leave the public `*Detail` string `null` rather than showing an empty
 parenthetical note. `rowCount` exists solely so a value-source note never reads "1 row(s)": it
 special-cases `n == 1` to `"1 row"` and treats a `null` count as `0`.

### `RecordHealthCheckRule` (interface)

**Role:** Plugin interface for Apex Evaluation Type.
**Type:** Interface · `global`

```apex
global interface RecordHealthCheckRule {
  Map<Id, RecordHealthCheckOutcome> evaluate(RecordHealthCheckScope scope);
}
```

Implementations are bulk by contract: query once for the complete scope, seed every requested Id,
overlay returned facts, and isolate record-specific conversion errors inside the record loop.

**Notable behavior:**
- **Important:** the signature cannot prove query growth or access mode. `RecordHealthCheckPluginDispatch` validates exact
  key coverage and prohibited effects; the supplied contract test measures behavior across scope
  sizes and can use a controlled least-privilege test setup as evidence.

### `RecordHealthCheckScope`

**Role:** Input to `RecordHealthCheckRule.evaluate`.
**Type:** Read-only global data holder

**Key members:**

| Member | Purpose |
| --- | --- |
| `objectApiName` | Object API name (for example `Account`) |
| `recordIds` | Detached copy of every record Id in the request scope |
| `parameters` | Detached parsed `ApexParametersJson__c` map |
| `ruleQualifiedApiName` | Qualified Rule identity |
| `checkSetQualifiedApiName` | Qualified parent Check Set identity |
| `runId` | Correlation id for the request |

**Notable behavior:**
- **Important:** getters return detached collections. A plugin cannot mutate the pipeline's record Ids
  or parameter map through the scope object.

**See also:** [Reference: Apex](../evaluation/04-apex-rule-contract.md)

---


## Example Apex plugins

These classes implement `RecordHealthCheckRule`. They are examples and fixtures, not required for
the engine to run Formula or Query Rules.

### `AccountHasRecentActivityCheck`

**Role:** Shipped Apex Rule for recent Account Task/Event activity.
**Type:** Example plugin (implements `RecordHealthCheckRule`) · `global with sharing`

Ships with Record Health Check in `force-app`. Passes when the Account has at least one completed Task or Event in
a look-back window. Tunable with `ApexParametersJson__c`: `{"daysBack": 90}` (default 30, bounds
1–3650). Sets Found/Expected and value-source detail; label, severity, and failure message come from
metadata.

**Key members:**

| Member | Purpose |
| --- | --- |
| `DEFAULT_DAYS_BACK` (`30`) | Look-back window only when `daysBack` is omitted |
| `MIN_DAYS_BACK` / `MAX_DAYS_BACK` (`1` / `3650`) | Valid bounds for `daysBack` |
| `resolveDaysBack(...)` | Parses and bounds-checks the `daysBack` parameter |

**Notable behavior:**
- **Important:** an omitted `daysBack` uses `DEFAULT_DAYS_BACK`; a supplied value that is nonnumeric or
 outside `MIN_DAYS_BACK`/`MAX_DAYS_BACK` returns `UNABLE_TO_EVALUATE` with `INVALID_CONFIG`. Both queries run
 `WITH USER_MODE` and use `SELECT COUNT()`, so Task/Event visibility follows the running user's
 sharing and FLS like every other Framework query.

**See also:** [Recent Account activity example](../../examples/apex/01-recent-activity.md)

### Integration-test plugins

These live under `integration-tests/main/default/classes/` and accompany the examples library. They
are not part of Record Health Check unless you deploy that folder.

| Class | What it checks | Typical JSON parameters |
| --- | --- | --- |
| `AccountOpenOpportunityHealthCheck` | Open Opportunities that are stale, missing Next Step, and not closing this quarter | `{"staleDays": 30}` |
| `AccountStrategicReadinessCheck` | Weighted readiness score (contacts, pipeline, activity, billing) | `{"minScore": 80, "activityDaysBack": 60}` |
| `ApprovalInactiveApproverCheck` | Pending approval steps assigned to inactive users (dynamic object/field names for Advanced Approvals) | Object/field/status overrides; returns `UNABLE_TO_EVALUATE` when the approval object is absent |

**See also:** [Apex examples](../../examples/apex/README.md)

---


## Test helpers (not runtime)

| Class | Note |
| --- | --- |
| `RecordHealthCheckTestDataFactory` | `@isTest` factory for Accounts/Contacts and related coverage data; not used at runtime |
| `*Test.cls` / coverage classes | Unit and coverage tests; not part of the Framework API |

---

## Related

- [Apex class reference](README.md)
- [Architecture](../framework/01-architecture.md)
