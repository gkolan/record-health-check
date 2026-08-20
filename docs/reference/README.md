# Record Health Check technical reference

> [!NOTE]
> On this page, find the exact behavior, limit, field contract, or Apex implementation detail you
> need after reading a task guide or example.

Use this folder when you need an exact answer, such as what a Reason Code means, which merge token is
available, or how a Query Check handles no records. Package-maintainer implementation details are
kept in a separate section at the end.

For step-by-step instructions, begin with the [documentation home](../README.md) or choose a
complete configuration from the [examples library](../examples/README.md).

**Configuring Checks in Setup?** Go to **Setup → Custom Metadata Types**, then select **Manage
Records** beside **Record Health Check Set** or **Record Health Check**. Use the
[Metadata reference](../metadata/README.md) for every field and stop after the Contracts or
Evaluation Types sections below; you do not need the internal Apex pages.

**Writing a custom Apex Check?** Use the [Apex Check contract](evaluation/apex-check-contract.md).

**Maintaining the Record Health Check package source?** Use the
[internal Apex class reference](apex/README.md). Those pages describe package implementation, not
the supported Apex APIs used by code in your org.

## Recommended path

| Step | Reference | What it provides |
| ---: | --- | --- |
| 1 | [Glossary](glossary.md) | Record Health Check and Salesforce terms used throughout the documentation |
| 2 | [Evaluation Type references](#evaluation-types) | Formula, Query, Compare two queries, and Apex behavior |
| 3 | [Contracts](#contracts) | Reason Codes, merge tokens, display formatting, and field limits |
| 4 | [Administrator reference](#administrator-reference) | Security, compatibility, identity, localization, limits, and upgrades |
| 5 | [Maintainer-only reference](#maintainer-only-reference) | Architecture, source checks, threat models, and internal Apex implementation |

## Administrator reference

| Reference | What it provides |
| --- | --- |
| [Security and data access](framework/security.md) | USER_MODE, Permission Sets, diagnostics, plugins |
| [Data model](framework/data-model.md) | ERD and relationship summary |
| [Compatibility](framework/compatibility.md) | Editions, Lightning Experience, API version |
| [Platform limitations and safe patterns](framework/platform-limitations.md) | Formula, activity, Person Account, query, currency, time, and data-model edge cases |
| [Localization](framework/localization.md) | Translation Workbench, display formats |
| [Configuration identity](framework/configuration-identity.md) | Qualified API Names, the `rhc` namespace, installed metadata, and metadata created in your org |
| [Package testing and upgrades](framework/package-testing-and-upgrades.md) | Test ownership, `RunLocalTests`, package installation, and upgrade behavior |

Terms: [Glossary](glossary.md).

## Contracts

| Reference | What it provides |
| --- | --- |
| [Reason Codes](contracts/reason-codes.md) | Status meanings and first investigation steps |
| [Merge tokens](contracts/merge-tokens.md) | Syntax, availability, fallback, limits |
| [Display value format](contracts/display-value-format.md) | Found / Expected formatting |
| [Field limits](contracts/field-limits.md) | Storage and resolved-text limits |
| [Agent tool contract](contracts/agent-tool-contract.md) | Versioned Agentforce, REST, and MCP boundary |

## Evaluation Types

| Evaluation Type | Complete reference |
| --- | --- |
| Verify with a formula | [Formula](evaluation/formula.md) |
| Verify with a query | [Query](evaluation/query.md) |
| Compare two queries | [Compare two queries](evaluation/compare-two-queries.md) |
| Verify with Apex | [Apex Check contract](evaluation/apex-check-contract.md) |

## Internal Apex class guides

The [internal Apex class reference](apex/README.md) is for developers changing the package source.
It explains which classes load configuration, run Checks, build results, publish events, and support
tests.

Developers creating an Apex Check in their own org do not need those internal pages. Use the public
[Apex Check contract](evaluation/apex-check-contract.md) instead.

## Maintainer-only reference

These pages are for people changing or reviewing the package source. They are not required to
configure a Check or use the Lightning card.

| Reference | What it provides |
| --- | --- |
| [Architecture](framework/architecture.md) | Package layers, internal flows, enforcement points, and release boundaries |
| [Code Analyzer suppressions](framework/code-analyzer-suppressions.md) | Static-analysis evidence for package pull requests |
| [Agentforce and MCP threat model](framework/agent-mcp-threat-model.md) | Integration trust boundaries, threats, and controls |
| [Internal Apex class guides](apex/README.md) | Package implementation by class and responsibility |

## Related

- [Documentation home](../README.md)
- [Configure Check Sets and Checks](../guides/configure-check-sets-and-checks.md)
- [Examples library](../examples/README.md)
- [Integration overview](../integration/README.md)
- [Metadata field references](../metadata/README.md)
- [API examples](../api/README.md)
