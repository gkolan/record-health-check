# Apex examples

> [!NOTE]
> On this page, choose an Apex example when a Formula or Query Check cannot express the Salesforce
> requirement clearly.

> [!IMPORTANT]
> Administrators can use the installed Recent Account activity class by selecting it in Setup.
> Writing or deploying any other Apex class is a developer task. If you do not have a reviewed,
> deployed class, choose Formula, Query, or Compare Two Queries instead.

Use this page to select an example before creating a **Verify with Apex** Check. Record Health Check
calls an Apex class written for the requirement. The
class receives the record IDs being checked and any values entered in **Apex Parameters (JSON)**.
It must return one result for every record ID.

## Choose an Apex example

| Example | Salesforce question | What the Apex demonstrates | Availability |
| --- | --- | --- | --- |
| [Recent Account activity](recent-activity.md) | Does the Account have a recent completed Task or Event? | Reads two objects and accepts a configurable number of days | Included with the installed package |
| [Open Opportunity health](open-opportunity-health.md) | Does any open Opportunity carry all three coaching risks? | Applies several conditions to each related record | Source example for package development and testing; not installed |
| [Strategic Account readiness](strategic-readiness.md) | Does a Strategic Account meet a configurable weighted score? | Calculates a score using several configurable values | Source example for package development and testing; not installed |
| [Inactive approval participants](inactive-approver.md) | Is a pending approval assigned to an inactive user? | Checks optional product objects and reports when they are unavailable | Source example for package development and testing; not installed |

Only **Recent Account activity** is ready to use after package installation. The other classes live
under `packages/record-health-check/integration-tests` and are not installed. Their pages explain
how to build a subscriber-owned class from the pattern by using the public `rhc.*` Apex types. Do
not copy an integration-test class unchanged into an org with the installed package.

On a Check record, select **Evaluation Type → Verify with Apex**. Salesforce then shows **Apex Class
Name** and **Apex Parameters (JSON)**. Select or enter only a class that exists in the org, and paste
the exact JSON documented by that class. A missing class normally produces Unable to Check; a class
that violates the plugin contract can produce System Error and a plugin Reason Code.

## What Record Health Check passes to Apex

The class must implement `rhc.RecordHealthCheckPlugin`. Record Health Check calls its `evaluate()`
method once for all record IDs in the current transaction.

| Apex value | What it contains |
| --- | --- |
| `scope.recordIds` | The records being checked: normally one from the Lightning card, or as many as 200 in one Apex or Flow request |
| `scope.parameters` | The values an administrator entered in **Apex Parameters (JSON)** on the Check |
| Returned `Map<Id, rhc.RecordHealthCheckOutcome>` | Exactly one `PASS`, `FAIL`, `SKIPPED`, or `UNABLE_TO_EVALUATE` outcome for every supplied record ID |

Do not put record IDs in **Apex Parameters (JSON)**. Record Health Check supplies them in
`scope.recordIds`. Copy that list once and use it in a SOQL `IN` filter so one query reads the data
for every record in the transaction:

```apex
List<Id> recordIds = scope.recordIds;

List<Account> accounts = [
  SELECT Id, Industry
  FROM Account
  WHERE Id IN :recordIds
  WITH USER_MODE
];
```

The Apex class must not run SOQL once per record. It also must not perform DML, make callouts, start
another background job, or publish events. Record Health Check rejects those side effects. The
[Apex Check contract](../../reference/evaluation/apex-check-contract.md) explains the complete
interface, security rules, result values, and tests.

## When Apex is the right choice

Choose Apex after confirming that Formula, Query, or Compare Two Queries cannot state the
requirement clearly. Apex is useful for calculations, reading several Salesforce objects, or
handling an optional installed product. It also requires a developer to create, secure, test, and
deploy the class.

Start with [Recent Account activity](recent-activity.md) for the complete, installed example. It
shows the class, its test behavior, every Check field, and what an administrator sees.

## Related

- [All practical examples](../README.md)
- [Reference: Apex](../../reference/evaluation/apex-check-contract.md)
- [Check fields](../../metadata/fields-check.md)
