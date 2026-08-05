# Operate Record Health Check in production

> [!NOTE]
> On this page, run Record Health Check as an ongoing production service: keep event allocation
> usage healthy, manage diagnostics access, back up configuration on a schedule, monitor
> subscribers, and verify a release before and after it ships.

Use this page after [Install and verify](../installation/02-install-and-verify.md) and
[Configure Check Sets and Rules](03-configure-check-sets-and-rules.md) have already produced a working
Check Set. This guide covers the ongoing operational discipline of running it in a live org, not the
initial setup.

## Event enablement and allocation hygiene

Lifecycle publication is off by default because it consumes the org's Platform Event allocation and
can trigger subscriber automation. Treat every enabled publication as a standing cost, not a
one-time switch.

| Practice | Why it matters |
| --- | --- |
| Enable **Publish User Run Event** and **Publish User Result Event** one Check Set or Rule at a time | Isolates a volume spike to one source instead of the whole org |
| Review org Platform Event allocation usage on a schedule, not only when a limit is hit | High-volume event allocations are shared across every publisher in the org, not owned by Record Health Check alone |
| Keep **Publish Error Log Event** on unless a specific Check Set's errors are noisy and already handled elsewhere | It defaults on so Framework failures stay observable; opting out removes that visibility for that Check Set |
| Audit which Check Sets and Rules have publication enabled at least quarterly | Configuration drifts as Rules are copied or repurposed; an old test Rule with publication still on wastes allocation |
| Confirm automatic page-load runs are not publishing | They cannot, by design, but a new integration built directly against the Lightning component's data should not assume otherwise |

See [Lifecycle events: Admin checklist before enabling](../integration/03-lifecycle-events.md#admin-checklist-before-enabling)
for the pre-enablement checklist and [Publication settings](../integration/03-lifecycle-events.md#publication-settings)
for exact field defaults.

## Diagnostics on/off discipline

**Show Diagnostics** is a Check Set-wide switch, not a per-user or per-session toggle. Operate it
like a temporary elevated-access grant:

1. Enable **Show Diagnostics** on the specific Check Set being investigated, not broadly.
2. Confirm only users holding `Record_Health_Check_View_Diagnostics` (via `Record_Health_Check_Admin`)
   can see the resulting detail; everyone else still sees the standard card.
3. Turn it back off when the investigation ends.
4. Periodically audit which Check Sets currently have **Show Diagnostics** checked; a forgotten
   Check Set left in diagnostics mode has no time-based expiration.

See [Security and data access: The diagnostics Custom Permission](../reference/framework/02-security.md#the-diagnostics-custom-permission)
for why both the Check Set setting and the Custom Permission must be true together, and
[Troubleshoot with Show Diagnostics](07-troubleshoot-with-show-diagnostics.md) for a full
investigation workflow.

## Configuration backup cadence

Check Set and Rule configuration is Custom Metadata, so it deploys and version-controls like any
other metadata, but a production org can still drift from source through direct Setup edits.
Establish a cadence, not a one-time export:

| Cadence | Action |
| --- | --- |
| Before every deployment | Export every `Record_Health_Check_Set__mdt` and `Record_Health_Check_Rule__mdt` record, per [Revalidate an installation: Before you start](../installation/04-upgrading.md#before-you-start) |
| On a recurring schedule (for example, weekly) | Export current production configuration even between deployments, to catch drift from direct Setup edits |
| Before any planned removal | Follow the backup step in [Uninstall and rollback](../installation/06-uninstall-and-rollback.md#back-up-custom-metadata-first) |
| After any bulk Setup edit session | Re-export immediately so the backup reflects the edit, not the state before it |

Store exports somewhere the release owner can restore from, and periodically prove that a restore
actually works in a sandbox. A backup that has never been restored is not verified rollback
evidence.

## Subscriber monitoring

A publish failure or a subscriber failure never changes a completed health-check result, which
means it can go unnoticed unless something is watching for it deliberately.

| What to monitor | Why |
| --- | --- |
| Publish failures in debug logs | Publishing is best-effort; a failed publish is logged as a warning and does not retry automatically |
| Subscriber processing errors (Flow fault paths, Apex trigger exceptions) | Independent of publication success; a published event can still fail to process |
| Duplicate or replayed event handling | Platform events are not exactly-once; confirm subscribers key on `EventId__c` for idempotency |
| `Record_Health_Check_Log__e` access list | Confirm only the intended subscriber or integration user still has access, since this event carries restricted error detail |
| Event volume trend per Check Set and Rule | A sudden increase usually means a new caller, a changed run frequency, or a misconfigured automatic trigger upstream of a deliberate run |

See [Lifecycle events: Subscriber failure guidance](../integration/03-lifecycle-events.md#subscriber-failure-guidance)
for symptom-to-cause mapping, and
[Platform Event subscriptions: Shared subscriber checklist](../platform-events/README.md#shared-subscriber-checklist)
for the subscriber-side implementation checklist.

## Production verification checklist

Run this checklist after every deployment, and periodically between deployments as a health check
on the health check:

- [ ] Open each active Lightning record page and confirm the intended Check Set appears.
- [ ] Run a known-passing record and confirm the expected Rules pass without exposing diagnostic
      detail.
- [ ] Run a known-failing record and confirm the expected severity, Found/Expected values, and
      action link appear.
- [ ] Run as a standard user and confirm the card respects that user's record, object, and field
      access.
- [ ] Confirm no Check Set has **Show Diagnostics** enabled outside an active investigation.
- [ ] Confirm event publication settings match the intended production configuration, not a
      leftover testing state.
- [ ] Exercise each Apex, Flow, and event-subscriber integration and confirm it still handles every
      returned status.
- [ ] Compare current Custom Metadata against the most recent backup and investigate any
      unexpected deletion, blank value, or inactive record.

This checklist is the day-2 companion to the one-time deployment verification in
[Revalidate an installation: Verification](../installation/04-upgrading.md#verification).
Run it on a schedule, not only during a release window.

## Related

- [Revalidate an installation](../installation/04-upgrading.md)
- [Lifecycle events](../integration/03-lifecycle-events.md)
- [Security and data access](../reference/framework/02-security.md)
- [Troubleshoot with Show Diagnostics](07-troubleshoot-with-show-diagnostics.md)
- [Platform Event subscriptions](../platform-events/README.md)
- [Uninstall and rollback](../installation/06-uninstall-and-rollback.md)
