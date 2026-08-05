# Metadata reference

Record Health Check configuration uses two Custom Metadata Types. The **Record Health Check Set**
controls the card and groups related Rules. The **Record Health Check Rule** defines one question
inside that card.

Start with the name you see in Salesforce Setup. Each reference also supplies the API name needed
for metadata XML, Apex, automation, and generated configuration.

## Recommended path

| Step | Reference | What it covers |
| ---: | --- | --- |
| 1 | [Check Set fields](01-fields-check-set.md) | Every field on `Record_Health_Check_Set__mdt` |
| 2 | [Rule fields](02-fields-check-rule.md) | Every field on `Record_Health_Check_Rule__mdt` |
| 3 | [Check Set Run Platform Event](03-event-set-run.md) | Set-run summary event fields |
| 4 | [Rule Result Platform Event](04-event-rule-result.md) | Per-Rule outcome event fields |
| 5 | [Log Platform Event](05-event-log.md) | Restricted Framework `ERROR` diagnostics |

## Pick a task

### Setup fields

| Plain name | Setup name | Field reference |
| --- | --- | --- |
| **Check Set** | Record Health Check Set | [01 - Check Set fields](01-fields-check-set.md) |
| **Rule** | Record Health Check Rule | [02 - Rule fields](02-fields-check-rule.md) |

### Platform Events

| Setup name | Field reference |
| --- | --- |
| Record Health Check Set Run | [03 - Check Set Run](03-event-set-run.md) |
| Record Health Check Rule Result | [04 - Rule Result](04-event-rule-result.md) |
| Record Health Check Log | [05 - Log](05-event-log.md) |

## Related

- [Configure Check Sets and Rules](../guides/03-configure-check-sets-and-rules.md)
- [Lifecycle events](../integration/03-lifecycle-events.md)
- [Platform Event subscriptions](../platform-events/README.md)
- [Reason Codes](../reference/contracts/01-reason-codes.md)
- [Examples library](../examples/README.md)
