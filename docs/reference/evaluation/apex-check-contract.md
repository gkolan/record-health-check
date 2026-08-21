# Create a custom Apex Check

Audience: Salesforce developers. Administrators select **Verify with Apex** for **Evaluation Type**
and paste a reviewed class API name into the Check record; they do not need to implement this
contract. Use a Formula or Query Check when either can express the rule safely.

> [!NOTE]
> On this page, create an Apex class for logic that cannot be expressed with a Formula or Query
> Check. The class receives up to 200 record IDs at once and must return one result for every ID.

## Interface

```apex
global interface RecordHealthCheckPlugin {
  Map<Id, RecordHealthCheckOutcome> evaluate(RecordHealthCheckScope scope);
}
```

This is the interface declared inside the installed package. A class created in your org uses the
`rhc.` prefix, as shown in the complete example below.

Declare the class `global with sharing` so the installed package can call it. Run every SOQL query
with the intended user access; the example uses `WITH USER_MODE`. Record Health Check validates the
returned record IDs, Statuses, Reason Codes, and prohibited actions, but your class remains
responsible for object, field, and record access in its own queries.

Treat deployment of a custom Apex Check like any other security-sensitive Apex deployment. `with
sharing` enforces record sharing, but it does not by itself enforce object and field access. Record
Health Check can detect prohibited changes; it cannot prove whether every custom query used user
mode. A code review is therefore required even when the contract test passes.

## Scope

The Scope contains the information supplied to the custom Apex Check.

`rhc.RecordHealthCheckScope` provides:

| Property | Meaning |
| --- | --- |
| `objectApiName` | Object shared by the requested IDs |
| `recordIds` | Copy of all requested record IDs in order |
| `recordIdAt(index)` | One ID at a numbered position, without creating another list copy |
| `parameters` | Parsed Check parameter JSON |
| `checkQualifiedApiName` | Selected Check identity |
| `checkSetQualifiedApiName` | Parent Check Set identity |
| `runId` | ID that connects results, logs, and events from the same run |

The class cannot change the package's original request. Read `recordIds` into a local variable once,
query for all IDs together, organize the query results in a map, and then build one outcome per
record. Each access to `scope.recordIds` returns another list copy. For a numbered loop, use
`scope.size()` and `scope.recordIdAt(index)` instead.

## Outcome

Return one Outcome for every requested record ID.

Build outcomes with the factories on `rhc.RecordHealthCheckOutcome`:

```apex
rhc.RecordHealthCheckOutcome.pass('RECENT_ACTIVITY_FOUND')
  .withFound(rhc.RecordHealthCheckValue.ofCount(3))
  .withComparison(
    'GREATER_THAN',
    rhc.RecordHealthCheckValue.ofCount(0)
  );
```

Available Status factories are `pass`, `fail`, `unableToEvaluate`, and `skipped`.
`error` is reserved for package contract failures. Found and Expected use
`rhc.RecordHealthCheckValue` factories for String, Boolean, Number, Date, DateTime, ID, Count,
and List values.

`RecordHealthCheckValue` carries a typed value, not a currency unit. The package cannot inspect or
repair arithmetic already performed inside a subscriber plugin, so custom Apex owns its currency
correctness. If a plugin compares monetary values, query and retain their ISO units explicitly and
refuse or deliberately normalize them according to the plugin's documented contract. The core
framework performs no currency conversion and does not infer plugin-internal units from display
labels.

The custom class does not set record identity, Check identity, Severity, display text, links, or
diagnostics. Record Health Check gets those values from the returned map key and Check Custom
Metadata.

### Provide Found and Expected values

An Apex Check must return Found and Expected values with their Salesforce data types for every
`PASS` or `FAIL` outcome.
The Check fields **Display: Found Text** and **Display: Expected Text** do not wrap or replace
those custom Apex values. If either field is populated on an Apex Check, metadata validation reports
the non-blocking `APEX_DISPLAY_TEXT_IGNORED` warning. Put the values in the custom class with
`.withFound()`, `.withExpected()`, or `.withComparison()`; use the Check failure message when
administrators need configurable explanatory wording.

## Bulk pattern

This example checks whether each Account has at least one Contact. It first creates a FAIL outcome
with a count of zero for every Account. One grouped query finds Accounts that have Contacts, and the
code replaces only those outcomes with PASS. Accounts with no query row still have a result.

```apex
global with sharing class ContactPresenceCheck
  implements rhc.RecordHealthCheckPlugin {
  global Map<Id, rhc.RecordHealthCheckOutcome> evaluate(
    rhc.RecordHealthCheckScope scope
  ) {
    // Read the property once because it returns a new list copy each time.
    List<Id> accountIds = scope.recordIds;

    Map<Id, rhc.RecordHealthCheckOutcome> outcomes =
      new Map<Id, rhc.RecordHealthCheckOutcome>();
    for (Id accountId : accountIds) {
      outcomes.put(
        accountId,
        rhc.RecordHealthCheckOutcome.fail('NO_CONTACTS')
          .withFound(rhc.RecordHealthCheckValue.ofCount(0))
          .withComparison(
            'GREATER_THAN',
            rhc.RecordHealthCheckValue.ofCount(0)
          )
      );
    }

    // One query checks every Account. Do not put SOQL inside the Account loop.
    for (AggregateResult row : [
      SELECT AccountId parentId, COUNT(Id) total
      FROM Contact
      WHERE AccountId IN :accountIds
      WITH USER_MODE
      GROUP BY AccountId
    ]) {
      Id recordId = (Id) row.get('parentId');
      Integer total = (Integer) row.get('total');
      outcomes.put(
        recordId,
        rhc.RecordHealthCheckOutcome.pass('CONTACTS_FOUND')
          .withFound(rhc.RecordHealthCheckValue.ofCount(total))
          .withComparison(
            'GREATER_THAN',
            rhc.RecordHealthCheckValue.ofCount(0)
          )
      );
    }
    return outcomes;
  }
}
```

## Actions a custom Apex Check must not perform

A custom Apex Check must not create, update, or delete records; publish events; enqueue work; send
email; make callouts; or start asynchronous Apex. Record Health Check uses a savepoint and governor
counters to reject observable prohibited actions. Apex exposes no reliable counter proving that a
plugin did not call `EventBus.publish`, start Batch Apex, or schedule Apex, so contract tests, static
analysis, and human code review must enforce those prohibitions. Runtime detection is not a complete
sandbox.

Catch a problem that affects only one record inside the record loop and return
`UNABLE_TO_EVALUATE` for that record so one problem does not erase the results for every other
record in the request.

## Verification

Extend `rhc.RecordHealthCheckContractTest`, provide a new custom Apex Check instance and an
`rhc.RecordHealthCheckContractTestData` factory, then call `verifyContract()` from an Apex
test. The contract test measures scopes of 1, 10, 50, and 200 records.

To test access behavior, create a user who genuinely cannot read a record or field used by the
Check. Apex does not expose a counter that proves whether a query used user mode, so the test result
and a review of the SOQL source remain separate requirements.

The framework's configured Query row limit does not wrap SOQL issued inside a subscriber plugin. Plugin authors
own their row limits: query no more than the plugin can evaluate completely, use an extra-row probe
when a collection-wide result depends on completeness, and return a documented
`UNABLE_TO_EVALUATE` outcome instead of deciding from a truncated collection. Do not disclose a
true count that the running user may not be entitled to see.

## Supported classes

The interface shown on this page is the supported custom Apex Check contract. Implement
`rhc.RecordHealthCheckPlugin` with `rhc.RecordHealthCheckScope`,
`rhc.RecordHealthCheckOutcome`, and `rhc.RecordHealthCheckValue`; the package does not include a
second custom Apex Check interface.

## Version compatibility

The response and Platform Event contract versions are independent of this interface. Compile and
run the contract test against the package version you plan to install. An event or response version
does not prove that a custom Apex Check compiles with that package version.

## Related

- [Plugin verification](../apex/plugin-verification.md)
- [Apex API](../../api/apex-api.md)
- [Recent activity example](../../examples/apex/recent-activity.md)
