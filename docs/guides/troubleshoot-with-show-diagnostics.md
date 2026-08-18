# Troubleshoot Record Health Check

> [!NOTE]
> On this page, diagnose problems with the Lightning card, Check configuration, Salesforce access,
> Flow, Apex, background jobs, and Platform Events. Start with the result users see, collect only the
> evidence you are authorized to view, and turn diagnostics off when the investigation is complete.
>
> **Reference**
>
> - This page is the primary troubleshooting runbook for Record Health Check.
> - For every other Check Set field, use the [Configure Check Sets and Checks](configure-check-sets-and-checks.md#3-check-set-fields).

Use this guide whenever Record Health Check does not load, run, evaluate, publish, or behave the
same way for two users. Start with the decision table below. Enable **Show Diagnostics** only when
the card and current user's access are part of the investigation.

Show Diagnostics adds on-screen and browser-console evidence for the current run. It does not save
history, change Salesforce data, or grant access by itself. Leave it off on production Check Sets
when the investigation is complete.

For what a normal (non-diagnostics) card looks like with Pass, Fail, and Skipped outcomes, see the
[Demo Account Relationship and Risk screenshot](../../assets/img/Example_Account_Relationship_Risk_Screenshot.png)
on [Install and verify](../installation/install-and-verify.md).

## What you will learn

| Question | Answer on this page |
| --- | --- |
| Why does checking Show Diagnostics appear to do nothing? | The viewer also needs **Record Health Check View Diagnostics** (`rhc__Record_Health_Check_View_Diagnostics`) through the Admin Permission Set |
| What changes on the card? | Authorized troubleshooting lines and details appear after a run |
| What appears in the browser console? | One `[RHC]` summary with a collapsed group for each Check and its complete diagnostics |
| How do I return to normal operation? | Uncheck Show Diagnostics and remove temporary administrator access when appropriate |

## Start with the symptom users see

Do not begin by changing the Check. Reproduce the problem once and record the exact time, running
user, Salesforce record, Check Set Qualified API Name, and Run ID. Then choose the matching row.

| Symptom | Check first | Likely cause area | Go to |
| --- | --- | --- | --- |
| Card is missing, empty, or says no Check Set is configured | App Builder component properties and Check Set identity | Lightning page or metadata selection | [Card and definition problems](#card-and-definition-problems) |
| Run button is absent | **When Checks Run** and **Run Button Display** on the Check Set | Intended card configuration | [Card and definition problems](#card-and-definition-problems) |
| One user succeeds and another does not | Permission Sets, record sharing, object access, and field access | Salesforce authorization | [Access differences](#access-differences-between-users) |
| Check is Skipped | Reason Code and prerequisite/applicability diagnostics | Applicability or dependency | [Read the result first](#read-the-result-first) |
| Check is Unable to Check | Reason Code, troubleshooting detail, and source details | Data, access, query, formula, or limit | [Show Diagnostics](#both-steps-are-required) |
| Check shows System Error | Expanded **Diagnosis** and Diagnostic ID | Configuration, custom Apex, or Record Health Check | [Read the diagnosis](#read-the-diagnosis) |
| Flow action faults or returns an aligned error | Flow interview details and returned category/message | Flow input, grouping, size, or evaluation | [Non-card entry points](#non-card-entry-points) |
| Apex call throws | Exception type/message and calling request | Invalid request, missing authorization, or prohibited custom Apex behavior | [Non-card entry points](#non-card-entry-points) |
| Queueable, Batch, or Scheduled job fails | Async job status plus the submitting/running user's debug log | Submission, scope, or finalization | [Non-card entry points](#non-card-entry-points) |
| Expected Platform Event never arrives | Publication option, Check settings, event access, and receiving automation logs | Event publication or receiving Flow, Apex, or integration | [Platform Event delivery](#platform-event-delivery) |

## Read the result first

Status and Reason Code are the fastest route to the correct layer:

| Status | Meaning | Troubleshooting posture |
| --- | --- | --- |
| Pass | The Check ran and its condition was met | Investigate only if the business expectation or displayed value is wrong |
| Fail | The Check ran and its condition was not met | Inspect Found, Expected, operator, and Check configuration; this is normally not a system defect |
| Skipped | The Check did not apply | Inspect applicability, prerequisite, and no-row behavior |
| Unable to Check | Record Health Check could not reach a reliable result | Inspect access, missing data, query or formula validity, and limits |
| System Error | Configuration or execution is broken | Open **Diagnosis**, follow its fix and verification steps, and retain the Diagnostic ID |

Look up the exact machine value in [Reason Codes](../reference/contracts/reason-codes.md). Do not
reinterpret Unable or Skipped as Fail; each means a different remediation and automation outcome.

## Read the diagnosis

For every catchable System Error or Unable result, an authorized administrator receives a
structured **Diagnosis** on the card. The card answers the first three questions; the matching
browser-console group completes the sequence:

1. **What failed?** A plain-language headline and safe summary.
2. **Where?** The lifecycle phase, component, Check, and, when Salesforce supplies it, Apex method
   and line.
3. **Why?** The classified likely cause, not merely `APEX_EVALUATOR_ERROR`.
4. **How do I fix it?** One or more actions tailored to configuration, access, query, formula,
   plugin contract, limits, or framework failure.
5. **How do I verify it?** A concrete rerun or configuration validation step.
6. **How do I correlate it?** A Diagnostic ID and Run ID that are safe to copy into a support case.

In the browser console, expand **Support report for this check** and copy the structured report when
you need to escalate. Review it before sharing: it can contain record and user IDs, queries, source
values, and customer data. The card itself intentionally shows only the concise diagnosis.

Debug logs are last-resort escalation evidence for an uncatchable platform limit, a Salesforce
internal error, or a novel framework defect whose diagnosis explicitly says telemetry is
incomplete. They are not the normal troubleshooting workflow.

## Review configuration before collecting developer evidence

When several records fail the same way, compare the Check Set and Check with
[Configure Check Sets and Checks](configure-check-sets-and-checks.md) and the appropriate Evaluation
Type reference. Confirm the exact Setup labels, API names, active settings, Evaluation Order, query
fields, operators, empty-result choices, and prerequisites. A correct configuration still requires
testing as the intended user because administrators can see records and fields other users cannot.

## Card and definition problems

1. In Lightning App Builder, confirm the component's **Check Set** value matches the intended
   Custom Metadata Developer Name.
2. Confirm the Check Set is active, uses the record's object API name, and has at least one active
   Check in the first 25 ordered Checks.
3. Treat a hidden Run button as configuration until proven otherwise. Check **When Checks Run**,
   **Run Button Display** on the selected Check Set. Hidden and icon-only controls intentionally
   release their unused header space to the title.
4. Refresh the record page after metadata, permission, or Lightning-page changes.
5. If definition loading still fails, capture the card's Diagnostic ID and copied diagnostic
   report. Use a debug log only if the diagnosis reports incomplete telemetry.

## Access differences between users

Compare users without granting broad administrator access permanently:

- both need the **Record Health Check User** Permission Set to run Record Health Check;
- Show Diagnostics additionally requires the diagnostics Custom Permission described below;
- record sharing and object/field permissions remain those of the running user;
- a custom Apex Check must query with the running user's access; and
- a Flow, Apex trigger, or integration receiving a Platform Event needs separate access to that
  event.

Test as the affected user whenever possible. A System Administrator success does not establish that
the intended user has the required access.

> [!WARNING]
> Turning on **Show Diagnostics** on the Check Set alone does **nothing** visible. Both the Check Set flag **and** the **Record Health Check View Diagnostics** (`rhc__Record_Health_Check_View_Diagnostics`) permission are required for troubleshooting output.

## Both steps are required

| Step | What to do | Where in Setup |
| ---- | ---------- | -------------- |
| **1. Check Set** | Check **Show Diagnostics** | **Custom Metadata Types** → **Record Health Check Set** → open your Check Set → **Show Diagnostics** (`ShowDiagnostics__c`) |
| **2. User** | Assign the **Record Health Check Admin** (`rhc__Record_Health_Check_Admin`) Permission Set | **Permission Sets** → open **Record Health Check Admin** (`rhc__Record_Health_Check_Admin`) → **Manage Assignments** → add the troubleshooting user |

Step 2 grants the **Record Health Check View Diagnostics** (`rhc__Record_Health_Check_View_Diagnostics`) Custom Permission, which unlocks advanced detail. The Check Set's **Show Diagnostics** flag then decides when that detail appears on the card and in the console.

The two controls answer different questions. **Show Diagnostics** lets an administrator choose
which Check Sets may produce troubleshooting output. The Custom Permission decides which users may
see it. Requiring both prevents a configuration change from exposing record identifiers, timing,
Reason Codes, source details, or access failures to every user of the Lightning page.

### Which Permission Set unlocks troubleshooting detail?

| Permission Set | API name | Can run checks | Includes View Diagnostics |
| --- | --- | --- | --- |
| Record Health Check User | `rhc__Record_Health_Check_User` | Yes | No |
| Record Health Check Admin | `rhc__Record_Health_Check_Admin` | Yes | Yes: includes **Record Health Check View Diagnostics** (`rhc__Record_Health_Check_View_Diagnostics`) |

If you checked Show Diagnostics on the Check Set but still see a normal card, the most common cause is that the viewing user does not have the **Record Health Check Admin** (`rhc__Record_Health_Check_Admin`) Permission Set.

## What View Diagnostics unlocks

**Record Health Check View Diagnostics** (`rhc__Record_Health_Check_View_Diagnostics`) is the Custom Permission that authorizes advanced result and
troubleshooting information. The Record Health Check Admin Permission Set includes it.

| Capability | View Diagnostics required | Show Diagnostics required | What the authorized user receives |
| --- | --- | --- | --- |
| Formula **Passes when** | Yes | No | The Formula Check's pass condition when the row uses the default Formula comparison display. Users without View Diagnostics see the business message instead of the formula expression. |
| Result troubleshooting line | Yes | Yes | Status, Reason Code, duration, and Evaluation Type beneath each result. |
| **Diagnosis** | Yes | Yes | A concise Issue, Where, and Why explanation for `UNABLE_TO_EVALUATE` or `ERROR`. |
| Browser-console prompt | Yes | Yes | A reminder that full technical evidence and next steps are available in the browser console. |
| `[RHC]` run summary | Yes | Yes | Run identity, outcome counts, timing, next steps, and one collapsed diagnostic group per Check. |
| Found and Expected source detail | Yes | Yes | `actualValueDetail` and `expectedValueDetail` notes inside each Check's collapsed **Advanced diagnostics** group. These explain where displayed values came from and never appear on the card. |

The Custom Permission does not grant record or field access. Record Health Check still uses the
running user's Salesforce access, and diagnostic output can describe only information the user was
allowed to evaluate.

After changing the Check Set or Permission Set assignment, **refresh the record page**.

## What you see on the Record Health Check card

After you **run** the checks (automatic or manual), and only when both steps above are complete:

| What | Description |
| ---- | ----------- |
| **Gray line under each result** | Compact summary, for example `FAIL · FORMULA_FALSE · 38ms · Formula`: Status, Reason Code, duration, and Evaluation Type (API value). |
| **Diagnosis** | An automatically expanded explanation limited to Issue, Where, and Why. Remediation, verification, IDs, and evidence stay in the browser console. |
| **Found / Expected** | On failing checks, labelled chips when the engine captured values. Found / Expected visibility is controlled by **Found/Expected Display** on the Check Set. |
| **Found and Expected source details** | When the viewer has **Record Health Check View Diagnostics** (`rhc__Record_Health_Check_View_Diagnostics`), source details are included in the browser-console diagnostics, not on the card. |
| **Console hint** | Small footnote directing technical users to the browser console (F12) for evidence and next steps. |

Users **without** **Record Health Check View Diagnostics** (`rhc__Record_Health_Check_View_Diagnostics`) never see the gray lines, Diagnosis panels, or the console hint: even when Show Diagnostics is checked on the Check Set. This is intentional so technical detail is not exposed to everyday users.

## What you see in the browser console

1. Open a record page that has the **Record Health Check** card.
2. Press **F12** (Windows/Linux) or open **Developer Tools** (Mac) and select the **Console** tab.
3. Run the Check Set from the card.
4. When the run finishes, find a group titled `[RHC] <CheckSetDeveloperName> · <outcome summary>`.

The group shows the Run ID and ordered next steps. Use the Check Set Developer Name in its title to
distinguish multiple Record Health Check cards on the same Lightning record page.

| Console entry | What it contains |
| --- | --- |
| **Outcome summary** | A count such as `3 Passed, 2 Failed · 847ms total`. |
| **Next steps** | Ordered plain-language guidance. System Error guidance appears before Unable, Fail, or Skipped guidance. |
| **Checks** | Every Check, ordered with System Error, Unable, Fail, and Skipped before Pass. Each Check is collapsed by default. |
| **Check summary** | Readable Status, Severity, Reason Code, Evaluation Type, duration, Issue, Where, Why, Fix, and Verify lines when available. |
| **Advanced diagnostics** | A collapsed JSON snapshot with identity, configuration, resolution, rendered values and sources, server diagnosis, and the complete normalized result for that Check. |
| **Support report for this check** | A collapsed, standalone JSON report for only that Check plus the run context needed to identify it. Review and redact it before sharing. |

Expand only the Check you need. Its summary separates Issue, Where, Why, Fix, and Verify. Expand
**Advanced diagnostics** when the summary is not enough. It can contain query templates, merged
record identifiers, prepared execution queries, source values, customer data, and the Diagnostic
ID, and must be reviewed before it is shared.

For a bounded per-record query, **Advanced diagnostics** shows the prepared query that execution used.
Its `LIMIT` is **Max Query Rows + 1** because the framework probes for one extra row to distinguish
an exact-cap result from `ROW_LIMIT_EXCEEDED`.

Use the **Diagnostic ID** and **Run ID** to correlate the card, console, Agentforce or API response,
and structured Log event. Open a Salesforce debug log only when the diagnosis explicitly lacks
enough evidence for resolution.
The console prints a redaction warning inside every per-Check support-report group. Record and User IDs,
queries, source values, and customer data can still be present; “support report” does not mean “safe
to publish without review.”

## Developer and integration evidence

### Salesforce debug logs

Use a debug log only after the Diagnosis, reviewed support report, and structured Log event cannot
identify the failed phase and first corrective action. This should be limited to uncatchable
governor limits, Salesforce internal failures, and novel framework defects.

1. In Setup, open **Debug Logs** and add a trace flag for the user who actually performs the run.
   Scheduled and asynchronous work can execute as a different user, so trace that user as well.
2. Reproduce once and note the local time and Run ID. Avoid leaving verbose tracing enabled while
   unrelated users continue working.
3. Open the matching log and search for `[RHC]`, the Run ID, the Check Set or Check identity,
   `EXCEPTION_THROWN`, `FATAL_ERROR`, and `LIMIT_USAGE_FOR_NS`.
4. Read the first relevant exception and its cause before later wrapper exceptions. Confirm whether
   the failure occurred while loading metadata, planning scope, evaluating Formula/SOQL/Apex,
   rendering display data, or publishing an event.
5. Disable the temporary trace flag and redact record data, user IDs, org IDs, queries, and tokens
   before sharing the log.

Debug output is evidence, not durable monitoring. Log availability is time-limited, and an
uncatchable Salesforce limit may prevent Record Health Check from writing its final diagnostic
line.

### Log platform event

`Record_Health_Check_Log__e` carries structured Record Health Check `ERROR` details for restricted
monitoring. Its Check Set control is **Publish Error Log Event** (`PublishErrorLogEvent__c`), which
is enabled by default. This event is separate from Check Result and Set Run lifecycle events.

Use it when a Flow, Apex trigger, or integration needs ongoing error notification. Its structured
details JSON retains category, phase, Diagnostic ID, fingerprint, ownership, retryability, scope
impact, and safe exception context independently from the human message. Publication can still
fail, and an uncatchable transaction-ending limit can prevent the event. See the complete field,
security, and loop-prevention details in [Log Platform Event](../metadata/event-log.md).

## Non-card entry points

| Entry point | Evidence to capture | Important distinction |
| --- | --- | --- |
| Flow | Failed interview details, input row, returned category/message, Run ID | An aligned error output is different from a Flow fault; group and response-size limits are validated by the adapter |
| Apex API | Request selection/options, exception type, response status/reason, Run ID | An invalid request or prohibited custom Apex action throws an exception instead of returning `FAIL`. |
| Queueable | `AsyncApexJob` status, job ID, submitting user, Finalizer/debug output | Submission and worker/finalizer failures occur in different transactions |
| Batch | Job ID, failing scope, first record IDs after redaction, scope debug log | One failing scope does not identify the Check without the request identity and Run ID |
| Scheduled | Cron job identity, scheduled user, launched Batch job ID | The schedule launches Batch; inspect both jobs |

Use [Apex API](../api/apex-api.md), [Flow actions](../integration/flow-actions.md),
[Queueable](../api/queueable.md), [Batch](../api/batch.md), and
[Scheduled](../api/scheduled.md) for the exact entry-point contracts.

## Platform-event delivery

Work from Record Health Check to the receiving Flow, Apex trigger, or integration in this order:

1. Confirm the run was deliberate. Record-page `RUN_ON_LOAD` activity does not publish lifecycle
   events.
2. For Apex, Flow, Queueable, Batch, Scheduled, Future, or Agent calls, confirm the request selected
   `ACTIONABLE` or `ALL`; the programmatic default is `NONE`.
3. For a user Run/Rerun, confirm the Check Set and Check publication fields are enabled. A hidden
   Run/Rerun control means that interactive publication path is unreachable.
4. Confirm the receiving user has access to the exact event and uses the namespaced channel in an
   installed package, such as `/event/rhc__Record_Health_Check_Result__e`.
5. Check receiving automation logs, replay handling, filters, and event allocations. A successful health
   check is not proof that best-effort publication or downstream processing succeeded.
6. Prevent repeated processing. Automation started by a Log event must not call Record Health Check from the same
   event transaction.

See [Lifecycle events](../integration/lifecycle-events.md) for publication rules and
[Subscribe with Pub/Sub API](../platform-events/external-pub-sub-api.md) for external integration
ideas and channel names.

## Escalation package

Before escalating, collect one coherent evidence set rather than unrelated screenshots:

- package version or installed `04t`, org type, and namespace shape;
- entry point, execution user, exact timestamp and timezone;
- Check Set and Check Qualified API Names, record object, and redacted record ID;
- Run ID, status, Reason Code, and visible message;
- redacted browser-console group and matching debug-log excerpt;
- Flow interview, background job, or receiving-automation identifier when applicable; and
- the smallest metadata configuration that reproduces the problem.

Never include session IDs, access/refresh tokens, authentication URLs, passwords, or customer data.

## What to capture for a bug report

For a behavior or evaluation issue, reproduce the problem with **Show Diagnostics** enabled and
include the following evidence:

- the expected behavior and the actual behavior;
- exact reproduction steps;
- the Check Set Qualified API Name and Check Developer Name;
- the displayed Status, Reason Code, and message;
- the redacted `[RHC]` console report; and
- a redacted screenshot or screen recording when the problem appears on the card.

If Show Diagnostics cannot be enabled or does not apply, explain why in the report. Also include the
package version or installed `04t`, installation type, org type, Salesforce API version, and browser
or device when relevant.

Before sharing evidence, remove customer data, record IDs, Org IDs, session IDs, and access tokens.
Redact both screenshots and console output. Security vulnerabilities must be reported privately
through the [Security policy](../../.github/SECURITY.md), not through a public issue.

## Checklist

- [ ] **Show Diagnostics** checked on the **same** Check Set the component uses (App Builder **Check Set** selection must match).
- [ ] Permission Set **Record Health Check Admin** (`rhc__Record_Health_Check_Admin`) assigned to the user viewing the page.
- [ ] Record page **refreshed** after metadata or permission changes.
- [ ] Checks **run** to completion (troubleshooting detail appears after the run, not on first load while rows are still pending).
- [ ] **Show Diagnostics turned off** on production Check Sets when troubleshooting is finished.

## Related

- [Install and verify](../installation/install-and-verify.md): first install and permission assignment
- [Configuration guide: Check Set fields](configure-check-sets-and-checks.md#3-check-set-fields): every Check Set field
- [Configuration guide: Troubleshooting](configure-check-sets-and-checks.md#13-troubleshooting): when a check fails or cannot run
