# Flow API pattern

> [!NOTE]
> On this page, choose the Flow entry point and open the complete how-to for inputs, outputs,
> Decision paths, and fault handling.

Flow Builder exposes **Run Record Health Check Set** and **Run Record Health Check Rule** in the
**Record Health Check** action category. Both actions use the same request contract as Apex
(`QualifiedApiName`, record ID, explicit event publication).

## Choose an API pattern

| Goal | Start here |
| --- | --- |
| Configure the Action, Decision statuses, collections, and tests | [Flow actions](../integration/flow-actions.md) (complete how-to) |
| Compare Flow with Apex, Lightning, and events | [Integration overview](../integration/README.md) |
| Call `evaluate` from Apex instead | [Apex API](apex-api.md) |
| Run checks asynchronously | [Queueable](queueable.md), [Batch](batch.md), or [Scheduled](scheduled.md) |

## Quick start expectations

1. The running user (or the automated Flow user) needs `Record_Health_Check_Run` access.
2. Keep each action collection within the 200-record request limit; split larger bulk work across
   transactions.
3. Branch on returned `PASS`, `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, and `ERROR` statuses. A
   business `FAIL` is an outcome, not a Flow fault. Use the fault path for invalid requests and
   transaction failures.

Do not maintain a second copy of Flow input/output tables here. The integration Flow actions page
owns that contract.

## Related

- [Flow actions](../integration/flow-actions.md)
- [Apex API](apex-api.md)
- [Lifecycle events](../integration/lifecycle-events.md)
- [Platform Event subscriptions](../platform-events/README.md)
