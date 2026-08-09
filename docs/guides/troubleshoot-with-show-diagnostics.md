# Troubleshoot Record Health Check

> [!NOTE]
> On this page, diagnose configuration, access, evaluation, card, Flow, Apex, asynchronous, and
> event-delivery problems from one starting point. Capture authorized evidence, identify the failing
> layer, and remove temporary diagnostic access when the investigation is complete.
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
| What appears in the browser console? | One `[RHC]` group containing run identity, results, timing, and available source details |
| How do I return to normal operation? | Uncheck Show Diagnostics and remove temporary administrator access when appropriate |

## Start by identifying the failing layer

Do not begin by changing Check logic. First reproduce once, record the exact time, user, record,
Check Set Qualified API Name, and Run ID, then choose the matching path.

| Symptom | First evidence | Likely layer | Go to |
| --- | --- | --- | --- |
| Card is missing, empty, or says no Check Set is configured | App Builder component properties and Check Set identity | Lightning page or metadata selection | [Card and definition problems](#card-and-definition-problems) |
| Run button is absent | **When Checks Run**, **Run Button Display**, and Lightning-page override | Intended card configuration | [Card and definition problems](#card-and-definition-problems) |
| One user succeeds and another does not | Permission Sets, record sharing, object access, and field access | Salesforce authorization | [Access differences](#access-differences-between-users) |
| Check is Skipped | Reason Code and prerequisite/applicability diagnostics | Applicability or dependency | [Read the result first](#read-the-result-first) |
| Check is Unable to Check | Reason Code, troubleshooting detail, and source details | Data, access, query, formula, or limit | [Show Diagnostics](#both-steps-are-required) |
| Check shows System Error | Run ID, Salesforce debug log, and Log event | Configuration, plugin, or Framework defect | [Server-side evidence](#server-side-evidence) |
| Flow action faults or returns an aligned error | Flow interview details and returned category/message | Flow input, grouping, size, or evaluation | [Non-card entry points](#non-card-entry-points) |
| Apex call throws | Exception type/message and calling request | Caller contract, authorization, or fatal plugin behavior | [Non-card entry points](#non-card-entry-points) |
| Queueable, Batch, or Scheduled job fails | Async job status plus the submitting/running user's debug log | Submission, scope, or finalization | [Non-card entry points](#non-card-entry-points) |
| Expected platform event never arrives | Publication option, metadata switch, event access, and subscriber logs | Publication or subscriber | [Platform-event delivery](#platform-event-delivery) |

## Read the result first

Status and Reason Code are the fastest route to the correct layer:

| Status | Meaning | Troubleshooting posture |
| --- | --- | --- |
| Pass | The Check ran and its condition was met | Investigate only if the business expectation or displayed value is wrong |
| Fail | The Check ran and its condition was not met | Inspect Found, Expected, operator, and Check configuration; this is normally not a system defect |
| Skipped | The Check did not apply | Inspect applicability, prerequisite, and no-row behavior |
| Unable to Check | The Framework could not safely reach a verdict | Inspect access, missing data, query/formula validity, and limits |
| System Error | Configuration or execution is broken | Capture the Run ID and use server-side evidence |

Look up the exact machine value in [Reason Codes](../reference/contracts/reason-codes.md). Do not
reinterpret Unable or Skipped as Fail; each means a different remediation and automation outcome.

## Validate configuration before runtime debugging

Run the metadata audit after a deployment or whenever several records fail in the same way:

```apex
List<RecordHealthCheckMetadataValidator.ValidationIssue> issues =
  RecordHealthCheckMetadataValidator.validate();
System.debug(LoggingLevel.ERROR, JSON.serializePretty(issues));
```

Package maintainers can run that source form directly. Subscriber Apex cannot call this
package-internal `public` class across the `rhc` namespace; subscribers should review the Check Set
and Check fields using [Configure Check Sets and Checks](configure-check-sets-and-checks.md), or ask
the package maintainer to run the supported validation procedure. An empty list means the metadata
audit found no issue; it does not prove that the running user can access every record and field.

## Card and definition problems

1. In Lightning App Builder, confirm the component's **Check Set** value matches the intended
   Custom Metadata Developer Name.
2. Confirm the Check Set is active, uses the record's object API name, and has at least one active
   Check in the first 25 ordered Checks.
3. Treat a hidden Run button as configuration until proven otherwise. Check **When Checks Run**,
   **Run Button Display**, and any component override. Hidden and icon-only controls intentionally
   release their unused header space to the title.
4. Refresh the record page after metadata, permission, or Lightning-page changes.
5. If definition loading still fails, capture the browser console error and a Salesforce debug log
   for the affected user at the same timestamp.

## Access differences between users

Compare users without granting broad administrator access permanently:

- both need the **Record Health Check User** Permission Set to run the Framework;
- Show Diagnostics additionally requires the diagnostics Custom Permission described below;
- record sharing and object/field permissions remain those of the running user;
- an Apex Check plugin is responsible for its own user-mode access; and
- a platform-event subscriber needs access to that specific event independently of run access.

Test as the affected user whenever possible. A System Administrator success does not establish that
the intended persona has the required access.

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
| Formula **Passes when** | Yes | No | The Formula Check's pass condition when the row uses the Framework's default Formula comparison display. Users without View Diagnostics see the business message instead of the formula expression. |
| Result troubleshooting line | Yes | Yes | Status, Reason Code, duration, and Evaluation Type beneath each result. |
| **Troubleshooting detail** | Yes | Yes | Technical context for a Check that returned `UNABLE_TO_EVALUATE` or `ERROR`, when detail is available. |
| Browser-console prompt | Yes | Yes | The **Check console (F12) for diagnostics** message on the card. |
| `[RHC]` run summary | Yes | Yes | Run identity, outcome counts, timing, and a table of Check results in the browser console. |
| Found and Expected source detail | Yes | Yes | `actualValueDetail` and `expectedValueDetail` notes inside the console's `[RHC] Source detail` group. These explain where displayed values came from and never appear on the card. |

The Custom Permission does not grant record or field access. Record Health Check still evaluates
with the running user's Salesforce access, and diagnostic output can describe only information the
Framework was allowed to evaluate.

After changing the Check Set or Permission Set assignment, **refresh the record page**.

## What you see on the Record Health Check card

After you **run** the checks (automatic or manual), and only when both steps above are complete:

| What | Description |
| ---- | ----------- |
| **Gray line under each result** | Compact summary, for example `FAIL · FORMULA_FALSE · 38ms · Formula`: Status, Reason Code, duration, and Evaluation Type (API value). |
| **Troubleshooting detail** | On checks that errored or did not run, a **Troubleshooting detail** block showing the technical message inline (SOQL problems, missing field access, and similar) |
| **Found / Expected** | On failing checks, labelled chips when the engine captured values. Found / Expected visibility is controlled by **Found/Expected Display** on the Check Set. |
| **Found and Expected source details** | When the viewer has **Record Health Check View Diagnostics** (`rhc__Record_Health_Check_View_Diagnostics`), source details are included in the browser-console diagnostics, not on the card. |
| **Console hint** | Small footnote at the bottom of the card: **Check console (F12) for diagnostics.** |

Users **without** **Record Health Check View Diagnostics** (`rhc__Record_Health_Check_View_Diagnostics`) never see the gray lines, Troubleshooting detail blocks, or the console hint: even when Show Diagnostics is checked on the Check Set. This is intentional so technical detail is not exposed to everyday users.

## What you see in the browser console

1. Open a record page that has the **Record Health Check** card.
2. Press **F12** (Windows/Linux) or open **Developer Tools** (Mac) and select the **Console** tab.
3. Run the Check Set from the card.
4. When the run finishes, find a group titled `[RHC] Health Check run <runId> | <CheckSetDeveloperName> | record <recordId>`.

The title contains the Run ID, selected Check Set Developer Name, and Record ID. Use the Check Set
Developer Name to distinguish multiple Record Health Check cards on the same Lightning record page.

| Console entry | What it contains |
| --- | --- |
| **Outcome summary** | A count such as `3 Passed, 2 Failed · 847ms total`. |
| **Start here** | The outcome summary, run identity, and ordered plain-language next steps. System Error guidance appears before Unable, Fail, or Skipped guidance. |
| **Run metadata** | Run ID, Check Set Developer Name, Record ID, User ID, and timestamp for matching Apex logs. |
| **Results table** | Every Check with its Status, Failure Severity, Reason Code, Found / Expected values, duration, and Evaluation Type. |
| **Full check details** | Every Check, ordered with System Error, Unable, Fail, and Skipped before Pass. Each collapsed group separates identity, configuration, resolved evaluation, rendered output, and server diagnostics. |
| **Copy for support** | A smaller JSON report without the duplicated raw-result object. Review and redact it before sharing. |
| **Advanced raw report** | The complete developer-oriented result. It may contain restricted data and is not the default support artifact. |

Use the **Run ID** to match Apex log entries when Apex logging is enabled for your user.
The console prints a redaction warning immediately before the support report. Record and User IDs,
queries, source values, and customer data can still be present; “support report” does not mean “safe
to publish without review.”

## Server-side evidence

### Salesforce debug logs

Use a debug log for System Error, thrown Apex exceptions, Flow faults, failed async work, or a card
request that never returns enough detail to the browser.

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

Debug output is evidence, not durable monitoring. Log availability is time-limited and an
uncatchable governor-limit termination may prevent the Framework from writing its final diagnostic
line.

### Log platform event

`Record_Health_Check_Log__e` carries structured Framework `ERROR` diagnostics for restricted
monitoring. Its Check Set control is **Publish Error Log Event** (`PublishErrorLogEvent__c`), which
is enabled by default. This event is separate from Check Result and Set Run lifecycle events.

Use it when an operations integration needs ongoing error notification. Do not treat it as a
replacement for debug logs: event publication is best effort, a transaction-ending limit can
prevent publication, and subscribers require explicit access. See the complete field, security,
loop-prevention, and subscriber contract in [Log Platform Event](../metadata/event-log.md).

## Non-card entry points

| Entry point | Evidence to capture | Important distinction |
| --- | --- | --- |
| Flow | Failed interview details, input row, returned category/message, Run ID | An aligned error output is different from a Flow fault; group and response-size limits are validated by the adapter |
| Apex API | Request selection/options, exception type, response status/reason, Run ID | Fatal caller-contract and plugin side-effect failures are thrown rather than converted to Fail |
| Queueable | `AsyncApexJob` status, job ID, submitting user, Finalizer/debug output | Submission and worker/finalizer failures occur in different transactions |
| Batch | Job ID, failing scope, first record IDs after redaction, scope debug log | One failing scope does not identify the Check without the request identity and Run ID |
| Scheduled | Cron job identity, scheduled user, launched Batch job ID | The schedule launches Batch; inspect both jobs |

Use [Apex API](../api/apex-api.md), [Flow actions](../integration/flow-actions.md),
[Queueable](../api/queueable.md), [Batch](../api/batch.md), and
[Scheduled](../api/scheduled.md) for the exact entry-point contracts.

## Platform-event delivery

Work from publisher to subscriber in order:

1. Confirm the run was deliberate. Record-page `RUN_ON_LOAD` activity does not publish lifecycle
   events.
2. For Apex, Flow, Queueable, Batch, Scheduled, Future, or Agent calls, confirm the request selected
   `ACTIONABLE` or `ALL`; the programmatic default is `NONE`.
3. For a user Run/Rerun, confirm the Check Set and Check publication fields are enabled. A hidden
   Run/Rerun control means that interactive publication path is unreachable.
4. Confirm the subscriber has access to the exact event and uses the namespaced channel in an
   installed package, such as `/event/rhc__Record_Health_Check_Result__e`.
5. Check subscriber logs, replay handling, filters, and event allocations. A successful health
   check is not proof that best-effort publication or downstream processing succeeded.
6. Prevent feedback loops. A Log-event subscriber must not call Record Health Check from the same
   event transaction.

See [Lifecycle events](../integration/lifecycle-events.md) for publication rules and
[Subscribe with Pub/Sub API](../platform-events/external-pub-sub-api.md) for external subscriber
ideas and channel names.

## Escalation package

Before escalating, collect one coherent evidence set rather than unrelated screenshots:

- package version or installed `04t`, org type, and namespace shape;
- entry point, execution user, exact timestamp and timezone;
- Check Set and Check Qualified API Names, record object, and redacted record ID;
- Run ID, status, Reason Code, and visible message;
- redacted browser-console group and matching debug-log excerpt;
- Flow interview, async job, or event-subscriber identifier when applicable; and
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
