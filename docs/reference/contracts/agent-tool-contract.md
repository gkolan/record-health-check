# Agent tool contract

Audience: Agentforce, REST, and MCP integrators. If you are not connecting an agent or MCP client,
you can ignore this contract. Administrators enabling native actions should use
[Agentforce actions](../../integration/agentforce-actions.md).

> [!NOTE]
> Use this contract when a native Agentforce action, Apex REST adapter, or MCP tool evaluates one
> Record Health Check or Check Set for one Salesforce record.

## Boundary

Version 1 supports two read-only operations:

| Operation | Selection | Records |
| --- | --- | ---: |
| `RUN_CHECK` | One exact Check `QualifiedApiName` | 1 |
| `RUN_CHECK_SET` | One exact Check Set `QualifiedApiName` | 1 |

The contract excludes record updates, arbitrary SOQL, arbitrary Apex, metadata changes, batch
evaluation, raw administrator diagnostics, event-publication choice, MCP prompts, and MCP resources.
Its schemas are
[`request.schema.json`](../../../contracts/agent-tool/1/request.schema.json) and
[`response.schema.json`](../../../contracts/agent-tool/1/response.schema.json).

## Request

| Field | Required | Limit | Meaning |
| --- | --- | --- | --- |
| `operation` | Yes | Two listed values | Selects the evaluation |
| `recordId` | Yes | 15 or 18 alphanumeric characters | Identifies one record; syntax does not prove access or existence |
| `qualifiedApiName` | Yes | 255 characters | Exact value returned by Salesforce |
| `correlationId` | No | 120 restricted characters | Connects approved operational evidence without carrying record data |

Adapters reject unknown fields. They never add or remove `rhc__`, retry an alternate name, or accept
a label in place of the exact qualified API name. Adapters use event publication `NONE` so a model
cannot create events by choosing an argument.

## Successful response

A completed evaluation returns `success=true` for all five health statuses. `FAIL` is a business
finding. `UNABLE_TO_EVALUATE` and `ERROR` do not prove that a record is healthy.

| Field | Check | Check Set | Limit |
| --- | --- | --- | --- |
| `contractVersion` | Yes | Yes | Fixed value `1.0` |
| `correlationId` | Yes | Yes | 120 restricted characters |
| `success`, `operation`, `status` | Yes | Yes | Fixed schema values |
| `reasonCode` | Optional | No | 80 characters |
| `passed`, `failed`, `skipped`, `unable`, `systemError` | No | Yes | Each is 0 through 25 |
| `diagnosticId` | Optional | Optional | 255 characters |
| `diagnosticCategory` | Optional | Optional | 80 characters |
| `diagnosticSummary` | Optional | Optional | 1,000 characters |
| `recommendedAction` | Optional | Optional | 1,000 characters |

Structured fields are the source of truth. Transport-specific prose cannot change or conceal their
meaning. The four diagnosis fields are bounded, disclosure-safe guidance for a completed evaluation;
they are not raw logs or administrator-only diagnostics.

## Adapter failure

An adapter failure returns `success=false`, a safe message of at most 1,000 characters, and one type:

| Error type | Meaning |
| --- | --- |
| `AUTHORIZATION` | The Salesforce principal cannot start the evaluation |
| `VALIDATION` | The request is malformed, incomplete, names invalid configuration, or targets a Salesforce instance host outside the approved MCP destinations |
| `LIMIT` | The request or response exceeds an enforced boundary |
| `EXECUTION` | An unexpected adapter or platform problem prevented completion |

An adapter failure has no health status or completed-evaluation diagnosis. It cannot include a stack
trace, query, formula, token, session ID, unrestricted exception, record field value, or
administrator diagnostic.

## Identity and sensitivity

The native action uses the configured Agentforce principal's Salesforce access. MCP uses a dedicated
Salesforce integration principal. MCP client credentials do not delegate the conversational user's
identity, so results can differ when principals have different object, field, sharing, restriction-
rule, or scoping-rule access.

Version 1 can return contract version, correlation ID, success, operation, status, reason code, Check
Set counts, the four optional bounded diagnosis fields, error type, and a safe error message. It
excludes found and expected values, display messages, action URLs, serialized Apex results, queries,
formulas, user IDs, raw logs, and administrator diagnostics.

## Compatibility and verification

Adding a required field, operation, output data, multi-record input, identity flow, or changed status
meaning requires a reviewed contract version and compatibility plan.

Run the schema gate:

```bash
npm run check:agent-tool-contract
```

## Related

- [Configuration identity](../framework/configuration-identity.md)
- [Security and data access](../framework/security.md)
- [Reason Codes](reason-codes.md)
- [Apex API](../../api/apex-api.md)
