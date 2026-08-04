# Formula examples

> [!NOTE]
> On this page, choose a practical Formula Rule for evaluating fields on the current Salesforce record or a reachable parent record without writing Apex.

Use **Verify with a formula** when Salesforce formula syntax can answer the readiness question from
the record being checked. Formula Rules are the simplest Evaluation Type for field completeness,
Boolean combinations, numeric comparisons, applicability, parent relationships, and display-only
Found and Expected values.

## Choose a Formula example

| Example | Salesforce question | Distinct Framework technique |
| --- | --- | --- |
| [Seller research readiness](01-account-research-ready.md) | Does the Account have a Phone or Website? | Formula `OR`, optional alternatives, and an edit action |
| [Billing address review](02-billing-address-ready.md) | Are Billing City, Billing State, and Billing Country populated? | Formula `AND` with separate Found and Expected display formulas |
| [Partner regional assignment](03-partner-regional-assignment.md) | Does a Partner Account have the country needed for assignment? | Formula applicability, `SKIPPED`, and compact passed-Rule display |
| [Branch handoff](04-branch-handoff.md) | Does the parent Account contain the headquarters location? | Parent relationship fields and a parent-record action URL |
| [Small-business program eligibility](05-program-eligibility.md) | Does Number of Employees meet the program minimum? | Numeric Formula comparison with Found and Expected always visible |

## When Formula is the right choice

Choose Formula when all required values are available from the current record or a parent
relationship and the decision remains clear in Salesforce formula syntax. Use a
[Query example](../query/README.md) when the answer depends on related records, or an
[Apex example](../apex/README.md) when the logic needs several queries, calculations, or defensive
runtime behavior.

For every Formula setting, outcome, security rule, and limit, use
[Reference: Formula](../../reference/evaluation/formula.md).

## Related

- [All practical examples](../README.md)
- [Reference: Formula](../../reference/evaluation/formula.md)
- [Rule fields](../../metadata/fields-check-rule.md)
- [Create your first Rule](../../installation/03-create-your-first-rule.md)
