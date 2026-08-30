# Record Health Check documentation

Record Health Check shows whether a Salesforce record meets requirements configured by an
administrator. It reports what it finds; it does not block saves or change the record.

## New here? Follow these steps

1. [See what Record Health Check does](./start-here/what-it-does.md).
2. [Install it in a sandbox](./install/install-in-a-sandbox.md).
3. [Explore a working installed example](./install/explore-installed-examples.md).
4. [Create your first Check](./step-by-step-guide/create-your-first-check.md).
5. [Configure the Lightning record-page component](./lightning-record-page/README.md).

Want the complete learning sequence? Open the [step-by-step guide](./step-by-step-guide/README.md).

## Pick your task

| Folder | Go here when you want to… |
| --- | --- |
| [Start here](./start-here/README.md) | Understand what Record Health Check does and choose your next task |
| [Step-by-step guide](./step-by-step-guide/README.md) | Follow the complete sequence from installation to a working Check |
| [Install](./install/README.md) | Install in a sandbox, install the demo in a scratch org, choose a version, upgrade, or uninstall |
| [Frequently asked questions](./faqs/README.md) | Find direct answers about use, setup, security, operations, and code |
| [Build Checks](./build-checks/README.md) | Choose an Evaluation Type and configure Check Sets and Checks |
| [Examples](./examples/README.md) | Copy a complete Formula, Query, Compare Two Queries, or Apex pattern |
| [Lightning record page](./lightning-record-page/README.md) | Configure and activate the Record Health Check component |
| [Flow guides](./flow-guides/README.md) | Run a Check or Check Set from Flow and branch on its result |
| [Save results](./save-results/README.md) | Send results to another process or save history with Platform Events |
| [Diagnostics](./diagnostics/browser-console.md) | Investigate browser-console evidence or Salesforce debug logs |
| [Production operations](./production-operations/README.md) | Back up configuration and operate the package after go-live |
| [Architecture](./architecture/README.md) | Understand framework structure, security boundaries, data relationships, and Apex implementation |
| [Reference](./reference/README.md) | Find the complete feature catalog, statuses, contracts, limits, merge syntax, and exact evaluation rules |
| [Developer guides](./developer-guides/README.md) | Use Apex, asynchronous execution, Agentforce, MCP, or Pub/Sub |
| [Quality gates](./quality-gates/README.md) | Understand the checks required for code, packages, and documentation |
| [Contributing](./contributing/README.md) | Change, test, document, or review the package source |

The folder names describe user goals. You should not need to know which internal API or metadata
layer owns your question before choosing a folder.

## Choose how to build a Check

| The required data is… | Evaluation Type | Start here |
| --- | --- | --- |
| On the current record or a parent | Formula | [Formula examples](./examples/formula/README.md) |
| On related records | Query | [Query examples](./examples/query/README.md) |
| Returned by two lists that must be compared | Compare Two Queries | [Compare Two Queries examples](./examples/compare-two-queries/README.md) |
| Part of a decision that needs code | Apex | [Apex examples](./examples/apex/README.md) |

## Important behavior

- Failed, Warning, and Info are `FAIL` health results, not Salesforce errors.
- Formula and Query Checks use only the records and fields available to the person running them.
- Platform Events are optional and are not permanent storage.
- The installed examples are for learning. Create organization-owned Check Sets before using the
  framework in a business process.

For exact status mappings, use [Understand result labels and statuses](./reference/results/statuses-and-labels.md).
For help, see [Support](../SUPPORT.md).
