# Record Health Check MCP service

This separately deployed Node.js service exposes two read-only MCP tools:

- `run_record_health_check`
- `run_record_health_check_set`

Each tool accepts one Salesforce record ID, one exact Custom Metadata `QualifiedApiName`, and an
optional safe correlation ID. The service does not expose generic SOQL, generic Apex, MCP resources,
MCP prompts, record mutation, or event-publication controls.

## Security model

Inbound clients use JWT bearer authentication in production. The verifier checks the signature,
issuer, audience, expiration, and `rhc.run` scope. `AUTH_MODE=none` is accepted only outside
production. Host and Origin checks protect the HTTP boundary.

Salesforce calls use OAuth client credentials and a dedicated integration principal. The service
permits only HTTPS login and instance hosts listed in `SALESFORCE_ALLOWED_HOSTS`. Redirects fail,
responses are size limited, calls time out, transient retries are capped, and a 401 causes at most
one token refresh. This identity is a service identity and does not reproduce the conversational
user's Salesforce permissions.

### Permission gates

Authorization is intentionally layered. Passing an outer gate never bypasses a later one.

| Gate                         | Enforced decision                                                                                                                                                    |
| ---------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| HTTP host and origin         | Reject requests whose `Host` or `Origin` is not explicitly allowed.                                                                                                  |
| Transport and operating mode | Require HTTPS destinations and prohibit unauthenticated mode in production.                                                                                          |
| JWT cryptography             | Verify the bearer-token signature against remote JWKS and accept only RS256 or ES256.                                                                                |
| JWT claims                   | Require the configured issuer, audience, expiration, subject, and `rhc.run` scope.                                                                                   |
| MCP capability allowlist     | Expose only `run_record_health_check` and `run_record_health_check_set`; do not expose generic query, Apex, mutation, resource, prompt, or publication capabilities. |
| Request contract             | Require one valid record ID and one exact Custom Metadata `QualifiedApiName`; reject unknown fields, oversized bodies, and unsafe correlation IDs.                   |
| Operational containment      | Apply the kill switch, concurrency and retry ceilings, timeouts, and response-size limits before or around downstream work.                                          |
| Salesforce destination       | Allow only configured Salesforce login and instance hosts; deny redirects and non-HTTPS destinations.                                                                |
| Salesforce authentication    | Use OAuth client credentials for a dedicated integration principal, with bounded token caching and one refresh after a 401.                                          |
| Package entitlement          | Require the Salesforce principal to hold the package's run custom permission through `Record_Health_Check_User` or an equivalent least-privilege permission set.     |
| Salesforce data access       | Execute `with sharing` and `WITH USER_MODE`, so the integration principal's object, field, sharing, restriction-rule, and scoping-rule access applies.               |
| Diagnostic separation        | Do not grant diagnostic-detail permissions to the integration principal unless the integration contract explicitly requires them.                                    |

The current service has one shared MCP scope (`rhc.run`) and one Salesforce integration principal.
It does not delegate the conversational user's Salesforce identity, implement per-record MCP
entitlements, or define separate scopes for the two tools. If a deployment needs stronger tenant
isolation, add separate per-tool scopes, an approved-client allowlist, tenant/org-binding claims,
short-lived tokens or revocation checks, per-client quotas, and private ingress or mTLS. A policy
gateway can add object- or record-level allowlists before the Salesforce call; Salesforce remains
the final data-authorization boundary.

Provide secrets through the hosting platform's secret manager. Never commit a populated `.env`
file. Logs contain only event names, operation names, bounded correlation IDs, timing, status, retry
counts, error categories, and the build identifier.

## Local verification

Use Node.js 22, then run:

```sh
npm ci
npm run check
```

The check formats and lints source, type-checks, runs the Vitest suite with coverage floors, runs an
official MCP SDK client against the Streamable HTTP endpoint, and produces the deployable build.

## Runtime configuration

Copy `.env.example` only as a field reference. Set all values in the deployment environment. The
Salesforce login host and every possible returned instance host must be present in
`SALESFORCE_ALLOWED_HOSTS`. Keep `KILL_SWITCH=false` during normal operation; setting it to `true`
makes health and MCP traffic return unavailable responses without making a Salesforce call.

`GET /healthz` reports only `ok` or `disabled` plus the non-secret build identifier. It deliberately
does not test Salesforce, return configuration, or expose credentials.

## Container build

```sh
docker build -t record-health-check-mcp:local .
```

The final image runs as the unprivileged Node user. Pin the image by digest in the hosting platform,
generate an SBOM, scan both dependencies and the built image, and retain the build identifier and
digest as release evidence.

## Shutdown and rollback

The process stops accepting traffic on `SIGTERM` or `SIGINT` and allows up to ten seconds for active
requests to finish. For emergency containment, first enable the kill switch or scale the service to
zero, revoke the inbound client credential, and revoke the Salesforce external-client credential.
Rollback by restoring the last approved image digest and configuration revision, then run the
health, authentication, tool-list, and non-production Salesforce smoke tests.
