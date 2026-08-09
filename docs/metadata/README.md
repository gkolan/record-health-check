# Metadata reference

> [!NOTE]
> On this page, choose the Custom Metadata or Platform Event field reference that matches the Setup
> label or API name you need to verify.

Record Health Check configuration uses two Custom Metadata Types. The **Record Health Check Set**
controls the card and groups related Checks. The **Record Health Check** defines one question
inside that card.

Start with the name you see in Salesforce Setup. Each reference also supplies the API name needed
for metadata XML, Apex, automation, and generated configuration.

## Choose a reference

| Reference | What it covers |
| --- | --- |
| [Check Set fields](fields-check-set.md) | Every field on **Record Health Check Set** (`Record_Health_Check_Set__mdt`) |
| [Check fields](fields-check.md) | Every field on **Record Health Check** (`Record_Health_Check__mdt`) |
| [Check Set Run Platform Event](event-set-run.md) | Set-run summary event fields |
| [Check Result Platform Event](event-check-result.md) | Per-Check outcome event fields |
| [Log Platform Event](event-log.md) | Restricted Framework `ERROR` diagnostics |

## Pick a task

### Setup fields

| Plain name | Setup name | Field reference |
| --- | --- | --- |
| **Check Set** | Record Health Check Set | [Check Set fields](fields-check-set.md) |
| **Check** | Record Health Check | [Check fields](fields-check.md) |

### Platform Events

| Setup name | Field reference |
| --- | --- |
| Record Health Check Set Run | [Check Set Run fields](event-set-run.md) |
| Record Health Check Result | [Check Result fields](event-check-result.md) |
| Record Health Check Log | [Log fields](event-log.md) |

These pages are field references. For publication timing and trust boundaries, use
[Lifecycle event behavior](../integration/lifecycle-events.md). For a working Flow or Apex
subscriber, use the [Platform Event subscription guides](../platform-events/README.md).

## Related

- [Configure Check Sets and Checks](../guides/configure-check-sets-and-checks.md)
- [Lifecycle events](../integration/lifecycle-events.md)
- [Platform Event subscriptions](../platform-events/README.md)
- [Reason Codes](../reference/contracts/reason-codes.md)
- [Examples library](../examples/README.md)
