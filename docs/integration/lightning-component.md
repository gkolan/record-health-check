# Lightning component

> [!NOTE]
> On this page, choose whether the Record Health Check card runs when a record page opens or waits
> for the user to select Run, then understand what users see and when optional Platform Events can
> be published.

Use this reference to choose whether a Check Set runs when the record page opens or waits for the
user to select **Run**. The choice affects when users see results and whether the card can publish
Platform Events.

The **Record Health Check** Lightning Web Component supports both experiences. Automatic page-load
evaluation is read-only and never publishes. An explicit **Run** or **Rerun** is a deliberate user
action and can publish when the Check Set and Checks enable publication.

The component is available only on Lightning record pages. App and Home pages do not provide the
`recordId` required for evaluation, so the component intentionally does not appear in their App
Builder palettes.

## Choose the run experience

| User experience | Check Set setting | When to use it | Platform Events |
| --- | --- | --- | --- |
| Results appear after the page opens | **When the page opens** (`RUN_ON_LOAD`) | Users need passive readiness guidance whenever they view the record | Never publishes |
| The card waits for the user | **When the user clicks Run** (`RUN_ON_REQUEST`) | The review is deliberate, data may change first, or publication may be enabled | Run and Rerun can publish when configured |

## What the component is

- A record-page component that displays and coordinates runs for one configured Check Set.
- A view of the current run's Check Set and Check results using the current user's Salesforce access.
- An optional event publisher only when the user explicitly clicks Run or Rerun.

## What the component is not

- It is not a result-history store.
- It does not block record save or automatically remediate failures.
- Automatic page load is not consent to publish lifecycle events.
- A completed card does not prove that a receiving Flow, Apex trigger, or integration processed an event.
- It is not available on App Pages or Home Pages. The component evaluates one record, so it is
  published only for record pages and does not appear in the App Builder palette elsewhere.

New to the model? Read [Integrate Record Health Check](../integration/README.md) first.

## Prerequisites and quick start

1. Assign the **Record Health Check User** (`rhc__Record_Health_Check_User`) Permission Set to the viewer
   and grant access to the record and fields used by the selected Checks.
2. In Lightning App Builder, open a **record page** and add **Record Health Check**, then select an
   active Check Set for that object. The component is listed only while you are editing a record
   page; it is not offered on App Pages or Home Pages because it has no record to evaluate there.
3. On the Check Set Custom Metadata record, set **When Checks Run** to **When the page opens** or
   **When the user clicks Run**, then choose the Run button display, labels, and icon. **Hide** is
   valid only for an automatic page-load Check Set.
4. Save and activate the Lightning page, then open a matching record.
5. Confirm the card returns rows and summary counts. Click Run or Rerun only when an explicit run is
   intended.

Every card query uses the viewing user's effective access. An empty Query result means no matching
rows were visible to that transaction; it is not proof of org-wide absence. Sharing, restriction
rules, and scoping rules are intentional visibility controls, and the card never bypasses them to
infer hidden records.

For installation details, use [Create your first Check](../installation/create-your-first-check.md). Advanced
diagnostic values additionally require **Show Diagnostics** and the
**Record Health Check View Diagnostics** (`rhc__Record_Health_Check_View_Diagnostics`) Custom Permission.
When both are present, the card renders the server-provided admin-detail message; that detail remains
absent for viewers without the permission and never changes record or field access.

## When the card publishes result events

| Component action | Source | Set event | Check events |
| --- | --- | --- | --- |
| Automatic page-load run | `RUN_ON_LOAD` | Never | Never |
| User clicks Run | `USER_INITIATED` | Enabled Check Set | Enabled Checks |
| User clicks Rerun | `USER_INITIATED` | Enabled Check Set | Enabled Checks |

Leave these settings off when users only need results on the card:

- `PublishUserRunEvent__c` enables one Set Run completion event for the Check Set.
- `PublishUserResultEvent__c` enables a Check Result event for that Check.

Error Log events use a separate default-on Check Set setting. `PublishErrorLogEvent__c` publishes
Record Health Check `ERROR` details from automatic and deliberate runs; uncheck it to opt that Check Set
out. This does not disable Salesforce debug-log output.

An automatic run never publishes lifecycle events even when both lifecycle switches are enabled.
It can still publish an Error Log event when the default-on error setting permits it.

The block is intentional. Opening or refreshing a record page is passive navigation, not a request
to notify another process. If automatic runs published, ordinary browsing could consume Platform
Event allocations, create repeated history, and start receiving automation repeatedly. Run and
Rerun provide the deliberate boundary required before publication is eligible.

## Component inputs and visible outputs

| Input/context | Meaning |
| --- | --- |
| Check Set selected in App Builder | One active Check Set whose Object matches the record page. The dropdown shows its Label and stores its exact Qualified API Name. |
| Current record ID | Record evaluated |
| Check Set **When Checks Run** = **When the page opens** (`RUN_ON_LOAD`) | Run after definitions load; publication blocked |
| Check Set **When Checks Run** = **When the user clicks Run** (`RUN_ON_REQUEST`) | Wait for an explicit Run; publication can be enabled |
| Check Set **Run Button Display** | Show label and icon, label only, a compact icon, or hide the action on automatic Check Sets only |
| Run or Rerun button | Explicit user-initiated run; publication can be enabled. Custom labels fall back to **Run** and **Rerun** when blank. |

When the display is **Hide**, the card removes the complete action area, so the title and subtitle
can use that space. **Icon only** uses a compact square button and retains an accessible Run or
Rerun name for assistive technology. An invalid custom icon name falls back to the built-in play
icon. A limit notice still reserves the space it needs in the header.

The App Builder override controls only presentation. It does not change when checks run. A manual
Check Set combined with an effective **Hide** value is invalid and the card explains the
configuration error instead of leaving users with no way to start the run.

An automatic Check Set continues to show **Rerun** after it finishes unless its action is hidden.
This default preserves existing card behavior after an upgrade. A Check Set with no active Checks
does not show Rerun because there is nothing to evaluate again.

A browser refresh and **Rerun** can both obtain current results, but only Rerun is an explicit user
action that can publish lifecycle events. Refreshing the page runs the automatic Check Set as part
of page load and never publishes those events. When the action is hidden, refresh the page to
reevaluate the card, or call the Check Set from Apex or Flow when another process needs an event.

The visible output is the completed row list and summary counts. Long Found and Expected values
clamp to two lines; use the adjacent `+`/`−` control to expand or collapse the complete value.
Results remain in component state; the component does not create a history record.

## Event outputs for Run and Rerun

### Check Set Run event

After every row resolves, a Set with publication enabled can produce `Record_Health_Check_Set_Run__e` with
`Phase__c = COMPLETED` and `Source__c = USER_INITIATED`. See
[Check Set Run event fields](../metadata/event-set-run.md#fields)
for the complete field list.

### Check Result event

Each server-finalized Check with publication enabled can produce `Record_Health_Check_Result__e` with
`Source__c = USER_INITIATED`. See
[Check Result event fields](../metadata/event-check-result.md#fields)
for the complete field list.

## What happens while the card runs

The component evaluates Checks through separate Salesforce requests so it can honor prerequisites,
stop after system errors when configured, and show results progressively.

When **Stop after a system error** is unchecked, the component allows up to five evaluations at a
time so the card can finish promptly without flooding the browser or Salesforce with one request per
Check all at once. When it is checked, evaluation becomes sequential; the component must know whether
the current Check returned `ERROR` before deciding whether the next Check is allowed to start.

For an explicit run:

1. Each server-finalized Check result can publish its own Check Result event after that Apex request commits.
2. When every row has resolved, the component makes one completion call.
3. That call can publish one aggregate Set Run event after its transaction commits.

Results the client determines without calling Apex, such as a dependency skip, count toward the Set
totals but do not create a separate Check Result event, because no server Check evaluation finalized.

Within one request, a prerequisite shared by multiple dependent Checks is evaluated once and reused.
A later Run or Rerun starts again from the current saved record data.

## Best-effort behavior

Event publication never changes the card result. If the completion call or event publication fails,
the user still sees the completed health-check results. The receiving Flow, Apex trigger, or
integration needs its own monitoring; the card is not event-delivery confirmation.

Use the [lifecycle-events overview](lifecycle-events.md) for cross-event behavior and
the linked metadata references for exact field types, replay, retention, and receiving-process design.

## Versioning and compatibility

The component reads the contract value included in the response returned to it. Events created by an
explicit Run or Rerun carry their own independent contract value. No component run behavior is
currently deprecated.

The contract numbers identify response and event fields for integrations; the Record Health Check version
identifies the installed release. Keeping them separate allows compatible updates without
making the Lightning component or receiving integrations treat every product release as a breaking schema
change.

## Related

- [Platform events](lifecycle-events.md)
- [Apex API](../api/apex-api.md)
- [Flow actions](flow-actions.md)
- [Configure Check Sets and Checks](../guides/configure-check-sets-and-checks.md)
- [Troubleshoot Record Health Check](../guides/troubleshoot-with-show-diagnostics.md)
