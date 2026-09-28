# Reference

Use this section when you need an exact field definition, rule, status, contract, platform
behavior, or explanation of how the framework is structured. For instructions that produce an
outcome, return to the [documentation home](../README.md) and choose a task-based guide.

## Choose a reference area

| Folder                                                         | What you can find there                                                                                        |
| -------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| [Feature catalog](./feature-catalog.md)                        | Every shipped capability, its supported behavior, and the detailed guide that owns it                          |
| [Public contract](./current-contract.md)                       | Complete plugin, evidence, display, diagnostics, preview, readiness, limit, and compatibility contract         |
| [Source inventory](./source-inventory.md)                      | Package contents generated directly from metadata and Apex source                                              |
| [Permission Sets](./permission-sets.md)                        | The seven installed access bundles and the ways they authorize runs, diagnostics, events, and readiness review |
| [Custom Permissions](./custom-permissions.md)                  | The Run Custom Permission and the separate Permission Set assignment used for diagnostics authorization        |
| [Configuration](./configuration/README.md)                     | Names, display formatting, and field limits                                                                    |
| [Merge syntax](./merge-syntax/README.md)                       | Token namespaces, properties, fallbacks, and SOQL usage                                                        |
| [Evaluation](./evaluation/README.md)                           | Exact Formula, Query, Compare Two Queries, and bulk-query behavior                                             |
| [Custom Metadata](./custom-metadata/README.md)                 | Check Set and Check configuration field dictionaries                                                           |
| [Platform Event metadata](./platform-event-metadata/README.md) | Fields published by the three Record Health Check Platform Events                                              |
| [Results](./results/README.md)                                 | Card labels, API statuses, and Reason Codes                                                                    |
| [Platform](./platform/README.md)                               | Compatibility, localization, limitations, and Salesforce-specific edge cases                                   |
| [Contracts](./contracts/README.md)                             | Versioned integration boundaries                                                                               |

Use the [glossary](./glossary.md) when a Record Health Check or Salesforce term is unfamiliar.

## Common lookups

| I need to know…                                                           | Reference                                                                              |
| ------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| What the package supports                                                 | [Complete feature catalog](./feature-catalog.md)                                       |
| What the public contract guarantees                                       | [Public contract](./current-contract.md)                                               |
| Which field to use in Setup                                               | [Custom Metadata](./custom-metadata/README.md)                                         |
| Which Permission Set to assign                                            | [Permission Sets](./permission-sets.md)                                                |
| What a readiness receipt stores and who can read it                       | [Readiness receipts](./readiness-receipts.md)                                          |
| What the Run Custom Permission controls, and how diagnostics access works | [Custom Permissions](./custom-permissions.md)                                          |
| Which fields a Platform Event publishes                                   | [Platform Event metadata](./platform-event-metadata/README.md)                         |
| Why a result says `FAIL`, `ERROR`, or `UNABLE_TO_EVALUATE`                | [Result statuses and card labels](./results/statuses-and-labels.md)                    |
| What a Reason Code means                                                  | [Reason Codes](./results/reason-codes.md)                                              |
| Which merge tokens are supported                                          | [Merge tokens](./merge-syntax/README.md)                                               |
| How Formula or Query evaluation behaves                                   | [Evaluation reference](./evaluation/README.md)                                         |
| How the framework is assembled                                            | [Framework architecture](../architecture/framework.md)                                 |
| Which package Apex class owns a responsibility                            | [Package Apex implementation reference](../architecture/apex-implementation/README.md) |

## Related

- [Documentation home](../README.md)
- [Build Checks](../build-checks/README.md)
- [Architecture](../architecture/README.md)
- [Custom Metadata](./custom-metadata/README.md)
- [Permission Sets](./permission-sets.md)
- [Readiness receipts](./readiness-receipts.md)
- [Custom Permissions](./custom-permissions.md)
- [Platform Event metadata](./platform-event-metadata/README.md)
- [Developer guides](../developer-guides/README.md)
- [Contributing](../contributing/README.md)
