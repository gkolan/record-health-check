# Deploy the MCP Service One Security Gate at a Time

> [!IMPORTANT]
> **Audience: platform, identity, security, and Salesforce integration engineers.** This is not a
> Lightning or Flow administrator task. If you cannot run Node.js and container security checks,
> hand this page to the team that operates hosted services.

Use this guide to deploy the separately hosted Record Health Check MCP service and prove that every
security gate works. The service gives an approved AI client two read-only tools:

- `run_record_health_check` evaluates one exact Check for one Salesforce record.
- `run_record_health_check_set` evaluates one exact Check Set for one Salesforce record.

This is an implementation guide, not only a security reference. Complete the gates in order. At
each gate, run both the successful test and the rejection test before continuing.

> [!IMPORTANT]
> The MCP service uses one dedicated Salesforce integration user. Results reflect that user's
> object, field, record-sharing, restriction-rule, and scoping-rule access. It does not use the
> access of the person chatting
> with the AI client. Use [native Agentforce actions](agentforce-actions.md) when results must reflect
> the Agentforce principal instead.

## What you will build

```text
Approved AI client
  -> HTTPS /mcp endpoint
  -> host and Origin checks
  -> JWT signature and claim checks
  -> two approved tools and request validation
  -> concurrency, timeout, retry, and kill-switch controls
  -> Salesforce OAuth client-credentials connection
  -> packaged read-only Apex REST endpoint
  -> sharing, object, field, and record access of the integration user
```

The gates are cumulative. Passing an outer gate never bypasses a later gate.

| Gate | What it proves |
| ---: | --- |
| 1 | Only approved HTTP hosts and browser origins reach the service. |
| 2 | Production uses HTTPS and cannot disable authentication. |
| 3 | The inbound bearer token was signed by the trusted identity provider. |
| 4 | The token was issued for this service, is current, identifies a subject, and has `rhc.run`. |
| 5 | The MCP client can discover only the two intended tools. |
| 6 | A tool call contains one safe record ID and one exact Qualified API Name. |
| 7 | Load, retries, timeouts, response size, and emergency shutdown are bounded. |
| 8 | The service can call only approved HTTPS Salesforce hosts. |
| 9 | Salesforce authenticates the dedicated integration user. |
| 10 | The integration user has the package's run entitlement. |
| 11 | Salesforce data security permits the requested record and fields. |

## Before you start

You need:

1. A non-production Salesforce org with Record Health Check installed.
2. An active Check Set and at least one Check that you can test safely.
3. The exact Check and Check Set **Qualified API Names** copied from Salesforce Setup. Do not add or
   remove `rhc__` yourself.
4. One readable test record and one record that the future integration user cannot read.
5. Permission to create a Salesforce user, Permission Sets, and an External Client App or supported
   Connected App.
6. Node.js 22, Docker when the hosting platform uses containers, and a secret manager.
7. A hosting platform that terminates HTTPS and can set environment variables and secrets.
8. An OAuth 2.0 identity provider that issues JWT access tokens and publishes a JWKS endpoint.
9. An MCP client that supports Streamable HTTP and bearer authentication.

The inbound JWT scope `rhc.run` belongs to the MCP service's identity provider. Salesforce's
**Record Health Check Run** Custom Permission is a separate authorization gate on the Salesforce
integration user. A request must pass both.

Record these non-secret values before proceeding:

| Name used below | Example | Where it comes from |
| --- | --- | --- |
| MCP host | `mcp.example.com` | DNS and hosting configuration |
| MCP endpoint | `https://mcp.example.com/mcp` | MCP host plus `/mcp` |
| issuer | `https://identity.example.com` | Inbound identity provider |
| audience | `record-health-check` | Inbound OAuth resource configuration |
| JWKS URL | `https://identity.example.com/.well-known/jwks.json` | Identity provider |
| Salesforce login URL | `https://example.my.salesforce.com` | The org's My Domain URL |
| Salesforce username | `record-health-mcp@example.com` | Dedicated integration user |
| readable record ID | A 15- or 18-character ID | Test record visible to the integration user |
| denied record ID | A 15- or 18-character ID | Test record hidden from the integration user |
| Check Set name | `My_Account_Checks` | Exact `QualifiedApiName` from Setup |

Never put client secrets, access tokens, session IDs, or production record IDs in this worksheet,
source control, screenshots, tickets, or command history.

## Step 1: Prepare and verify the service locally

This step proves the source and tests before credentials are introduced.

1. Open a terminal in `packages/record-health-check-mcp`.
2. Confirm that `node --version` reports Node.js 22.
3. Install the locked dependencies:

   ```sh
   npm ci
   ```

4. Run the complete MCP package check:

   ```sh
   npm run check
   ```

5. Confirm that formatting, linting, type checking, unit tests, coverage, protocol tests, and build
   all pass.
6. Do not copy `.env.example` into source control. Use it only as a list of required fields.

If this step fails, fix the local build before configuring Salesforce or the hosting platform. A
successful local test does not prove any production gate, but a failed local test makes later gate
results unreliable.

## Step 2: Create the dedicated Salesforce integration user

Do not use an administrator, a human employee, or the Agentforce user.

1. In Salesforce Setup, enter `Users` in **Quick Find**, then select **Users**.
2. Select **New User**.
3. Enter a descriptive name such as `Record Health MCP Integration`.
4. Enter a unique username controlled by the integration owner.
5. Select the least-privileged API-capable license available for the required objects and Apex REST
   access in your org.
6. Select a minimal profile. Do not select **System Administrator**.
7. Save the user.
8. In Setup, enter `Permission Sets` in **Quick Find**, then select **Permission Sets**.
9. Open **Record Health Check User**.
10. Select **Manage Assignments**, then **Add Assignments**.
11. Select the dedicated integration user and complete the assignment.
12. Do not assign **Record Health Check Admin** merely to make the integration work.

**Expected result:** the user exists and has the package's normal run permission, but does not have
administrator or diagnostic-detail access.

## Step 3: Grant only the required Salesforce data access

The package Permission Set grants package access. It cannot know which business objects and fields
your Checks use.

1. Create a separate Permission Set such as `Record Health MCP Data Access`.
2. In that Permission Set, open **Object Settings**.
3. For each object evaluated by the selected Check Sets, grant **Read** only.
4. Grant field read access only for fields used by those Checks.
5. Grant access to parent or related objects and fields used by formulas or queries.
6. Do not grant **Create**, **Edit**, **Delete**, **Modify All**, or **View All** unless a separately
   approved requirement needs it. The MCP tools themselves are read-only.
7. Assign the Permission Set to the dedicated integration user.
8. Configure sharing so the user can read the intended test record.
9. Keep a second test record outside the user's sharing access.
10. If the org uses restriction rules or scoping rules, confirm that they produce the intended
    record set for this user.

**Expected result:** the user can read every object and field required for the approved Checks, but
cannot read the denied test record or unrelated sensitive fields.

## Step 4: Create the Salesforce OAuth client-credentials connection

Salesforce calls this a client credentials flow. It authenticates one configured integration user
without an interactive login.

1. In Setup, enter `External Client Apps Manager` in **Quick Find**, then select
   **External Client Apps Manager**.
2. Create an External Client App for the Record Health Check MCP service. If your org uses a
   supported Connected App instead, apply the equivalent client-credentials policy.
3. Give the app a specific name such as `Record Health Check MCP Production`.
4. Enable OAuth.
5. Add only the OAuth scopes needed to call the packaged Apex REST endpoint. Avoid broad scopes that
   the service does not require.
6. Enable **Client Credentials Flow**.
7. Set the run-as user to the dedicated integration user created in Step 2.
8. Save the app and allow time for Salesforce configuration propagation.
9. Obtain the consumer key and secret using your org's protected consumer-details workflow.
10. Store them immediately in the hosting secret manager as `SALESFORCE_CLIENT_ID` and
    `SALESFORCE_CLIENT_SECRET`.
11. Do not paste either value into `.env.example` or a deployment manifest.

**Expected result:** the app is bound to the dedicated user, and the secret manager contains the
credentials. The source repository does not contain them.

## Step 5: Build and deploy an immutable service image

1. From `packages/record-health-check-mcp`, build the image:

   ```sh
   docker build -t record-health-check-mcp:local .
   ```

2. Scan the dependencies and the final image with your approved scanners.
3. Generate an SBOM.
4. Push the image to the approved registry.
5. Record the immutable image digest.
6. Configure the hosting platform to deploy by digest, not a mutable tag.
7. Configure HTTPS, DNS, and the `/mcp` route.
8. Run the container as its built-in unprivileged Node user. Do not override it to root.
9. Set `BUILD_ID` to the source revision or other immutable release identifier.

Do not enable public production traffic yet. The remaining steps configure and prove every gate.

## Gate 1: Approved HTTP hosts and Origins

This gate prevents requests sent through an unexpected hostname or browser origin.

### Configure the gate

1. Set `ALLOWED_HOSTS` to the exact public MCP hostname. For multiple hosts, use a comma-separated
   list with no wildcards.
2. Set `ALLOWED_ORIGINS` to each approved browser origin host. If no browser client is approved,
   retain only the explicitly required non-browser behavior established by your platform tests.
3. Set `MCP_SERVER_URL` to the public HTTPS URL ending in `/mcp`.
4. Confirm that the load balancer preserves the original `Host` value expected by the application.
5. Restart the service through the hosting platform's normal deployment mechanism.

Example non-secret values:

```text
ALLOWED_HOSTS=mcp.example.com
ALLOWED_ORIGINS=approved-client.example.com
MCP_SERVER_URL=https://mcp.example.com/mcp
```

### Prove the gate

1. Send a request through the approved public hostname. Authentication may reject it at a later
   gate, but the response must not be a host rejection.
2. Repeat with a deliberately unapproved `Host` value in a controlled test environment.
3. Repeat with an unapproved `Origin` header.
4. Confirm that both negative requests are rejected before Salesforce is called.
5. Confirm that logs contain only the safe error category. They must not contain request headers or
   tokens.

If approved traffic fails, compare the externally visible hostname with `ALLOWED_HOSTS` and inspect
the reverse proxy's host-forwarding configuration.

## Gate 2: HTTPS and production authentication mode

This gate prevents plaintext production destinations and unauthenticated production startup.

### Configure the gate

1. Set `NODE_ENV=production`.
2. Set `AUTH_MODE=jwt`.
3. Set `MCP_SERVER_URL` to an `https://` URL ending in `/mcp`.
4. Set `SALESFORCE_LOGIN_URL` to the org's HTTPS My Domain URL.
5. Configure the hosting platform to redirect or reject plaintext HTTP before it reaches the app.
6. Confirm that TLS certificate renewal and expiry monitoring are enabled.

### Prove the gate

1. Start the production configuration with `AUTH_MODE=jwt`; it must start when all required JWT
   fields are present.
2. In a disposable non-production revision, set `AUTH_MODE=none` while leaving
   `NODE_ENV=production`.
3. Confirm that configuration validation prevents startup.
4. Restore `AUTH_MODE=jwt`.
5. Request the HTTP URL and confirm that the platform redirects to HTTPS or rejects it.

Never use `AUTH_MODE=none` to diagnose production authentication. It is intended only for bounded
local development outside production.

## Gate 3: JWT signature verification

This gate proves that the inbound access token was signed by the trusted identity provider.

### Configure the gate

1. Register the MCP service as an OAuth resource or API in the inbound identity provider.
2. Configure the provider to issue JWT access tokens signed with RS256 or ES256.
3. Copy the provider's HTTPS JWKS URL.
4. Set `MCP_AUTH_JWKS_URL` to that URL.
5. Ensure the service can reach the JWKS host through approved outbound network policy.
6. Establish a key-rotation procedure that overlaps old and new public keys long enough for current
   tokens to expire safely.

### Prove the gate

1. Obtain a short-lived access token through the approved client flow.
2. Call `tools/list` with that bearer token and confirm that authentication succeeds.
3. Change one character in the token signature and repeat the request.
4. Confirm that the altered token is rejected and Salesforce is not called.
5. Test a token signed by an unrelated key and confirm rejection.
6. Rotate a non-production signing key and confirm that expected overlap and retirement behavior
   match the documented procedure.

Do not decode or print production tokens in logs. Use synthetic non-production tokens for negative
tests.

## Gate 4: JWT claim verification

Signature verification alone does not prove that a token belongs to this service.

### Configure the gate

1. Set `MCP_AUTH_ISSUER` to the token's exact `iss` value, including scheme and path.
2. Set `MCP_AUTH_AUDIENCE` to the audience assigned to this MCP service.
3. Set `MCP_AUTH_REQUIRED_SCOPE=rhc.run`.
4. Configure the identity provider to include a nonempty subject (`sub`).
5. Configure short token expiration and approved clock synchronization for the service hosts.
6. Grant `rhc.run` only to approved MCP clients.

### Prove the gate

Obtain synthetic tokens that vary one claim at a time and verify these results:

| Token | Expected result |
| --- | --- |
| Correct issuer, audience, subject, expiry, and `rhc.run` | Accepted |
| Wrong issuer | Rejected |
| Wrong audience | Rejected |
| Missing subject | Rejected |
| Expired token | Rejected |
| Missing `rhc.run` | Rejected |
| `rhc.run` present among other space-separated scopes | Accepted |

Confirm that every rejected request stops before a Salesforce token request or Apex REST call.

## Gate 5: Approved MCP capabilities

This gate limits what an authenticated AI client can discover and invoke.

### Configure the gate

No environment setting broadens the approved tool list. The deployed source defines it. Do not add generic
SOQL, arbitrary Apex, record mutation, MCP resources, or MCP prompts to this service.

### Prove the gate

1. Connect an official or conforming MCP SDK client to the `/mcp` endpoint.
2. Authenticate with a valid token.
3. Send `tools/list`.
4. Confirm that the response contains exactly:
   - `run_record_health_check`
   - `run_record_health_check_set`
5. Confirm that `resources/list` and `prompts/list` do not expose Salesforce content.
6. Attempt to call an invented tool such as `run_soql`.
7. Confirm that the call is rejected before Salesforce is contacted.
8. Save the redacted tool-list result as release evidence.

Repeat this proof after every dependency or tool-contract change.

## Gate 6: Tool request contract

This gate prevents the model or client from sending ambiguous, excessive, or unsafe arguments.

### Configure a first call

1. Copy the exact Check Set **Qualified API Name** from Salesforce Setup.
2. Copy the readable test record's 15- or 18-character Salesforce ID.
3. Choose a safe correlation ID containing only letters, numbers, `.`, `_`, `:`, or `-`.
4. Call `run_record_health_check_set` through the MCP client with these logical arguments:

   ```json
   {
     "recordId": "001000000000001AAA",
     "checkSetQualifiedApiName": "My_Account_Checks",
     "correlationId": "mcp-guide-pass-001"
   }
   ```

5. Replace the example values. Do not send the literal example record ID.
6. Confirm that the response uses contract version `1.0` and returns a health status or a safe
   adapter error.

### Prove the gate

Test each invalid request separately:

1. Missing record ID.
2. Record ID with the wrong length or characters.
3. Missing Qualified API Name.
4. Qualified API Name containing spaces or punctuation that Salesforce names cannot contain.
5. An extra, unknown argument.
6. An oversized request body.
7. A correlation ID containing newline characters or other unsafe punctuation.

Every case must be rejected safely without echoing the complete arguments into logs. An unknown but
syntactically valid Qualified API Name can pass this outer contract and be rejected later by Salesforce;
that distinction is expected.

## Gate 7: Operational containment

This gate keeps valid-looking traffic from exhausting the service or Salesforce.

### Configure the gate

Start with the repository defaults unless load tests justify a lower value:

```text
SALESFORCE_TIMEOUT_MS=10000
SALESFORCE_MAX_RESPONSE_BYTES=65536
SALESFORCE_MAX_RETRIES=1
MAX_CONCURRENT_SALESFORCE_CALLS=10
KILL_SWITCH=false
```

1. Set the hosting platform's request and autoscaling limits at or below approved capacity.
2. Keep `SALESFORCE_MAX_RETRIES` low. Retrying multiplies Salesforce traffic during an outage.
3. Keep the service response limit aligned with the package's bounded contract.
4. Restrict permission to change `KILL_SWITCH` to named operators.
5. Create an alert for concurrency rejection, timeout, response-size rejection, retries, and
   kill-switch activation.

### Prove the gate

1. Send fewer simultaneous requests than `MAX_CONCURRENT_SALESFORCE_CALLS`; they should proceed.
2. Exceed that number in staging; excess work must fail predictably rather than queue without bound.
3. Make the Salesforce test double respond slower than `SALESFORCE_TIMEOUT_MS`; confirm timeout.
4. Return a response larger than `SALESFORCE_MAX_RESPONSE_BYTES`; confirm rejection.
5. Simulate a transient Salesforce response and confirm no more than the configured retries occur.
6. Set `KILL_SWITCH=true` in staging.
7. Call both tools and confirm unavailable responses.
8. Confirm the Salesforce mock or audit counter does not increase.
9. Set `KILL_SWITCH=false` and repeat one successful smoke test.

The kill switch is the fastest containment control. It is not a substitute for revoking compromised
inbound or Salesforce credentials.

## Gate 8: Approved Salesforce destinations

This gate prevents access tokens and requests from being redirected to an unapproved host.

### Configure the gate

1. Set `SALESFORCE_LOGIN_URL` to the org's exact HTTPS My Domain login URL.
2. Set `SALESFORCE_ALLOWED_HOSTS` to that hostname.
3. Perform a non-production token request and note the exact Salesforce instance hostname returned.
4. Add every legitimate returned instance hostname to `SALESFORCE_ALLOWED_HOSTS`.
5. Use comma-separated hostnames only. Do not include a scheme, path, port, or wildcard.
6. Review the list after a Salesforce instance migration or My Domain change.

Example:

```text
SALESFORCE_LOGIN_URL=https://example.my.salesforce.com
SALESFORCE_ALLOWED_HOSTS=example.my.salesforce.com,example.my.salesforce-sites.com
```

Only list a host that the actual OAuth and Apex REST flow requires. The second example host is not
a universal requirement.

### Prove the gate

1. Run a valid call and confirm both the login and instance hosts are approved.
2. In staging, remove the returned instance host and repeat the call.
3. Confirm safe rejection before sending the Apex REST request to that host.
4. Simulate an OAuth or Salesforce redirect to an unapproved host.
5. Confirm that redirects are rejected rather than followed.
6. Restore the approved host list and repeat the successful call.

## Gate 9: Salesforce authentication

This gate proves that Salesforce recognizes the OAuth app and executes as the dedicated user.

### Configure the gate

1. Inject `SALESFORCE_CLIENT_ID` and `SALESFORCE_CLIENT_SECRET` from the secret manager.
2. Set `SALESFORCE_REST_PATH` to the packaged endpoint:

   ```text
   /services/apexrest/rhc/record-health-check/contract-1/evaluations
   ```

3. Restrict secret access to the service runtime and credential owners.
4. Deploy a configuration revision without printing environment values.
5. Use Salesforce login history and External Client App audit information to confirm that calls run
   as the dedicated integration username.

### Prove the gate

1. Call one tool with valid inbound authentication and valid Salesforce credentials.
2. Confirm the executing Salesforce username in protected audit data.
3. Replace the Salesforce secret with a synthetic invalid value in staging.
4. Confirm safe authentication failure and no tool result.
5. Restore the valid secret through the secret manager.
6. Repeat the successful call.
7. Rotate the secret using an overlap procedure, then revoke the old credential and prove that it no
   longer works.

Never troubleshoot this gate by assigning System Administrator to the integration user.

## Gate 10: Package run entitlement

This gate proves that an authenticated Salesforce user is allowed to run Record Health Check.

### Configure the gate

1. In Setup, open **Permission Sets**.
2. Open **Record Health Check User**.
3. Confirm that the dedicated integration user appears under **Manage Assignments**.
4. Confirm that the user's assigned permissions include the packaged run Custom Permission.
5. Do not add the diagnostics Custom Permission.

### Prove the gate

1. Run a known-readable Check Set and confirm the request reaches evaluation.
2. Remove **Record Health Check User** from the integration user in a controlled test org.
3. Repeat the same call.
4. Confirm a safe permission error. It must not return `PASS`, `FAIL`, or a diagnostic stack trace.
5. Reassign **Record Health Check User**.
6. Repeat the successful call.

This test isolates package entitlement from normal object and field access. Keep the same record,
Check Set, OAuth app, and inbound token for both calls.

## Gate 11: Salesforce object, field, sharing, and rule access

This final gate proves that successful authentication and package entitlement do not bypass
Salesforce data security.

### Prove object access

1. Run a Check against the readable test record and record the safe result.
2. Remove read access to the target object from the integration user's data Permission Set.
3. Repeat the same call and confirm `UNABLE_TO_EVALUATE` or the documented safe access error. It
   must not return a false `PASS`.
4. Restore object read access.

### Prove field access

1. Identify one field required by the test Check.
2. Remove read access to only that field.
3. Repeat the call and confirm the package does not reveal the value or claim a reliable pass.
4. Restore field access.

### Prove record access

1. Run the Check against the readable record.
2. Repeat it with the denied record ID.
3. Confirm the denied record does not produce its health data.
4. Review sharing, restriction rules, and scoping rules if the result differs from the expected
   denial.

### Prove diagnostic separation

1. Trigger a safe configuration or access failure in the test org.
2. Confirm that the MCP response omits raw field values, queries, formulas, stack traces, and
   administrator diagnostics.
3. Confirm that the integration user does not have **Record Health Check View Diagnostics**.
4. Restore the test configuration.

## Step 6: Connect the approved MCP client

MCP client screens differ, but the values and proof are the same.

1. Add a remote Streamable HTTP MCP server in the approved client.
2. Enter the exact `MCP_SERVER_URL` ending in `/mcp`.
3. Configure the client's OAuth relationship with the inbound identity provider.
4. Request audience `MCP_AUTH_AUDIENCE` and scope `rhc.run`.
5. Authenticate as an approved client subject.
6. Refresh the tool list.
7. Confirm that exactly the two Record Health Check tools appear.
8. Ask the client to evaluate the known readable record with the exact Check Set Qualified API Name.
9. Inspect the interaction details and confirm the selected tool and arguments.
10. Confirm that the client describes `FAIL` as an unhealthy business result, not a tool failure.
11. Confirm that `UNABLE_TO_EVALUATE` and `ERROR` are never translated to `PASS`.

If the client cannot present OAuth fields or send a bearer token to a remote Streamable HTTP server,
it is not compatible with this production deployment as configured.

## Step 7: Run the adoption test matrix

Before production, test these cases end to end through the actual client:

| Case | Expected behavior |
| --- | --- |
| Known `PASS` Check | Client reports that the requirement passed. |
| Known `FAIL` Check | Client reports a business condition requiring attention. |
| `SKIPPED` Check | Client says the Check did not apply or run. |
| Missing required access | Client does not claim a reliable result. |
| Unknown valid Qualified API Name | Safe not-found/configuration response. |
| Malformed Qualified API Name | Rejected at the request-contract gate. |
| Denied record | No record health data is disclosed. |
| Expired inbound token | Rejected before Salesforce. |
| Missing `rhc.run` | Rejected before Salesforce. |
| Invented MCP tool | Rejected before Salesforce. |
| Kill switch enabled | Both tools unavailable; Salesforce call count unchanged. |
| Prompt-like text in record data | Treated as data, not as new instructions. |
| Unrelated user question | Neither health-check tool is selected. |

Retain redacted evidence containing the build ID, test case, expected result, actual result, time,
and approver. Do not retain tool arguments or Salesforce data.

## Step 8: Promote and operate safely

1. Promote the same image digest through development, test, staging, and production.
2. Use separate inbound OAuth clients, Salesforce OAuth apps, Salesforce users, secrets, domains,
   and approved host lists in every environment.
3. Run Gates 1–11 in staging against the exact production candidate.
4. Deploy production configuration through review and approval.
5. Run only approved non-sensitive smoke tests in production.
6. Monitor authentication rejection, latency, Salesforce `429`, timeouts, retries, schema mismatch,
   concurrency rejection, and kill-switch state.
7. Review access quarterly and after any tool, scope, object, field, identity, or ownership change.
8. Rotate inbound and Salesforce credentials using overlap, verification, and old-credential
   revocation.
9. Practice rollback to the previous image digest in staging.
10. Practice enabling the kill switch and revoking both trust relationships.

Use the [MCP operations and security runbook](../../packages/record-health-check-mcp/OPERATIONS.md)
for incident response, telemetry rules, evidence, rotation, and rollback exercises.

## Troubleshooting by gate

| Symptom | First gate to inspect | What to check |
| --- | ---: | --- |
| Request rejected immediately by hostname | 1 | Public hostname, proxy forwarding, `ALLOWED_HOSTS` |
| Service will not start in production | 2 | HTTPS URLs, `AUTH_MODE`, missing JWT values, `BUILD_ID` |
| Every bearer token is invalid | 3 | JWKS reachability, signing algorithm, active key ID |
| Token is signed but rejected | 4 | Exact issuer, audience, subject, expiry, `rhc.run` |
| Unexpected tools appear | 5 | Deployed source and image digest |
| One tool call is rejected before Salesforce | 6 | Field names, record ID, Qualified API Name, extra fields |
| Requests time out or receive unavailable | 7 | Kill switch, concurrency, timeout, retry and response limits |
| OAuth works but the instance call is blocked | 8 | Returned instance hostname in `SALESFORCE_ALLOWED_HOSTS` |
| Salesforce returns authentication failure | 9 | Client ID, rotated secret, app policy, run-as user |
| Salesforce user authenticates but cannot run package | 10 | Record Health Check User assignment and run permission |
| One record or Check cannot be evaluated | 11 | Object, field, sharing, restriction, and scoping-rule access |

Change one gate at a time during diagnosis. Broadening several approved host lists or permissions at once
makes the final security boundary impossible to prove.

## Official Salesforce references

- [Configure a Client Credentials Flow](https://help.salesforce.com/s/articleView?id=sf.configure_client_credentials_flow_for_external_client_apps.htm&language=en_US&type=5)
- [External Client Apps](https://help.salesforce.com/s/articleView?id=sf.external_client_apps.htm&language=en_US)
- [Create custom Agentforce actions using Apex](https://developer.salesforce.com/docs/ai/agentforce/guide/agent-invocablemethod.html)
- [Agentforce actions overview](https://developer.salesforce.com/docs/ai/agentforce/guide/get-started-actions.html)
- [MCP solutions for Salesforce developers](https://developer.salesforce.com/docs/ai/agentforce/guide/mcp.html)

Salesforce Setup labels and available licenses can vary by edition and release. If a label differs,
use the official reference for the org's current release and preserve the security outcome described
at that step.

## Related

- [Choose native Agentforce actions](agentforce-actions.md)
- [Agent tool REST API](agent-tool-rest-api.md)
- [Agent tool contract](../reference/contracts/agent-tool-contract.md)
- [Agentforce and MCP threat model](../reference/framework/agent-mcp-threat-model.md)
- [Security and data access](../reference/framework/security.md)
- [MCP service technical README](../../packages/record-health-check-mcp/README.md)
- [MCP operations and security runbook](../../packages/record-health-check-mcp/OPERATIONS.md)
