# Record Health Check documentation

> [!NOTE]
> On this page, find the shortest path from your Salesforce goal to the Record Health Check
> guidance that will help you finish the job.

Record Health Check is a **metadata-driven Framework**. Check Sets and Rules are defined in Custom
Metadata. The Lightning record-page card shows advisory results. The same checks can run from Apex
or Flow. The Framework never blocks a save and never writes the evaluated record.

If you are new, do **not** read every page. Follow the recommended path, or jump to the task you
need below.

## Recommended path for new users

| Step | Task | Expected result |
| ---: | --- | --- |
| 1 | [Learn how it works](installation/01-how-it-works.md) | You can explain Check Set vs Rule, and that the Framework does not block saves |
| 2 | [Install and verify](installation/02-install-and-verify.md) | A Record Health Check card appears on a sandbox record page |
| 3 | [Create your first Rule](installation/03-create-your-first-rule.md) | The card evaluates one Rule you configured in Setup |
| 4 | [Choose another example](examples/README.md) | You pick an Evaluation Type based on where the data lives |
| 5 | [Review the configuration guide](guides/03-configure-check-sets-and-rules.md) | The Check Set is ready for broader testing |

Prefer a scripted demo org instead of building from scratch? Use
[Try the demo](installation/05-create-rhc-scratch-org.md).

## What do you want to do?

| I want to… | Start here | What you will learn |
| --- | --- | --- |
| Install and see a working card | [Install and verify](installation/02-install-and-verify.md) | How to install the unlocked package, assign access, place the card, and verify |
| Revalidate or upgrade an existing org | [Revalidate an installation](installation/04-upgrading.md) | How to back up configuration and verify after upgrade |
| Remove the Framework | [Uninstall and rollback](installation/06-uninstall-and-rollback.md) | How to remove placements, subscribers, and the package |
| Answer a common question first | [FAQ](guides/02-faq.md) | Short answers on saves, editions, install paths, and Demo Check Sets |
| Create my first Rule in Setup | [Create your first Rule](installation/03-create-your-first-rule.md) | How to author a Formula Rule and test Pass and Fail |
| Copy a practical example | [Examples library](examples/README.md) | How to choose an Evaluation Type and adapt a tested pattern |
| Configure advanced Check Set / Rule behavior | [Configure Check Sets and Rules](guides/03-configure-check-sets-and-rules.md) | How to design a full readiness review |
| Add Fix it links | [Configure action links](guides/04-configure-action-links.md) | How to pair Fix Message with Action Label and URL |
| Troubleshoot an unexpected result | [Troubleshoot with Show Diagnostics](guides/07-troubleshoot-with-show-diagnostics.md) | How to reveal authorized diagnostics safely |
| Keep a production org healthy | [Operate in production](guides/08-operate-in-production.md) | Day-2 monitoring and diagnostics hygiene |
| Look up one Setup field | [Metadata reference](metadata/README.md) | Exact Setup labels, API names, and defaults |
| Look up a Framework term | [Glossary](reference/01-glossary.md) | Shared terms for outcomes and configuration |
| Choose Lightning, Apex, Flow, or events | [Integration overview](integration/README.md) | Which surface fits the readiness decision |
| Call `evaluate` from Apex | [Apex API](api/01-apex-api.md) | How to invoke Check Sets from code |
| Call checks from Flow | [Flow actions](integration/02-flow-actions.md) | How to configure an Action and Decision path |
| Write an Apex Rule plugin | [Apex Rule contract](reference/evaluation/04-apex-rule-contract.md) | The plugin interface and verification expectations |
| Subscribe to lifecycle events | [Platform Event subscriptions](platform-events/README.md) | How to build a Flow or Apex subscriber |
| Compare to Validation Rules / Duplicate Rules / Flow | [Compare to native Salesforce](guides/01-compare-to-native-salesforce.md) | When advisory health checks fit versus blocking tools |
| Review security and data access | [Security and data access](reference/framework/02-security.md) | USER_MODE, permission sets, diagnostics, and plugins |
| Check edition / Lightning compatibility | [Compatibility](reference/framework/04-compatibility.md) | Supported editions and known limits |
| Read the architecture | [Architecture](reference/framework/01-architecture.md) | Layers, entry points, and ownership |
| Browse every technical reference | [Technical references](reference/README.md) | Contracts, Evaluation Types, and Apex class guides |

## Learn by example

| Your data is… | Evaluation Type | Examples |
| --- | --- | --- |
| On the current record or a parent | Verify with a formula | [Formula examples](examples/formula/) |
| On related records | Verify with a query | [Query examples](examples/query/) |
| Returned by two independent queries | Compare two queries | [Compare-two-queries examples](examples/compare-two-queries/) |
| Part of a decision that needs custom code | Verify with Apex | [Apex examples](examples/apex/) |

[Browse every example and learning outcome →](examples/README.md)

## Important behavior to know

- Record Health Check reports readiness; it does **not** block a Salesforce record from being saved.
- A normal business issue returns `FAIL`. An unexpected execution problem returns `ERROR`.
- Formula and query evaluation uses the running user's Salesforce access.
- Lifecycle-event publication for Set Run / Rule Result is off by default (Error Log defaults on).
- The Framework ships four Demo Check Sets (`Example_…`, card titles prefixed with `Demo:`).
  Use the [examples library](examples/README.md) for teaching patterns; additional packs may live in
  [RecordHealthCheck-Examples](https://github.com/gkolan/RecordHealthCheck-Examples).

## Related

- [Installation paths](installation/README.md)
- [Guides](guides/README.md)
- [Integration overview](integration/README.md)
- [Technical references](reference/README.md)
- [Support](../SUPPORT.md)
- [Release notes](../CHANGELOG.md)
