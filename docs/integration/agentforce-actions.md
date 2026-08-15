# Agentforce actions

> [!NOTE]
> Use this page to give a native Agentforce agent read-only access to one Record Health Check or
> Check Set result without routing through an external MCP server.

## Choose the native actions

The package provides two native Agentforce actions:

| Agentforce action | Apex class | Use |
| --- | --- | --- |
| **Run Record Health Check for Agentforce** | `RecordHealthCheckRunCheckAgentAction` | Evaluate one exact Check for one record |
| **Run Record Health Check Set for Agentforce** | `RecordHealthCheckRunSetAgentAction` | Evaluate the complete active Check Set for one record |

Use the Check Set action for a general record-health question. Use the Check action only when the
agent must answer one named data-quality question.

The actions evaluate with the configured Agentforce principal's Salesforce access. This differs from
an MCP call made through a dedicated integration user. Prefer these native actions when the result
must reflect the agent principal's object, field, record-sharing, restriction-rule, and scoping-rule
access.

## Before configuration

1. Install a package version that contains the Agentforce actions.
2. Assign the Agentforce principal **Record Health Check User**
   (`rhc__Record_Health_Check_User`) or equivalent least-privilege access.
3. Grant that principal read access to every target object and field required by the selected Checks.
4. Confirm that record sharing lets the principal read the intended records.
5. Copy each Check or Check Set exact `QualifiedApiName` from Salesforce. Do not add or remove
   `rhc__`.
6. Test the configuration with the same principal used by the active agent.

The User Permission Set grants run access but not the diagnostics Custom Permission. Do not assign
the Admin Permission Set only to make an agent action run.

## Basic Agentforce configuration pattern

In Agentforce Builder, create a focused subagent or topic for record-health questions. Add one or
both Apex invocable actions as required by the use case.

Use instructions with these rules:

1. Call the Check Set action whenever the user asks for the actual overall health, readiness,
   completeness, or quality of a record under a configured Check Set.
2. Call the single Check action only for a specifically named Check.
3. Supply exactly one record ID and one exact qualified API name.
4. Never infer a health result from conversation context or from Salesforce fields already available
   to the model.
5. Never call both native and MCP versions for the same request unless deterministic comparison is
   the explicit use case.
6. Interpret output according to the status table below.

## Interpret action output

Both actions use contract version `1.0` and return `success`, `operation`, `status`, and a correlation
ID. The Check action can return a reason code. The Check Set action returns explicit counts.

| Output | Agent behavior |
| --- | --- |
| `success=false` | Report the safe adapter error. Do not claim any health status. |
| `PASS` | State that the selected Check or Check Set passed. |
| `FAIL` | State that evaluation completed and found a business condition requiring attention. |
| `SKIPPED` | State that the Check did not apply or did not run. |
| `UNABLE_TO_EVALUATE` | State that no reliable conclusion was reached. Never translate it to `PASS`. |
| `ERROR` | State that a system or evaluator problem prevented a reliable result. Never translate it to `PASS`. |

The actions return evaluation fields only. They do not return Found or Expected values, display
messages, action URLs, raw serialized results, queries, formulas, stack traces, or administrator
diagnostics.

## Limits and side effects

Each action call accepts exactly one request for one record. More than one input returns aligned
`LIMIT` responses with `AGENT_SINGLE_RECORD_REQUIRED`.

The model cannot select event publication. Native Agentforce actions always use `NONE`, so invoking
an action does not publish Record Health Check result events. The evaluation remains read-only and
does not update the checked record.

## Test before activation

Test these cases in Agentforce Builder with the intended principal:

1. A Check that returns each supported status.
2. A Check Set with a mixture of statuses.
3. An unknown but correctly formatted qualified API name.
4. A malformed qualified API name.
5. A record the principal cannot read.
6. A required field the principal cannot read.
7. A principal without **Record Health Check Run**.
8. Prompt-like text stored in a record or Check message.
9. An unrelated user request that must not invoke either action.

Review the interaction details. Confirm the selected action, exact inputs, structured output, and
final response for each test. An administrator's successful test does not prove that the production
Agentforce principal has the intended access.

## Related

- [Agent tool contract](../reference/contracts/agent-tool-contract.md)
- [Agentforce and MCP threat model](../reference/framework/agent-mcp-threat-model.md)
- [Security and data access](../reference/framework/security.md)
- [Configuration identity](../reference/framework/configuration-identity.md)
- [Flow actions](flow-actions.md)
