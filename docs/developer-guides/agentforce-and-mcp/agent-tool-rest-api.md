# Agent tool REST API

This guide is for integration developers.

> [!NOTE]
> Use this API only as the Salesforce boundary for an approved Agentforce or MCP service identity.
> Native in-org Agentforce actions remain the preferred user-context integration.

> [!IMPORTANT]
> **Audience: Salesforce and integration developers.** This is not an Agentforce Builder Setup
> guide. Card and Flow administrators should use the Lightning or Flow pages instead.

## Choose this integration

The version 1 REST API exposes two read-only operations over one `POST` endpoint. It exists so a
separately hosted MCP server can call the same Record Health Check engine used by Lightning, Flow,
Apex, and native Agentforce actions.

Use the native [Agentforce actions](./agentforce-actions.md) when evaluation must use the configured
Agentforce principal. Use this REST API only when the dedicated integration principal's access model
is approved for the business purpose.

## Endpoint

The unpackaged development route is:

```text
/services/apexrest/record-health-check/contract-1/evaluations
```

Salesforce adds the package namespace segment for a namespaced installation. Confirm the installed
route during package verification. For the `rhc` namespace, the expected route is:

```text
/services/apexrest/rhc/record-health-check/contract-1/evaluations
```

The resource accepts `POST` with `Content-Type: application/json`. Other methods are not exposed.

## Access

The Salesforce user associated with the OAuth token is the running integration principal. Assign
that user the following minimum package access:

- **Record Health Check Run** (`rhc__Record_Health_Check_Run`);
- Apex class access to `RecordHealthCheckAgentRestResource` and `RecordHealthCheck`;
- read access to both Record Health Check Custom Metadata Types; and
- read access, field access, sharing, restriction-rule access, and scoping-rule access required for
  the target records and configured Checks.

The packaged **Record Health Check User** Permission Set includes package entry-point access but also
includes other supported package surfaces and result-event access. For a dedicated integration user,
an administrator can create a narrower org-owned Permission Set containing only the listed access.
Do not grant the diagnostics Custom Permission to the integration principal.

Use a Salesforce External Client App or supported connected app with a dedicated integration user,
client-credentials policy, narrow OAuth scopes, managed secret storage, rotation, and revocation.

In Setup, create an organization-owned Permission Set for the integration principal. Under **Custom
Permissions**, enable **Record Health Check Run**; under **Apex Class Access**, add the REST resource
and public framework entry point; under **Custom Metadata Types**, grant read access to both Record
Health Check types; and under **Object Settings**, grant only the target objects and fields required
by approved Checks. Assign it only to the dedicated integration user.

The endpoint is read-only with respect to business data. It always forces result-event publication
to `NONE`, so an MCP or REST caller cannot produce Check Set Run or Check Result Platform Events.

## Basic request pattern

Run one Check:

```json
{
  "operation": "RUN_CHECK",
  "recordId": "001000000000001AAA",
  "qualifiedApiName": "Account_Name_Required",
  "correlationId": "mcp-request-42"
}
```

Run one Check Set by changing `operation` to `RUN_CHECK_SET` and supplying the exact Check Set
`QualifiedApiName`.

The API rejects unknown JSON fields. It never adds or removes `rhc__`, retries alternate identities,
accepts arbitrary SOQL or Apex, or lets the caller choose event publication. The request body limit
is 16,384 bytes.

## Completed evaluation

Every completed evaluation uses HTTP `200`, including business `FAIL`, `SKIPPED`,
`UNABLE_TO_EVALUATE`, and `ERROR` results. A Check response follows this shape:

```json
{
  "contractVersion": "1.0",
  "correlationId": "mcp-request-42",
  "success": true,
  "operation": "RUN_CHECK",
  "status": "FAIL",
  "reasonCode": "VALUE_MISSING"
}
```

A Check Set response replaces `reasonCode` with `passed`, `failed`, `skipped`, `unable`, and
`systemError` counts. The strongest Set status uses this order:

```text
ERROR -> UNABLE_TO_EVALUATE -> FAIL -> PASS -> SKIPPED
```

An HTTP client must not treat HTTP `200` alone as a healthy result. Read `success`, then `status` and
the explicit counts.

## Adapter errors

| HTTP status | Error type | Meaning |
| ---: | --- | --- |
| `400` | `VALIDATION` | Invalid JSON, operation, ID, configuration identity, or evaluation selection |
| `403` | `AUTHORIZATION` | The Salesforce integration principal lacks the run entitlement |
| `413` | `LIMIT` | Request body exceeds 16,384 bytes |
| `415` | `VALIDATION` | Content type is not JSON |
| `500` | `EXECUTION` | An unexpected adapter or evaluator failure prevented completion |

Adapter errors return `success=false`, a safe error type, and a safe message. They do not include a
health status, query, formula, stack trace, exception text, record value, token, session ID, or
administrator diagnostic.

## Limits and security behavior

- One request evaluates one record and one exact Check or Check Set.
- Event publication is always `NONE`.
- Execution is attributed to `AGENT` for lifecycle context shared by approved agent and tool callers.
- The checked record remains unchanged.
- Salesforce user-mode queries and sharing enforce the integration principal's access.
- Record absence and inaccessible data never authorize an elevated comparison query.
- Correlation IDs use at most 120 restricted characters and never grant access.

## Verification

Before connecting an MCP server, verify these cases in a non-production subscriber-style org:

1. Namespaced and unpackaged endpoint routes.
2. One completed response for each of the five statuses.
3. Exact administrator-created and packaged qualified API names.
4. Missing run permission, missing record sharing, and missing field access.
5. Unknown JSON property, operation, and configuration identity.
6. Wrong content type and oversized body.
7. Fatal evaluator failure returns a generic HTTP `500` response.
8. No result event is published and no checked record is modified.

## Related

- [Agent tool contract](../../reference/contracts/agent-tool-contract.md)
- [Agentforce and MCP threat model](../../architecture/agentforce-and-mcp-threat-model.md)
- [Agentforce actions](./agentforce-actions.md)
- [Security and data access](../../architecture/security-and-data-access.md)
