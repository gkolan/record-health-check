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
