# Reference: Security and data access

> [!NOTE]
> On this page, review how Record Health Check protects Salesforce data: the running user's access
> model, SOQL safety, plugin isolation, the two Permission Sets, the diagnostics permission, what the
> Framework does and does not persist, what an event body carries, fix-link safety, and merge-token
> resolution.

Use this page when you evaluate Record Health Check for a security review, decide which Permission
Set to assign, or confirm what a subscriber can see in a platform event.

## The trust model in one paragraph

Record Health Check evaluates with the running user's own Salesforce access. It never elevates
privilege, never performs DML on the evaluated record, and never executes administrator-authored
SOQL as written. The Framework rewrites, validates, and caps every input before it runs, and it
keeps troubleshooting detail behind an explicit Custom Permission so a normal user never sees more
than a status, a reason code, and administrator-authored display text.

## Access model: USER_MODE everywhere

Every query the Framework runs against a business record uses `WITH USER_MODE`. That includes the
record load for a Rule, Formula field-dependency lookups, Query and Compare-two-queries evaluation,
and applicability count queries.

| Property | Behavior |
| --- | --- |
| Object and field access | Enforced for the running user, not the user who authored the Rule |
| Record access (sharing) | Enforced for the running user through standard Salesforce sharing |
| Missing access | Returns `UNABLE_TO_EVALUATE` with a neutral reason code, never a thrown exception |
| Privilege escalation | None. The Framework classes are `with sharing`, and no query runs `WITH SYSTEM_MODE` |

Salesforce access, not Record Health Check, decides what a user can read. If a user cannot see an
Account or a field on it in Salesforce, that user cannot see it through a Rule either.

## SOQL template safety

Administrator-authored SOQL (Source Query, Comparison Query, and applicability count queries) is
never executed as written. `RecordHealthCheckSoqlTemplate` parses and rewrites it first.

| Check | What happens on failure |
| --- | --- |
| `WITH SYSTEM_MODE` present | Rejected before execution; the Rule returns `INVALID_SOQL_TEMPLATE` |
| DML keywords present (`INSERT`, `UPDATE`, `DELETE`, `UPSERT`, `MERGE`) | Rejected before execution; the Rule returns `INVALID_SOQL_TEMPLATE` |
| No `WITH USER_MODE` clause | The Framework injects one in the correct position before running the query |
| Outer `LIMIT` above 2,000 | Rewritten down to the enforced maximum row count |
| Merge tokens outside `record.*` | Rejected; only `record.*` tokens are valid inside SOQL |

A Rule author writes ordinary SOQL. The Framework decides how it runs. This means a malformed or
overly broad query becomes a documented status on one card instead of an uncatchable governor
exception or an unintended system-mode read.

Rule scope is also enforced structurally: a caller can only evaluate a Rule through its own Check
Set, and cannot evaluate a Rule whose Check Set is inactive or targets a different object. See
[Architecture: The configuration model](01-architecture.md#4-the-configuration-model).

## Plugin side-effect bans

A custom Apex Rule plugin (`RecordHealthCheckRule`) is trusted code: the Framework cannot isolate or
observe every read it performs. It can, however, guarantee that a plugin call does not write to the
transaction (no DML, callouts, email, platform events, or asynchronous work).

`RecordHealthCheckPluginDispatch` wraps every plugin call in a savepoint and rejects:

| Prohibited effect | Result |
| --- | --- |
| DML of any kind | Thrown Framework exception, `PLUGIN_SIDE_EFFECT_DETECTED` |
| Callouts | Thrown Framework exception, `PLUGIN_SIDE_EFFECT_DETECTED` |
| Email | Thrown Framework exception, `PLUGIN_SIDE_EFFECT_DETECTED` |
| Platform event publication | Thrown Framework exception, `PLUGIN_SIDE_EFFECT_DETECTED` |
| Asynchronous work (Queueable, Future, Batch, Scheduled) | Thrown Framework exception, `PLUGIN_SIDE_EFFECT_DETECTED` |

The savepoint rolls back any detected effect before the pipeline derives display content or
publishes lifecycle events, so a misbehaving plugin cannot commit a write through a Rule evaluation.

That write check is not a read-security boundary. A plugin must still use `with sharing` and
`WITH USER_MODE` queries on its own; the Framework validates returned keys and statuses and blocks
forbidden writes, but the plugin author remains responsible for its own data access. Review every
plugin query for CRUD/FLS enforcement before deployment, and use the multi-size contract test and
permission test data described in [Verify an Apex Rule plugin](../apex/08-plugin-verification.md)
to gather evidence rather than assuming it.

## Permission Sets: User vs Admin

Access is split into two Permission Sets so run access and troubleshooting access can be
granted independently.

| Permission Set | Grants | Assign to |
| --- | --- | --- |
| `Record_Health_Check_User` | The `Record_Health_Check_Run` Custom Permission, needed to call the protected Apex surface and run checks | Every user who should see the card |
| `Record_Health_Check_Admin` | Everything in `Record_Health_Check_User`, plus the `Record_Health_Check_View_Diagnostics` Custom Permission and the metadata validation surface | Rule authors and troubleshooters only |

Do not assign `Record_Health_Check_Admin` to users who only need to run checks. Diagnostic detail
can include SOQL text, formula text, and specific access-denial causes that a regular user should
not see.

## The diagnostics Custom Permission

Diagnostic detail requires two things to be true at the same time:

1. The Check Set has **Show Diagnostics** (`ShowDiagnostics__c`) checked.
2. The running user holds the `Record_Health_Check_View_Diagnostics` Custom Permission (included in
   `Record_Health_Check_Admin`).

If either condition is false, the user sees the standard card: a status, a severity, and
administrator-authored text. Neither condition alone is enough, so a Check Set left in diagnostics
mode after a troubleshooting session does not expose detail to users who lack the permission, and a
troubleshooter with the permission does not see detail on a Check Set that has not enabled it.

Turn **Show Diagnostics** off again once troubleshooting finishes. It is a Check Set-wide setting,
not a per-user toggle, so leaving it on exposes detail to every user who happens to hold the
Custom Permission.

### Why access codes are remapped

`FIELD_NOT_ACCESSIBLE` and `RECORD_NOT_ACCESSIBLE` never appear as the public `reasonCode` on a
result. The engine remaps both to the neutral `CANNOT_EVALUATE` before returning it to a normal
user. Revealing which of the two happened, or that a specific hidden record exists, can disclose
Salesforce access information to someone who is not allowed to see it.

An authorized troubleshooter with **Show Diagnostics** enabled and the diagnostics permission still
sees the specific code on `adminDetail.reasonCode`, so a real investigation is never blocked. See
[Reason Codes: Access and permissions](../contracts/01-reason-codes.md#access-and-permissions) for the
full remapping table.

## What is and isn't persisted

Record Health Check does not build a database of historical results. A run produces a response and,
optionally, publishes platform events; nothing is written back to the evaluated record or to a
Framework-owned results table.

| Data | Persisted by the Framework? |
| --- | --- |
| The evaluated record | No. Evaluation is read-only; the Framework performs no DML on it |
| A Rule's Pass/Fail/Skipped/Unable to Check/System Error outcome | No. It exists only in the response returned to the caller |
| Found and Expected values | No. They are formatted for display and returned, not stored |
| Historical trend of results over time | No. A subscriber must build its own storage from lifecycle events |
| `[RHC]` debug lines | Only as long as Salesforce debug logs are retained, subject to org debug-log settings |
| Held `ERROR` detail before `flush()` | Transient, in memory, for the duration of the run; published or discarded, never written to a table |
| Check Set and Rule configuration | Yes, as Custom Metadata, which deploys like any other metadata and consumes no record storage |

If a business process needs a history of readiness over time, subscribe to lifecycle events and
write your own storage. See [Architecture: Out of scope](01-architecture.md#16-out-of-scope).

## What an event body carries

The two lifecycle result events are deliberately minimal. `Record_Health_Check_Set_Run__e` and
`Record_Health_Check_Rule_Result__e` carry status, counts, severities, Reason Codes, the evaluated
record's ID when one is available, and correlation fields such as `RunId__c`. They never carry:

- The Salesforce user Id of who ran the check
- Administrator-authored display messages
- Found or Expected values
- SOQL or formula source
- `adminDetail` diagnostic text

`Record_Health_Check_Log__e` is the exception. It is a restricted channel that carries the
error message, exception type, and stack trace for a Framework `ERROR`, published immediately so it
survives the rollback that a failing check can trigger. Grant access to this event only to the
subscriber or integration that needs to investigate errors, separately from the User and Admin
Permission Sets, which do not grant it. See
[Lifecycle events: Diagnostics events are a separate channel](../../integration/03-lifecycle-events.md#diagnostics-events-are-a-separate-channel).

Treat every subscriber grant as a data-access decision: Set Run and Rule Result events are safe for
a broad audience because they carry no message text or user identity, while Log events need the
same care as an error log or stack trace anywhere else in the org.

## Fix-link rules

**Action URL** on a failed Rule is checked for safety after its merge tokens resolve and are
URL-encoded.

| Allowed | Rejected |
| --- | --- |
| Same-org relative Lightning paths starting with `/lightning/` | `http://` |
| Other same-org relative paths starting with `/` | `javascript:` |
| External `https://` URLs | `data:` |
| | `mailto:` |
| | Protocol-relative URLs such as `//example.com` |
| | URLs containing backslashes |
| | URLs longer than 2,000 characters |

A rejected or oversized URL is dropped; **Fix Message** can still render on its own. The check runs
twice: once in Apex before the response leaves the server, and again in the Lightning component
(`healthCheckPresentation`) before the value is bound as an `href`, so a link only ever opens a
same-org or `https://` destination. Opening the link does not perform DML; a user can still edit or
create a record on the destination page and choose to save it there.

See [Configure action links](../../guides/04-configure-action-links.md) for the complete URL pattern
library and review checklist.

## Merge tokens

Merge tokens only resolve known namespaces (`record`, `rhcRule`, `rhcSet`, `rhcResult`, `rhcRun`),
and each surface allows only the namespaces that make sense on it: SOQL accepts `record.*` only,
Action URL rejects result tokens, and display text accepts all five. Unknown namespaces and
properties are configuration errors, not silent no-ops.

| Safety property | Enforcement |
| --- | --- |
| Token count | Capped at 100 per template; over the cap returns `TOKEN_LIMIT_EXCEEDED` |
| Resolved message length | Capped at 20,000 characters; over the cap returns `RESOLVED_TEMPLATE_TOO_LONG` rather than a truncated, possibly misleading message |
| SOQL bind typing | A token bound into SOQL is typed and escaped; strings are quoted, numbers/dates/Booleans are not, and an unconvertible fallback returns `MISSING_BIND_VALUE` instead of running a malformed query |
| Field readability | The running user must be able to read every field a token names, or the Rule returns `UNABLE_TO_EVALUATE` |

Because SOQL tokens are typed and escaped rather than concatenated as text, a merge token cannot be
used to inject arbitrary SOQL. See [Reference: Merge tokens](../contracts/02-merge-tokens.md) for the full
namespace, fallback, and surface contract.

## Error messages at public boundaries

Public boundaries (the Apex API, Flow actions, and the Lightning component) return a safe message
and a stable Reason Code. Raw exception text, stack traces, and internal identifiers stay inside
diagnostics, only when the same **Show Diagnostics** and Custom Permission combination described
above allows it.

## Reporting a vulnerability

Record Health Check's security policy lives in [`.github/SECURITY.md`](../../../.github/SECURITY.md).
Report a suspected vulnerability privately through GitHub Security Advisories, not a public issue.
Diagnostic detail reaching an unauthorized user is treated as a security issue in its own right, not
only a bug.

## Related

- [Architecture: Security model](01-architecture.md#9-security-model)
- [Reason Codes](../contracts/01-reason-codes.md)
- [Lifecycle events](../../integration/03-lifecycle-events.md)
- [Verify an Apex Rule plugin](../apex/08-plugin-verification.md)
- [Configure action links](../../guides/04-configure-action-links.md)
- [Troubleshoot with Show Diagnostics](../../guides/07-troubleshoot-with-show-diagnostics.md)
- [Security policy](../../../.github/SECURITY.md)
