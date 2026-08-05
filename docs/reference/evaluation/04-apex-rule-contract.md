# Reference: Apex Rule plugins

> On this page, build a bulk Apex Rule plugin, return typed outcomes, and verify its access and
> resource behavior.
>
> [!NOTE]
> An Apex Rule plugin receives one complete record scope and returns exactly one outcome
> for every requested record ID.

## Interface

```apex
global interface RecordHealthCheckRule {
  Map<Id, RecordHealthCheckOutcome> evaluate(RecordHealthCheckScope scope);
}
```

Use a `global with sharing` class for a plugin that must work from the managed package.
Run its SOQL with user access. The Framework validates returned keys, statuses, reason
codes, and forbidden writes, but the plugin remains responsible for its own data access.

Plugin deployment is a trusted-code action. The Framework cannot isolate or observe privileged
reads performed by custom subscriber Apex: `with sharing` covers record sharing, while the plugin
must still enforce object and field access and use user-mode queries. The write check is not
a read-security boundary, and passing the contract test is not proof that every query is safe.

## Scope

`RecordHealthCheckScope` provides:

| Property | Meaning |
| --- | --- |
| `objectApiName` | Object shared by the requested IDs |
| `recordIds` | Defensive copy of the complete ordered scope |
| `recordIdAt(index)` | One ID without allocating another defensive list; use for index-based loops |
| `parameters` | Parsed Rule parameter JSON |
| `ruleQualifiedApiName` | Selected Rule identity |
| `checkSetQualifiedApiName` | Parent Check Set identity |
| `runId` | Correlation ID |

The scope is immutable to subscriber code. Read `recordIds` once, query once, index the result,
then create outcomes in a record loop. For index-based processing, call `size()` and
`recordIdAt(index)` instead of repeatedly accessing `recordIds`, because each property access
intentionally returns a detached copy.

## Outcome

Build outcomes with the factories on `RecordHealthCheckOutcome`:

```apex
RecordHealthCheckOutcome.pass('RECENT_ACTIVITY_FOUND')
  .withFound(RecordHealthCheckValue.ofCount(3))
  .withComparison(
    'GREATER_THAN',
    RecordHealthCheckValue.ofCount(0)
  );
```

Available verdict factories are `pass`, `fail`, `unableToEvaluate`, and `skipped`.
`error` is reserved for Framework contract failures. Found and Expected use
`RecordHealthCheckValue` factories for String, Boolean, Number, Date, DateTime, ID, Count,
and List values.

Plugins do not set record identity, Rule identity, severity, display text, links, or
diagnostics. The Framework derives those values from the map key and metadata.

## Bulk pattern

Start by placing every requested ID in the output map. Run grouped queries above the
record loop, then replace each seeded outcome with its evaluated result. This preserves a
result for records that have zero related rows.

```apex
global with sharing class ContactPresenceRule implements RecordHealthCheckRule {
  global Map<Id, RecordHealthCheckOutcome> evaluate(
    RecordHealthCheckScope scope
  ) {
    Map<Id, RecordHealthCheckOutcome> outcomes = new Map<Id, RecordHealthCheckOutcome>();
    for (Id recordId : scope.recordIds) {
      outcomes.put(
        recordId,
        RecordHealthCheckOutcome.fail('NO_CONTACTS')
          .withFound(RecordHealthCheckValue.ofCount(0))
      );
    }

    for (AggregateResult row : [
      SELECT AccountId parentId, COUNT(Id) total
      FROM Contact
      WHERE AccountId IN :scope.recordIds
      WITH USER_MODE
      GROUP BY AccountId
    ]) {
      Id recordId = (Id) row.get('parentId');
      Integer total = (Integer) row.get('total');
      outcomes.put(
        recordId,
        RecordHealthCheckOutcome.pass('CONTACTS_FOUND')
          .withFound(RecordHealthCheckValue.ofCount(total))
      );
    }
    return outcomes;
  }
}
```

## Forbidden writes and isolation

A plugin must not perform DML, publish events, enqueue work, send email, make callouts, or
start asynchronous work. Dispatch uses a savepoint for each plugin call and rejects a
forbidden write. Catch record-specific evaluation failures inside the record loop and return
`UNABLE_TO_EVALUATE` for that record so one bad record does not erase the rest of the
scope.

## Verification

Extend `RecordHealthCheckRuleContractTest`, provide a new plugin instance and a
`RecordHealthCheckRuleContractTestData` factory, then call `verifyContract()` from an Apex
test. The contract test measures scopes of 1, 10, 50, and 200 records.

Permission behavior needs a controlled least-privilege test setup. Apex exposes no runtime
counter for query access mode, so behavioral evidence and source scanning remain distinct.

## Supported contract

The bulk interface shown on this page is the supported plugin contract. Implement
`RecordHealthCheckRule` with `RecordHealthCheckScope`, `RecordHealthCheckOutcome`, and
`RecordHealthCheckValue`; no alternate plugin interface is packaged.

The response and Platform Event contract versions are independent of the plugin interface. Plugin
authors should compile and run the contract test against the package release they plan to
install; do not infer plugin compatibility from an event or response version number.

## Related

- [Plugin verification](../apex/08-plugin-verification.md)
- [Apex API](../../api/01-apex-api.md)
- [Recent activity example](../../examples/apex/01-recent-activity.md)
