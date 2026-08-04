# Reference: Apex entry points (L5)

> [!NOTE]
> On this page, look up the L5 entry-point classes that expose Record Health Check to Apex,
> Flow, Lightning, schedulers, and lifecycle publication.

This page is part of the [Apex class reference](README.md). For the architecture story, see
[Architecture](../framework/architecture.md).

## Entry points (L5)

### `RecordHealthCheck`

**Role:** Single public Apex request API.
**Type:** Service class · `global with sharing`

Runs one qualified Rule or Check Set selection over a detached record scope. The request carries its
result mode, event-publication choice, and optional correlation id explicitly.

**Key members:**

| Member | Purpose |
| --- | --- |
| `evaluate(RecordHealthCheckRequest)` | Evaluate one qualified selection and return the common response envelope |

**Notable behavior:**
- **When to use it:** any Apex process that needs typed results for one Rule or every active Rule in
  one Check Set.
- **Gotcha:** selection identities are Custom Metadata `QualifiedApiName` values, not labels or bare
  names chosen with `LIMIT 1`.

**See also:** [Reference: Apex API](../../api/apex-api.md)

### `RecordHealthCheckController`

**Role:** Aura-enabled API for the Lightning card.
**Type:** Service class · `public with sharing`

Exposes four card operations and nothing else. It does not contain evaluation logic; it cleans up
inputs, supplies Lightning lifecycle sources, and delegates to `RecordHealthCheckConfigService` and
`RecordHealthCheckScopePipeline`.

**Key members:**

| Member | Purpose |
| --- | --- |
| `getCheckSetAvailabilityForRecord(recordId)` | Active/inactive Check Sets for the record's object (setup banner) |
| `getCheckDefinitions(checkSetQualifiedApiName, recordId, runId)` | Display settings and ordered Rule definitions for the card |
| `evaluateCheck(checkSetQualifiedApiName, ruleQualifiedApiName, recordId, runId, source)` | One Rule evaluation (one Apex transaction per Rule from the card) |
| `completeRun(checkSetQualifiedApiName, runId, source, recordId, resultsJson)` | After a user-initiated run: re-evaluates server-side and publishes the Set completed event |

**Notable behavior:**
- **Source behavior:** the browser may request only Lightning-allowed source values. Unknown values
 fall back to non-publishable `RUN_ON_LOAD` behavior (as documented in architecture).
- **Gotcha:** `getCheckDefinitions` distinguishes a caught `ConfigException` (logged at `DEBUG`,
 reason code passed through as-is) from any other exception (logged at `ERROR`, always rethrown as
 `LOAD_FAILED`) so a real governor-limit or NPE failure is never mistaken by the card for a genuine
 missing-Check-Set condition. `completeRun` also ignores any Rule results the browser tried to pass
 in - it always re-evaluates server-side before publishing, since a lifecycle event must reflect
 server-side counts.

**See also:** [Lightning component](../../integration/lightning-component.md)

### `RecordHealthCheckRunRuleFlowAction`

**Role:** Packaged Flow action "Run Record Health Check Rule".
**Type:** Invocable Flow action · `public with sharing`

Invocable wrapper around the scope pipeline for one qualified Rule per request. It returns the common
evaluation fields and JSON response for advanced consumers.

**Notable behavior:**
- **Gotcha:** the action validates the complete request list before evaluation and uses the shared
  scope ceiling from `RecordHealthCheckConstants`.

### `RecordHealthCheckRunSetFlowAction`

**Role:** Packaged Flow action "Run Record Health Check Set".
**Type:** Invocable Flow action · `public with sharing`

Invocable wrapper around the scope pipeline for one qualified Check Set per request. It returns the
shared summary counts and JSON response.

**Notable behavior:**
- **Gotcha:** the action validates request shape and scope size before dispatch, so malformed bulk
  input fails before partial work.

**See also:** [Flow actions](../../integration/flow-actions.md)

### `RecordHealthCheckLifecyclePublisher`

**Role:** Optional Set Run and Rule Result platform events.
**Type:** Service class · `public with sharing`

Publishes deliberate-run lifecycle events. Shipped callers attribute `APEX_API`, `FLOW`,
`USER_INITIATED`, `SCHEDULED`, `BATCH`, `QUEUEABLE`, `FUTURE`, or `AGENT` on `Source__c`.
`RUN_ON_LOAD` is never published (Lightning keeps page-load publication off). Honors Check Set
`PublishUserRunEvent__c` and Rule `PublishUserResultEvent__c`. Publishes in batches of 100, never
fails the health-check run when publish fails, and blocks publication in subscriber context to
prevent loops.

**Key members:**

| Member | Purpose |
| --- | --- |
| `CONTRACT_VERSION`, `FRAMEWORK_VERSION`, `SOURCE_*`, `PUBLISH_CHUNK_SIZE` | Event contract, Framework version, source attribution values, and the 100-row publish batch size |
| `publishResponse(...)` | Publish Rule and optional Set events for a deliberate programmatic run |
| `publishInteractiveResponse(...)` | Publish filtered outcomes for an explicit Lightning Run / Rerun |
| `isRunPublicationEnabled(...)` | Whether the Check Set's `PublishUserRunEvent__c` allows Set publication |
| `enterSubscriberContext()` | Prevent nested republication from event subscribers |

**Notable behavior:**
- **Gotcha:** `newEventId` builds a unique key from the run id and a suffix so a caller-supplied run
  id cannot exceed the platform event's `EventId__c` field. Subscriber context keeps a subscriber
  reacting to one of these events from publishing again and looping.

**See also:** [Lifecycle events](../../integration/lifecycle-events.md)

### `RecordHealthCheckRunContext`

**Role:** Run id, source, and timing for one evaluation.
**Type:** Data holder · `public` (no sharing keyword)

Holds `runId`, `source`, `startedAt`, `completedAt`, and `durationMs`. Created at the start of an
evaluation path; `complete()` stamps end time. Exposed to merge tokens (`rhcRun.*`) and used when
building lifecycle events.

**Notable behavior:**
- **Gotcha:** `complete()` is safe to call more than once - it only stamps `completedAt`/`durationMs`
 when `completedAt` is still `null`, so calling it again along a call chain cannot overwrite the
 original duration with a later, longer one.

### `RecordHealthCheckSetPicklist`

**Role:** App Builder dynamic picklist for Check Set Developer Name.
**Type:** Service class · `public with sharing`, extends `VisualEditor.DynamicPickList`

Lists active Check Set Developer Names for the page's object
(`DesignTimePageContext.entityName`). Both label and stored value are the Developer Name. When
exactly one active Check Set matches, it becomes the default so a first drop onto the page needs no
extra click.

**Notable behavior:**
- **Why it exists:** DeveloperName, not MasterLabel, is used for both the picklist label and value
 because MasterLabels are not guaranteed unique across Check Sets while the DeveloperName is. This
 also avoids configuration mistakes caused by free-text entry. When
 `entityName` is blank (for example, a template being edited outside a record page), `getValues()`
 falls back to listing every active Check Set rather than none.

---

## Related

- [Apex class reference](README.md)
- [Architecture](../framework/architecture.md)
