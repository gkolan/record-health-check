# Receive events in an external system with Pub/Sub API

This guide is for integration developers.

> [!NOTE]
> On this page, design an external Record Health Check integration that authenticates with least
> privilege, resumes safely after disconnects, and separates replay position from duplicate
> processing.

> [!IMPORTANT]
> **Audience: external integration engineers.** Pub/Sub API, gRPC, Avro, Replay IDs, and
> ManagedSubscribe are not Salesforce Setup features. Use a Platform Event-triggered Flow instead
> when the work can stay inside Salesforce.

Use Salesforce Pub/Sub API when middleware, a data warehouse, or a monitoring service must receive
Record Health Check Platform Events outside Salesforce. Pub/Sub API uses gRPC over HTTP/2 and sends
event data in Apache Avro format. Start with an official Salesforce sample client instead of
building the protocol yourself.

For example, an integration can receive one Check Set Run event per Account, save it in a data
warehouse, and update a long-term health trend report.

Pub/Sub API is currently available in Enterprise, Performance, Unlimited, and Developer Editions.
It is not available in Government Cloud. Confirm current Salesforce availability and allocations
before designing a production dependency.

## Choose the topic

Pub/Sub API platform-event topics use `/event/<qualified-event-api-name>`.

| Topic after installing the `rhc` package | What it carries |
| --- | --- |
| `/event/rhc__Record_Health_Check_Set_Run__e` | Run summaries |
| `/event/rhc__Record_Health_Check_Result__e` | Per-Check outcomes |
| `/event/rhc__Record_Health_Check_Log__e` | Restricted diagnostics |

The installed Record Health Check package uses the `rhc__` namespace shown above. Confirm the exact
event API name in the Salesforce org the integration connects to; do not add or remove `rhc__`.

## Prepare access

1. Create a dedicated Salesforce integration user and an approved OAuth configuration.
2. Grant API access and Read access only to the required Platform Events. Grant Log-event access
   separately and only after a security review.
3. Store credentials in the integration platform's secret manager. Never place access tokens,
   refresh tokens, client secrets, or Salesforce auth URLs in source control or logs.
4. Confirm the org's event delivery allocation and define alerts before enabling publication.

Create the External Client App or supported Connected App through the organization's Salesforce
identity standard. Use a dedicated integration user, an approved OAuth flow, API access, and Read
access only to the required event objects. This page does not prescribe a universal client-secret
or certificate policy; follow the security owner's rotation and revocation requirements.

The external system's destination permissions are independent of Salesforce event access. Apply the
destination's own encryption, retention, deletion, and record-ID handling requirements.

## Limits and transaction boundary

The external integration runs outside the Salesforce transaction that published the event. Its
success or failure cannot change the completed health-check result. Size fetch requests for the
integration's real capacity, up to Salesforce's maximum of 100 requested events per FetchRequest,
and monitor the org's event publishing and delivery limits. For high-volume processing, write
receipts and destination records in bounded groups while preserving each event's failure details.

## Implement the subscription

1. Authenticate the dedicated integration user and supply the access token, instance URL, and tenant
   ID headers required by the client.
2. Call `GetTopic` and `GetSchema`, then decode event data with the returned Avro schema. Ignore
   additive fields that the current contract version does not use.
3. Start the first subscription with `LATEST` when only new events are wanted, or `EARLIEST` for a
   deliberate backfill of events still retained on the bus.
4. Set `num_requested` to the number of events the integration can process, up to 100. Send another
   FetchRequest as capacity becomes available. This is Pub/Sub API flow control.
5. Validate the contract version and required fields. Store a durable receipt keyed by
   `EventId__c`, then perform the destination action.
6. After durable processing, save the Replay ID from the last processed event. If a later empty
   keepalive response arrives, save its Replay ID instead because it represents the later received
   stream position. Store the bytes exactly as received; do not compare them numerically.
7. On a temporary stream failure, reconnect with `CUSTOM` and the saved Replay ID. Use exponential
   backoff with jitter and alert on sustained disconnection or processing lag.

## Keep three identifiers separate

| Identifier | Do not use it for | Purpose |
| --- | --- | --- |
| `EventId__c` | Stream position | Record Health Check application-level deduplication |
| Pub/Sub event ID | Business correlation or stream position | Unique identity assigned to the Salesforce event message |
| Replay ID | Deduplication, ordering arithmetic, or business identity | Opaque position used to resume a retained stream |

Replay IDs are not guaranteed to be contiguous or unique across every Salesforce maintenance
event. Store them as opaque bytes exactly as received; never increment, compare numerically, or
manufacture one. Record Health Check's `RunId__c` connects related events but is not a unique
receipt key.

## Recover safely

Salesforce stores high-volume Platform Events for 72 hours. Events can remain available longer, but
Salesforce does not guarantee storage beyond 72 hours. If a saved Replay ID is invalid or outside
that window, choose a documented recovery policy:

- Use `LATEST` when losing missed notifications is acceptable.
- Use `EARLIEST` to process everything still retained, accepting duplicates and load.
- Reconcile from the integration's durable receipts or Salesforce source records when completeness
  is required. Do not claim that the event stream can reconstruct data older than its retention
  window.

Handle permission errors, exhausted delivery allocations, malformed requests, and invalid replay
IDs separately from temporary service failures. A permanent event-data error belongs in a review or
dead-letter store; repeatedly reconnecting does not repair it.

Salesforce also offers `ManagedSubscribe`, which stores committed Replay ID progress on the server,
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

- [Choose a Record Health Check event](../save-results/README.md)
- [Lifecycle event behavior](../save-results/when-to-use-platform-events.md)
- [Platform Event metadata](../reference/platform-event-metadata/README.md)
- [Operate in production](../production-operations/operate-in-production.md)
