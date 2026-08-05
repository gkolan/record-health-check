# Install or revalidate Record Health Check

> [!NOTE]
> On this page, choose a safe route for a new installation or an existing-org revalidation and see the Salesforce outcome each step is designed to prove.

Use the new-install path when the org does not already contain Record Health Check. Use the
revalidation path when the org already has Custom Metadata configuration, Lightning placement,
Apex callers, Flow integrations, or Platform Event subscribers.

**Not sure you need this Framework yet?** Start with
[How it works](01-how-it-works.md) and
[Compare to native Salesforce](../guides/01-compare-to-native-salesforce.md) before you install.

## Choose your path

| Your starting point | Follow this path | What you will accomplish |
| --- | --- | --- |
| I am new and only need a sandbox card working | [Install and verify](02-install-and-verify.md) (Option A: unlocked package) | Install, assign access, place the card, verify a Demo Check Set |
| I want to understand Check Sets and Rules first | [How it works](01-how-it-works.md) → [Install and verify](02-install-and-verify.md) → [Create your first Rule](03-create-your-first-rule.md) | Understand the Framework, install, place the card, and author one Formula Rule |
| I want the complete scripted demo | [Create the demo scratch org](05-create-rhc-scratch-org.md) | Reproduce the maintained demo org, data, record page, permissions, and verified outcomes |
| Record Health Check is already installed | [Revalidate an installation](04-upgrading.md) | Back up configuration, validate and deploy or upgrade, verify integrations, retain rollback |
| I need to remove Record Health Check | [Uninstall and rollback](06-uninstall-and-rollback.md) | Remove placements, subscribers, permission assignments, and the package or source metadata |
| I want another Rule pattern | [Examples library](../examples/README.md) | Choose an Evaluation Type and adapt a tested configuration |

## New installation sequence

| Step | Page | What you learn or verify |
| ---: | --- | --- |
| 1 | [How Record Health Check works](01-how-it-works.md) | How Check Sets, Rules, Evaluation Types, and outcomes fit together |
| 2 | [Install and verify](02-install-and-verify.md) | How to install the unlocked package (Option A) or source-deploy (Option B), assign access, place the card, and verify |
| 3 | [Create your first Rule](03-create-your-first-rule.md) | How to create a Check Set and Formula Rule in Setup and test both PASS and FAIL |

## Existing-installation sequence

The [revalidation guide](04-upgrading.md) starts with a restorable configuration backup. It uses the
same manifest for dry-run validation and deployment, then verifies Lightning pages, user access,
business outcomes, integrations, event subscribers, and rollback evidence.

## Next steps

- [Documentation home](../README.md): task map for install, configure, integrate, and reference
- [Examples library](../examples/README.md): learn through complete Salesforce scenarios
- [Metadata reference](../metadata/README.md): look up current Setup labels, API names, allowed values, and defaults
- [Operate in production](../guides/08-operate-in-production.md): day-2 monitoring and diagnostics hygiene
- [Uninstall and rollback](06-uninstall-and-rollback.md): remove an installation safely
