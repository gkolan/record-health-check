# Agentforce and MCP threat model

Audience: security architects and Agentforce or MCP implementers. If you only need to let an agent
run a Check, use [Agentforce actions](../developer-guides/agentforce-and-mcp/agentforce-actions.md).

> [!NOTE]
> Use this page to review identities, trust boundaries, and controls before enabling a Record Health
> Check Agentforce action or MCP server.

## Principals and flow

The native action remains inside Salesforce and evaluates with the configured Agentforce principal.
MCP crosses four boundaries: an approved client obtains an inbound token, calls the hosted MCP server
over HTTPS, the server obtains a separate Salesforce token, and a versioned Apex REST adapter
evaluates with a dedicated Salesforce integration principal.

The inbound MCP credential and outbound Salesforce credential require separate scopes, storage,
rotation, revocation, and audit trails. Neither credential represents the conversational user.

## Threats and controls

| Threat | Required control | Verification |
| --- | --- | --- |
| Arbitrary model input | Strict schema, no unknown fields, two-operation list | Invalid-schema tests |
| Namespace guessing | Exact `QualifiedApiName`; no alternate-name retry | Namespaced tests |
| Record probing | Salesforce sharing and user-mode access; rate limits; no denied-record disclosure | Access tests |
| Service identity mistaken for user delegation | Setup documentation; prefer native action for in-org use | Identity review |
| Prompt injection in stored text | Treat output as data; exclude display text; fixed agent instructions | Injection suite |
| Tool side effects | Read-only operations; publication `NONE`; no generic Apex or SOQL | Mutation and event tests |
| Diagnostics disclosure | Allow only four bounded, disclosure-safe diagnosis fields; exclude raw administrator diagnostics; integration user lacks diagnostics permission | Contract and restricted-user tests |
| Credential theft | Managed secrets, narrow scopes, rotation, token validation, no token logs | Rotation and log tests |
| Server-side request forgery | Salesforce host list, redirect refusal, outbound controls | Host tests |
| Excessive calls | Per-client rate, concurrency, timeout, body, and response limits | Load tests |
| Retry amplification | Retry only safe transient failures with capped backoff | Failure injection |
| Malformed Salesforce response | Contract and size validation; fail closed | Response tests |
| Cross-client response leak | Supported MCP SDK; isolated request state; concurrency tests | Parallel tests |
| Sensitive telemetry | Log field list, no bodies, retention policy, canary scan | Telemetry scan |
| Unexpected MCP tool | Agentforce Registry tool list; deployment inventory check | Tool-list test |
| Supply-chain compromise | Locked dependencies, scans, SBOM, immutable artifact | Attestation |
| Unsafe release | Staged rollout, kill switch, revocation, independent rollback | Rollback drill |

## Invariants

- `FAIL` is a completed evaluation, not a transport error.
- `UNABLE_TO_EVALUATE`, `ERROR`, missing output, and adapter failure never become `PASS`.
- MCP never claims to preserve the conversational user's Salesforce access.
- Removing **Record Health Check Run** prevents evaluation.
- Ordinary Agentforce and MCP principals can receive only the four bounded completed-evaluation
  diagnosis fields; they cannot receive raw or administrator-only diagnostics.
- Models cannot select event publication in version 1.
- MCP exposes no generic query, Apex, record update, or metadata operation.
- Logs exclude complete tool inputs and Apex responses.

Security, product, Apex, Agentforce, identity, MCP service, and operations owners must approve this
model before production. Repeat review when tools, outputs, identities, scopes, objects, hosting,
persistence, or publication behavior changes.

## Related

- [Agent tool contract](../reference/contracts/agent-tool-contract.md)
- [Security and data access](./security-and-data-access.md)
- [Configuration identity](../reference/configuration/names-and-api-identities.md)
- [Lifecycle events](../save-results/when-to-use-platform-events.md)
- [Security policy](../../.github/SECURITY.md)
