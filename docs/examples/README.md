# Record Health Check examples

> [!NOTE]
> On this page, turn the question you want to answer about a Salesforce record into the right Evaluation Type and a practical Rule you can adapt with confidence.

Use these examples to build a health check for a Salesforce record. Each example starts with a
business question, explains which Evaluation Type fits, lists the Setup values, and shows how to
test the result.

You do not need to read every page. Choose the row that is closest to what you want to check, copy
the example, and adapt its fields and messages for your organization.

> [!TIP]
> **Not installed yet?** Finish [Install and verify](../installation/02-install-and-verify.md) first,
> then return here. Prefer the shipped Demo Check Sets for a first sandbox proof, then adapt an
> example for your org.

## Choose the right Evaluation Type

Start with where the information for your check is stored.

| What do you need to check? | Use | Good first example |
| --- | --- | --- |
| Fields on the current record or a parent record | [**Verify with a formula**](formula/README.md) | [Seller research readiness](formula/01-account-research-ready.md) |
| Related records, such as Contacts, Opportunities, or Cases | [**Verify with a query**](query/README.md) | [Customer handoff](query/01-customer-contact.md) |
| Whether the results of two queries match or overlap | [**Compare two queries**](compare-two-queries/README.md) | [Opportunity Contact Role coverage](compare-two-queries/01-opportunity-contact-role-coverage.md) |
| Logic that formulas and queries cannot express clearly | [**Verify with Apex**](apex/README.md) | [Recent Account activity](apex/01-recent-activity.md) |

> [!TIP]
> Start with a formula when possible. Move to a query when the answer depends on related records.
> Use Apex only when the other Evaluation Types cannot express the business decision clearly.

## How to use an example

1. Open an example that resembles your business requirement.
2. Read **Why use this Evaluation Type** to confirm that it is the right approach.
3. Copy the values from **Configure the Rule** into **Setup → Custom Metadata Types → Record
   Health Check Rule → Manage Records**.
4. Replace the sample fields, values, and messages with the ones approved for your organization.
5. Follow **Test the Rule** and confirm both a passing and a failing result before activating it.

The shared [reference folder](../reference/README.md) keeps all Evaluation Type contracts in one place. Use
the practical examples when you are learning or building a Rule. Use a reference when you need all
available settings, operators, limits, or result behavior.

| Evaluation Type | Start with | Detailed reference |
| --- | --- | --- |
| [Verify with a formula](formula/README.md) | [Seller research readiness](formula/01-account-research-ready.md) | [Formula reference](../reference/evaluation/formula.md) |
| [Verify with a query](query/README.md) | [Customer handoff](query/01-customer-contact.md) | [Query reference](../reference/evaluation/query.md) |
| [Compare two queries](compare-two-queries/README.md) | [Opportunity Contact Role coverage](compare-two-queries/01-opportunity-contact-role-coverage.md) | [Compare two queries reference](../reference/evaluation/compare-two-queries.md) |
| [Verify with Apex](apex/README.md) | [Recent Account activity](apex/01-recent-activity.md) | [Apex reference](../reference/evaluation/apex-rule-contract.md) |

## Formula examples

Choose **Verify with a formula** when the Rule can read everything it needs from the current record
or a parent relationship. A formula is usually the simplest option and does not require Apex.

| Example | What it checks | What you will learn |
| --- | --- | --- |
| [Seller research readiness](formula/01-account-research-ready.md) | An Account has a Phone or Website | Allow either of two fields to satisfy a Rule |
| [Billing address review](formula/02-billing-address-ready.md) | Required billing-address fields are populated | Require several fields together |
| [Partner regional assignment](formula/03-partner-regional-assignment.md) | Partner Accounts have regional-assignment information | Run a Rule only for matching records |
| [Branch handoff](formula/04-branch-handoff.md) | A branch has the headquarters information needed for handoff | Read a parent record and link users to it |
| [Small-business program eligibility](formula/05-program-eligibility.md) | Employee count meets a program limit | Compare a number and explain the found and expected values |

## Query examples

Choose **Verify with a query** when the answer depends on related Salesforce records. One query can
return a count, a field value, or a list for the Rule to evaluate.

| Example | What it checks | What you will learn |
| --- | --- | --- |
| [Customer handoff](query/01-customer-contact.md) | An Account has at least one Contact | Compare a related-record count with a minimum |
| [Pipeline next steps](query/02-opportunity-next-steps.md) | Every open Opportunity has a Next Step | Require every returned record to pass |
| [Meaningful pipeline](query/03-significant-opportunity.md) | At least one open Opportunity meets an Account-specific amount | Compare query results with a value from the current record |
| [Forecast amounts](query/04-forecast-amounts.md) | Every open Opportunity has an Amount greater than zero | Evaluate numbers and handle empty values |
| [Placeholder email cleanup](query/05-placeholder-contact-emails.md) | Contact emails do not use a placeholder domain | Check text returned by a query |
| [Account Owner team membership](query/06-account-owner-team-membership.md) | The Account Owner is also an Account Team member | Find a current-record value in a related-record list |
| [Case review capacity](query/07-high-priority-case-capacity.md) | The high-priority Case backlog stays within a limit | Compare a related-record count with a maximum |

## Compare-two-queries examples

Choose **Compare two queries** when both sides of the decision come from related records. The Rule
can compare two counts or determine whether two lists match, contain the same values, or overlap.

| Example | What it checks | What you will learn |
| --- | --- | --- |
| [Opportunity Contact Role coverage](compare-two-queries/01-opportunity-contact-role-coverage.md) | Every open Opportunity has a Contact Role | Compare two related-record counts |
| [Open-pipeline product continuity](compare-two-queries/02-open-pipeline-product-continuity.md) | Open pipeline includes a previously purchased Product | Check whether two lists share a value |
| [Account Team coverage](compare-two-queries/03-account-team-opportunity-coverage.md) | The Account Team includes every open Opportunity Owner | Check whether one list contains every value from another list |

## Apex examples

Choose **Verify with Apex** when the Rule needs calculations, several steps, or Salesforce behavior
that the other Evaluation Types cannot express clearly. Apex examples require development and test
coverage before deployment.

| Example | What it checks | What you will learn |
| --- | --- | --- |
| [Recent Account activity](apex/01-recent-activity.md) | An Account has a recent completed Task or Event | Combine results from multiple Salesforce objects and accept a configurable date window |
| [Open Opportunity health](apex/02-open-opportunity-health.md) | An open Opportunity does not have several warning signs at once | Apply several conditions to the same related record |
| [Strategic Account readiness](apex/03-strategic-readiness.md) | A Strategic Account meets a weighted readiness score | Calculate and explain a configurable score |
| [Inactive approval participants](apex/04-inactive-approver.md) | An approval assignment does not include an inactive user | Inspect approval data while accounting for licensed product objects |

## Framework functionality covered

The library is organized so each practical example adds a different Framework technique. Examples
may use the same Salesforce object, but they do not repeat the same Rule pattern.

| Example | Distinct Framework depth |
| --- | --- |
| [Seller research readiness](formula/01-account-research-ready.md) | Formula `OR`, optional alternatives, and an edit action |
| [Billing address review](formula/02-billing-address-ready.md) | Formula `AND` with display-only Found and Expected formulas |
| [Partner regional assignment](formula/03-partner-regional-assignment.md) | Formula applicability, `SKIPPED`, and count-only display for passed Rules |
| [Branch handoff](formula/04-branch-handoff.md) | Parent relationship fields and a parent-record action URL |
| [Small-business program eligibility](formula/05-program-eligibility.md) | Numeric Formula comparison with Found/Expected visible on every result |
| [Customer handoff](query/01-customer-contact.md) | Aggregate `COUNT()` compared with a fixed minimum |
| [Pipeline next steps](query/02-opportunity-next-steps.md) | `ALL_ROWS_PASS`, **Is not empty**, no-row `SKIPPED`, and empty-field failure |
| [Meaningful pipeline](query/03-significant-opportunity.md) | `ANY_ROW_PASSES` compared with an Account formula and formula applicability |
| [Forecast amounts](query/04-forecast-amounts.md) | Numeric `ALL_ROWS_PASS` with result-summary merge tokens |
| [Placeholder email cleanup](query/05-placeholder-contact-emails.md) | Text exclusion, ignored blank fields, and a prerequisite Rule |
| [Account Owner team membership](query/06-account-owner-team-membership.md) | Query list-membership mode using a record formula and Comparison Query |
| [Case review capacity](query/07-high-priority-case-capacity.md) | Aggregate upper limit plus optional Rule Result and Check Set Run lifecycle events |
| [Opportunity Contact Role coverage](compare-two-queries/01-opportunity-contact-role-coverage.md) | Aggregate alias, two-query equality, and count-query applicability |
| [Open-pipeline product continuity](compare-two-queries/02-open-pipeline-product-continuity.md) | Two lists compared with **Lists overlap** |
| [Account Team coverage](compare-two-queries/03-account-team-opportunity-coverage.md) | Two lists compared with **Lists contain all** and no-row failure |
| [Recent Account activity](apex/01-recent-activity.md) | Apex across Task and Event with bounded JSON parameters |
| [Open Opportunity health](apex/02-open-opportunity-health.md) | Apex applying several conditions to each related record plus count-query applicability |
| [Strategic Account readiness](apex/03-strategic-readiness.md) | Weighted Apex score, multiple JSON parameters, and formula applicability |
| [Inactive approval participants](apex/04-inactive-approver.md) | Dynamic object and field names, defensive `UNABLE_TO_EVALUATE`, and stop-after-`ERROR` behavior |

The reference pages document additional operators and limits that do not need a separate business
example. The library favors a smaller set of credible, clearly differentiated Rules over one page
for every possible picklist value.

## Related documentation

- [Create your first Rule](../installation/03-create-your-first-rule.md)
- [Configure Check Sets and Rules](../guides/configure-check-sets-and-rules.md)
- [Rule fields](../metadata/fields-check-rule.md)
- [Check Set fields](../metadata/fields-check-set.md)
