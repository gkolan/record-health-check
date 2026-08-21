# Compare two queries examples

> [!NOTE]
> On this page, choose an example that compares the results of two SOQL queries without custom
> Apex.

Use **Compare two queries** when both values needed for the decision come from Salesforce records.
For example, compare the number of open Opportunities with the number that have Contact Roles, or
compare open-pipeline Product IDs with previously purchased Product IDs.

## Choose a Compare two queries example

| Example | Salesforce question | What the example demonstrates |
| --- | --- | --- |
| [Opportunity Contact Role coverage](opportunity-contact-role-coverage.md) | Does every open Opportunity have a Contact Role? | Aggregate aliases, two-query equality, and count-query applicability |
| [Open-pipeline product continuity](open-pipeline-product-continuity.md) | Does open pipeline include a Product the customer previously purchased? | Two lists compared with **Lists overlap** |
| [Account Team coverage](account-team-opportunity-coverage.md) | Does the Account Team include every open Opportunity owner? | Two lists compared with **Lists contain all** and no-row failure |

These examples are instructions; the installed package does not create these Checks. Follow one
example to create a Check in **Setup → Custom Metadata Types → Record Health Check → Manage
Records**.

## When two queries are the right choice

Choose this Evaluation Type when the answer requires comparing two query results. Use a
[Query example](../query/README.md) when one query result can be compared with a fixed value or a
value from the current record. Use an [Apex example](../apex/README.md) only when the available
count and list comparisons cannot express the requirement clearly.

Both **Source Query** and **Comparison Query** are required. If one side is a fixed value or current
record field, use Verify with a query instead. For aggregates other than bare `COUNT()`, give the
aggregate an alias in SOQL and enter that alias in the matching query-field setting.

Every example configures these fields:

| Setup field | What it does |
| --- | --- |
| **Source Query** | Produces the value shown as **Found** |
| **Comparison Query** | Produces the value shown as **Expected** |
| **How To Read Query Results** | Chooses whether each query is read as one count/value or as a list |
| **Comparison Operator** | Decides whether Found passes when compared with Expected |

The three list operators answer different questions:

| Comparison Operator | Passes when |
| --- | --- |
| **Lists overlap** | Found and Expected share at least one value |
| **Lists contain all** | Expected contains every value in Found; Expected can contain additional values |
| **Lists match exactly** | Found and Expected contain the same values |

For example, Source `[005A, 005B]` and Comparison `[005A, 005B, 005C]` pass **Lists contain all**
because the Comparison side covers every required Source value. Reversing the queries asks a
different question. **Lists match exactly** would fail because Comparison has the extra `005C`.

Choose the documented no-row behavior for each example. An empty Source list can mean there is
nothing to require, while an empty Comparison list can mean no coverage exists; do not assume those
business meanings are interchangeable.

The running user's record and field access applies to both queries. A value the user cannot access
cannot appear in either result, so test the Check with the same access assigned to its intended
users.

For both query shapes, compatible operators, no-row behavior, security, and limits, use
[Reference: Compare two queries](../../reference/evaluation/compare-two-queries.md).

## Related

- [All practical examples](../README.md)
- [Reference: Compare two queries](../../reference/evaluation/compare-two-queries.md)
- [Check fields](../../metadata/fields-check.md)
- [Configure Check Sets and Checks](../../guides/configure-check-sets-and-checks.md)
