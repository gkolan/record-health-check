# Choose how a Check starts

> [!NOTE]
> Use this page to choose the supported entry point for a Record Health Check run. Record Health
> Check does not run merely because a Salesforce record or Custom Metadata record is saved.

Choose the person or process that needs to start evaluation, then follow the linked guide.

## Supported start paths

| Who or what starts the run | Entry point | Best for | Continue with |
| --- | --- | --- | --- |
| A person opens a record | Lightning card with **When the page opens** | Immediate advisory guidance on one record | [Add the Lightning card](../lightning-record-page/configure-the-component.md) |
| A person selects Run or Rerun | Lightning card with **When the user clicks Run** | Deliberate review of one record | [Add the Lightning card](../lightning-record-page/configure-the-component.md) |
| A Flow | **Run Record Health Check Set** or **Run Record Health Check** action | Automation that needs the result in the same Flow interview | [Flow actions](../flow-guides/action-inputs-and-outputs.md) |
| Apex in the current transaction | `rhc.RecordHealthCheck.evaluate` | Code that must branch on the response immediately | [Apex API](../developer-guides/run-from-apex.md) |
| Queueable Apex | `rhc.RecordHealthCheckQueueable.enqueue` | Up to 200 known record IDs processed later | [Queueable API](../developer-guides/async-apex/queueable.md) |
| Packaged Batch Apex | `rhc.RecordHealthCheckBatch.run` | 1 to 2,000 known record IDs | [Batch API](../developer-guides/async-apex/batch.md) |
| Custom Batch Apex | Your `Database.Batchable` calls `evaluate` | A query locator or custom persistence requirement | [Batch API](../developer-guides/async-apex/batch.md) |
| Scheduled Apex | Your schedulable class or packaged scheduling helper | Recurring asynchronous evaluation | [Scheduled API](../developer-guides/async-apex/scheduled.md) |
| Agentforce | Packaged Check or Check Set action | An agent that needs structured health results | [Agentforce actions](../developer-guides/agentforce-and-mcp/agentforce-actions.md) |
| Hosted service or MCP client | Agent REST resource | A reviewed server-side integration | [Agent REST API](../developer-guides/agentforce-and-mcp/agent-tool-rest-api.md) |

Do not create new `@future` integrations. Move existing work to Queueable Apex.

## These actions do not start a run

- Saving an Account, Contact, Opportunity, or other business record
- Saving a Record Health Check Custom Metadata record
- Adding the component to an App page or Home page; the component supports record pages
- Receiving a Platform Event, unless your own subscriber explicitly calls a Flow or Apex entry point
- Running a Validation Rule; Record Health Check is advisory and does not block the save

## Important limits at the start

| Surface | Limit or behavior |
| --- | --- |
| Lightning card | Evaluates one record and the first 25 active Checks in the selected Check Set |
| Direct Apex or one Flow request group | Up to 200 records and 25 active Checks |
| One Flow action call | Up to 10 distinct Check or Check Set and Event Publication groups |
| Queueable helper | Up to 200 known record IDs |
| Packaged Batch helper | 1 to 2,000 known record IDs; default scope size 100 |
| Agentforce and REST | Event publication is always `NONE` |

## Card load versus Run

Opening or refreshing a record page can evaluate the card, but a load never publishes Check Set Run
or Check Result events. An explicit Run or Rerun can publish those events when the Check Set and
Check publication settings are enabled. Error Log publication is a separate setting.

## Next steps

- [Where results can go](./choose-where-results-go.md)
- [Read Record Health Check results](../reference/results/statuses-and-labels.md)
- [Compare Record Health Check with native Salesforce](./when-to-use-record-health-check.md)
