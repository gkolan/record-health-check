# Generate a non-agent execution workflow with AI

> [!NOTE]
> Use this page after the Check configuration is human-approved. The prompt helps a developer or
> administrator build the Flow or Apex process that runs the Check and consumes its result. It does
> not cover MCP or Agentforce.

A Check defines an evaluation. It does not by itself create a nightly job, record-triggered Flow,
durable history, notification, or event receiver. Copy the prompt below into an approved AI
assistant, append the filled requirement block, and treat the result as unreviewed source code and
metadata.

Prefer an installed Record Health Check entry point over new subscriber code. Generate custom Apex
only when the installed adapters cannot supply dynamic record selection, direct result persistence,
or the required recovery behavior.

## Copy this implementation prompt

```text
You are helping a Salesforce implementation team build a non-agent Record Health Check 2.0.10
execution and result-delivery workflow. MCP and Agentforce are outside this task.

Return an implementation proposal and complete source artifacts for human review. Do not deploy
anything and do not claim the output is production-ready. Never invent an object, field,
relationship, Check, Check Set, permission set, destination object, or integration API name. Use an
exact name supplied in the requirement or a visibly replaceable Your_Something__c placeholder.
State every unresolved API name in a final confirmation list.

Choose the smallest supported design:
1. Use the Lightning record card when a person needs the result on one record.
2. Use RecordHealthCheckRunCheckFlowAction or RecordHealthCheckRunSetFlowAction when Flow needs the
   result synchronously. Prefer the Set action when prerequisites or the complete assessment matter.
3. Use RecordHealthCheck.evaluate with RecordHealthCheckRequest when Apex needs the typed response
   synchronously.
4. Use RecordHealthCheckQueueable.enqueue for one Check Set and no more than 200 known record IDs
   when an asynchronous job ID plus optional lifecycle events is enough.
5. Use RecordHealthCheckBatch.run for one Check Set and no more than 2,000 known record IDs when the
   work must be split across transactions.
6. Use RecordHealthCheckScheduled.scheduleDaily only for a daily 2:00 AM schedule over the fixed
   record-ID snapshot captured when the schedule is created. The time is interpreted in the
   scheduling user's time zone.
   This is a fixed record-ID snapshot, not a query that discovers newly qualifying records.
7. Generate a custom Queueable when subscriber code must inspect or save a typed response after the
   submitting transaction. Generate a custom Batch with a selective QueryLocator when each run must
   discover the current record population or when subscriber-owned persistence is required in each
   execute transaction. Generate a thin Schedulable that delegates to that Batch only when a
   recurring Apex schedule is required and Scheduled Flow is not the better owner.
8. Use a Platform Event receiver only when a separate Flow, Apex trigger, or external integration
   must consume results after commit. Prefer the direct Flow or Apex response when the current
   transaction already has it.

Public contract:
- Synchronous Apex calls RecordHealthCheck.evaluate(request). Build the request with
  RecordHealthCheckRequest.forCheck(...) or forCheckSet(...), then explicitly choose result mode,
  event publication, execution origin, and an optional safe run ID.
- RecordHealthCheckQueueable.enqueue(checkSetQualifiedApiName, recordIds, publication) returns an
  AsyncApexJob ID.
- RecordHealthCheckBatch.run(checkSetQualifiedApiName, recordIds, publication) automatically
  chooses a scope from 1 through 100 and lowers it for the selected Check Set's FormulaEval budget.
  Its four-argument overload accepts a scope size from 1 through 200, rejects a size that does not
  fit the remaining formula budget, and returns an AsyncApexJob ID.
- RecordHealthCheckScheduled.scheduleDaily(jobName, checkSetQualifiedApiName, recordIds,
  publication) returns a CronTrigger ID.
- An AsyncApexJob ID is not a health result. A CronTrigger ID is not a health result. The packaged
  asynchronous adapters do not return individual outcomes to their submitter and Record Health
  Check does not save ordinary run results.
- Event publication is NONE by default. ACTIONABLE publishes FAIL, UNABLE_TO_EVALUATE, and ERROR
  Check results plus a terminal Check Set heartbeat. ALL also publishes PASS and SKIPPED.
- Automatic Lightning page-load and refresh-driven runs never publish result events.
- Preview and readiness evidence validate an exact draft and scope. They are not runtime history,
  activation approval, or an execution scheduler.

Before selecting a pattern, ask for:
- the exact Check or Check Set Qualified API Name and whether sibling prerequisites matter;
- the base object and exact record-selection rule;
- whether record IDs are known at submission time or must be queried on every run;
- typical and maximum record counts and related-query volume;
- whether the result is needed synchronously;
- the exact interactive user or automation principal and required sharing, CRUD, FLS, restriction
  rule, and scoping-rule behavior;
- the statuses that cause business action;
- whether results are transient, returned directly, saved to an approved destination, or published
  to a named receiver;
- schedule, time zone, overlap, retry, deduplication, retention, and monitoring requirements;
- exact destination object and field API names if results are saved;
- human owners for business behavior, Apex/security, Flow, integrations, and operations.

Test first:
1. Write a scenario matrix for PASS, FAIL, SKIPPED, UNABLE_TO_EVALUATE, ERROR, empty scope, null or
   duplicate IDs, invalid identities, missing permissions, maximum scope, governor pressure,
   namespace differences, schedule time zone, overlapping jobs, partial persistence failure,
   duplicate event delivery, receiver outage, and retry exhaustion. Mark a category not applicable
   only with a reason.
2. Create or identify the lowest-layer automated test that proves the requested behavior, run it
   against the missing or disabled implementation, and record the expected red test result.
3. Generate production code only after the red result. Preserve the test as a regression guard.
4. Provide exact green-test commands, expected assertions, manual sandbox setup, records, action,
   expected outcomes, and monitoring locations. Never claim a test or deployment ran unless its
   actual output was supplied.

Apex rules:
- Follow existing repository layering and naming. Use public with sharing unless a managed-package
  boundary requires global. Every executable class declares an explicit sharing keyword.
- Put SOQL and DML outside loops. Use collections, selective predicates, deterministic ORDER BY
  where order matters, and a bounded Batch scope.
- Use WITH USER_MODE for static queries and AccessLevel.USER_MODE for subscriber DML. Process
  Database.SaveResult entries when partial success is intentional.
- Do not hardcode record IDs, credentials, org URLs, or namespace prefixes. Use Named Credentials
  for callouts and exact Qualified API Names supplied by the administrator.
- Never use @future. Prefer Queueable with a Finalizer for one asynchronous transaction, Batch for a
  large or dynamically queried population, and a thin Schedulable only to delegate.
- Separate selection, orchestration, persistence, and notification responsibilities. Do not combine
  QueryLocator construction, result interpretation, DML, and notification in one large method.
- Do not log record data, formulas, queries, session information, credentials, or restricted
  diagnostics. Sanitize user-facing exceptions.
- Moving work to Queueable, Batch, Scheduled Apex, Flow system context, or a subscriber wrapper does
  not authorize bypassing Record Health Check's run permission or the intended data-access model.

Flow rules:
- Use the installed Run Record Health Check or Run Record Health Check Set action instead of a
  custom invocable wrapper when its inputs and outputs are sufficient.
- Connect an unrecoverable action fault to the organization's monitored Flow fault path. FAIL,
  SKIPPED, UNABLE_TO_EVALUATE, and ERROR are returned health outcomes, not Flow faults.
- One invocation accepts at most 200 input rows and no more than 10 distinct
  Check-or-Check-Set/publication groups. A Check Set with more than 25 active Checks is rejected
  whole.
- Branch on Status, Reason Code, and explicit Set counts. Do not parse human-readable messages.
  Parse Result JSON only when a documented field absent from the ordinary outputs is genuinely
  required.
- Prefer Scheduled Flow for a simple recurring query and action when its transaction boundaries and
  limits fit. Document how the collection is split before it reaches 200 rows.

Persistence and events:
- Record Health Check provides no general durable result-history object. Any saved normal result is
  subscriber-owned persistence with subscriber-owned CRUD/FLS, retention, reporting, and deletion.
- Use partial-success DML only with explicit per-record failure handling. Save the run ID and job ID
  when operators need correlation, but do not use a run ID as an event uniqueness key.
- Make every Platform Event receiver idempotent using the event's application Event ID. Define
  replay-position storage, bounded retries, poison-event handling, unsupported contract-version
  handling, retention beyond the event bus, allocation monitoring, and receiver outage recovery.
- Platform Event publication acceptance does not prove receiver delivery. A downstream failure does
  not change the completed health result.
- Restrict Record Health Check Log event access. It can contain technical diagnostics and is not an
  ordinary business-result channel.

Required output:
1. Plain-language architecture choice and why simpler options were rejected.
2. Confirmed requirements, unresolved questions, and exact API names still needed.
3. Entry-to-exit sequence, including principal, transaction boundaries, limits, and failure
   channels.
4. Scenario matrix and the red-before-green test plan.
5. Complete artifact inventory. Include every Apex class, test, metadata XML file, Flow,
   permission-set change, destination schema item, and operational configuration genuinely needed.
6. Complete deployable source for each authorized artifact, following project conventions. Do not
   emit placeholder source as if it compiled.
7. Result mapping for every health status and every non-health failure channel.
8. Security, bulk, schedule, persistence, event, and recovery review.
9. Exact local validation commands and a sandbox verification procedure.
10. Human approvals and deployment evidence still pending.

Do not create a custom Batch merely because the word "batch" appeared in the requirement. Use the
packaged RecordHealthCheckBatch when a bounded fixed population and Platform Events are sufficient.
Create a custom Batch only for a current QueryLocator population, direct response persistence, or
custom recovery that the packaged adapter does not provide.
```

## Append this requirement block

```text
Build the execution and result-delivery workflow for this approved Record Health Check:

- Exact Check or Check Set Qualified API Name: <value copied from Setup>
- Selection: <one Check | complete Check Set>
- Base object: <exact API name>
- Record population: <known IDs | exact current query rule>
- Typical and maximum records: <counts>
- Timing: <synchronous | enqueue now | schedule and time zone>
- Running principal: <interactive user or automation user>
- Expected access model: <sharing, CRUD/FLS, restriction/scoping rules>
- Result consumer: <current Flow/Apex | named event receiver | named saved-result owner | transient>
- Status actions: <what happens for PASS, FAIL, SKIPPED, UNABLE_TO_EVALUATE, ERROR>
- Durable history required?: <no | destination object and exact fields>
- Platform Events required?: <no | ACTIONABLE | ALL and named receiver>
- Retry, deduplication, retention, and monitoring: <requirements>
- Overlap policy: <skip, reject, serialize, or permit concurrent runs>
- Human owners: <business, Salesforce admin, Apex/security, Flow/integration, operations>
```

## Choose the generated artifact deliberately

| Requirement                                                            | Preferred artifact                                                                   |
| ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| A Flow needs an immediate decision                                     | Installed Check or Check Set Flow action                                             |
| Apex needs an immediate typed response                                 | Public Apex API                                                                      |
| Up to 200 known IDs can run later and events/job status are sufficient | Packaged Queueable                                                                   |
| Up to 2,000 known IDs need multiple transactions                       | Packaged Batch with its formula-aware automatic scope, or an explicitly tested scope |
| The same fixed population runs daily at 2:00 AM                        | Packaged Scheduled adapter                                                           |
| Each run must query the current population                             | Custom Batch, optionally started by Scheduled Flow or a thin Schedulable             |
| Async code must save returned results directly                         | Custom Queueable or Batch plus a separate persistence service                        |
| Another process must react after commit                                | Tested Platform Event receiver                                                       |
| A simple Flow can query and invoke within its documented limits        | Scheduled or autolaunched Flow                                                       |

## Human review boundary

Generated Apex requires normal code review, security review, automated tests, Code Analyzer, a
deployment dry-run, and sandbox execution. Generated Flow requires an administrator to inspect its
running context, bulk behavior, fault connectors, and every mapped input/output. Event and
persistence designs require the receiving application's owner to approve access, retry, retention,
and recovery.

## Related

- [Choose entry and exit points](./choose-entry-and-exit-points.md)
- [Run from Apex](../../developer-guides/run-from-apex.md)
- [Queueable Apex](../../developer-guides/async-apex/queueable.md)
- [Batch Apex](../../developer-guides/async-apex/batch.md)
- [Scheduled Apex](../../developer-guides/async-apex/scheduled.md)
- [Flow action inputs and outputs](../../flow-guides/action-inputs-and-outputs.md)
- [Save or send results](../../save-results/README.md)
