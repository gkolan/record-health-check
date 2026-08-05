# Record Health Check APIs

> [!NOTE]
> On this page, choose a synchronous or asynchronous API pattern and follow a complete example that uses the Record Health Check request contract.

Record Health Check exposes one typed Apex entry point and two Flow actions. The examples in this
section show how to use that contract from interactive automation, synchronous Apex, Queueable
Apex, Batch Apex, scheduled work, and future methods.

## Recommended path

| Step | Guide | Execution model |
| ---: | --- | --- |
| 1 | [Apex API](01-apex-api.md) | Synchronous decision in Apex |
| 2 | [Flow API](02-flow.md) | Synchronous in the Flow transaction |
| 3 | [Queueable Apex](03-queueable.md) | One bounded request in a separate transaction |
| 4 | [Batch Apex](04-batch.md) | Large populations in controlled scopes |
| 5 | [Scheduled Apex](05-scheduled.md) | Recurring health checks |
| 6 | [Move from Future to Queueable](06-future.md) | Replace an existing future method |

Prefer synchronous Apex or Flow when the current transaction needs the result. Prefer Queueable
Apex for new asynchronous work. Use Batch Apex when the record population requires multiple
transactions.

## Pick a task

### Synchronous

| I want to… | Guide |
| --- | --- |
| Make an immediate decision in Apex | [01 - Apex API](01-apex-api.md) |
| Branch in Flow Builder | [02 - Flow API](02-flow.md) |

### Asynchronous

| I want to… | Guide |
| --- | --- |
| Move one request to a separate transaction | [03 - Queueable Apex](03-queueable.md) |
| Process a large record population | [04 - Batch Apex](04-batch.md) |
| Run recurring health checks | [05 - Scheduled Apex](05-scheduled.md) |
| Replace an existing future method | [06 - Move from Future to Queueable](06-future.md) |

## Shared request contract

Every Apex example builds a `RecordHealthCheckRequest` and calls
`RecordHealthCheck.evaluate(request)`. A request selects one qualified Check Set or Rule, includes
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
- [Reason Codes](../reference/contracts/01-reason-codes.md)
- [Architecture](../reference/framework/01-architecture.md)
