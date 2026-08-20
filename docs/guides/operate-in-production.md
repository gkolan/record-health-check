# Operate Record Health Check in production

> [!NOTE]
> On this page, keep Record Health Check reliable after go-live by reviewing Platform Event usage,
> limiting diagnostics, backing up Check configuration, monitoring receiving automation, and
> retesting after Salesforce changes.

Use this page after [Install and verify](../installation/install-and-verify.md) and
[Configure Check Sets and Checks](configure-check-sets-and-checks.md) have already produced a working
Check Set. This guide covers the recurring work needed in a live org, not the initial setup.

The Salesforce administrator owns page placement, permission assignments, Check configuration,
and routine user tests. A release manager or developer owns source-controlled backup, Apex callers,
and deployment evidence. The automation owner monitors any Flow, Platform Event, or external
subscriber. Assign each role explicitly even when one person fills several roles.

If your org never enabled result events, focus on configuration backup, diagnostics remaining off,
permission review, and known passing/failing user tests. Skip event-volume and subscriber checks.

## Keep Platform Events off until automation needs them

Leave **Publish User Run Event** and **Publish User Result Event** unchecked when users only need the
results on the Lightning card or when Apex, Flow, or Batch Apex saves results directly. Publishing
an event uses the org's Platform Event allocation and can start receiving automation every time a
result is published.

In this guide, **receiving automation** means a Platform Event-triggered Flow, Apex trigger, or
external integration that listens for a Record Health Check event.

| Practice | Why it matters |
| --- | --- |
| Enable **Publish User Run Event** and **Publish User Result Event** for one Check Set or Check at a time | Makes it clear which configuration caused an unexpected increase in event volume. |
| Review Platform Event usage regularly instead of waiting for a limit error | The allocation is shared by every Platform Event publisher in your org, not reserved for Record Health Check. |
| Keep **Publish Error Log Event** on unless a specific Check Set's errors are already monitored another way | It defaults on so unexpected Record Health Check errors can be monitored. Turning it off removes that event for the Check Set. |
| Review which Check Sets and Checks have publication enabled at least quarterly | A copied or retired Check can continue publishing events that no process uses. |
| Confirm receiving automation handles `PASS`, `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, and `ERROR` as intended | A completed Batch or Check Set can still contain business failures or results that could not be evaluated. |

See [Lifecycle events: Admin checklist before enabling](../integration/lifecycle-events.md#admin-checklist-before-enabling)
for the pre-enablement checklist and [What controls publication](../integration/lifecycle-events.md#what-controls-publication)
for exact field defaults.

Review the org allocation from **Setup → Company Information** and the event-delivery usage views
available for your Salesforce edition. When allocation is exhausted, consumers can miss expected
events even though the card or synchronous caller already received its health result. Treat a
missing event as an automation incident, not as proof that the Check did not run.

## Turn diagnostics on only while investigating

**Show Diagnostics** applies to the entire Check Set. It is not a temporary switch for only the
administrator's current browser session:

1. Enable **Show Diagnostics** on the specific Check Set being investigated, not broadly.
2. Confirm only users holding **Record Health Check View Diagnostics** (`rhc__Record_Health_Check_View_Diagnostics`) (via **Record Health Check Admin** (`rhc__Record_Health_Check_Admin`))
   can see the resulting detail; everyone else still sees the standard card.
3. Turn it back off when the investigation ends.
4. Periodically audit which Check Sets currently have **Show Diagnostics** checked; a forgotten
   Check Set left in diagnostics mode has no time-based expiration.

See [Security and data access: The diagnostics Custom Permission](../reference/framework/security.md#the-diagnostics-custom-permission)
for why both the Check Set setting and the Custom Permission must be true together, and
[Troubleshoot Record Health Check](troubleshoot-with-show-diagnostics.md) for a full
investigation workflow.

## Back up Check configuration regularly

Check Set and Check configuration is Custom Metadata, so it deploys and can be version-controlled
like other metadata. Direct Setup edits can still leave a production org out of sync with source.
Use a repeatable schedule, not a one-time export:

| Cadence | Action |
| --- | --- |
| Before every deployment | Back up every **Record Health Check Set** (`Record_Health_Check_Set__mdt`) and **Record Health Check** (`Record_Health_Check__mdt`) record, per [Back up and restore configuration](back-up-configuration.md) |
| On a recurring schedule appropriate for your change volume, such as weekly | Export current production configuration between deployments to find direct Setup edits that are not yet in source control. |
| Before any planned removal | Follow [Preserve the configuration first](../installation/uninstall-and-rollback.md#preserve-the-configuration-first) |
| After any bulk Setup edit session | Re-export immediately so the backup reflects the edit, not the state before it |

Store the retrieved metadata in the repository your team uses for Salesforce changes. Periodically
deploy the backup to a sandbox and confirm the Check Sets and Checks are restored correctly. A file
that has never been restored is only an untested copy.

## Monitor the Flow, Apex, or integration that receives events

An event can fail to publish, or it can publish successfully and then fail in the receiving Flow,
Apex trigger, or integration. Neither failure changes the health result already returned to the
caller, so monitor both sides separately.

| What to monitor | Why |
| --- | --- |
| Publish failures in debug logs | Publishing is best-effort; a failed publish is logged as a warning and does not retry automatically |
| Receiving automation errors, including Flow fault paths and Apex trigger exceptions | A Platform Event can publish successfully even when the process receiving it fails. |
| Repeated or replayed events | Confirm receiving automation uses `EventId__c` so the same event does not create the same follow-up record or notification twice. |
| `Record_Health_Check_Log__e` access list | Confirm only the users and integrations responsible for error monitoring have access because this event contains restricted troubleshooting details. |
| Event volume by Check Set and Check | An increase can mean a new caller, a changed schedule, or automation starting the same health check more often than intended. |

For debug logs, open **Setup → Debug Logs**, add a trace flag for the user or automated process, run
one controlled test, and inspect the newest log. Remove broad trace flags when the investigation
ends. In a Platform Event-triggered Flow, store `EventId__c` on the follow-up record and use **Get
Records** plus a Decision before Create Records so replaying the same event does not duplicate work.

See [Lifecycle events: missing or repeated events](../integration/lifecycle-events.md#when-an-event-is-missing-or-processed-twice)
for symptom-to-cause mapping, and
[Platform Event receiving automation checklist](../platform-events/README.md#receiving-automation-checklist)
for the subscriber-side implementation checklist.

## Production verification checklist

Run this checklist after every deployment, and periodically between deployments as a health check
on the health check:

- [ ] Open each active Lightning record page and confirm the intended Check Set appears.
- [ ] Run a known-passing record and confirm the expected Checks pass without exposing diagnostic
      detail.
- [ ] Run a known-failing record and confirm the expected severity, Found/Expected values, and
      action link appear.
- [ ] Run as a standard user and confirm the card respects that user's record, object, and field
      access.
- [ ] Confirm no Check Set has **Show Diagnostics** enabled outside an active investigation.
- [ ] Confirm event publication settings match the intended production configuration, not a
      leftover testing state.
- [ ] Exercise each Apex, Flow, and Platform Event integration and confirm it still handles every
      returned status.
- [ ] Compare current Custom Metadata against the most recent backup and investigate any
      unexpected deletion, blank value, or inactive record.

This checklist is the day-2 companion to the one-time deployment verification in
[Upgrade and revalidate: Revalidate what people use](../installation/upgrading.md#step-3-revalidate-what-people-use).
Run it on a schedule, not only during a release window.

## Related

- [Revalidate an installation](../installation/upgrading.md)
- [Lifecycle events](../integration/lifecycle-events.md)
- [Security and data access](../reference/framework/security.md)
- [Troubleshoot Record Health Check](troubleshoot-with-show-diagnostics.md)
- [Platform Event subscriptions](../platform-events/README.md)
- [Uninstall and rollback](../installation/uninstall-and-rollback.md)
- [Back up and restore configuration](back-up-configuration.md)
