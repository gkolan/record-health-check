# Query examples

> [!NOTE]
> On this page, choose a Query example when the answer depends on related Salesforce records.

Use **Verify with a query** when one SOQL query can retrieve the related records needed for the
decision. For example, count Contacts, require every open Opportunity to have a Next Step, or check
whether the Account Owner appears in the Account Team.

SOQL is Salesforce Object Query Language. You paste it into **Source Query**. A minimal related
query has this shape:

```sql
SELECT Id
FROM Contact
WHERE AccountId = {!record.Id}
```

`SELECT` chooses the returned field, `FROM` names the object, and `WHERE` relates rows to the open
record. `{!record.Id}` is replaced safely with that record's ID.

Messages can use a display fallback, such as `{!record.Name fallback="this record"}`, so guidance
remains readable when an optional value is blank or unavailable.

These pages are instructions; the installed package does not create these Checks. Follow an
example to create a Check in **Setup → Custom Metadata Types → Record Health Check → Manage
Records**.

## Choose a Query example

| Example | Salesforce question | What the example demonstrates |
| --- | --- | --- |
| [Customer handoff](customer-contact.md) | Does the Account have at least one Contact? | Aggregate `COUNT()` compared with a fixed minimum |
| [Pipeline next steps](opportunity-next-steps.md) | Does every open Opportunity have a Next Step? | `ALL_ROWS_PASS`, empty-field failure, and no-row `SKIPPED` |
| [Meaningful pipeline](significant-opportunity.md) | Is any open Opportunity meaningful for this Account? | `ANY_ROW_PASSES`, record-formula comparison, and Formula applicability |
| [Forecast amounts](forecast-amounts.md) | Does every open Opportunity have a positive Amount? | Numeric `ALL_ROWS_PASS` with result-summary merge tokens |
| [Placeholder email cleanup](placeholder-contact-emails.md) | Are populated Contact emails free of a placeholder domain? | Text exclusion, ignored blanks, and a prerequisite Check |
| [Account Owner team membership](account-owner-team-membership.md) | Is the Account Owner represented on the Account Team? | List membership using a record formula and Comparison Query |
| [Case review capacity](high-priority-case-capacity.md) | Is the high-priority Case backlog within its maximum? | Aggregate upper limit and optional lifecycle-event publication |

## When Query is the right choice

Choose Query when one related-record source contains the values the Check must evaluate. Use
[Compare two queries](../compare-two-queries/README.md) when both sides of the decision come from
SOQL, or [Apex](../apex/README.md) when the decision needs custom calculations or combines several
Salesforce objects.

Choose **How To Read Query Results** based on what the query returns:

| Value | Use it when |
| --- | --- |
| **One row or aggregate** | The query returns one field value, `COUNT()`, `SUM()`, or another single aggregate value |
| **Any record passes** | At least one returned record must meet the comparison |
| **Every record passes** | Every returned record must meet the comparison |
| **Compare as lists** | The Check searches a returned list or compares it with another list |

For **Any record passes**, **Every record passes**, and **Compare as lists**, also choose **If Query
Finds No Records**. Do not select its result mechanically. Decide what no matching records means for
the requirement: `PASS`, `FAIL`, `SKIPPED`, or `UNABLE_TO_EVALUATE`.

**Comparison Query** supplies the list used by list-membership modes; for two independent query
results, use the separate Compare Two Queries Evaluation Type. Set **Max Query Rows** from 1 to
2,000. If the source returns more than the configured cap, the Check returns Unable to Check with
`ROW_LIMIT_EXCEEDED` rather than evaluating a partial list. A malformed query or missing field also
returns an unable result with a Reason Code.

A **Prerequisite Check** prevents this Check from running until an earlier Check in the same Set
passes. Put the prerequisite earlier in Evaluation Order.

All queries run with the running user's record and field access. Test the Check with the access
assigned to intended users, especially when hidden related records could change the result.

For every Query mode, comparison source, no-row behavior, empty-value option, and limit, use
[Reference: Query](../../reference/evaluation/query.md).

## Related

- [All practical examples](../README.md)
- [Reference: Query](../../reference/evaluation/query.md)
- [Check fields](../../metadata/fields-check.md)
- [Configure Check Sets and Checks](../../guides/configure-check-sets-and-checks.md)
