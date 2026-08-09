# Technical references

> [!NOTE]
> On this page, choose the trusted technical reference for a Framework outcome, field limit, or
> source-code responsibility and find the related Salesforce configuration contract.

Use these references when you need exact Framework behavior rather than a task walkthrough. For a
guided configuration path, begin with the [documentation home](../README.md) or
the [examples library](../examples/README.md).

**Looking up Setup fields?** Use [Metadata reference](../metadata/README.md), not this folder.

**Writing an Apex Check plugin?** Use [Apex Check contract](evaluation/apex-check-contract.md).
**Maintaining Framework Apex classes?** Use the [Apex class reference](apex/README.md).

## Recommended path

| Step | Reference | What it provides |
| ---: | --- | --- |
| 1 | [Glossary](glossary.md) | Exact Framework terms and the primary page for each term |
| 2 | [Evaluation Type references](#evaluation-types) | Formula, Query, Compare two queries, and Apex behavior |
| 3 | [Contracts](#contracts) | Reason Codes, merge tokens, display formatting, and field limits |
| 4 | [Framework references](#framework-references) | Architecture, security, compatibility, identity, and package behavior |
| 5 | [Apex class guides](#apex-class-guides) | Source ownership and implementation detail for maintainers |

## Framework references

| Reference | What it provides |
| --- | --- |
| [Architecture](framework/architecture.md) | Principles, layers, Check path, entry points, limits |
| [Security and data access](framework/security.md) | USER_MODE, Permission Sets, diagnostics, plugins |
| [Data model](framework/data-model.md) | ERD and relationship summary |
| [Compatibility](framework/compatibility.md) | Editions, Lightning Experience, API version |
| [Localization](framework/localization.md) | Translation Workbench, display formats |
| [Configuration identity](framework/configuration-identity.md) | Qualified API Names, `rhc` namespace, Demo vs subscriber |
| [Package testing and upgrades](framework/package-testing-and-upgrades.md) | Test ownership, RunLocalTests, subscriber upgrade path |

Terms: [Glossary](glossary.md).

## Contracts

| Reference | What it provides |
| --- | --- |
| [Reason Codes](contracts/reason-codes.md) | Status meanings and first investigation steps |
| [Merge tokens](contracts/merge-tokens.md) | Syntax, availability, fallback, limits |
| [Display value format](contracts/display-value-format.md) | Found / Expected formatting |
| [Field limits](contracts/field-limits.md) | Storage and resolved-text limits |

## Evaluation Types

| Evaluation Type | Complete reference |
| --- | --- |
| Verify with a formula | [Formula](evaluation/formula.md) |
| Verify with a query | [Query](evaluation/query.md) |
| Compare two queries | [Compare two queries](evaluation/compare-two-queries.md) |
| Verify with Apex | [Apex Check contract](evaluation/apex-check-contract.md) |

## Apex class guides

The [Apex class reference](apex/README.md) explains its maintainer-only layer numbering before the
class index. Plugin authors can stay on the public [Apex Check contract](evaluation/apex-check-contract.md).

## Related

- [Documentation home](../README.md)
- [Configure Check Sets and Checks](../guides/configure-check-sets-and-checks.md)
- [Examples library](../examples/README.md)
- [Integration overview](../integration/README.md)
- [Metadata field references](../metadata/README.md)
- [API examples](../api/README.md)
