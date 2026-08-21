# Apex classes that coordinate a health-check request (L4)

> [!IMPORTANT]
> **Audience: package maintainers and Salesforce developers.** This class-level reference is not a
> Setup or Flow walkthrough. Administrators should use the Flow, configuration, and evaluation
> guides; subscriber developers should use the public Apex API or Apex Check contract.

> [!NOTE]
> Use this page to understand the internal classes that select the Checks, load the Salesforce
> records, run each Evaluation Type, and assemble the response. Custom Apex should start with
> `rhc.RecordHealthCheck.evaluate(...)`, not call these classes directly.

This page is part of the [Apex class reference](README.md). For the architecture story, see
[Architecture § How one Check is evaluated](../framework/architecture.md#6-how-one-check-is-evaluated).

## Request coordination (L4)

### `RecordHealthCheckScopePipeline`

**Role:** Coordinate one request from its Qualified API Name through its final response.

**Type:** Service class · `public with sharing`

`RecordHealthCheck.evaluate`, the installed Flow actions, and the Lightning card's `evaluateCheck`
method use this class. It validates the request, loads the requested Salesforce records with user
access enforced, runs the applicable Checks in order, optionally adds display content, publishes the
requested Platform Events, and returns `RecordHealthCheckResponse`. The Lightning card's
`completeRun` method publishes already-completed results and does not run this class again.

**Key members:**

| Member | Purpose |
| --- | --- |
| `evaluate(...)` | Run the requested Check or Check Set for the supplied record IDs |

**Notable behavior:**

- **Important:** the card evaluates one Check per Apex transaction; Apex and Flow may evaluate a whole
  Check Set in one transaction. The same Check Set can therefore use more transaction limits in Apex
  or Flow than it does on the card.
- **Important:** use the exact Check or Check Set **Qualified API Name** copied from Setup. Do not use
  its label or add or remove `rhc__`.

**See also:** [Entry points](entry-points.md), [Evaluators](evaluators.md)

### `RecordHealthCheckScopePlanner`

**Role:** Decide which Checks and records can run before evaluation begins.

**Type:** Service class · `public with sharing`

Loads the selected Check or Check Set, confirms that it is active and matches the record IDs' object,
and enforces the 25-Check and 200-record limits. It also checks the planned Formula Evaluation and
custom Apex Check limits before any Check runs. For each Check, it determines which records are
applicable and whether a prerequisite result requires the Check to be skipped.

**Notable behavior:**

- **Important:** an applicability miss returns `SKIPPED` with a Reason Code; it is not a Fail.
- Transaction planning reserves the scope record load, applicability queries, every evaluator
  query, both sides of Compare Two Queries, and the second query used when a Query Check selects
  `COMPARISON_QUERY` as its expected-value source.

### `RecordHealthCheckEvaluatorRegistry`

**Role:** Send each Check to the class that runs its Evaluation Type.

**Type:** Service class · `public with sharing`

Maps the Custom Metadata values `FORMULA`, `QUERY`, `COMPARE_TWO_QUERIES`, and `APEX` to the matching
evaluator class.

**See also:** [Evaluators](evaluators.md)

### `RecordHealthCheckFieldPlanner`

**Role:** Identify which fields must be loaded from each Salesforce record.

**Type:** Service class · `public with sharing`

Reads the Check's formulas, merge tokens, and other settings to identify the record fields it needs.
The pipeline then loads those fields for all requested records in one user-mode query. Custom Apex
uses `RecordHealthCheck.evaluate(request)` and does not call this class directly.

**Key members:**

| Member | Purpose |
| --- | --- |
| `collectRecordFields(...)` | Identify the record fields referenced by a Check |

**Notable behavior:**

- Before a field enters dynamic SOQL, the class confirms through Salesforce describe information
  that the field path exists and is readable. An invalid or inaccessible field is not added to the
  record query; the affected Check later returns the appropriate configuration or access result.

### `RecordHealthCheckFormulaFieldScanner`

**Role:** Extract selectable record paths from a Salesforce formula expression.

**Type:** Formula parsing service · `public with sharing`

Masks formula string literals and global references, preserves complete relationship paths, and
normalizes validated polymorphic colon references such as `Owner:User.IsActive` into the dot path
the record query can select. `RecordHealthCheckFieldPlanner` calls this class while expanding
formula dependencies; custom Apex does not call it directly.

**Key members:**

| Member | Purpose |
| --- | --- |
| `scan(...)` | Return described record-field paths in document order with duplicates removed |

### `RecordHealthCheckBulkQuerySupport`

**Role:** Run a supported Query Check SOQL template once for all requested records.

**Type:** Service class · `public with sharing`

Replaces the record-specific condition with one query that covers all requested record IDs, then
assigns the returned rows to the matching record. This prevents one SOQL query per record.
Classification masks string literals and considers only depth-zero correlation, ordering, and limit
clauses. A record token found only in a nested query or literal is rejected as
`UNSUPPORTED_BULK_QUERY_SHAPE`; it is never used to rewrite the outer query accidentally.

**See also:** [Query Evaluation Type](../evaluation/query.md)

### `RecordHealthCheckBulkQueryRewriter`

**Role:** Convert a record-specific SOQL template into one bulk query.

**Type:** Service class · `public with sharing`

Changes a validated SOQL template so one query can serve all requested record IDs without changing
the condition configured by the Check author. An unsupported query shape is rejected instead of
falling back to a query inside a record loop.

### `RecordHealthCheckScopeResultSupport`

**Role:** Convert each internal result into the response returned to Apex, Flow, or Lightning.

**Type:** Service class · `public with sharing`

Adds requested display text, hides or replaces access-sensitive Reason Codes when needed, and checks
that an Action URL is safe before returning it.

**See also:** [Security and data access](../framework/security.md), [Results and plugins](results-and-plugins.md)

---

## Related

- [Apex class reference](README.md)
- [Architecture](../framework/architecture.md)
- [Entry points](entry-points.md)
- [Evaluators](evaluators.md)
