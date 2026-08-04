# Technical references

> [!NOTE]
> On this page, choose the trusted technical reference for a Framework outcome, field limit, or
> source-code responsibility and find the related Salesforce configuration contract.

Use these references when you need exact Framework behavior rather than a task walkthrough. For a
guided configuration path, begin with the [documentation home](../README.md) or
the [examples library](../examples/README.md).

**Looking up Setup fields?** Use [Metadata reference](../metadata/README.md), not this folder.

**Writing an Apex Rule plugin?** Use [Apex Rule contract](evaluation/apex-rule-contract.md).
**Maintaining Framework Apex classes?** Use the [Apex class reference](apex/README.md).

## Choose a technical reference

| Your question | Reference | What it provides |
| --- | --- | --- |
| How is the Framework structured end to end? | [Architecture](framework/architecture.md) | Principles, layers, Rule path, entry points, limits, and ownership overview |
| How does security and data access work? | [Security and data access](framework/security.md) | USER_MODE, Permission Sets, diagnostics, persistence, events, plugins, and fix links |
| How do Check Sets, Rules, and events relate? | [Data model](framework/data-model.md) | ERD and relationship summary for configuration and lifecycle events |
| Which editions and experiences are supported? | [Compatibility](framework/compatibility.md) | Editions, Lightning Experience, API version, and known limits |
| Are labels and messages translation-ready? | [Localization](framework/localization.md) | Translation Workbench scope, display formats, and comparison values |
| How do Qualified API Names and package boundaries work? | [Configuration identity](framework/configuration-identity.md) | Exact identity contract, `rhc` namespace, and Demo vs subscriber metadata |
| What do Framework terms mean? | [Glossary](glossary.md) | Check Set, Rule, Evaluation Type, Reason Code, QualifiedApiName, and outcome vocabulary |
| What does this stable result code mean? | [Reason Codes](contracts/reason-codes.md) | Status meanings and the first useful investigation for each code |
| Which merge-token namespaces and limits apply? | [Merge tokens](contracts/merge-tokens.md) | Strict syntax, availability, fallback behavior, and limits |
| How are Found and Expected values formatted? | [Display value format](contracts/display-value-format.md) | Display: Value Format choices and automatic type formatting |
| Why was a value rejected or text returned `UNABLE_TO_EVALUATE`? | [Field limits](contracts/field-limits.md) | Salesforce storage limits, Framework resolved limits, and remedies |
| What does each production Apex class own? | [Apex classes](apex/README.md) | Layer index, then L5→L1 class guides |

## Choose an Evaluation Type reference

Use these when you know the Rule's Evaluation Type and need its complete setup contract, operators,
outcomes, limits, security behavior, or failure paths.

| Evaluation Type | Use it when the Rule needs to… | Complete reference |
| --- | --- | --- |
| **Verify with a formula** | Evaluate fields on the current record or a reachable parent record | [Formula](evaluation/formula.md) |
| **Verify with a query** | Evaluate related Salesforce records through one SOQL source | [Query](evaluation/query.md) |
| **Compare two queries** | Compare two independent SOQL results as counts, values, or lists | [Compare two queries](evaluation/compare-two-queries.md) |
| **Verify with Apex** | Run custom logic that Formula and Query Rules cannot express clearly | [Apex Rule contract](evaluation/apex-rule-contract.md) |

## Other reference families

| Information you need | Reference family |
| --- | --- |
| Check Set and Rule Custom Metadata fields | [Metadata field references](../metadata/README.md) |
| Platform Event fields and subscriber possibilities | [Platform Event references](../metadata/README.md#choose-a-platform-event-reference) |
| Public Apex methods and response classes | [Apex API](../api/apex-api.md) |
| Flow and asynchronous Apex examples | [API examples](../api/README.md) |
| Flow and Apex Platform Event subscribers | [Platform Event subscriptions](../platform-events/README.md) |
| Plugin verification harness | [Plugin verification](apex/plugin-verification.md) |
| Test-seam / architecture policy (contributors) | [Contributor policy: Apex test seams](apex/test-seams.md) |
| Folder map for framework, evaluation, contracts, and Apex | See the four directories under `docs/reference/`. Writing a Rule plugin uses `evaluation/apex-rule-contract.md`; maintaining Framework classes uses `apex/` |

## Related

- [Documentation home](../README.md)
- [Configure Check Sets and Rules](../guides/configure-check-sets-and-rules.md)
- [Examples library](../examples/README.md)
- [Integration overview](../integration/README.md)
