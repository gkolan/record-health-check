# Subscribe to Record Health Check Platform Events

> [!NOTE]
> On this page, choose a Record Health Check event and build a Flow or Apex subscriber that handles duplicate delivery, access, retention, and subscriber failures.

Record Health Check publishes three Platform Events. Check Set Run and Rule Result events announce
finalized outcomes after the publishing transaction commits. Log events report restricted
Framework errors immediately when error-event publication is enabled.

## Recommended path

| Step | Event guide | Publish behavior |
| ---: | --- | --- |
| 1 | [Check Set Run](01-check-set-run.md) | Publish After Commit - one completion summary |
| 2 | [Rule Result](02-rule-result.md) | Publish After Commit - one outcome per selected Rule |
| 3 | [Log](03-error-log.md) | Publish Immediately - restricted Framework errors |

Start with Check Set Run when counts and overall completion are sufficient. Add Rule Result only
when automation needs Rule-level status, severity, or Reason Code. Restrict Log subscribers because
messages and stack traces can contain organization-specific information.

## Pick a task

| I want to… | Guide |
| --- | --- |
| One completion summary for a Check Set | [01 - Check Set Run](01-check-set-run.md) |
| One finalized outcome for each Rule | [02 - Rule Result](02-rule-result.md) |
| Restricted Framework error diagnostics | [03 - Log](03-error-log.md) |

## Choose Flow or Apex

| Subscriber | Best fit | Main constraint |
| --- | --- | --- |
| Platform event-triggered Flow | Declarative routing, record creation, and notifications | Runs asynchronously and needs a lasting duplicate check |
| Apex trigger | Complex transformations, controlled bulk DML, and reusable handlers | Requires tests, access review, and independent monitoring |

Both subscribers receive events asynchronously. Neither can change the synchronous health-check
response. Store `EventId__c` in a unique field when processing must happen once, and store the
Salesforce replay ID only when an external subscriber needs a replay position.

## Shared subscriber checklist

1. Grant read access to the selected Platform Event only to the subscriber identity.
2. Create a lasting receipt or destination record with a unique `EventId__c` field.
3. Route using API fields such as Status, Reason Code, source, and metadata names.
4. Treat new field values as a review path instead of dropping the event.
5. Keep processing safe when Salesforce retries or replays an event.
6. Monitor subscriber failures separately from publication and health-check results.
7. Define retention for every stored result or diagnostic record.
8. Test commit, rollback, duplicate delivery, missing optional fields, and restricted access.

## Related

- [API examples](../api/README.md)
- [Lifecycle event behavior](../integration/03-lifecycle-events.md)
- [Platform Event metadata](../metadata/README.md#platform-events)
- [Reason Codes](../reference/contracts/01-reason-codes.md)
