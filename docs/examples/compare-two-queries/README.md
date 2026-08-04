# Compare two queries examples

> [!NOTE]
> On this page, choose a practical Rule for comparing two independent SOQL results as counts or lists without writing custom Apex.

Use **Compare two queries** when both sides of the readiness decision come from related Salesforce
records. The Framework can compare two aggregate values or determine whether two returned lists
are equal, overlap, or contain all required values.

## Choose a Compare two queries example

| Example | Salesforce question | Distinct Framework technique |
| --- | --- | --- |
| [Opportunity Contact Role coverage](01-opportunity-contact-role-coverage.md) | Does every open Opportunity have a Contact Role? | Aggregate aliases, two-query equality, and count-query applicability |
| [Open-pipeline product continuity](02-open-pipeline-product-continuity.md) | Does open pipeline include a Product the customer previously purchased? | Two lists compared with **Lists overlap** |
| [Account Team coverage](03-account-team-opportunity-coverage.md) | Does the Account Team include every open Opportunity owner? | Two lists compared with **Lists contain all** and no-row failure |

These teaching configurations are illustrative. They are not installed by the Framework package.
Adapt the field tables into your org's Custom Metadata when you want the behavior.

## When two queries are the right choice

Choose this Evaluation Type when a complete answer requires comparing two related-record
populations. Use a [Query example](../query/README.md) when only one SOQL source is needed. Move to
an [Apex example](../apex/README.md) only when the comparison cannot be expressed through the
supported count, value, or list operators.

For both query shapes, compatible operators, no-row behavior, security, and limits, use
[Reference: Compare two queries](../../reference/evaluation/compare-two-queries.md).

## Related

- [All practical examples](../README.md)
- [Reference: Compare two queries](../../reference/evaluation/compare-two-queries.md)
- [Rule fields](../../metadata/fields-check-rule.md)
- [Configure Check Sets and Rules](../../guides/configure-check-sets-and-rules.md)
