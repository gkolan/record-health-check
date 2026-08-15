# MCP operations and security runbook

## Ownership and environment separation

Assign separate named owners for the inbound OAuth client, Salesforce integration identity, hosting
service, alerts, and release approval. Development, test, staging, and production must use distinct
OAuth clients, Salesforce users, secret-manager entries, domains, and Salesforce host lists. A
production deployment must reject a staging issuer, audience, client, Salesforce host, or secret.

Review access quarterly and immediately after a tool, scope, object, field, hosting, identity, or
ownership change. The review must confirm that diagnostics access remains absent unless separately
approved.

## Salesforce integration identity

Use a Salesforce External Client App or supported Connected App restricted to one integration user.
Grant only API access, the packaged REST class, the packaged **Record Health Check Run** Custom
Permission, and read access to the explicitly supported objects, fields, and records. Do not grant
generic Apex execution, metadata mutation, unrestricted object access, or **Record Health Check View
Diagnostics**.

Verify the executing identity by comparing the External Client App audit record and Salesforce login
history with the integration username. Prove least privilege with allowed and denied object, field,
record, Apex-class, run-permission, and diagnostics cases in each release environment.

## Credential provisioning and rotation

1. Create the replacement inbound and outbound credentials without removing the active credentials.
2. Store both replacements in the hosting secret manager, never in source control or a build layer.
3. Deploy a configuration-only revision that accepts or uses the replacements.
4. Run authentication, tool-list, `PASS`, unauthorized-record, and audit-identity smoke tests.
5. Revoke the old credentials and repeat the safe-failure and successful-call tests.
6. Record redacted credential identifiers, revision, timestamps, approvers, and interruption metrics.

For emergency revocation, enable the kill switch first, revoke both trust relationships, inspect
authentication and Salesforce audit activity, rotate secrets, deploy a reviewed revision, and only
then disable the kill switch.

## Telemetry contract

Logs permit only timestamp, build identifier, correlation identifier, duration, error category,
event name, HTTP status, operation, and retry count. Never log tool arguments, record IDs, record
fields, display or diagnostic messages, request or response bodies, tokens, authorization headers,
client secrets, session IDs, or exception stacks.

Collect counters and histograms for request volume, latency, MCP authentication rejection, completed
health status, adapter error class, Salesforce HTTP category, retries, timeouts, response-size
rejection, schema mismatch, concurrency rejection, and kill-switch rejection. Retain operational logs
for 30 days and aggregated metrics for 90 days unless the security owner approves a different period.
Delete test canaries and drill data immediately after evidence approval.

Alert on sustained authentication rejection, error-rate or latency increase, Salesforce `429`,
timeouts, schema mismatch, exhausted concurrency, and kill-switch activation. Exercise every alert
in staging before production approval and retain the alert event and acknowledgement identifier.

## Failure runbooks

### Salesforce or OAuth outage

Confirm the failure category without printing a token or body. Enable the kill switch if retries or
latency threaten Salesforce or the service. Check provider and Salesforce status, token endpoint
latency, recent configuration changes, and host-list changes. Restore service only after a staging
smoke test proves authentication and one bounded evaluation.

### Contract mismatch or bad deployment

Enable the kill switch, preserve redacted schema-mismatch counts, and compare the deployed service
digest with the Salesforce package version. Roll back to the previous approved digest without
changing Salesforce metadata. Re-enable traffic after protocol and Salesforce smoke tests pass.

### Unusual volume

Confirm the client identifier and rate without inspecting tool arguments. Revoke or throttle the
offending inbound client, lower autoscaling maxima if needed, and inspect Salesforce limit usage.
Do not raise rate or concurrency limits during an incident without security and Salesforce-owner
approval.

### Suspected disclosure

Enable the kill switch, revoke affected credentials, preserve access-controlled audit evidence,
notify the security owner, and scan logs and traces for seeded and suspected values. Follow the
approved incident-retention and deletion process. Do not copy raw Salesforce data into the incident
record.

## Load, failure, and telemetry exercise

Run staging tests below, at, and above the configured request, Salesforce-call concurrency, body,
response, and timeout limits. Inject token-endpoint failure, expired tokens, Salesforce `429`,
Salesforce timeout, malformed JSON, contract mismatch, oversized response, telemetry unavailability,
and kill-switch activation. Every excess request must fail predictably, and the kill-switch exercise
must prove that the Salesforce mock or audit counter does not increase.

Seed unique fake token, secret, record, and personal-data canaries in rejected test inputs. Export the
resulting logs and traces, scan for every complete canary, and retain only the redacted scan result.

## Deployment and rollback evidence

For each promoted artifact, record the source revision, service version, build identifier, package
lock digest, container digest, base-image digest, SBOM digest, dependency and container scan results,
attestation, deployment revision, environment configuration revision, smoke-test run, and approvers.
Promote the same digest through development, test, staging, and production.

Perform a staging rollback by calling both tools before rollback, restoring the previous digest,
then calling both tools again. Separately prove that operators can enable the kill switch, revoke the
inbound credential, revoke the Salesforce credential, and remove the Agentforce tool assignment
without uninstalling or destructively deleting Salesforce metadata.
