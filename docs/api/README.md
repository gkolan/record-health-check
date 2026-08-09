# Record Health Check APIs

> [!NOTE]
> On this page, choose a synchronous or asynchronous API pattern and follow a complete example that uses the Record Health Check request contract.

Record Health Check exposes one typed Apex entry point and two Flow actions. The examples in this
section show how to use that contract from interactive automation, synchronous Apex, Queueable
Apex, Batch Apex, scheduled work, and future methods.

## Choose an execution model

| Guide | Execution model |
| --- | --- |
| [Apex API](apex-api.md) | Synchronous decision in Apex |
| [Flow API](flow.md) | Synchronous in the Flow transaction |
| [Queueable Apex](queueable.md) | One bounded request in a separate transaction |
| [Batch Apex](batch.md) | Known IDs up to 2,000, or custom query-backed discovery in controlled scopes |
| [Scheduled Apex](scheduled.md) | Recurring fixed IDs, or a custom scheduler for current-population discovery |
| [Move from Future to Queueable](future.md) | Replace an existing future method |

Prefer synchronous Apex or Flow when the current transaction needs the result. Prefer Queueable
Apex for new asynchronous work. Use Batch Apex when the record population requires multiple
transactions.

## Pick a task

### Synchronous

| I want to… | Guide |
| --- | --- |
| Make an immediate decision in Apex | [Apex API](apex-api.md) |
| Branch in Flow Builder | [Flow API](flow.md) |

### Asynchronous

| I want to… | Guide |
| --- | --- |
| Move one request to a separate transaction | [Queueable Apex](queueable.md) |
| Process a large record population | [Batch Apex](batch.md) |
| Run recurring health checks | [Scheduled Apex](scheduled.md) |
| Replace an existing future method | [Move from Future to Queueable](future.md) |

## Shared request contract

Every subscriber Apex example builds an `rhc.RecordHealthCheckRequest` and calls
`rhc.RecordHealthCheck.evaluate(request)`. A request selects one qualified Check Set or Check, includes
the complete record scope, and declares whether lifecycle events should publish.

The default publication mode is `NONE`. Use `ACTIONABLE` to publish `FAIL`,
`UNABLE_TO_EVALUATE`, and `ERROR` outcomes, or `ALL` to publish every outcome.

## Design requirements

- Keep each request within the public record and planned-evaluation limits.
- Use Custom Metadata `QualifiedApiName`, including the namespace prefix when Salesforce returns one.
- Treat `FAIL` as a normal business result, not an Apex exception.
- Handle `SKIPPED`, `UNABLE_TO_EVALUATE`, and `ERROR` explicitly.
- Preserve `runId` when work crosses transaction or system boundaries.
- Test with the access used by the real Flow, Apex job, or integration user.
- Persist results only when the use case requires history and has an access and retention design.

## Related

- [Platform Event subscriptions](../platform-events/README.md)
- [Integration overview](../integration/README.md)
- [Reason Codes](../reference/contracts/reason-codes.md)
- [Architecture](../reference/framework/architecture.md)
