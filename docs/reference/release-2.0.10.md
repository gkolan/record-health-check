# Record Health Check 2.0.10

> [!NOTE]
> On this page, review the complete public contract introduced in 2.0.10 and the compatibility,
> security, limits, examples, and evidence that govern each feature.

Use this reference to implement or review every public 2.0.10 behavior. Version 2.0.10 expands the
subscriber extension contract, adds detached draft preview and readiness evidence, and introduces
structured display content. It also removes several parser-shaped authoring restrictions from Query
Checks and makes framework limits fail as one visible unit. Existing Checks remain compatible: every new Apex interface is
optional, plain metadata text still renders, diagnostic contract 2.0 is opt-in, and normal
evaluation remains the authority for PASS, FAIL, SKIPPED, UNABLE_TO_EVALUATE, and ERROR.

For the promoted artifact and immutable installation links, see the
[2.0.10.1 release record](../quality-gates/release-2.0.10.1-record.md).

## What changed

| Area                 | 2.0.10 behavior                                                                                                           | Start here                                                                                                     |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| Apex parameters      | A plugin can declare typed parameters, defaults, bounds, administrator labels, and capacity                               | [Declare a plugin definition](#declare-a-plugin-definition)                                                    |
| Outcome construction | Typed equality and list helpers reject contradictory outcomes while they are built                                        | [Build typed outcomes](#build-typed-outcomes)                                                                  |
| Per-record recovery  | One ordinary record failure can become UNABLE_TO_EVALUATE without discarding sibling results                              | [Recover per record](#recover-per-record)                                                                      |
| Evidence             | A plugin can attach bounded, typed, permission-filtered rows                                                              | [Attach evidence](#attach-evidence)                                                                            |
| Presentation         | Metadata and Apex can supply structured text, links, groups, actions, labels, and formats                                 | [Add structured presentation](#add-structured-presentation)                                                    |
| Formula planning     | Draft validation resolves dependencies, offsets, access failures, and safe compiler categories                            | [Formula planning](#formula-planning-and-compiler-diagnostics)                                                 |
| Diagnostics          | Authorized callers can request a bounded 2.0 incident and trace projection                                                | [Authorized diagnostics](#authorized-diagnostics)                                                              |
| Draft preview        | Administrators can validate or execute a detached Check without saving it first                                           | [Detached preview](#detached-preview)                                                                          |
| Readiness            | A successful preview can leave private, expiring evidence tied to the exact definition and scope                          | [Readiness receipts](#readiness-receipts)                                                                      |
| Check authoring      | Business sorting, opaque child queries, dependency order, currency proof, and whole-set limits follow the authored intent | [Conventional Check authoring](#conventional-check-authoring)                                                  |
| Card heading         | Check Sets can show title and subtitle, title only, or hide the heading while controlling Run/Rerun separately            | [Configure Check Set fields](./custom-metadata/check-set-fields.md#card-heading-display-cardheadingdisplay__c) |

## Declare a plugin definition

Implement `RecordHealthCheckPluginDefinitionSource` in addition to `RecordHealthCheckPlugin`, then return a `RecordHealthCheckPluginDefinition` from `getDefinition()`.

The following class excerpt shows only the definition method. Retain the required `evaluate`
implementation in your existing plugin; this excerpt is not a complete, standalone class.

```apex
global with sharing class MyCheck implements RecordHealthCheckPlugin, RecordHealthCheckPluginDefinitionSource {
  global RecordHealthCheckPluginDefinition getDefinition() {
    return new RecordHealthCheckPluginDefinition()
      .integerParameter('daysBack', 30, 1, 3650)
      .describe('daysBack', 'Look-back days', 'Inclusive activity window.')
      .booleanParameter('includeClosed', true)
      .capacity(200, true, 'LOW');
  }
}
```

The available builders are:

| Builder                                           | Accepted contract                                                                   |
| ------------------------------------------------- | ----------------------------------------------------------------------------------- |
| `integerParameter(key, default, min, max)`        | Integer values with inclusive optional bounds                                       |
| `choiceParameter(key, default, choices)`          | One exact member of a nonempty ordered choice list                                  |
| `stringParameter(key, default, maxLength)`        | String bounded to 1–4,096 characters                                                |
| `booleanParameter(key, default)`                  | JSON Boolean                                                                        |
| `required(key, value)`                            | Controls whether omission is rejected                                               |
| `nullable(key, value)`                            | Controls whether explicit JSON `null` is accepted                                   |
| `describe(key, label, helpText)`                  | Administrator label and help text                                                   |
| `capacity(maxScopeSize, bulkSafe, estimatedCost)` | Applicable-record cap, bulk-safety declaration, and `LOW`, `MEDIUM`, or `HIGH` cost |

Definition limits and validation rules:

- A definition may declare at most 50 parameters.
- Keys must match `[A-Za-z][A-Za-z0-9_]{0,39}` and must be unique.
- Labels are required after `describe` and may contain at most 80 characters. Help text may contain at most 512.
- A choice list has 1–50 unique, nonblank values. Each value may contain at most 255 characters.
- Integer defaults must fall inside their declared bounds. String defaults must fit their declared maximum.
- `maxScopeSize` is 1–200. A plugin declaring `bulkSafe=false` must also declare a maximum scope size.
- Unknown JSON keys, duplicate JSON keys, nested values, wrong scalar types, invalid choices, and out-of-range values are rejected as invalid configuration.
- A JSON number such as `5.0` is accepted for an integer only when it has no fractional component. A string such as `"5"` is not an integer under the declared contract.
- Defaults apply to omitted values. Explicit `null` is distinct from omission and requires `nullable(key, true)`.
- Capacity is enforced after applicability, so records that do not apply do not consume the plugin's declared scope.

Plugins that do not implement the definition interface retain the legacy flat-JSON behavior. Preview can fully report parameter schema only when the class is resolved in `EXECUTE` mode.

## Build typed outcomes

`RecordHealthCheckValue` provides canonical values for `STRING`, `BOOLEAN`, `NUMBER`, `DATE`, `DATETIME`, `ID`, `COUNT`, and `LIST`. Scalar values use `storedValue`; lists use `storedValues`. Numbers are locale-neutral, dates are ISO dates, datetimes are UTC ISO-8601 values, IDs normalize to their Salesforce string form, and counts cannot be negative.

2.0.10 adds these guarded outcome builders:

- `passEquals(reason, found, expected)` requires compatible equal values.
- `failEquals(reason, found, expected)` requires compatible unequal values.
- `noneFound(reason)` creates a PASS with two empty LIST values.
- `itemsFound(reason, items)` creates a FAIL against an empty LIST and rejects a null or empty item list.

The builders reject blank or over-80-character reason codes, mismatched types, null stored scalar values, and a verdict that contradicts the values. The engine still validates outcomes returned through the lower-level `pass`, `fail`, `withFound`, `withExpected`, and `withComparison` methods.

## Recover per record

For work that loads data once and then evaluates records independently, implement `RecordHealthCheckRecordEvaluator` and call `RecordHealthCheckOutcome.tryEvaluate(recordId, evaluator)` once per record.

- An ordinary exception becomes `UNABLE_TO_EVALUATE` with `RECORD_EVALUATION_FAILED`.
- A null outcome becomes `UNABLE_TO_EVALUATE` with `RECORD_RESULT_MISSING`.
- Fatal framework failures, permission failures, and detected side effects are rethrown so the engine can preserve its security and transaction guarantees.
- The helper does not make queries or DML safe inside a loop. Load shared data before iterating.

## Attach evidence

Attach a `RecordHealthCheckEvidence` snapshot with `outcome.withEvidence(evidence)`. Evidence is explanatory data; it cannot change the verdict, comparison, identity, severity, or applicability.

```apex
RecordHealthCheckEvidence evidence = new RecordHealthCheckEvidence(
    'Values used for this decision.'
  )
  .column('rule', 'Rule', 'STRING')
  .column('observed', 'Observed', 'NUMBER')
  .row(
    new List<RecordHealthCheckEvidenceCell>{
      RecordHealthCheckEvidenceCell.value(RecordHealthCheckValue.ofString('minimum')),
      RecordHealthCheckEvidenceCell.value(RecordHealthCheckValue.ofCount(2))
    }
  )
  .groupBy(null, 'rule');
```

Evidence limits:

| Limit               |                                                            Value |
| ------------------- | ---------------------------------------------------------------: |
| Summary             |                                                   512 characters |
| Columns             |                                                             1–20 |
| Rows returned       |                                                              100 |
| Column key          |               Same 40-character key grammar as plugin parameters |
| Column label        |                                                    80 characters |
| String or ID cell   |                                                 1,024 characters |
| Serialized evidence | 256 KiB per envelope, also subject to the shared response budget |

Evidence columns accept `STRING`, `ID`, `NUMBER`, `BOOLEAN`, `DATE`, and `DATETIME`. A `COUNT` value is projected through a `NUMBER` column. Rows must match the declared column count and types, including null values. Use a null of the declared scalar type; LIST values are not scalar nulls and are not accepted in evidence columns. `stepGroupKey`, when present, must name a `NUMBER` column; `ruleGroupKey` must name a `STRING` or `ID` column.

Use `RecordHealthCheckEvidenceCell.value` for synthetic values. Use `field(recordId, fieldPath, value)` for record-field provenance. Field cells are returned only when the source record is in the authorized evaluation map and the field is accessible. Unauthorized rows are omitted, counts become unknown when completeness cannot be established, and malformed evidence becomes a disclosure-safe “Details unavailable” envelope.

## Add structured presentation

### Metadata merge syntax

Message, fix, display-value, action-label, action-URL, and supported description fields can use the documented merge syntax. Literal text remains text. Structured links use an explicit link token and degrade to their readable label if the destination is unsafe or unavailable.

```text
Review {!record.Name fallback="this record"}. {!link label="Open record" href="/lightning/r/Account/{!record.Id}/view"}
```

Destinations must be a safe same-org path beginning with `/` or an absolute HTTPS URL. Unsafe schemes, credentials in URLs, control characters, malformed interpolation, and oversized content are rejected or reduced to safe plain text. Rendered links open in a new context with `noopener noreferrer` protection.

Structured-display limits are 100 link tokens, 1,000 nodes, 20,000 visible characters, and 64 KiB for one Check field. Link labels and complete URLs may contain at most 2,000 characters.

A response shares 256 KiB across its optional structured display and evidence. This counts serialized UTF-8 JSON for the `displayContent` and `evidence` objects, their property names, and the enclosing projection objects and array. Machine evaluation facts and legacy plain-text fallbacks are separate from this optional-presentation limit; it is not a maximum size for the entire API response.

Allocation follows selected Check order, then normalized record order. Within each result, message, fix, Found and Expected precede evidence. Oversized fields are omitted whole, preserving their original plain-text fallback. Evidence retains whole leading rows and updates returned, omitted and completeness information; unknown authorized totals remain unknown. Once the shared budget is exhausted, later optional content is omitted. An authorized diagnostic viewer receives at most one fixed omission warning in the existing admin-detail message. Existing diagnostic explanations and terminal reason codes are preserved; ordinary responses do not gain diagnostic details.

For source validation, the integration-only [display-budget verification fixture](../quality-gates/display-budget-verification.md) exercises ordered fallback with PASS, FAIL, SKIPPED and UNABLE_TO_EVALUATE records. Browser verification remains a separate release step.

### Apex display overrides

Implement `RecordHealthCheckDisplayPlugin` to add presentation after `evaluate` on the same plugin instance:

```apex
global Map<Id, RecordHealthCheckDisplayOverride> getDisplay(
  RecordHealthCheckScope scope
) {
  return new Map<Id, RecordHealthCheckDisplayOverride>{
    scope.recordIdAt(0) => new RecordHealthCheckDisplayOverride()
      .withMessage(new RecordHealthCheckDisplayText().text('Needs follow-up.'))
      .withAction(new RecordHealthCheckDisplayAction('Open record', '/lightning/r/Account/' + scope.recordIdAt(0) + '/view'))
  };
}
```

An override can supply Found, Expected, outcome message, fix guidance, one atomic action label/destination pair, an Expected label, and Found/Expected display formats with optional currency ISO codes. `RecordHealthCheckDisplayText` supports `text`, `link`, `recordLinks`, `groups`, `lineBreak`, and `paragraphBreak`. Group keys are nonblank, unique within one `groups` call, and at most 255 characters; empty groups are omitted unless they define an empty state. Visible groups are separated by exactly one line break.

The framework also limits its detached copy of one `getDisplay` result to 256 KiB of serialized UTF-8 JSON, including record keys, object overhead, rich fields and presentation metadata. It allocates message, fix, Found and Expected in scope-record order, then the record's action, label and format metadata together. Once allocation is exhausted, later optional content is omitted; already accepted fields remain available. This bounds the framework's retained copy, not memory allocated inside subscriber code. The final response budget above still applies.

Display execution is presentation-only and runs for `EVALUATION_WITH_DISPLAY` requests, including
Apex callers that explicitly select that result mode. Evaluation-only requests omit the display hook. It runs at most once after evaluation, on the same instance, and may reuse state already computed by `evaluate`. It must not issue SOQL, DML, callouts, async work, email, or events. It cannot replace record/check identity, status, reason, severity, applicability, publication settings, or diagnostic facts.

Invalid scope-wide display output falls back to metadata presentation for that scope. An invalid per-record override falls back only for that record. An omitted field falls back independently, so a plugin can override one value without taking ownership of every visible field. Unsafe links become readable text or the metadata action. Headless API evaluation remains stable because presentation does not alter evaluation data.

## Formula planning and compiler diagnostics

The formula planner tokenizes references with deterministic start and end offsets, resolves relationship paths, and separates missing fields from inaccessible fields. This applies to ordinary dot paths and colon-prefixed relationship syntax. An existing but inaccessible relationship reports `FIELD_NOT_ACCESSIBLE`; an unknown path reports `FIELD_NOT_RESOLVED`.

Compilation probes use bounded, disclosure-safe categories. Raw exception messages and formula source are not returned. AUTO return-type probing reports only a diagnostic that belongs to the selected or final result, so an error from an earlier attempted return type cannot masquerade as the final cause. Stable categories include syntax or token, type mismatch, unsupported function or construct, and generic compilation failure; the exact category is exposed through preview findings and authorized diagnostics when available.

Formula globals such as `$User`, `$Profile`, `$Setup`, `$Permission`, and `$CustomMetadata` remain outside the checked-record dependency contract. See [platform limitations](./platform/limitations.md#formula-planning-and-evaluation).

## Conventional Check authoring

A positional query-row token accepts any readable outer `ORDER BY`, including an ordinary business
sort such as `CreatedDate DESC`. Adding `Id` is optional and remains a useful native SOQL tie-breaker
when identical business values must be repeatable. A self query constrained by
`Id = {!record.Id}` and an ungrouped aggregate already prove single-row behavior and need no sort.

An outer scalar remains addressable beside a valid relationship subquery. Unsupported outer SELECT
expressions and unreadable outer ordering still fail closed. For scope-wide evaluation, a correlated
ordered query with `LIMIT N` keeps up to N rows per evaluated record in the authored order instead of
applying the limit once to the combined scope.

`EvaluationOrder__c` controls presentation order. A prerequisite may appear later and execution still
runs it first; missing prerequisites and dependency cycles remain configuration errors. In a
multi-currency org, currency safety accepts a direct ISO equality only when the complete boolean
predicate requires that same literal on every possible branch.

A Check Set with more than 25 active Checks is rejected before evaluation with
`FRAMEWORK_MAX_CHECKS_EXCEEDED`. The record card, Apex, Flow, preview, and metadata validation paths
therefore never present a partial run as the result of the whole set.

## Authorized diagnostics

The diagnostic contract version is `2.0`. Request it explicitly:

```apex
RecordHealthCheckRequest request = RecordHealthCheckRequest.forCheckSet(
    'My_Check_Set',
    recordIds
  )
  .withDiagnosticContractVersion('2.0');
RecordHealthCheckResponse response = RecordHealthCheck.evaluate(request);
RecordHealthCheckDiagnosticResponse diagnostics = response.diagnostics();
```

Only `2.0` is accepted. Without an explicit request, the normal response stays unchanged. The diagnostic response contains value-free envelopes keyed by run, Check, record, phase, invocation state, reason and origin, configuration field, token and offsets, base object, dependency path, sanitized exception coordinates, ordered lifecycle trace, truncation state, and terminal failure.

Diagnostics are authorized through the existing administrator/diagnostic access checks. Projection has a 128 KiB response budget. Traces are bounded and keep the terminal failure independently, so truncation cannot erase the final cause. Compiler exceptions are categorized and sanitized; raw exception text, source formulas, record values, bind values, and inaccessible schema names are not diagnostic payloads.

## Detached preview

`RecordHealthCheckPreviewService.preview(request)` validates a detached `Record_Health_Check__mdt` draft against a server-owned Check Set. It requires both Record Health Check administrator access and permission to run Checks.

Create an immutable request with `RecordHealthCheckPreviewRequest.forDraftCheck(draft, qualifiedSetName, recordIds)`, then select:

- `VALIDATE_ONLY`: validates configuration and plans fields without resolving or executing Apex plugins.
- `EXECUTE`: validates, resolves plugin schema, and evaluates the draft with event publication forced to `NONE`.
- `withReadinessReceipt(true)`: explicitly requests a receipt after a valid preview.

The request accepts at most 200 unique record IDs and a 1 MiB canonical payload. Null IDs are removed and duplicate IDs preserve first-occurrence order. Only documented Check fields are copied; relationship query fields and `SystemModstamp` are ignored, while any other unsupported populated field is rejected. The draft must belong to the selected server-owned Check Set, preserve protected identity fields, and have an acyclic prerequisite chain.

The versioned response includes a run ID, definition fingerprint, mode, validation status, capability map, structured findings, sorted resolved fields, optional execution results, optional readiness receipt, readiness state, current-live-verification flag, and resolved plugin parameter descriptions.

Capability values explain what the preview actually proved. Configuration and field planning are complete in both modes. For Apex in `VALIDATE_ONLY`, plugin schema and plugin freshness are incomplete. `EXECUTE` can complete schema resolution, while plugin freshness remains an explicit limitation rather than an inferred guarantee.

Preview findings include stable code, severity, readable message, configuration field, offending token, token offsets, and sanitized diagnostic detail. Preview requests never publish user-result, user-run, or error-log events.

## Readiness receipts

A receipt is saved only when explicitly requested and validation is `VALID`. Its public status is `SAVED`, `NOT_SAVED`, `NOT_REQUESTED`, or `NOT_ELIGIBLE`. A save failure returns a fixed disclosure-safe warning and does not invalidate the completed preview.

Receipts are private package records tied to:

- the exact definition fingerprint;
- Check and Check Set identity;
- actor and org;
- preview contract and mode;
- a SHA-256 digest of the sorted record-ID scope;
- verification time and 30-day expiry;
- capability states; and
- outcome counts for the draft Check only.

Counts exclude prerequisite and sibling results. A current live verification requires the same actor, org, definition, set, and scope digest, an unexpired eligible receipt, and the required capabilities. Changing the draft or scope therefore makes earlier evidence stale instead of silently reusing it.

`deleteExpiredReadinessReceipts(true)` deletes at most 200 expired rows visible to the authorized administrator. Passing `false` is rejected because cleanup requires explicit confirmation.

## Shipped 2.0.10 example

`AccountHasRecentActivityCheck` is the reference implementation. The active **Example: Account Check Builder Guide** Check Set includes **Example: Verified engagement cadence**, configured with `{"daysBack": 60, "minimumActivities": 2}`.

The example demonstrates:

- typed parameter declaration with defaults, bounds, labels, help, and bulk capacity;
- two aggregate queries for the complete scope, with zero-activity records preserved;
- PASS and FAIL outcomes with typed Found/Expected values;
- evidence containing Account ID, observed count, required count, and look-back window;
- display-only message, safe record link, Expected label, number formats, remediation, and action;
- metadata fallback text and action when display output is absent or rejected; and
- stable `APEX_PASS`, `APEX_FAIL`, and public `INVALID_APEX_PARAMETERS` reason behavior.

The shipped readiness data exercises a ready Account that passes, a needs-review Account that fails, and an empty Account that fails with an observed count of zero. The verification procedure is in [Recent Account activity](../examples/apex/recent-activity.md) and [Explore the installed examples](../install/explore-installed-examples.md).

This is a deliberate example boundary. The other installed Formula, Query, and Compare Two Queries
Checks receive 2.0.10 runtime fixes without unrelated metadata changes. Invalid formulas,
inaccessible fields, unsafe links, diagnostic payloads, and forced plugin failures remain in
integration fixtures. Preview and readiness reuse an existing definition because they are
administrator workflows rather than additional Check types. See
[Example coverage for 2.0.8 through 2.0.10](../examples/versioned-example-coverage.md) for the full
capability-to-fixture decision and deterministic data matrix.

## Compatibility and operational boundaries

- New interfaces and response fields are additive. Existing Apex plugins need no source change.
- The engine continues to own identity, severity, applicability, event publication, and final contract validation.
- Preview and readiness require administrator authorization; normal record-card users do not gain draft-management access.
- Evidence and display links pass through access and URL policy before transport.
- Readiness is evidence about one exact draft and scope, not approval, deployment, or a permanent test record.
- Hosted Salesforce compilation, package installation, namespace, LWS/Locker, and browser validation remain separate release evidence. Offline source gates cannot prove those platform behaviors.

## Verification matrix

| Scenario                         | Shipped or integration fixture                                   | Automated guard                                                                                         | Expected result                                                                                                                                      |
| -------------------------------- | ---------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| Ordinary positive cadence        | `RHC Builder Ready Account` and `Acme Corporation`               | `AccountHasRecentActivityCheckTest` plus `readiness-scenarios.json`                                     | PASS with typed counts/evidence                                                                                                                      |
| Ordinary negative cadence        | `RHC Builder Needs Review Account`                               | Same guards                                                                                             | FAIL with remediation/action                                                                                                                         |
| Empty related data               | `RHC Builder Empty Account`                                      | `accountsWithNoActivityStillReceiveAnOutcome`                                                           | FAIL, Found `0`, evidence present                                                                                                                    |
| Threshold boundary               | Two activities with minimum two                                  | typed-evidence test and demo scenario                                                                   | PASS at equality                                                                                                                                     |
| Stale activity                   | Task 400 days old                                                | `activityOutsideWindowFails`                                                                            | FAIL                                                                                                                                                 |
| Wrong relationship               | Contact-only WhoId Task                                          | `whoOnlyContactTaskIsExplicitlyOutsideWhatIdContractRow22`                                              | FAIL; activity excluded                                                                                                                              |
| Invalid parameter                | Wrong type, zero, or out-of-range value                          | `invalidDaysBackIsRejected` and definition-contract tests                                               | Direct class defense uses `INVALID_CONFIG`; normal Record Health Check evaluation rejects it first as UNABLE_TO_EVALUATE / `INVALID_APEX_PARAMETERS` |
| Bulk/governor                    | 1 versus 200 Accounts                                            | `queryCountDoesNotGrowWithScopeSize`                                                                    | Two queries in either scope                                                                                                                          |
| Permission/access                | least-privilege activity visibility and FLS planner fixtures     | contract/security Apex tests and sandbox procedure                                                      | visible data only; inaccessible dependencies classified without disclosure                                                                           |
| Namespace                        | namespaced integration package metadata and qualified identities | namespace/source gates and hosted package validation                                                    | qualified identities remain distinct                                                                                                                 |
| Inline-link success/failure      | shipped cadence fallback plus `RHC_Link_Metadata`                | `RHCLinkFixtureTest` and LWC tests                                                                      | safe link clickable; unsafe destination becomes safe text/fallback                                                                                   |
| Display override success/failure | shipped cadence plugin plus structured integration plugin        | `AccountHasRecentActivityCheckTest`, `RecordHealthCheckScopeDisplayTest`, `RHCPresentationResolverTest` | valid fields override; invalid fields fall back without changing evaluation                                                                          |
| Evidence access and limits       | subscriber evidence fixtures                                     | `RHCSubscriberEvidenceSpecTest`, `RHCDiagnosticProjectionBudgetTest`                                    | authorized bounded projection or disclosure-safe unavailable result                                                                                  |
| Detached validate/execute        | preview Apex fixtures                                            | `RecordHealthCheckPreviewControllerTest`                                                                | deterministic findings; execution only in EXECUTE mode; no events                                                                                    |
| Stale/tampered readiness         | private readiness fixtures                                       | preview and fingerprint tests                                                                           | stale or noncurrent; draft-only counts remain isolated                                                                                               |
| Formula relationship FLS         | colon and ordinary relationship fixtures                         | `RHCFieldPlannerSecurityTest`, `RHCSubscriberFormulaSpecTest`                                           | `FIELD_NOT_ACCESSIBLE`, never `FIELD_NOT_RESOLVED` for known inaccessible paths                                                                      |
| Compiler diagnostic probing      | formula compiler cache fixtures                                  | `RHCFormulaCompilerCacheTest`                                                                           | bounded selected/final category without raw formula or wrong AUTO probe                                                                              |

LWS and Locker card rendering, managed-package namespace compilation, and real user-mode access are
platform variations. Verify them in the retained release org pair when the release owner authorizes
that hosted validation. The repository's offline gates and Apex source tests remain the repeatable
guards between hosted runs.

## Related

- [Write an Apex Check](../developer-guides/write-an-apex-check.md)
- [Recent Account activity example](../examples/apex/recent-activity.md)
- [Results and plugins architecture](../architecture/apex-implementation/results-and-plugins.md)
- [Subscriber foundations architecture](../architecture/apex-implementation/subscriber-foundations.md)
- [Custom Metadata field reference](./custom-metadata/README.md)
- [Reason codes](./results/reason-codes.md)
