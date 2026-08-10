# Formula examples

> [!NOTE]
> On this page, choose a Formula example when the answer comes from fields on the record being
> checked or one of its parent records.

Use **Verify with a formula** when a Salesforce formula can return `TRUE` for a passing record and
`FALSE` for a record that needs attention. For example, require several Account fields, allow Phone
or Website, compare Number of Employees with a limit, or read a field from the parent Account.

These pages are instructions; the installed package does not create these Checks. Follow an
example to create a Check in **Setup → Custom Metadata Types → Record Health Check → Manage
Records**.

## Choose a Formula example

| Example | Salesforce question | What the example demonstrates |
| --- | --- | --- |
| [Seller research readiness](account-research-ready.md) | Does the Account have a Phone or Website? | Formula `OR`, optional alternatives, and an edit action |
| [Billing address review](billing-address-ready.md) | Are Billing City, Billing State, and Billing Country populated? | Formula `AND` with separate Found and Expected display formulas |
| [Partner regional assignment](partner-regional-assignment.md) | Does a Partner Account have the country needed for assignment? | Formula applicability, `SKIPPED`, and compact passed-Check display |
| [Branch handoff](branch-handoff.md) | Does the parent Account contain the headquarters location? | Parent relationship fields and a parent-record action URL |
| [Small-business program eligibility](program-eligibility.md) | Does Number of Employees meet the program minimum? | Numeric Formula comparison with Found and Expected always visible |

## When Formula is the right choice

Choose Formula when all required values are available from the current record or a parent
relationship and the decision is clear in Salesforce formula syntax. A Formula Check cannot read a
list of child records such as an Account's Contacts. Use a [Query example](../query/README.md) for
child or other related records. Use an [Apex example](../apex/README.md) when the requirement needs
custom calculations or must combine data from several Salesforce objects.

Every Formula Check needs:

| Setup field | What to enter |
| --- | --- |
| **Evaluation Type** | Verify with a formula |
| **Pass Condition** | A Salesforce formula that returns `TRUE` to pass and `FALSE` to fail |
| **Applies To** | All records, or an optional rule that produces `SKIPPED` when the Check does not apply |

**Display: Found Formula** and **Display: Expected Formula** are optional. They explain the result
on the card but do not decide whether the record passes. Leave **Formula Result Type** as **Auto**
unless the example explains why another type is useful.

Formula evaluation uses the running user's access to the record and fields. Test the passing and
failing cases with the access assigned to intended users, not only with administrator access.

For every Formula setting, outcome, security check, and limit, use
[Reference: Formula](../../reference/evaluation/formula.md).

## Related

- [All practical examples](../README.md)
- [Reference: Formula](../../reference/evaluation/formula.md)
- [Check fields](../../metadata/fields-check.md)
- [Create your first Check](../../installation/create-your-first-check.md)
