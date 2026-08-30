# Apex entry points (L5)

> [!IMPORTANT]
> **Audience: package contributors and Salesforce developers.** This class-level reference is not a
> Setup or Flow walkthrough. Administrators should use the Flow, configuration, and evaluation
> guides; subscriber developers should use the public Apex API or Apex Check contract.

> [!NOTE]
> Use this page to identify the package class behind each supported way to start a health check or
> publish its results. Follow the linked task guide when you need working setup steps and examples.

This page is part of the [Apex class reference](./README.md). For the architecture story, see
[Architecture](../framework.md).

## Entry points (L5)

### `RecordHealthCheck`

**Role:** Run a Check or Check Set from Apex and return its results.

**Type:** Service class · `global with sharing`

Pass a `RecordHealthCheckRequest` containing the exact Check or Check Set Qualified API Name, the
record IDs to check, the type of response needed, whether to publish Platform Events, and an optional
run ID. The method returns one `RecordHealthCheckResponse` containing the results.

**Key members:**

| Member | Purpose |
| --- | --- |
| `evaluate(RecordHealthCheckRequest)` | Run the requested Check or Check Set and return a `RecordHealthCheckResponse` |

**Notable behavior:**

- **When to use it:** any Apex process that needs typed results for one Check or every active Check in
  one Check Set.
- **Important:** copy the Check or Check Set's exact **Qualified API Name** from Setup. An item created
  by an administrator in your org might be `My_Account_Checks`. An item included with the installed
  package can begin with `rhc__`. Do not use its label and do not add or remove `rhc__`.

**See also:** [Reference: Apex API](../../developer-guides/run-from-apex.md)

### `RecordHealthCheckController`

**Role:** Load and run Checks for the Record Health Check Lightning card.

**Type:** Service class · `public with sharing`

Exposes five card operations and nothing else. It cleans up the card's inputs, identifies whether the
run came from page load or a button click, and passes the work to the package classes that load and
run the Checks.

**Key members:**

| Member | Purpose |
| --- | --- |
| `getCheckSetAvailabilityForRecord(recordId)` | Active/inactive Check Sets for the record's object (setup banner) |
| `getCheckSetShellConfig(checkSetQualifiedApiName)` | Lightweight active Check Set run mode, card text, active Check count, and Run-button presentation used before definitions load |
| `getCheckDefinitions(checkSetQualifiedApiName, recordId, runId)` | Display settings and ordered Check definitions for the card |
| `evaluateCheck(checkSetQualifiedApiName, checkQualifiedApiName, recordId, runId, source)` | One Check evaluation (one Apex transaction per Check from the card) |
| `completeRun(checkSetQualifiedApiName, runId, source, recordId, resultsJson)` | After a user-initiated run: filters completed card results, calculates the summary, and publishes the Set completion event |

**Notable behavior:**

- **Source behavior:** the browser may request only Lightning-allowed source values. Unknown values
  are treated as `RUN_ON_LOAD`, which does not publish health-result Platform Events.
- **Important:** `getCheckDefinitions` distinguishes a caught `ConfigException` (logged at `DEBUG`,
  reason code passed through as-is) from any other exception (logged at `ERROR` and returned as
  `LOAD_FAILED`). The card can therefore distinguish an invalid setup from an unexpected Apex
  failure. `completeRun` does not run the Checks again. It accepts only the current record, one
  result for each Check in the selected Check Set, and a `USER_INITIATED` source before calculating
  the summary and publishing the configured events.

**See also:** [Lightning component](../../lightning-record-page/configure-the-component.md)

### `RecordHealthCheckRunCheckFlowAction`

**Role:** Run one Check for each input record in Flow.

**Type:** Invocable Flow action · `public with sharing`

This class provides the installed **Run Record Health Check** Flow action. Each input supplies a Check
Qualified API Name, one record ID, and `NONE`, `ACTIONABLE`, or `ALL` for Platform Event publication.
Each output contains success or error details, Status, Reason Code, and the complete result as JSON.

**Notable behavior:**

- **Important:** the action checks the entire input collection before running any Checks. It accepts
  no more than 200 input rows in one Flow action call.

### `RecordHealthCheckRunSetFlowAction`

**Role:** Run every active Check in one Check Set for each input record in Flow.

**Type:** Invocable Flow action · `public with sharing`

This class provides the installed **Run Record Health Check Set** Flow action. Each output contains
success or error details, an overall Status, the PASS/FAIL/SKIPPED/UNABLE_TO_EVALUATE/ERROR counts,
and the complete response as JSON.

**Notable behavior:**

- **Important:** the action checks the request fields and the number of inputs before running any
  Checks. Invalid bulk input therefore does not leave a partly completed run.

**See also:** [Flow actions](../../flow-guides/action-inputs-and-outputs.md)

### `RecordHealthCheckValidateMetadataAction`

**Role:** Validate Record Health Check configuration from an administrator Flow.

**Type:** Invocable Flow action · `global with sharing`

The installed **Validate Record Health Check Configuration** action audits every Check Set and
Check, including inactive drafts. It returns whether the configuration is valid, error and warning
counts, and a JSON report that identifies each component, field, reason code, and message.

**Notable behavior:**

- The action uses the same query-shape, required-field, and dependency validators as runtime.
- Add it to an administrator-only Flow and correct every error before activation.

### `RecordHealthCheckRunCheckAgentAction`

**Role:** Run one exact Check for one record as a native Agentforce action.

**Type:** Invocable Agentforce action · `public with sharing`

This class provides **Run Record Health Check for Agentforce**. It accepts exactly one record ID,
one exact Check Qualified API Name, and an optional safe correlation ID. It fixes event publication
to `NONE`, attributes execution to `AGENT`, and returns versioned structured fields without display
or diagnostic data.

**Notable behavior:**

- **Important:** `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, and `ERROR` remain completed health
  results. Authorization, request, limit, and execution problems use a separate safe error channel.

### `RecordHealthCheckRunSetAgentAction`

**Role:** Run one exact Check Set for one record as a native Agentforce action.

**Type:** Invocable Agentforce action · `public with sharing`

This class provides **Run Record Health Check Set for Agentforce**. It returns the strongest Set
status and explicit PASS, FAIL, SKIPPED, UNABLE_TO_EVALUATE, and ERROR counts under agent tool
contract version `1.0`.

**Notable behavior:**

- **Important:** the action accepts one input only. It never exposes event-publication choice, raw
  serialized results, display values, or administrator diagnostics to the model.

**See also:** [Agentforce actions](../../developer-guides/agentforce-and-mcp/agentforce-actions.md)

### `RecordHealthCheckAgentRestResource`

**Role:** Expose the two approved agent tool operations to a separately authenticated service.

**Type:** Apex REST resource · `global with sharing`

This class accepts one strict JSON request at the versioned agent tool route. It fixes publication to
`NONE`, attributes execution to `AGENT`, and returns contract version `1.0`. Completed health results
use HTTP `200`; adapter authorization, validation, limit, and execution failures use separate safe
HTTP and JSON responses.

**Notable behavior:**

- **Important:** unknown JSON fields, generic operations, multi-record input, unsafe correlation IDs,
  and alternate configuration identities are rejected before evaluation. Response objects exclude
  display data and diagnostics.

**See also:** [Agent tool REST API](../../developer-guides/agentforce-and-mcp/agent-tool-rest-api.md)

### `RecordHealthCheckLifecyclePublisher`

**Role:** Publish optional Check Result and Check Set Run Platform Events.

**Type:** Service class · `public with sharing`

Publishes events for deliberately started runs. Package callers identify the source as `APEX_API`,
`FLOW`, `USER_INITIATED`, `SCHEDULED`, `BATCH`, `QUEUEABLE`, `FUTURE`, or `AGENT` on `Source__c`.
`RUN_ON_LOAD` is never published. For Apex, Flow, Batch, and other programmatic runs, the request's
`NONE`, `ACTIONABLE`, or `ALL` value controls publication. For a person clicking Run or Rerun on the
Lightning card, the Check Set's `PublishUserRunEvent__c` and each Check's
`PublishUserResultEvent__c` settings control publication. The class publishes up to 100 events in
each EventBus call and logs a publication failure without failing the health check itself.

**Key members:**

| Member | Purpose |
| --- | --- |
| `CONTRACT_VERSION`, `FRAMEWORK_VERSION`, `SOURCE_*`, `PUBLISH_CHUNK_SIZE` | Event contract version, package version reported by the event, source values, and the 100-event publish group size |
| `publishResponse(...)` | Publish Check and optional Set events for a deliberate programmatic run |
| `publishInteractiveResponse(...)` | Publish filtered outcomes for an explicit Lightning Run / Rerun |
| `isRunPublicationEnabled(...)` | Whether the Check Set's `PublishUserRunEvent__c` allows Set publication |
| `enterSubscriberContext()` | Package-internal loop guard; custom Apex in an org that installs the package cannot call this `public` method through the `rhc` namespace |

**Notable behavior:**

- **Important:** `newEventId` builds a unique key from the run id and a suffix so a caller-supplied run
  id cannot exceed the platform event's `EventId__c` field. An internal setting prevents the
  package's own event-handling code from publishing the same event again. A Flow or Apex trigger
  that receives these events must also avoid starting the same health check again, or it can create
  a loop.

**See also:** [Lifecycle events](../../save-results/when-to-use-platform-events.md)

### `RecordHealthCheckEventId`

**Role:** Generate unique, bounded application identifiers for lifecycle-event publications.

**Type:** Utility class · `public with sharing`

`newId(runId, eventIdentity)` preserves up to 50 characters of the caller-owned Run ID as an
operational prefix and hashes the run, event identity, current time, a cryptographic random value,
and a transaction-local sequence into a 16-character suffix. Separate publications therefore have
different `EventId__c` values even when a caller deliberately reuses the same Run ID. A replay of
the same Platform Event retains its original ID, so subscriber deduplication remains safe.

**Notable behavior:**

- **Important:** `RunId__c` remains the correlation key; it is not an event-uniqueness key.
- Generated IDs are at most 67 characters and fit the event contract's Text(80) field.

**See also:** [Check Result events](../../save-results/save-individual-results.md)

### `RecordHealthCheckRunContext`

**Role:** Store the run ID, source, and elapsed time for one health-check request.

**Type:** Data holder · `public` (no sharing keyword)

Holds `runId`, `source`, `startedAt`, `completedAt`, and `durationMs`. Created at the start of an
evaluation path; `complete()` stamps end time. Exposed to merge tokens (`rhcRun.*`) and used when
building lifecycle events.

**Notable behavior:**

- **Important:** `complete()` is safe to call more than once. It sets `completedAt` and `durationMs`
  only the first time, so a later call cannot replace the original completion time.

### `RecordHealthCheckSetPicklist`

**Role:** Provide the Check Set list shown in Lightning App Builder.

**Type:** Service class · `public with sharing`, extends `VisualEditor.DynamicPickList`

Lists active Check Sets that match the Lightning record page's Salesforce object. App Builder shows
each Check Set's label and stores its exact Qualified API Name. When exactly one active Check Set
matches, the component selects it automatically.

**Notable behavior:**

- **Why it exists:** the list avoids mistakes caused by typing a Check Set name manually. The label
  helps the administrator recognize the Check Set, while the stored Qualified API Name keeps an
  administrator-created item such as `My_Account_Checks` distinct from an installed-package item
  such as `rhc__Example_Account_Check_Builder_Guide`. When App Builder does not provide an object name, such as
  while editing a template outside a record page, the list shows every active Check Set.

---

## Related

- [Apex class reference](./README.md)
- [Architecture](../framework.md)
