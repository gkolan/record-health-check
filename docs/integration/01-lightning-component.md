# Lightning component

> [!NOTE]
> On this page, choose how the Record Health Check card runs on a Lightning record page and understand how that choice shapes user control, concurrent requests, visible results, and lifecycle-event eligibility.

Use this reference to choose whether a Check Set runs when the record page opens or waits for the
user to select **Run**. The choice affects the card experience and whether the run is eligible to
publish lifecycle events.

The **Record Health Check** Lightning Web Component supports both experiences. Automatic page-load
evaluation is read-only and never publishes. An explicit **Run** or **Rerun** is a deliberate user
action and can publish when the Check Set and Rules enable publication.

The component is available only on Lightning record pages. App and Home pages do not provide the
`recordId` required for evaluation, so the component intentionally does not appear in their App
Builder palettes.

## Choose the run experience

| User experience | Check Set setting | When to use it | Lifecycle events |
| --- | --- | --- | --- |
| Results appear after the page opens | **When the page opens** (`RUN_ON_LOAD`) | Users need passive readiness guidance whenever they view the record | Never publishes |
| The card waits for the user | **When the user clicks Run** (`RUN_ON_REQUEST`) | The review is deliberate, data may change first, or publication may be enabled | Run and Rerun can publish when configured |

## What the component is

- A record-page component that displays and coordinates runs for one configured Check Set.
- A transient view of Set and Rule results under the current user's access.
- An optional event publisher only when the user explicitly clicks Run or Rerun.

## What the component is not

- It is not a result-history store.
- It does not block record save or automatically remediate failures.
- Automatic page load is not consent to publish lifecycle events.
- A completed card does not prove that an event subscriber processed anything.
- It is not available on App Pages or Home Pages. The component evaluates one record, so it is
  published only for record pages and does not appear in the App Builder palette elsewhere.

New to the model? Read [Integrate Record Health Check](../integration/README.md) first.

## Prerequisites and quick start

1. Assign **Record Health Check User** to the viewer and grant access to the record and fields used
   by the selected Rules.
2. In Lightning App Builder, open a **record page** and add **Record Health Check**, then select an
   active Check Set for that object. The component is listed only while you are editing a record
   page; it is not offered on App Pages or Home Pages because it has no record to evaluate there.
3. On the Check Set Custom Metadata record, set **When Checks Run** to **When the page opens** or
   **When the user clicks Run**.
4. Save and activate the Lightning page, then open a matching record.
5. Confirm the card returns rows and summary counts. Click Run or Rerun only when an explicit run is
   intended.

For installation details, use [Create your first Rule](../installation/03-create-your-first-rule.md). Advanced
diagnostic values additionally require **Show Diagnostics** and the
`Record_Health_Check_View_Diagnostics` Custom Permission.

## Behavior matrix

| Component action | Source | Set event | Rule events |
| --- | --- | --- | --- |
| Automatic page-load run | `RUN_ON_LOAD` | Never | Never |
| User clicks Run | `USER_INITIATED` | Enabled Check Set | Enabled Rules |
| User clicks Rerun | `USER_INITIATED` | Enabled Check Set | Enabled Rules |

Lifecycle Custom Metadata switches remain off by default:

- `PublishUserRunEvent__c` enables one Set Run completion event for the Check Set.
- `PublishUserResultEvent__c` enables a Rule Result event for that Rule.

Error Log events use a separate default-on Check Set setting. `PublishErrorLogEvent__c` publishes
Framework `ERROR` diagnostics from automatic and deliberate runs; uncheck it to opt that Check Set
out. This does not disable Salesforce debug-log output.

An automatic run never publishes lifecycle events even when both lifecycle switches are enabled.
It can still publish an Error Log event when the default-on error setting permits it.

The block is intentional. Opening or refreshing a record page is passive navigation, not a request
to notify downstream systems. If automatic runs published, ordinary browsing could consume Platform
Event allocations, create duplicate history, and trigger subscriber automation repeatedly. Run and
Rerun provide the deliberate boundary required before publication is eligible.

## Component inputs and visible outputs

| Input/context | Meaning |
| --- | --- |
| Check Set selected in App Builder | Configuration loaded and evaluated by the card |
| Current record ID | Record evaluated |
| Check Set **When Checks Run** = **When the page opens** (`RUN_ON_LOAD`) | Run after definitions load; publication blocked |
| Check Set **When Checks Run** = **When the user clicks Run** (`RUN_ON_REQUEST`) | Wait for an explicit Run; publication can be enabled |
| Run or Rerun button | Explicit user-initiated run; publication can be enabled |

The visible output is the completed row list and summary counts. Long Found and Expected values
clamp to two lines; use the adjacent `+`/`−` control to expand or collapse the complete value.
Results remain in component state; the component does not create a history record.

## Event outputs for Run and Rerun

### Check Set Run event

After every row resolves, a Set with publication enabled can produce `Record_Health_Check_Set_Run__e` with
`Phase__c = COMPLETED` and `Source__c = USER_INITIATED`. See
[Check Set Run event fields](../metadata/03-event-set-run.md#fields)
for the complete field list.

### Rule Result event

Each server-finalized Rule with publication enabled can produce `Record_Health_Check_Rule_Result__e` with
`Source__c = USER_INITIATED`. See
[Rule Result event fields](../metadata/04-event-rule-result.md#fields)
for the complete field list.

## Why publication happens in two stages

The component evaluates Rules through separate Apex requests so it can enforce dependencies,
control concurrency, stop after system errors, and progressively reveal results.

When **Stop after a system error** is unchecked, the component allows up to five evaluations at a
time so the card can finish promptly without flooding the browser or Salesforce with one request per
Rule all at once. When it is checked, evaluation becomes sequential; the component must know whether
the current Rule returned `ERROR` before deciding whether the next Rule is allowed to start.

For an explicit run:

1. Each server-finalized Rule result can publish its own Rule Result event after that Apex request commits.
2. When every row has resolved, the component makes one completion call.
3. That call can publish one aggregate Set Run event after its transaction commits.

Results the client determines without calling Apex, such as a dependency skip, count toward the Set
totals but do not create a separate Rule Result event, because no server Rule evaluation finalized.

Within one server evaluation, a prerequisite shared by multiple dependent Rules is memoized and
evaluated once. The cache is cleared when that top-level evaluation finishes; a later Run or Rerun
starts from current record data.

## Best-effort behavior

Event publication never changes the card result. If the completion call or event publication fails,
the user still sees the completed health-check results. Consumers should monitor their own event and
subscriber processing rather than treating the card as delivery confirmation.

Use the [lifecycle-events overview](03-lifecycle-events.md) for cross-event behavior and
the linked metadata references for exact field types, replay, retention, and subscriber design.

## Versioning and compatibility

The component reads the contract value included in the synchronous response. Events created by an
explicit Run or Rerun carry their own independent contract value. No component run behavior is
currently deprecated.

The contract numbers identify response and event shapes for integrations; the Framework version
identifies the installed release. Keeping them separate allows compatible updates without
making the Lightning component or subscribers treat every product release as a breaking schema
change.

## Related

- [Platform events](03-lifecycle-events.md)
- [Apex API](../api/01-apex-api.md)
- [Flow actions](02-flow-actions.md)
- [Configure Check Sets and Rules](../guides/03-configure-check-sets-and-rules.md)
- [Troubleshoot with Show Diagnostics](../guides/07-troubleshoot-with-show-diagnostics.md)
