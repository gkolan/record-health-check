# Record Health Check documentation

> [!NOTE]
> On this page, find the shortest path from your Salesforce goal to the Record Health Check
> guidance that will help you finish the job.

Record Health Check is a **metadata-driven Framework**. Check Sets and Checks are defined in Custom
Metadata. The Lightning record-page card shows advisory results. The same checks can run from Apex
or Flow. The Framework never blocks a save and never writes the evaluated record.

If you are new, follow the recommended path. If you already know the task, use the intent table to
open the page that owns it.

## Recommended path for new users

| Step | Task | Expected result |
| ---: | --- | --- |
| 1 | [Learn how it works](installation/how-it-works.md) | You can explain Check Set vs Check, and that the Framework does not block saves |
| 2 | [Install and verify in your org](installation/install-and-verify.md) | A Record Health Check card appears on a sandbox record page |
| 3 | [Create your first Check](installation/create-your-first-check.md) | The card evaluates one Check you configured in Setup |
| 4 | [Choose another example](examples/README.md) | You pick an Evaluation Type based on where the data lives |
| 5 | [Review the configuration guide](guides/configure-check-sets-and-checks.md) | The Check Set is ready for broader testing |

Prefer to evaluate known records and outcomes in a separate org? Use
[Deploy to a demo scratch org](installation/create-rhc-scratch-org.md).

## What do you want to do?

| I want to… | Start here | What you will learn |
| --- | --- | --- |
| Learn the product and create a first Check | [Installation and first Check](installation/README.md) | Product fit, installation, a prepared demo, and the first successful Check |
| Configure a complete review | [Guides](guides/README.md) | Check Set behavior, action links, card styling, AI-assisted drafting, and troubleshooting |
| Start from a working pattern | [Examples](examples/README.md) | Formula, Query, Compare two queries, and Apex patterns organized by where the data lives |
| Connect Lightning, Flow, Apex, or events | [Integration overview](integration/README.md) | Supported callers, responses, asynchronous execution, and Platform Event subscribers |
| Operate an installation | [Production operations](guides/operate-in-production.md) | Upgrade, monitoring, diagnostics, backups, and removal |
| Look up an exact contract | [Technical references](reference/README.md) | Fields, limits, security behavior, compatibility, and source architecture |

## Common tasks

| Task | Start here |
| --- | --- |
| Decide whether Record Health Check fits | [Compare to native Salesforce](guides/compare-to-native-salesforce.md) |
| Install or upgrade the package | [Choose an installation path](installation/README.md) |
| Configure a complete readiness review | [Configure Check Sets and Checks](guides/configure-check-sets-and-checks.md) |
| Troubleshoot an unexpected result | [Troubleshoot Record Health Check](guides/troubleshoot-with-show-diagnostics.md) |
| Choose Lightning, Apex, Flow, or events | [Integration overview](integration/README.md) |
| Build a Platform Event subscriber | [Platform Event subscription guides](platform-events/README.md) |
| Stream events to an external system | [External Pub/Sub API subscriber](platform-events/external-pub-sub-api.md) |
| Look up a Setup field or API name | [Metadata reference](metadata/README.md) |
| Review security or compatibility | [Security and data access](reference/framework/security.md) and [compatibility](reference/framework/compatibility.md) |

## Learn by example

| Your data is… | Evaluation Type | Examples |
| --- | --- | --- |
| On the current record or a parent | Verify with a formula | [Formula examples](examples/formula/README.md) |
| On related records | Verify with a query | [Query examples](examples/query/README.md) |
| Returned by two independent queries | Compare two queries | [Compare-two-queries examples](examples/compare-two-queries/README.md) |
| Part of a decision that needs custom code | Verify with Apex | [Apex examples](examples/apex/README.md) |

[Browse every example and learning outcome →](examples/README.md)

## Important behavior to know

- Record Health Check reports readiness; it does **not** block a Salesforce record from being saved.
- A normal business issue returns `FAIL`. An unexpected execution problem returns `ERROR`.
- Formula and query evaluation uses the running user's Salesforce access.
- Lifecycle-event publication for Set Run / Check Result is off by default (Error Log defaults on).
- The Framework ships four example Check Sets (`Example_…`, card titles prefixed with `Example:`).
  Use the [examples library](examples/README.md) for teaching patterns.

## Related

- [Installation paths](installation/README.md)
- [Guides](guides/README.md)
- [Integration overview](integration/README.md)
- [Technical references](reference/README.md)
- [Support](../SUPPORT.md)
- [Release notes](../CHANGELOG.md)
