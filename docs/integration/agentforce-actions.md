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

1. Confirm the org has Agentforce enabled, the required Salesforce licenses are assigned, and the
   intended agent opens in Agentforce Builder. Builder labels can change by Salesforce release, so
   use the current action-search UI rather than relying on one screenshot.
2. Install a package version that contains the Agentforce actions and confirm Record Health Check
   appears in **Setup → Installed Packages**.
3. Identify the agent's running principal from the agent configuration, then assign that principal
   **Record Health Check User**
   (`rhc__Record_Health_Check_User`) or equivalent least-privilege access.
4. If the agent has no existing data Permission Set, create an org-owned Permission Set that grants
   only the approved objects and fields, then assign it to the same principal.
5. Confirm that record sharing lets the principal read the intended records.
6. Copy each Check or Check Set exact `QualifiedApiName` from Salesforce. Do not add or remove
   `rhc__`.
7. Test the configuration with the same principal used by the active agent.

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

## Example: Give an agent an Account health tool

This walkthrough uses these example choices:

| Decision | Example choice |
| --- | --- |
| Agent | `Account Readiness Assistant` |
| Target object | Account |
| Check Set | An administrator-created Set named `My_Account_Checks` |
| Normal action | **Run Record Health Check Set for Agentforce** |
| Optional focused action | **Run Record Health Check for Agentforce** |
| Result publication | None; native actions always use `NONE` |

Replace `My_Account_Checks` with the exact **Check Set Qualified API Name** from your org. It is an
example name, not metadata installed by Record Health Check.

Native agent actions never publish Record Health Check result Platform Events. `success = false`
means the tool request failed and the agent must not claim a health conclusion. `success = true`
with `FAIL` means evaluation completed and found an unmet requirement. `ERROR` means evaluation
returned a system problem, not a passing or business-failure answer.

### Step 1: Prepare two test Accounts

1. Choose a sandbox or other non-production org where Agentforce is enabled.
2. Confirm that the installed Record Health Check version contains the two native actions listed
   above.
3. Create or choose one Account that should pass `My_Account_Checks`.
4. Create or choose a second Account that should fail at least one Check.
5. Copy each Account ID from its Salesforce URL.
6. Open the Check Set in Salesforce Setup and copy its exact `QualifiedApiName`.
7. If you will configure the single-Check action, copy that Check's exact `QualifiedApiName` too.
8. Write down the expected status for both test Accounts before testing the agent.

**Expected result:** you have one known-positive case, one known-negative case, and exact
configuration names. Do not test adoption using an unknown record whose correct result is unclear.

### Step 2: Identify the Agentforce principal

The principal is the Salesforce user whose access applies when the native action runs.

1. In Agentforce Studio or the agent's Setup page, open the agent you will configure.
2. Identify the user assigned to run the agent.
3. Open that user from **Setup → Users → Users**.
4. Record the username in the test plan.
5. Confirm that it is not a broad administrator account used only because setup was easier.

**Expected result:** the team can name the exact Salesforce user whose object, field, and record
access will govern every health result.

### Step 3: Assign Record Health Check access

1. From Setup, enter `Permission Sets` in **Quick Find**, then select **Permission Sets**.
2. Open **Record Health Check User**.
3. Select **Manage Assignments**.
4. Select **Add Assignments**.
5. Select the Agentforce principal from Step 2.
6. Complete the assignment.
7. Return to the user's Permission Set assignments and confirm that **Record Health Check User** is
   present.

That packaged Permission Set includes both Agentforce action Apex classes and the **Record Health
Check Run** Custom Permission. It deliberately excludes diagnostic details.

**Rejection test:** in a controlled test org, remove the assignment and run the action. Confirm that
the response reports a safe authorization error and does not report `PASS` or `FAIL`. Restore the
assignment before continuing.

### Step 4: Grant the data access required by the Checks

1. List every object and field used by `My_Account_Checks` and its active Checks.
2. Include related and parent objects used by formulas or queries.
3. Open the Permission Set used for this agent's business-data access.
4. Under **Object Settings**, grant **Read** for each required object.
5. Grant read access for each required field.
6. Confirm that sharing gives the Agentforce principal access to the two test Accounts.
7. Review applicable restriction rules and scoping rules.
8. Do not grant edit or delete access merely to run these actions. The actions do not update the
   checked record.

**Rejection test:** remove read access to one required field, run the affected Check, and confirm
that the response does not claim a reliable `PASS`. Restore the field access after the test.

### Step 5: Create a focused subagent or topic

Agentforce Builder labels vary between the topic-based and newer subagent-based experiences. Use a
focused topic or subagent that owns record-health questions rather than adding the actions to an
unrelated general-purpose area.

1. Open the agent in Agentforce Builder.
2. Create a topic or subagent for record-health questions.
3. Enter a clear name such as `Account Record Health`.
4. Describe its scope: it answers whether one Account satisfies a named Record Health Check or Check
   Set.
5. Add instructions that require a real action result before claiming health.
6. Add instructions that exclude requests to change records, expose diagnostics, or invent a
   result.
7. Save the topic or subagent.

Example instructions:

```text
Use the Record Health Check Set action when the user asks for the overall health,
readiness, completeness, or quality of one Account under My_Account_Checks.

Use the single Record Health Check action only when the user asks for one specifically
named Check. Never infer health from conversation text or fields already shown to you.

Report PASS and FAIL as completed health results. Treat SKIPPED as not applicable or not
run. Never translate UNABLE_TO_EVALUATE or ERROR into PASS. Do not claim a result if the
action reports success=false.
```

Replace the example Check Set name in the instructions with the exact name used by the action.

### Step 6: Add the Check Set action

1. In the record-health topic or subagent, select the option to add or create an action.
2. Choose **Apex** as the reference action type.
3. Choose **Invocable Method** as the reference action category when that field appears.
4. Select **Run Record Health Check Set for Agentforce** as the reference action.
5. Give the agent action a clear name such as `Evaluate Account Check Set`.
6. Describe when to use it: evaluate one record under one exact Record Health Check Set when the
   user asks for overall health, readiness, completeness, or quality.
7. Keep **Record ID** as a required input. It must be the ID of the record being evaluated.
8. Keep **Check Set Qualified API Name** as a required input.
9. Configure the exact value `My_Account_Checks` when the action design permits a fixed input. If the
   value remains model-supplied, state the one approved exact name in the action instructions.
10. Leave **Correlation ID** optional. Do not ask the model to place record data or user text in it.
11. Make the structured outputs available to the reasoning engine.
12. Save the action.

**Expected result:** the action references the packaged Check Set invocable method and accepts one
record ID plus one exact Check Set name.

### Step 7: Add the optional single-Check action

Skip this step unless users genuinely ask about one specifically named Check.

1. Add another Apex Invocable Method action to the same focused topic or subagent.
2. Select **Run Record Health Check for Agentforce**.
3. Give it a name that distinguishes one Check from the complete Check Set.
4. Describe exactly which named questions justify this narrower action.
5. Keep **Record ID** and **Check Qualified API Name** required.
6. Fix or constrain the Check Qualified API Name when possible.
7. State that the agent must not call both actions for the same request unless the user explicitly
   asks for a deterministic comparison.
8. Save the action.

Adding fewer actions makes selection easier to understand and test. The Check Set action is enough
for most record-health adoption scenarios.

### Step 8: Verify action inputs and outputs

Open each action and confirm:

| Item | Required configuration |
| --- | --- |
| Record ID | One Salesforce record ID; never a list |
| Qualified API Name | Exact Check or Check Set name copied from Setup |
| Correlation ID | Optional safe operational identifier, at most 120 characters |
| Contract Version | Available to reasoning; current actions return `1.0` |
| Success | Checked before the agent claims any health conclusion |
| Status | Interpreted with the five-state table below |
| Counts | Check Set action exposes passed, failed, skipped, unable, and system-error counts |
| Error fields | Used for a safe explanation, not rewritten as a health result |

The single-Check action also returns a reason code. The Check Set action returns counts instead of
individual Check values or messages.

### Step 9: Test selection and results in Agentforce Builder

1. Open **Preview** or the current Builder testing panel.
2. Use the same agent principal that production will use.
3. Ask for the known passing Account's overall health.
4. Inspect the interaction details.
5. Confirm that the Check Set action ran once with the correct Account ID and Qualified API Name.
6. Confirm that the final answer says the Check Set passed.
7. Ask the same question for the known failing Account.
8. Confirm that the final answer describes `FAIL` as a completed business finding, not a technical
   action failure.
9. Ask an unrelated question and confirm that neither action runs.
10. If configured, ask a specifically named Check question and confirm that only the single-Check
    action runs.

An administrator's successful preview does not prove the agent user's access. Confirm the principal
shown in the interaction or audit details.

### Step 10: Run the negative tests

Test each case separately so that the failed gate is clear:

1. A malformed Qualified API Name.
2. An unknown but syntactically valid Qualified API Name.
3. A record the Agentforce principal cannot read.
4. A Check that requires a field the principal cannot read.
5. A principal without **Record Health Check User**.
6. A Check that returns `SKIPPED`.
7. A Check that returns `UNABLE_TO_EVALUATE`.
8. A controlled evaluator failure that returns `ERROR`.
9. Prompt-like instructions stored in a record field or Check message.
10. A request containing two record IDs.

For every case, inspect the selected action, exact inputs, structured output, and final answer. The
agent must not disclose inaccessible data, follow prompt-like record content as instructions, or
translate an inconclusive result into `PASS`.

### Step 11: Commit, activate, and monitor

1. Save all topic, subagent, instruction, and action changes.
2. Run the complete positive and negative test matrix again.
3. Commit or save the agent version using the version controls shown in your Builder experience.
4. Activate the tested version.
5. Connect only the intended channels and users.
6. Review early production interactions for unexpected tool selection and status interpretation.
7. Record the agent version, package version, principal, action names, Check names, test evidence,
   and approver.
8. After changing a Check, Check Set, permission, sharing rule, action, or instruction, repeat the
   affected tests.
9. To contain a native-action incident, remove the actions from the agent or deactivate the agent
   version. Do not uninstall the package or delete Check metadata as the first response.

Salesforce publishes a detailed current example of creating an Invocable Method action in
[Agentforce Builder](https://developer.salesforce.com/docs/ai/agentforce/guide/apex-examples-custom-action.html).
Use it when the current Builder labels differ from this guide.

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

- [Deploy the external MCP service one security gate at a time](deploy-mcp-service.md)
- [Agent tool contract](../reference/contracts/agent-tool-contract.md)
- [Agentforce and MCP threat model](../reference/framework/agent-mcp-threat-model.md)
- [Security and data access](../reference/framework/security.md)
- [Configuration identity](../reference/framework/configuration-identity.md)
- [Flow actions](flow-actions.md)
