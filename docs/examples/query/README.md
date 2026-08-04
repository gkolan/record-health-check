# Query examples

> [!NOTE]
> On this page, choose a practical Query Rule for turning related Salesforce records into a count, value, list, or per-row readiness decision.

Use **Verify with a query** when one SOQL source can retrieve the related records behind the
decision. Query Rules can compare counts, require every or any returned row to pass, inspect empty
values, search a returned list, and control what happens when no records are found.

## Choose a Query example

| Example | Salesforce question | Distinct Framework technique |
| --- | --- | --- |
| [Customer handoff](01-customer-contact.md) | Does the Account have at least one Contact? | Aggregate `COUNT()` compared with a fixed minimum |
| [Pipeline next steps](02-opportunity-next-steps.md) | Does every open Opportunity have a Next Step? | `ALL_ROWS_PASS`, empty-field failure, and no-row `SKIPPED` |
| [Meaningful pipeline](03-significant-opportunity.md) | Is any open Opportunity meaningful for this Account? | `ANY_ROW_PASSES`, record-formula comparison, and Formula applicability |
| [Forecast amounts](04-forecast-amounts.md) | Does every open Opportunity have a positive Amount? | Numeric `ALL_ROWS_PASS` with result-summary merge tokens |
| [Placeholder email cleanup](05-placeholder-contact-emails.md) | Are populated Contact emails free of a placeholder domain? | Text exclusion, ignored blanks, and a prerequisite Rule |
| [Account Owner team membership](06-account-owner-team-membership.md) | Is the Account Owner represented on the Account Team? | List membership using a record formula and Comparison Query |
| [Case review capacity](07-high-priority-case-capacity.md) | Is the high-priority Case backlog within its maximum? | Aggregate upper limit and optional lifecycle-event publication |

## When Query is the right choice

Choose Query when one related-record source contains the values the Rule must evaluate. Use
[Compare two queries](../compare-two-queries/README.md) when both sides of the decision come from
SOQL, or [Apex](../apex/README.md) when the decision needs several objects, calculations, or logic
that is difficult to express declaratively.

For every Query mode, comparison source, no-row behavior, empty-value option, and limit, use
[Reference: Query](../../reference/evaluation/query.md).

## Related

- [All practical examples](../README.md)
- [Reference: Query](../../reference/evaluation/query.md)
- [Rule fields](../../metadata/fields-check-rule.md)
- [Configure Check Sets and Rules](../../guides/configure-check-sets-and-rules.md)
