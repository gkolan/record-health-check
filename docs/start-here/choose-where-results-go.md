# Choose where results go

> [!NOTE]
> Use this page before adding automation or scheduling work. Every run has an immediate consumer,
> but asynchronous helpers do not retain health rows unless you select a real result destination.

## Result destinations

| Start path | Immediate result | Optional result destination |
| --- | --- | --- |
| Lightning card | Rows on the card | Check Set Run and Check Result events only after Run or Rerun when enabled |
| Flow action | Flow outputs and Result JSON | `ACTIONABLE` or `ALL` Platform Event publication |
| Direct Apex | `RecordHealthCheckResponse` | `ACTIONABLE` or `ALL` Platform Event publication |
| Queueable, Batch, or Scheduled Apex | Job or schedule ID to the submitter | Platform Events, or persistence implemented by your custom Batch |
| Agentforce action | Structured action output | None; result-event publication is forced to `NONE` |
| Agent REST or MCP | HTTP JSON | None; result-event publication is forced to `NONE` |

There is no packaged custom object, report row, email, or history record for health results.

## Choose Platform Event publication deliberately

| Publication value | What is published |
| --- | --- |
| `NONE` | No Check Set Run or Check Result events |
| `ACTIONABLE` | Check Result events with `FAIL`, `UNABLE_TO_EVALUATE`, or `ERROR`, plus one completed Set Run heartbeat for every scanned record, including all-pass and all-skipped runs |
| `ALL` | All eligible results |

For a card Run, use **Publish User Run Event** on the Check Set and **Publish User Result Event** on
each Check. Those checkboxes do not control Flow, Apex, Batch, Queueable, or Scheduled requests.

Result events publish after a successful transaction commit. If later work rolls back the
transaction, the events are not delivered. Restricted Error Log events use their own Check Set
setting and can publish immediately.

## Asynchronous warning

A completed Apex job proves that Salesforce finished executing the job. It does not mean the
records passed. The packaged Queueable, Batch, and Scheduled helpers return no health rows to the
submitter. Before scheduling them, choose one of these exits:

1. Publish `ACTIONABLE` or `ALL` and build a subscriber.
2. Write a custom Batch that stores approved fields from each `RecordHealthCheckResponse`.
3. Accept intentionally that publication `NONE` leaves no health-result history.

Batch scopes commit independently. Results from early scopes can already exist when a later scope
fails; wait for and correlate the terminal job envelope before declaring the full Batch complete.
The terminal failure cannot retract earlier committed result events.

## Avoid event loops

A Flow or Apex trigger that receives a Record Health Check Platform Event must not call the same
Check Set again without an explicit loop guard. Otherwise, one result can start another run and
publish another result indefinitely.

## Next steps

- [Choose how a Check starts](./choose-how-checks-run.md)
- [Lifecycle and publication controls](../save-results/when-to-use-platform-events.md)
- [Platform Event guides](../save-results/README.md)
- [Read Record Health Check results](../reference/results/statuses-and-labels.md)
