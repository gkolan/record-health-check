# Metadata reference

Record Health Check configuration uses two Custom Metadata Types. The **Record Health Check Set**
controls the card and groups related Rules. The **Record Health Check Rule** defines one question
inside that card.

Start with the name you see in Salesforce Setup. Each reference also supplies the API name needed
for metadata XML, Apex, automation, and generated configuration.

## Choose the field reference

| Plain name | Setup name | API type | Field reference |
| ---------- | ---------- | -------- | --------------- |
| **Check Set** | Record Health Check Set | `Record_Health_Check_Set__mdt` | [Check Set fields](fields-check-set.md) |
| **Rule** | Record Health Check Rule | `Record_Health_Check_Rule__mdt` | [Rule fields](fields-check-rule.md) |

## Choose a Platform Event reference

The Framework also defines three high-volume Salesforce Platform Events. Each event has a different
publication contract and security profile.

| Setup name | API name | Field reference | Purpose |
| --- | --- | --- | --- |
| Record Health Check Set Run | `Record_Health_Check_Set_Run__e` | [Check Set Run Platform Event](event-set-run.md) | One after-commit summary for a deliberate Check Set run |
| Record Health Check Rule Result | `Record_Health_Check_Rule_Result__e` | [Rule Result Platform Event](event-rule-result.md) | One after-commit public outcome for an enabled Rule |
| Record Health Check Log | `Record_Health_Check_Log__e` | [Log Platform Event](event-log.md) | Restricted, immediately published Framework `ERROR` diagnostics |

## Find the next detail

| Document | Role |
| -------- | ---- |
| [Check Set fields](fields-check-set.md) | Every field on the Check Set type |
| [Rule fields](fields-check-rule.md) | Every field on the Rule type |
| [Reason Codes](../reference/contracts/reason-codes.md) | Stable codes for skipped, unable, setup, and error outcomes |
| [Lifecycle-events overview](../integration/lifecycle-events.md) | Publication behavior, source rules, optional publication choices, and subscriber failures |
| [Check Set Run Platform Event](event-set-run.md) | Every field, summary-event possibilities, examples, limits, and subscriber design |
| [Rule Result Platform Event](event-rule-result.md) | Every field, status interpretation, routing possibilities, limits, and subscriber design |
| [Log Platform Event](event-log.md) | Every diagnostic field, security requirements, loop protection, and limitations |
| [API examples](../api/README.md) | Public `evaluate(request)` API, Flow actions, and asynchronous Apex patterns |
| [Platform Event subscriptions](../platform-events/README.md) | Flow and Apex subscriber patterns for all three events |
| [Lightning component](../integration/lightning-component.md) | Automatic versus explicit publication behavior |
| [Field limits](../reference/contracts/field-limits.md) | Salesforce storage limits and Framework completed-text limits |
| [Configure Check Sets and Rules](../guides/configure-check-sets-and-rules.md) | Mental model, walkthroughs, troubleshooting, go-live checklist |

For merge tokens, applicability, and evaluator behavior, see
[Configure Check Sets and Rules](../guides/configure-check-sets-and-rules.md) and the Evaluation Type
references under [Technical references](../reference/README.md#choose-an-evaluation-type-reference).
Practical Rule patterns remain in the [examples library](../examples/README.md).

## Related

- [Configure Check Sets and Rules](../guides/configure-check-sets-and-rules.md): mental model and walkthroughs
- [Revalidate an installation](../installation/04-upgrading.md): deployment verification and rollback guide
- [Examples library](../examples/README.md): practical Rule patterns by Evaluation Type
