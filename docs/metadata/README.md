# Metadata reference

Record Health Check configuration uses two Custom Metadata Types. The **Record Health Check Set**
controls the card and groups related Checks. The **Record Health Check** defines one question
inside that card.

Start with the name you see in Salesforce Setup. Each reference also supplies the API name needed
for metadata XML, Apex, automation, and generated configuration.

## Recommended path

| Step | Reference | What it covers |
| ---: | --- | --- |
| 1 | [Check Set fields](01-fields-check-set.md) | Every field on **Record Health Check Set** (`Record_Health_Check_Set__mdt`) |
| 2 | [Check fields](02-fields-check.md) | Every field on **Record Health Check** (`Record_Health_Check__mdt`) |
| 3 | [Check Set Run Platform Event](03-event-set-run.md) | Set-run summary event fields |
| 4 | [Check Result Platform Event](04-event-check-result.md) | Per-Check outcome event fields |
| 5 | [Log Platform Event](05-event-log.md) | Restricted Framework `ERROR` diagnostics |

## Pick a task

### Setup fields

| Plain name | Setup name | Field reference |
| --- | --- | --- |
| **Check Set** | Record Health Check Set | [01 - Check Set fields](01-fields-check-set.md) |
| **Check** | Record Health Check | [02 - Check fields](02-fields-check.md) |

### Platform Events

| Setup name | Field reference |
| --- | --- |
| Record Health Check Set Run | [03 - Check Set Run](03-event-set-run.md) |
| Record Health Check Result | [04 - Check Result](04-event-check-result.md) |
| Record Health Check Log | [05 - Log](05-event-log.md) |

## Related

- [Configure Check Sets and Checks](../guides/03-configure-check-sets-and-checks.md)
- [Lifecycle events](../integration/03-lifecycle-events.md)
- [Platform Event subscriptions](../platform-events/README.md)
- [Reason Codes](../reference/contracts/01-reason-codes.md)
- [Examples library](../examples/README.md)
