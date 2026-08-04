# Reference: Apex scope orchestration (L4)

> [!NOTE]
> On this page, look up the L4 classes that resolve a Check Set or Rule selection and evaluate
> one complete ordered record scope.

This page is part of the [Apex class reference](README.md). For the architecture story, see
[Architecture § How one Rule is evaluated](../framework/architecture.md#6-how-one-rule-is-evaluated).

## Scope orchestration (L4)

### `RecordHealthCheckScopePipeline`

**Role:** Resolves a qualified selection and evaluates one complete ordered record scope.
**Type:** Service class · `public with sharing`

Every public surface (`RecordHealthCheck.evaluate`, Flow actions, Lightning
`evaluateCheck` / `completeRun`) ends in this pipeline. It plans the scope, loads records in
USER_MODE, dispatches Evaluation Types, shapes display results, and returns the common response
envelope.

**Key members:**

| Member | Purpose |
| --- | --- |
| `evaluate(...)` | Run one qualified Rule or Check Set selection over a detached record scope |

**Notable behavior:**
- **Gotcha:** the card evaluates one Rule per Apex transaction; Apex and Flow may evaluate a whole
  Check Set in one call. Do not assume identical governor budgets across those surfaces.
- **Gotcha:** selection identities are Custom Metadata `QualifiedApiName` values.

**See also:** [Entry points](entry-points.md), [Evaluators](evaluators.md)

### `RecordHealthCheckScopePlanner`

**Role:** Selection, request budgets, applicability, and prerequisite planning.
**Type:** Service class · `public with sharing`

Decides which Rules run, which records are in scope, and whether applicability or prerequisite
checks skip a Rule before evaluation.

**Notable behavior:**
- **Gotcha:** an applicability miss returns `SKIPPED` with a Reason Code; it is not a Fail.

### `RecordHealthCheckEvaluatorRegistry`

**Role:** Maps Evaluation Type values to a common scope evaluator contract.
**Type:** Service class · `public with sharing`

Dispatches `FORMULA`, `SOQL`, `COMPARE_QUERIES`, and `APEX` to the matching L3 evaluator.

**See also:** [Evaluators](evaluators.md)

### `RecordHealthCheckFieldPlanner`

**Role:** Internal field-planning support used by the scope pipeline.
**Type:** Service class · `public with sharing`

Builds the approved set of readable record fields needed by a Rule before
`RecordHealthCheckScopePipeline` performs its scope-wide user-mode load. Public callers use
`RecordHealthCheck.evaluate(request)` and do not call the planner directly.

**Key members:**

| Member | Purpose |
| --- | --- |
| `collectRecordFields(...)` | Plan the record fields needed by a Rule before the scope-wide user-mode load |

**Notable behavior:**
- **Gotcha:** candidate fields are resolved through describe metadata before entering dynamic SOQL;
  malformed, unavailable, and unreadable paths are ignored.

### `RecordHealthCheckBulkQuerySupport`

**Role:** Executes supported query templates once for a complete scope.
**Type:** Service class · `public with sharing`

Runs a validated SOQL template across the whole record scope and attributes rows back to each
requested record Id.

**See also:** [Query Evaluation Type](../evaluation/query.md)

### `RecordHealthCheckBulkQueryRewriter`

**Role:** Rewrites validated query templates for scope-wide execution.
**Type:** Service class · `public with sharing`

Transforms a Rule's SOQL template so one query can serve every record in the scope without changing
the Rule author's intent.

### `RecordHealthCheckScopeResultSupport`

**Role:** Converts internal outcomes into public results, diagnostics, display text, and safe URLs.
**Type:** Service class · `public with sharing`

Applies display shaping, Reason Code remapping for access-sensitive failures, and Action URL safety
after evaluation completes.

**See also:** [Security and data access](../framework/security.md), [Results and plugins](results-and-plugins.md)

---

## Related

- [Apex class reference](README.md)
- [Architecture](../framework/architecture.md)
- [Entry points](entry-points.md)
- [Evaluators](evaluators.md)
