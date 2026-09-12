# Choose entry and exit points for an AI-drafted Check

> [!NOTE]
> Use this page after the AI has described the business rule and before anyone activates the Check.
> It covers the supported administrator, Lightning, Flow, and Apex paths. Agentforce and MCP have
> separate contracts and are outside this decision.

A correct formula, query, or Apex plugin is only the evaluation rule. A complete implementation
also identifies who starts it, whose Salesforce access applies, whether the answer is needed now or
later, and where the result goes. Record Health Check does not save ordinary run results by itself.

## Configuration and verification entry points

| Entry point                                                                | What enters Record Health Check                                                 | What comes back or changes                                                          | Important boundary                                                                       |
| -------------------------------------------------------------------------- | ------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| Salesforce Setup                                                           | Saved Check Set and Check Custom Metadata                                       | Inactive or active configuration                                                    | Save AI drafts inactive; Setup does not prove runtime behavior.                          |
| Metadata deployment                                                        | Version-controlled Custom Metadata and any Apex plugin                          | Deployed configuration and code                                                     | Deployment success is not business approval or outcome verification.                     |
| Validate Record Health Check Configuration Flow action                     | Saved active and inactive configuration                                         | Valid flag, counts, and structured JSON findings                                    | This audits configuration; it does not run the business outcomes.                        |
| Record Health Check Preview component or `RecordHealthCheckPreviewService` | One detached Check, an existing parent Check Set, and representative record IDs | Findings, capabilities, optional execution results, and optional readiness evidence | Preview publishes no result or error-log events and does not save or activate the Check. |

Use [Validate and preview an AI draft](./validate-and-preview-an-ai-draft.md) for the exact Preview
workflow. A readiness receipt is private, expiring evidence for the exact actor, org, definition,
Check Set, mode, and record scope. It is not ordinary result history and is not human approval.

## Runtime entry points

| Runtime caller               | Selection and timing                                                                             | Immediate return                                                                      | Where health outcomes go                                                                                                                                        |
| ---------------------------- | ------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Lightning record card        | One configured Check Set on one record; page-load or explicit Run/Rerun                          | Rendered card rows, summary, actions, and permitted diagnostics                       | The browser only, unless an explicit Run/Rerun uses enabled user-result publication. Page-load and refresh-driven runs never publish result events.             |
| Flow actions                 | One Check or one Check Set per input; synchronous within the Flow transaction                    | Success/error channel, status, reason or counts, and evaluation JSON                  | The Flow should branch on the returned fields. Select event publication only for a separate consumer.                                                           |
| Public Apex API              | One Check or one Check Set for a bounded record list; synchronous                                | Typed `RecordHealthCheckResponse`, with evaluation, optional display, or summary mode | The caller can act on or save the response. Event publication is optional and independent of the returned response.                                             |
| `RecordHealthCheckQueueable` | One Check Set for known record IDs; asynchronous                                                 | `AsyncApexJob` ID when accepted                                                       | The packaged job does not return outcomes to its submitter. Publish events, use a custom Queueable that saves the typed response, or accept transient outcomes. |
| `RecordHealthCheckBatch`     | One Check Set over a bounded known population, split across transactions                         | `AsyncApexJob` ID when accepted                                                       | The packaged Batch can publish events. A custom Batch can save returned results during `execute`; otherwise the outcomes are transient.                         |
| `RecordHealthCheckScheduled` | One Check Set and a fixed record-ID population captured when scheduled; later delegates to Batch | `CronTrigger` schedule ID                                                             | Follow the later Batch job and its configured event or subscriber-owned persistence path. Newly qualifying records are not discovered automatically.            |

Use a Check Set rather than a single Check whenever sibling prerequisites or the complete assessment
matter. Single-Check Lightning, Flow, and Apex calls do not enforce the selected Check's sibling
prerequisite.

The card, Flow, and Apex paths all apply the effective running user's sharing and object, field, and
record access. Moving work to Queueable, Batch, or Scheduled Apex does not elevate access. Test with
the actual interactive user or automation principal, including restriction and scoping rules.

## Exit points and ownership

| Exit                                           | Contract                                                                                               | Owner and recovery decision                                                                                                                     |
| ---------------------------------------------- | ------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| Lightning display                              | Human-readable status, messages, values, links, and optional diagnostics                               | Product owner approves wording; administrator tests the real page and user.                                                                     |
| Flow outputs                                   | Machine status/counts plus evaluation JSON; faults use a separate Flow fault path                      | Flow owner handles every health status and connects the fault path.                                                                             |
| Apex response                                  | Typed results, summary, and optional authorized display data; request/authorization failures can throw | Apex owner handles business results separately from exceptions and avoids logging restricted data.                                              |
| Async job and schedule IDs                     | Salesforce platform execution state, not health outcome state                                          | Automation owner monitors Apex Jobs/Scheduled Jobs and separately proves where outcomes went.                                                   |
| Check Result and Check Set Run Platform Events | Optional public lifecycle results published after commit                                               | Integration owner provides idempotency through the event's application Event ID, retention, retry, access, allocation, and receiver monitoring. |
| Record Health Check Log Platform Event         | Optional restricted `ERROR` diagnostics                                                                | Security/operations owner limits publisher and subscriber access and protects any stored copy.                                                  |
| Preview readiness receipt                      | Private, immutable, expiring verification evidence                                                     | Release owner decides whether evidence is required and cleans up expired receipts.                                                              |
| Subscriber-owned records or external storage   | Organization-defined durable history                                                                   | The subscriber owns schema, CRUD/FLS, retention, deduplication, partial-save recovery, and reporting.                                           |

Platform Event acceptance does not prove receiver delivery. A receiver failure cannot change the
already completed health result. With publication `NONE` and no subscriber-owned saving,
asynchronous results are not durable.

## Questions the AI must answer

Do not approve the draft until its execution and result-delivery plan answers all of these:

1. Which exact entry point starts the Check, and does it run one Check or the complete Check Set?
2. Who is the actual running principal, and what data and Apex access will that principal have?
3. Is the answer required synchronously, or can an asynchronous job produce it later?
4. What are the typical and maximum record scopes, including related-query volume?
5. Does the current caller consume a direct response, or is a separate result receiver necessary?
6. If results must persist, which subscriber-owned object or external system saves them?
7. If events are enabled, who owns deduplication, retries, retention, allocation, and monitoring?
8. How are health statuses kept separate from Flow faults, Apex exceptions, failed jobs,
   publication warnings, and downstream receiver failures?
9. Which human proves the complete path with PASS, FAIL, SKIPPED, UNABLE_TO_EVALUATE, ERROR, null,
   permission-restricted, bulk, and recovery cases?

When the selected caller or consumer has not been built, continue with
[Generate a non-agent execution workflow with AI](./execution-workflow-generator.md). That prompt
prefers the installed adapters and generates subscriber code only for dynamic selection, direct
persistence, or custom recovery.

## Related

- [Draft Check configuration with AI](./README.md)
- [Flow action inputs and outputs](../../flow-guides/action-inputs-and-outputs.md)
- [Run from Apex](../../developer-guides/run-from-apex.md)
- [Queueable Apex](../../developer-guides/async-apex/queueable.md)
- [Batch Apex](../../developer-guides/async-apex/batch.md)
- [Scheduled Apex](../../developer-guides/async-apex/scheduled.md)
- [Save or send results](../../save-results/README.md)
- [Apex entry points](../../architecture/apex-implementation/entry-points.md)
- [Generate a non-agent execution workflow](./execution-workflow-generator.md)
