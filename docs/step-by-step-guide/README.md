# Step-by-step guide

Use this page when you want a predictable sequence instead of choosing among all documentation
topics. Complete each step in a sandbox and move on only after the expected result works.

## First working Check

| Step | Do this | Stop when… |
| ---: | --- | --- |
| 1 | [Understand what the framework does](../start-here/what-it-does.md) | You can explain the difference between a Check Set and a Check |
| 2 | [Install and verify it in a sandbox](../install/install-in-a-sandbox.md) | A normal user can see the Record Health Check card |
| 3 | [Explore the installed examples](../install/explore-installed-examples.md) | One installed Check Set runs on a record page |
| 4 | [Create your first Check](./create-your-first-check.md) | Your own Check shows both a passing and an attention state |
| 5 | [Add and activate the card](../lightning-record-page/README.md) | The intended app users can open and run it |
| 6 | [Configure a complete Check Set](../build-checks/configure-check-sets-and-checks.md) | Every Check has been tested with representative users and records |

Do not test only as a System Administrator. A card-only tester needs **Record Health Check Card
User**; an automation user needs the permission set for the way it runs checks. Every runner
also needs access to the records and fields the Check reads.

## Choose your next path

### Build more Checks

1. [Choose the Evaluation Type](../examples/README.md).
2. Copy the closest Formula, Query, Compare Two Queries, or Apex example.
3. [Add a safe fix link](../build-checks/add-fix-link.md) when users need a next action.
4. [Understand result labels and statuses](../reference/results/statuses-and-labels.md).

### Run from Flow

1. Prove the Check Set on the card first.
2. [Run it from Flow](../flow-guides/run-a-check.md).
3. Use `Success` for request handling and `Status` for the health decision. `FAIL` is not a Flow
   fault.
4. Leave event publication as `NONE` unless a separate process must receive the result.

### Save history or notify another process

1. [Decide whether you need Platform Events](../save-results/when-to-use-platform-events.md).
2. Start with [Check Set run summaries](../save-results/save-run-summaries.md) when counts are enough.
3. Save events to an organization-owned object if you need lasting history.
4. Test duplicate delivery and failure handling before activation.

### Go to production

1. [Back up the configuration](../production-operations/back-up-configuration.md).
2. [Review security and data access](../architecture/security-and-data-access.md).
3. [Follow the production operations checklist](../production-operations/operate-in-production.md).
4. Keep [troubleshooting](../diagnostics/browser-console.md) available to support owners.

### Extend with code or agents

Start in [Developer guides](../developer-guides/README.md). Administrators can skip that folder unless
they are handing an Apex, background-job, Agentforce, MCP, or external event task to a developer.

## If something fails

| What you see | Start here |
| --- | --- |
| The card is missing or has the wrong Check Set | [Add the card to a record page](../lightning-record-page/configure-the-component.md) |
| A result is unexpected | [Troubleshoot Record Health Check](../diagnostics/browser-console.md) |
| A status or Reason Code is unclear | [Look up exact behavior](../reference/README.md) |
| Flow does not branch as expected | [Flow action inputs and outputs](../flow-guides/action-inputs-and-outputs.md) |
| A receiving Flow gets no event | [Save or send results after a run](../save-results/README.md) |

## Related

- [Documentation home](../README.md)
- [Start here](../start-here/README.md)
