# Technical references

> [!NOTE]
> On this page, choose the trusted technical reference for a Framework outcome, field limit, or
> source-code responsibility and find the related Salesforce configuration contract.

Use these references when you need exact Framework behavior rather than a task walkthrough. For a
guided configuration path, begin with the [documentation home](../README.md) or
the [examples library](../examples/README.md).

**Looking up Setup fields?** Use [Metadata reference](../metadata/README.md), not this folder.

**Writing an Apex Rule plugin?** Use [Apex Rule contract](evaluation/04-apex-rule-contract.md).
**Maintaining Framework Apex classes?** Use the [Apex class reference](apex/README.md).

## Recommended path - Framework

| Step | Reference | What it provides |
| ---: | --- | --- |
| 1 | [Architecture](framework/01-architecture.md) | Principles, layers, Rule path, entry points, limits |
| 2 | [Security and data access](framework/02-security.md) | USER_MODE, Permission Sets, diagnostics, plugins |
| 3 | [Data model](framework/03-data-model.md) | ERD and relationship summary |
| 4 | [Compatibility](framework/04-compatibility.md) | Editions, Lightning Experience, API version |
| 5 | [Localization](framework/05-localization.md) | Translation Workbench, display formats |
| 6 | [Configuration identity](framework/06-configuration-identity.md) | Qualified API Names, `rhc` namespace, Demo vs subscriber |

Terms: [Glossary](01-glossary.md).

## Contracts

| Step | Reference | What it provides |
| ---: | --- | --- |
| 1 | [Reason Codes](contracts/01-reason-codes.md) | Status meanings and first investigation steps |
| 2 | [Merge tokens](contracts/02-merge-tokens.md) | Syntax, availability, fallback, limits |
| 3 | [Display value format](contracts/03-display-value-format.md) | Found / Expected formatting |
| 4 | [Field limits](contracts/04-field-limits.md) | Storage and resolved-text limits |

## Evaluation Types

| Step | Evaluation Type | Complete reference |
| ---: | --- | --- |
| 1 | Verify with a formula | [Formula](evaluation/01-formula.md) |
| 2 | Verify with a query | [Query](evaluation/02-query.md) |
| 3 | Compare two queries | [Compare two queries](evaluation/03-compare-two-queries.md) |
| 4 | Verify with Apex | [Apex Rule contract](evaluation/04-apex-rule-contract.md) |

## Apex class guides

Layer index (L5→L1): [Apex classes](apex/README.md).

## Related

- [Documentation home](../README.md)
- [Configure Check Sets and Rules](../guides/03-configure-check-sets-and-rules.md)
- [Examples library](../examples/README.md)
- [Integration overview](../integration/README.md)
- [Metadata field references](../metadata/README.md)
- [API examples](../api/README.md)
