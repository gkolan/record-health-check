# Execution-context war room

Use this runbook when the same Check behaves differently on a Lightning record page, in Flow, or
in asynchronous Apex. The goal is to identify the transaction's actual execution user and access
before changing the Check.

Record Health Check does not elevate a caller. Each transaction uses its running user's object,
field, record, restriction-rule, scoping-rule, locale, currency, and timezone context. A later
Queueable, Batch, or scheduled transaction must be investigated separately from the transaction
that submitted it.

## Stabilize the incident

1. Record the affected record ID, Check or Check Set Qualified API Name, status, Reason Code, Run
   ID, exact time, and displayed timezone.
2. Stop retries that create additional Flow interviews or asynchronous jobs.
3. Do not replace the Check with system-mode SOQL or grant administrator access as a diagnostic
   shortcut.
4. Reproduce once through the page and once through the failing automation with the same saved
   record.
5. Capture the interactive user, Flow execution mode, submitting user, and asynchronous job owner.

For an Apex job, query its observable platform identity:

```sql
SELECT Id, Status, JobType, ApexClass.Name, CreatedById, CreatedBy.Name,
       NumberOfErrors, ExtendedStatus
FROM AsyncApexJob
WHERE Id = '707...'
```

For a scheduled run, also inspect the schedule owner and timezone in **Setup → Scheduled Jobs**.
Salesforce interprets a CRON expression in the scheduling user's timezone.

## Scenario 1: Page passes, Flow cannot evaluate

**Signal:** The card returns `PASS`, while Flow returns `UNABLE_TO_EVALUATE`, `RECORD_NOT_VISIBLE`,
or a public `CANNOT_EVALUATE` reason.

**Likely cause:** The Flow transaction uses a different user, execution mode, or permission set.
Record Health Check still performs business-data reads in user mode and still requires the **Record
Health Check Run** Custom Permission.

**Actions:**

1. Confirm the card user and Flow execution user are not being treated as interchangeable.
2. Compare object, field, record, restriction-rule, and scoping-rule access for every referenced
   field and query object.
3. Confirm the Flow user has **Record Health Check User** rather than relying on Flow system context.
4. Debug the Flow with the same record and intended automation principal.

**Exit condition:** Both outcomes are explainable from the documented access difference, or the
intended automation principal produces the approved result without elevated access.

## Scenario 2: `$User` ownership formula differs or never evaluates

**Signal:** A Check author expects `OwnerId = $User.Id` to behave differently for the page user and
automation user.

**Root cause:** `$User`, `$Profile`, `$Setup`, `$Permission`, and `$CustomMetadata` are not supported
record-context FormulaEval globals. `$User.Id` is masked from record-field planning so it cannot
become a bogus `User.Id` query path, then FormulaEval rejects the expression. Record Health Check
returns `UNABLE_TO_EVALUATE` with `INVALID_FORMULA`; it must never turn that uncertainty into
`FAIL` or a caller-dependent verdict.

**Actions:**

1. Replace `$User` logic with an explicit record field, a user-mode Query Check, or reviewed custom
   Apex with a documented identity contract.
2. For “active User owner,” use the supported `Owner:User.IsActive` formula or the documented User
   query pattern; decide explicitly how Queue/Group owners should behave.
3. Rerun through every intended entry point.

**Exit condition:** The Check no longer contains unsupported globals and its ownership policy is
identical in configuration, result text, and operator guidance.

## Scenario 3: The result flips around midnight

**Signal:** A `TODAY()` or `NOW()` Check changes at different times for interactive and scheduled
runs, especially when operators quote timestamps in another timezone.

**Likely cause:** The transactions use different users or schedules, and the investigation compared
wall-clock times without preserving timezone context.

**Actions:**

1. Capture the timezone of the page user, Flow user, scheduling user, and any integration user.
2. Record timestamps in UTC and in each relevant Salesforce user timezone.
3. Reproduce with a fixed record date outside the midnight boundary, then repeat at the boundary
   only if the business rule truly depends on it.
4. Prefer an explicit stored cutoff date or datetime when every entry point must share one boundary.

**Exit condition:** The expected cutoff timezone is documented and all entry points either use that
same explicit cutoff or intentionally document their differing windows.

## Scenario 4: Queueable or Batch differs from synchronous Apex

**Signal:** Direct Apex or Flow succeeds, but the submitted job returns no usable results, fails, or
sees a different record set.

**Likely cause:** The background transaction rechecks authorization and data access. Submission
success proves only that Salesforce accepted the job.

**Actions:**

1. Inspect `AsyncApexJob` rather than treating the submitter's transaction as the execution log.
2. Add a temporary trace flag for the actual job user and reproduce one job.
3. Compare the qualified identity, record scope, event-publication choice, Run ID, and visible rows.
4. Treat a user-mode zero-row result as “no visible matching rows,” not proof that no rows exist.

**Exit condition:** The job completes under the intended user with the intended visible scope, and
operators can correlate its job ID and Run ID.

## Scenario 5: Scheduled results changed after an administrator change

**Signal:** A schedule that previously worked begins returning authorization, visibility, or date
boundary differences without a Check metadata change.

**Likely cause:** The scheduled job owner, that user's permissions, or that user's timezone changed.
The packaged scheduler rechecks authorization when the schedule fires and delegates evaluation to
Batch Apex.

**Actions:**

1. Identify the schedule owner and the Batch job created for the affected run.
2. Verify the owner's active status, **Record Health Check User** assignment, business-data access,
   and timezone.
3. Compare the scheduled record set with the records visible to that user at execution time.
4. Recreate the schedule under the approved automation principal if ownership is wrong; do not
   broaden the old owner's access merely to preserve a legacy schedule.

**Exit condition:** Schedule ownership, timezone, permission assignment, and record scope are
explicitly owned and included in the operational handoff.

## Evidence package

Before closing the war room, retain only approved, redacted evidence:

- page and automation statuses, Reason Codes, Run IDs, and timestamps;
- Flow execution mode and intended automation principal;
- Queueable, Batch, and schedule job IDs and owners;
- relevant permission and sharing differences without copied customer field values; and
- the corrective action and a same-record verification through every affected entry point.

Remove temporary trace flags and elevated troubleshooting access. Do not retain tokens, session
IDs, unrestricted queries, or unredacted record values in tickets or shared logs.

## Related

- [Security and data access](../architecture/security-and-data-access.md#whose-record-and-field-access-is-used)
- [Run a Check from Flow](../flow-guides/run-a-check.md)
- [Formula Checks](../reference/evaluation/formula.md)
- [Salesforce debug logs](./salesforce-debug-logs.md)
