# Examples you can copy

> [!NOTE]
> On this page, choose an Evaluation Type and a complete example that matches the Salesforce
> requirement you want to check.

Use these examples to build a health check for a Salesforce record. Each example starts with a
business question, explains which Evaluation Type fits, lists the Setup values, and shows how to
test the result.

You do not need to read every page. Choose the row closest to your requirement, create a Check from
the example values, and replace its fields, limits, and messages with values approved for your org.

> [!IMPORTANT]
> The pages in this library are instructions, not metadata installed in your org. The installed
> package includes [four Check Sets and 21 Checks](../install/explore-installed-examples.md) whose names
> begin with `rhc__Example_`. Other examples exist only in these documentation pages unless an
> administrator creates them.

Unless a page states otherwise, its Check Set shows a **Run** button with the `utility:play` icon
and changes the button label to **Rerun** after the first run. The configuration tables give the
exact field values.

> [!TIP]
> **Not installed yet?** Finish [Install and verify](../install/install-in-a-sandbox.md) first,
> then return here. Use an example Check Set included with the installed package for the first
> sandbox test. Create a new Check Set for your org before adapting a documentation example.

## Choose the right Evaluation Type

Start with where Salesforce stores the information needed to decide whether the record passes.

| What do you need to check? | Use | Good first example |
| --- | --- | --- |
| Fields on the current record or a parent record | [**Verify with a formula**](./formula/README.md) | [Seller research readiness](./formula/account-research-ready.md) |
| Related records, such as Contacts, Opportunities, or Cases | [**Verify with a query**](./query/README.md) | [Customer handoff](./query/customer-contact.md) |
| Whether the results of two queries match or overlap | [**Compare two queries**](./compare-two-queries/README.md) | [Opportunity Contact Role coverage](./compare-two-queries/opportunity-contact-role-coverage.md) |
| A decision that requires custom code | [**Verify with Apex**](./apex/README.md) | [Recent Account activity](./apex/recent-activity.md) |

> [!TIP]
> Start with a formula when possible. Move to a query when the answer depends on related records.
> Use Apex only when the other Evaluation Types cannot express the business decision clearly.

## How to use an example

1. Open an example that resembles your business requirement.
2. Read **Why use this Evaluation Type** to confirm why the example uses Formula, Query, Compare
   Two Queries, or Apex.
3. Create the Check Set first when the example requires a new one. In Setup, go to **Custom Metadata
   Types → Record Health Check Set → Manage Records**.
4. Create the Check. In Setup, go to **Custom Metadata Types → Record Health Check → Manage
   Records** and copy the values from **Configure the Check**.
5. Replace the sample fields, limits, and messages with values that match your org's requirement.
6. Add the Record Health Check component to the correct Lightning record page if it is not already
   present. Select the Check Set, save, and activate the page as **Org Default**, **App Default**,
   or for the intended app, record type, and profiles.
7. Assign **Record Health Check Card User** to the test user and confirm that the Check Set **Object**
   matches the Lightning record page object.
8. Follow **Test the Check** and confirm the documented passing, failing, skipped, or error results
   that apply before making the Check available to users.

`utility:play` is a standard Lightning icon name that you paste into **Run Button Icon**; it is not
a file upload. Tables can show API values such as `ALL_ROWS_PASS` beside their Setup labels so
developers can identify metadata, but administrators should select the visible Setup label.

The [technical reference](../reference/README.md) lists every setting, operator, limit, and result
rule. Use an example when creating a Check. Use the reference when the example does not cover a
setting you need.

| Evaluation Type | Start with | Detailed reference |
| --- | --- | --- |
| [Verify with a formula](./formula/README.md) | [Seller research readiness](./formula/account-research-ready.md) | [Formula reference](../reference/evaluation/formula.md) |
| [Verify with a query](./query/README.md) | [Customer handoff](./query/customer-contact.md) | [Query reference](../reference/evaluation/query.md) |
| [Compare two queries](./compare-two-queries/README.md) | [Opportunity Contact Role coverage](./compare-two-queries/opportunity-contact-role-coverage.md) | [Compare two queries reference](../reference/evaluation/compare-two-queries.md) |
| [Verify with Apex](./apex/README.md) | [Recent Account activity](./apex/recent-activity.md) | [Apex reference](../developer-guides/write-an-apex-check.md) |

## Formula examples

Choose **Verify with a formula** when the Check can read everything it needs from the current record
or a parent relationship. A formula is usually the simplest option and does not require Apex.

| Example | What it checks | What you will learn |
| --- | --- | --- |
| [Seller research readiness](./formula/account-research-ready.md) | An Account has a Phone or Website | Allow either of two fields to satisfy a Check |
| [Billing address review](./formula/billing-address-ready.md) | Required billing-address fields are populated | Require several fields together |
| [Partner regional assignment](./formula/partner-regional-assignment.md) | Partner Accounts have regional-assignment information | Run a Check only for matching records |
| [Branch handoff](./formula/branch-handoff.md) | A branch has the headquarters information needed for handoff | Read a parent record and link users to it |
| [Small-business program eligibility](./formula/program-eligibility.md) | Employee count meets a program limit | Compare a number and explain the found and expected values |

## Query examples

Choose **Verify with a query** when the answer depends on related Salesforce records. One query can
return a count, a field value, or a list for the Check to evaluate.

| Example | What it checks | What you will learn |
| --- | --- | --- |
| [Customer handoff](./query/customer-contact.md) | An Account has at least one Contact | Compare a related-record count with a minimum |
| [Pipeline next steps](./query/opportunity-next-steps.md) | Every open Opportunity has a Next Step | Require every returned record to pass |
| [Meaningful pipeline](./query/significant-opportunity.md) | At least one open Opportunity meets an Account-specific amount | Compare query results with a value from the current record |
| [Forecast amounts](./query/forecast-amounts.md) | Every open Opportunity has an Amount greater than zero | Evaluate numbers and handle empty values |
| [Placeholder email cleanup](./query/placeholder-contact-emails.md) | Contact emails do not use a placeholder domain | Check text returned by a query |
| [Account Owner team membership](./query/account-owner-team-membership.md) | The Account Owner is also an Account Team member | Find a current-record value in a related-record list |
| [Case review capacity](./query/high-priority-case-capacity.md) | The high-priority Case backlog stays within a limit | Compare a related-record count with a maximum |

## Compare-two-queries examples

Choose **Compare two queries** when both sides of the decision come from related records. The Check
can compare two counts or determine whether two lists match, contain the same values, or overlap.

| Example | What it checks | What you will learn |
| --- | --- | --- |
| [Opportunity Contact Role coverage](./compare-two-queries/opportunity-contact-role-coverage.md) | Every open Opportunity has a Contact Role | Compare two related-record counts |
| [Open-pipeline product continuity](./compare-two-queries/open-pipeline-product-continuity.md) | Open pipeline includes a previously purchased Product | Check whether two lists share a value |
| [Account Team coverage](./compare-two-queries/account-team-opportunity-coverage.md) | The Account Team includes every open Opportunity Owner | Check whether one list contains every value from another list |

## Apex examples

Choose **Verify with Apex** when the Check needs calculations, several steps, or Salesforce behavior
that the other Evaluation Types cannot express clearly. Apex examples require development and test
coverage before deployment.

`AccountHasRecentActivityCheck` is included in the managed package. The strategic-readiness and
inactive-approver classes are integration-test examples and are not installed in a subscriber org.
The open-opportunity example is also a source-development recipe unless your team deploys it.

| Example | What it checks | What you will learn |
| --- | --- | --- |
| [Recent Account activity](./apex/recent-activity.md) | An Account has a recent completed Task or Event whose `WhatId` is the Account | Combine WhatId-scoped Task/Event results and accept a configurable date window |
| [Open Opportunity health](./apex/open-opportunity-health.md) | An open Opportunity does not have several warning signs at once | Apply several conditions to the same related record |
| [Strategic Account readiness](./apex/strategic-readiness.md) | A Strategic Account meets a weighted readiness score | Calculate and explain a configurable score |
| [Inactive approval participants](./apex/inactive-approver.md) | An approval assignment does not include an inactive user | Inspect approval data while accounting for licensed product objects |

## What makes each example different

Each example teaches a different Record Health Check feature. Examples can use the same Salesforce
object without repeating the same configuration pattern.

| Example | Feature demonstrated |
| --- | --- |
| [Seller research readiness](./formula/account-research-ready.md) | Formula `OR`, optional alternatives, and an edit action |
| [Billing address review](./formula/billing-address-ready.md) | Formula `AND` with display-only Found and Expected formulas |
| [Partner regional assignment](./formula/partner-regional-assignment.md) | Formula applicability, `SKIPPED`, and count-only display for passed Checks |
| [Branch handoff](./formula/branch-handoff.md) | Parent relationship fields and a parent-record action URL |
| [Small-business program eligibility](./formula/program-eligibility.md) | Numeric Formula comparison with Found/Expected visible on every result |
| [Customer handoff](./query/customer-contact.md) | Aggregate `COUNT()` compared with a fixed minimum |
| [Pipeline next steps](./query/opportunity-next-steps.md) | `ALL_ROWS_PASS`, **Is not empty**, no-row `SKIPPED`, and empty-field failure |
| [Meaningful pipeline](./query/significant-opportunity.md) | `ANY_ROW_PASSES` compared with an Account formula and formula applicability |
| [Forecast amounts](./query/forecast-amounts.md) | Numeric `ALL_ROWS_PASS` with result-summary merge tokens |
| [Placeholder email cleanup](./query/placeholder-contact-emails.md) | Text exclusion, ignored blank fields, and a prerequisite Check |
| [Account Owner team membership](./query/account-owner-team-membership.md) | Query list-membership mode using a record formula and Comparison Query |
| [Case review capacity](./query/high-priority-case-capacity.md) | Aggregate upper limit plus optional Check Result and Check Set Run lifecycle events |
| [Opportunity Contact Role coverage](./compare-two-queries/opportunity-contact-role-coverage.md) | Aggregate alias, two-query equality, and count-query applicability |
| [Open-pipeline product continuity](./compare-two-queries/open-pipeline-product-continuity.md) | Two lists compared with **Lists overlap** |
| [Account Team coverage](./compare-two-queries/account-team-opportunity-coverage.md) | Two lists compared with **Lists contain all** and no-row failure |
| [Recent Account activity](./apex/recent-activity.md) | Apex across Task and Event with bounded JSON parameters |
| [Open Opportunity health](./apex/open-opportunity-health.md) | Apex applying several conditions to each related record plus count-query applicability |
| [Strategic Account readiness](./apex/strategic-readiness.md) | Weighted Apex score, multiple JSON parameters, and formula applicability |
| [Inactive approval participants](./apex/inactive-approver.md) | Dynamic object and field names, defensive `UNABLE_TO_EVALUATE`, and stop-after-`ERROR` behavior |

The reference pages document additional operators and limits that do not need separate examples.

## Related documentation

- [Create your first Check](../step-by-step-guide/create-your-first-check.md)
- [Installed example Check Sets](../install/explore-installed-examples.md)
- [Configure Check Sets and Checks](../build-checks/configure-check-sets-and-checks.md)
- [Check fields](../reference/custom-metadata/check-fields.md)
- [Check Set fields](../reference/custom-metadata/check-set-fields.md)
