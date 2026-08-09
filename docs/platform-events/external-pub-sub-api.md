# Subscribe from an external system with Pub/Sub API

> [!NOTE]
> On this page, design an external Record Health Check subscriber that authenticates with least
> privilege, resumes safely after disconnects, and separates replay position from duplicate
> processing.

Use Salesforce Pub/Sub API when middleware, a data warehouse, or an observability service needs a
real-time event stream outside Salesforce. Pub/Sub API uses gRPC and Avro; use an official
Salesforce sample client as the starting point instead of implementing the protocol from scratch.

## Choose the topic

Pub/Sub API platform-event topics use `/event/<qualified-event-api-name>`.

| Namespaced installed-package topic | Purpose |
| --- | --- |
| `/event/rhc__Record_Health_Check_Set_Run__e` | Run summaries |
| `/event/rhc__Record_Health_Check_Result__e` | Per-Check outcomes |
| `/event/rhc__Record_Health_Check_Log__e` | Restricted diagnostics |

Confirm the qualified API name in the target org. Namespace behavior differs between package-source
development and the installed namespaced unlocked package.

## Prepare access

1. Create a dedicated integration identity and an approved OAuth configuration.
2. Grant API access and Read access only to the required Platform Events. Grant Log-event access
   separately and only after a security review.
3. Store credentials in the integration platform's secret manager. Never place access tokens,
   refresh tokens, client secrets, or Salesforce auth URLs in source control or logs.
4. Confirm the org's event delivery allocation and define alerts before enabling publication.

The subscriber's destination permissions are independent of event access. Apply the destination's
own encryption, retention, deletion, and record-ID handling requirements.

## Limits and transaction boundary

The external worker runs outside the Salesforce publishing transaction. Its success or failure
cannot change the completed health-check result. Size fetch requests for the worker's real capacity,
and monitor the org's event publishing and delivery limits. For high-volume or bulk processing,
write receipts and destination records in bounded batches while preserving per-event failure detail.

## Implement the subscription

1. Authenticate and obtain the Salesforce tenant and API endpoint required by the client library.
2. Call `GetTopic` and `GetSchema`, then decode event data with the returned Avro schema. Ignore
   additive fields that the current contract version does not use.
3. Start the first subscription with `LATEST` when only new events are wanted, or `EARLIEST` for a
   deliberate backfill of events still retained on the bus.
4. Request only the number of events the worker can process. Send additional fetch requests as
   capacity becomes available; this is the subscriber's flow control.
5. Validate the contract version and required fields. Store a durable receipt keyed by
   `EventId__c`, then perform the destination action.
6. Persist the last **successfully processed** replay ID only after the receipt and required side
   effects are durable.
7. On a temporary stream failure, reconnect with `CUSTOM` and that saved replay ID. Use exponential
   backoff with jitter and alert on sustained disconnection or processing lag.

## Keep three identifiers separate

| Identifier | Do not use it for | Purpose |
| --- | --- | --- |
| `EventId__c` | Stream position | Record Health Check application-level deduplication |
| Pub/Sub event ID | Business correlation | Unique identity of the Salesforce event message |
| Replay ID | Deduplication, ordering arithmetic, or business identity | Opaque position used to resume a retained stream |

Replay IDs are not guaranteed to be contiguous or unique across every Salesforce maintenance
event. Store the value exactly as received; never increment, compare numerically, or manufacture
one. Record Health Check's `RunId__c` correlates related events but is not a unique receipt key.

## Recover safely

Salesforce guarantees high-volume event retention for 72 hours. If a saved replay ID is invalid or
outside that window, choose a documented recovery policy:

- Use `LATEST` when losing missed notifications is acceptable.
- Use `EARLIEST` to process everything still retained, accepting duplicates and load.
- Reconcile from the subscriber's durable receipts or Salesforce source data when completeness is
  required. Do not claim that the event stream can reconstruct data older than its retention window.

Handle permission errors, exhausted delivery allocations, malformed requests, and invalid replay
IDs separately from temporary service failures. A permanent event-data error belongs in a review or
dead-letter store; repeatedly reconnecting does not repair it.

Salesforce also offers `ManagedSubscribe`, which stores committed replay progress on the server,
but that RPC is Beta. Evaluate Beta support and lifecycle requirements explicitly before adopting it
for a production dependency.

## Verify before production

1. Subscribe in a sandbox and publish a deliberate run with a known Run ID.
2. Confirm field decoding, durable receipt creation, and destination behavior.
3. Deliver or replay the same event and confirm that `EventId__c` prevents a duplicate side effect.
4. Disconnect the client, publish events, reconnect with `CUSTOM`, and confirm catch-up.
5. Test an invalid contract version, a destination outage, an expired or invalid replay ID, and a
   restricted Log event.
6. Monitor connection state, last receipt time, processing lag, retry count, dead-letter count,
   event allocation usage, and age of the saved checkpoint.

## Official Salesforce references

- [Pub/Sub API overview](https://developer.salesforce.com/docs/platform/pub-sub-api/guide/intro.html)
- [Subscribe RPC and flow control](https://developer.salesforce.com/docs/platform/pub-sub-api/references/methods/subscribe-rpc.html)
- [Event message durability and replay](https://developer.salesforce.com/docs/platform/pub-sub-api/guide/event-message-durability.html)
- [Retry long-lived RPC calls](https://developer.salesforce.com/docs/platform/pub-sub-api/guide/retry-rpc-calls.html)
- [Pub/Sub API errors](https://developer.salesforce.com/docs/platform/pub-sub-api/guide/handling-errors.html)
- [Managed subscriptions (Beta)](https://developer.salesforce.com/docs/platform/pub-sub-api/guide/managed-sub.html)

## Related

- [Choose a Record Health Check event](README.md)
- [Lifecycle event behavior](../integration/lifecycle-events.md)
- [Platform Event metadata](../metadata/README.md#platform-events)
- [Operate in production](../guides/operate-in-production.md)
