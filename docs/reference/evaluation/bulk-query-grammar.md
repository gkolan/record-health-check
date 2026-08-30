# Bulk query grammar

This reference defines the supported grammar for advanced Query Checks.

This is the exact supported grammar for advanced Query Checks.

> [!NOTE]
> On this page, maintainers can compare the supported query strategies used by the Apex runtime
> with the release inventory that prevents unsupported query shapes from entering the package.

This contract defines how a query authored for one record is classified for one scope-wide query.
The Apex runtime in `RecordHealthCheckBulkQuerySupport` is the source of truth. The release inventory in
`scripts/release/inventory_bulk_query_shapes.py` mirrors these rules and pins changed shapes with
self-tests so CI cannot approve a strategy the runtime would not use.

| Strategy | Authored shape | Scope behavior |
| --- | --- | --- |
| `SELF` | `Id = {!record.Id}` | Query the evaluated records and correlate by `Id`. |
| `CHILD_DIRECT` | A direct field equals `{!record.Id}` | Group rows by that lookup field. |
| `CHILD_PATH` | A relationship path equals `{!record.Id}` | Group rows by that relationship path. |
| `TOKEN_INDIRECT` | A field equals another record token, including a token with options such as `fallback` | Collect token values, query once, and map rows back to the scope. |
| `SCOPE_INVARIANT` | No record token | Execute once and reuse the result for every record. |
| `ORDERED_PICK_AGGREGATE` | One bare selected field is also the single ordered field with `LIMIT 1` | Rewrite to `MIN` or `MAX` grouped by the correlation field. |
| `ORDERED_PICK_IN_MEMORY` | `ORDER BY ... LIMIT 1` where the selected field differs from the ordered field or is a relationship path | Fetch a bounded scope result and choose one row per record in Apex. |
| `UNCLASSIFIED` | Unsupported or ambiguous correlation | Reject the configuration; do not fall back to one query per record. |

The aggregate ordered-pick strategy accepts only a bare field. A relationship selection such as
`Owner.Name` must remain in-memory because `MIN(Owner.Name)` is not a safe generated selection.
Negated correlation, non-equality correlation, multiple ordered fields with a limit, and per-record
limits greater than one are unclassified.

For example, `WHERE Id = {!record.OwnerId fallback="005000000000001"}` remains
`TOKEN_INDIRECT`: token options do not make a record-correlated query scope-invariant. Use a real
fallback value that is valid for the referenced field; the synthetic ID here documents grammar
only.

The generated [bulk query shape inventory](../../../scripts/release/generated/bulk-query-shape-inventory.md)
records the strategy selected for every shipped and integration-fixture query template.

## Related

- [Framework architecture](../../architecture/framework.md)
- [Query evaluation](./query.md)
- [Bulk query shape inventory](../../../scripts/release/generated/bulk-query-shape-inventory.md)
