# Security and data access

> [!NOTE]
> Use this page to decide which Permission Set to assign, understand whose Salesforce access a Check
> uses, and review what custom Apex, Platform Events, diagnostics, and action links can expose.

## Security summary

Record Health Check reads Salesforce data with the access of the user who starts the run. It does
not grant access to a record or field the user cannot already read. A standard Check does not change
the checked record.

The package protects four separate areas:

| Area | Protection |
| --- | --- |
| Starting a run | Requires the **Record Health Check Run** Custom Permission and access to the appropriate Apex entry point |
| Reading Salesforce data | Package queries use `WITH USER_MODE` and package classes use `with sharing` |
| Reading Check definitions | After Run authorization succeeds, packaged Custom Metadata definitions load in system mode; this does not grant access to business records or configuration editing |
| Viewing troubleshooting detail | Requires both the Check Set setting and the diagnostics Custom Permission |
| Publishing or receiving events | Requires Platform Event permissions and an explicit publication choice or setting |

## Choose the correct Permission Set

The package installs four Permission Sets. **Record Health Check Run**
(`rhc__Record_Health_Check_Run`) is a Custom Permission included in both; it is not a Permission Set
by itself.

To assign one, go to **Setup → Permission Sets**, open the installed Permission Set, select
**Manage Assignments**, and then select **Add Assignments**. Do not search for a Permission Set named
**Record Health Check Run**; that name belongs to the Custom Permission contained in the installed
Permission Sets.

| Installed Permission Set | What it provides | Assign it to |
| --- | --- | --- |
| **Record Health Check Card User** (`rhc__Record_Health_Check_Card_User`) | Run Custom Permission and Lightning controller class only | People who only run the record-page card; this is the least-privilege default for interactive users |
| **Record Health Check User** (`rhc__Record_Health_Check_User`) | Run Custom Permission; access to Lightning, Apex, Flow, Agentforce, REST, Queueable, Batch, and Scheduled entry classes; read access to both Custom Metadata Types; create/read access for Set Run and Check Result events | Automation principals that use those broader entry points; not the default card-only assignment |
| **Record Health Check Admin** (`rhc__Record_Health_Check_Admin`) | Runner access plus diagnostics, Custom Metadata type visibility, validation, and App Builder picklist access | Administrators who maintain or troubleshoot Checks; creating Custom Metadata also requires Salesforce Customize Application or equivalent access |
| **Record Health Check Error Log Publisher** (`rhc__Record_Health_Check_Error_Log_Publisher`) | Create and Read access to the restricted Log Platform Event (Salesforce requires Read with Create) | Narrowly selected runners whose Check Sets enable error-log publication; assignees must be trusted with restricted error data |

Do not assign the Admin Permission Set merely because a person needs to run a Check. Diagnostic
detail can include formula text, SOQL text, and specific access problems.

The installed Permission Sets do not grant access to `Record_Health_Check_Log__e`. Grant access to
that Error Log event separately and only to the Flow, Apex code, integration user, or monitoring tool
that needs restricted troubleshooting details.

## Whose record and field access is used?

The user who starts each Salesforce transaction supplies the access used in that transaction.

| How the run starts | Which user's access applies? |
| --- | --- |
| Person opens or runs the Lightning card | That person's access |
| Record-triggered or autolaunched Flow | The user and execution context Salesforce gives that Flow transaction |
| Apex | The user running the Apex transaction |
| Scheduled Apex or Batch Apex | The user under whom Salesforce executes that scheduled or Batch transaction |

Record Health Check queries business records with `WITH USER_MODE`. Salesforce therefore enforces
object access, field access, record sharing, restriction rules, scoping rules, and future user-mode
visibility controls for that user.

The Admin Permission Set grants Record Health Check administration capabilities. It does not grant
access to Account, Opportunity, Case, or any other business object or field. Grant those permissions
through your organization's normal profiles and permission sets.

The Flow action still checks the **Record Health Check Run** Custom Permission. Confirm that the
user who causes or executes the Flow has an installed runner Permission Set, and test the Flow in
its actual execution context rather than assuming a system-context Flow bypasses the package check.

Query outcomes describe only the rows visible in that transaction. Zero returned rows do not prove
that no matching rows exist elsewhere in the org; they prove that the configured user-mode query
found no visible rows. Record Health Check never runs an elevated comparison query to distinguish a
truly empty dataset from rows hidden by sharing, restriction rules, or scoping rules. Doing so would
leak the existence of data the running user cannot access. Choose the Check's configured no-rows
policy with that visible-scope meaning in mind. Org-wide completeness requires a separately
authorized administrative design outside the ordinary evaluator.

If the initial record query cannot return a requested record, its result uses
`RECORD_NOT_VISIBLE`. A field-access problem is returned publicly as `CANNOT_EVALUATE`; an authorized
administrator can see the more specific `FIELD_NOT_ACCESSIBLE` diagnostic. An invalid request or a
missing Run Custom Permission can stop the request before individual results exist.

Before rollout, test with a real user from each intended access group. An administrator's successful
test does not prove that a sales or service user can read every field required by the Check.

## How stored SOQL is protected

Source Query, Comparison Query, and applicability count query text is inspected before it runs.

| Query condition | Package behavior |
| --- | --- |
| Contains `WITH SYSTEM_MODE` | Rejects the query as `INVALID_SOQL_TEMPLATE` |
| Contains a data-changing keyword such as `INSERT`, `UPDATE`, `DELETE`, `UPSERT`, or `MERGE` | Rejects the query as `INVALID_SOQL_TEMPLATE` |
| Does not contain `WITH USER_MODE` | Adds `WITH USER_MODE` in the supported location |
| Requests an outer `LIMIT` above 2,000 | Lowers that outer limit to 2,000 |
| Uses a merge token other than `record.*` | Rejects the query |

Merge-token values are converted to the Salesforce data type required by the field and safely
inserted into the query. A missing or invalid value returns a documented Reason Code instead of
running altered SOQL. See [Merge tokens](../contracts/merge-tokens.md).

## Plugin write restrictions

A custom Apex Check implements `rhc.RecordHealthCheckPlugin`. It is code created by your team, so it
must receive the same security review as any other Apex class in your org.

The custom class must:

- declare `with sharing`;
- use `WITH USER_MODE` for SOQL;
- check any additional object and field access required by its logic;
- avoid changing records, making callouts, sending email, publishing events, or starting
  asynchronous Apex; and
- return exactly one result for every record ID it receives.

Record Health Check places a savepoint around construction and evaluation. It detects changes to
Apex counters for record changes, callouts, Queueable jobs, future methods, and email. When detected,
it stops the run; record changes and queued work can be rolled back, but an already-sent callout or
email cannot be undone.

Apex does not expose a reliable counter for every effect. In particular, the package cannot prove
at run time that custom code did not publish a Platform Event or start Batch or Scheduled Apex.
Code review, static analysis, and the supplied contract tests must enforce those restrictions. The
package also cannot correct an unsafe query written inside the custom class.

See [Create a custom Apex Check](../evaluation/apex-check-contract.md) for the required review and
tests. Administrators only paste the reviewed class API name into the Check record in Setup.

## The diagnostics Custom Permission

Detailed troubleshooting appears only when both conditions are true:

1. **Show Diagnostics** is selected on the Check Set.
2. The running user has **Record Health Check View Diagnostics**
   (`rhc__Record_Health_Check_View_Diagnostics`).

The Admin Permission Set includes that Custom Permission. The User Permission Set does not.

Turn **Show Diagnostics** off after troubleshooting. It applies to the whole Check Set, so every
person who also has the diagnostics permission can see the details while it remains enabled.

Public results hide specific field-access details behind `CANNOT_EVALUATE`. Authorized diagnostics
can show the more specific reason and relevant configuration. This helps an administrator fix the
Check without telling a normal user which hidden field or record caused the problem.

## Does Record Health Check save sensitive values?

The package does not install a result-history object and does not write Found or Expected values
back to the checked record.

| Information | Saved by Record Health Check? |
| --- | --- |
| Status, Reason Code, Found, and Expected in the returned response | No; returned to the current Apex, Flow, or Lightning caller |
| Checked record changes | No |
| Check Set and Check configuration | Yes; stored as Custom Metadata |
| `[RHC]` lines | Present only in Salesforce debug logs according to the org's log retention |
| Error details waiting for logger `flush()` | Held only for the current transaction, then published or discarded |

When history is required, create a custom object owned by your team and save only the returned fields
that the business needs. Apply object, field, sharing, and retention controls to that object. See
[Data model](data-model.md#recommended-save-returned-results-when-history-is-required).

## What do the Platform Events contain?

The health-result events contain identifiers and result classifications, not the displayed business
values.

`Record_Health_Check_Result__e` and `Record_Health_Check_Set_Run__e` can contain:

- Run ID, event ID, source, occurrence time, and contract/package version;
- Check or Check Set Qualified API Name;
- checked record ID;
- Status, Reason Code, and Severity for a Check result; and
- final counts for a Check Set result.

They do not contain the running user's ID, Found, Expected, Check messages, SOQL, formula text, stack
trace, or diagnostics. `ContainsRestrictedDetail__c` on the Check Result event is always `false` in
the current implementation.

`Record_Health_Check_Log__e` is different. It can contain the user ID, record ID, error message,
exception type, and stack trace. Treat access to it like access to a restricted error log. See
[Lifecycle events](../../integration/lifecycle-events.md).

## Which action links are allowed?

After merge tokens are resolved, Record Health Check accepts:

- a same-org path beginning with `/`, including `/lightning/...`; or
- an external URL beginning with `https://`.

It rejects `http://`, `javascript:`, `data:`, `mailto:`, a protocol-relative URL beginning with
`//`, a backslash, or a value longer than 2,000 characters. Apex checks the URL before returning it,
and the Lightning component checks it again before displaying a link.

Opening an allowed link does not save a record automatically. The destination page can still let a
user edit and save data according to that user's Salesforce access. See
[Configure action links](../../guides/configure-action-links.md).

## Security review checklist

- Assign the User Permission Set to runners and reserve the Admin Permission Set for Check authors
  and troubleshooters.
- Test every Check with representative non-administrator users.
- Review stored SOQL and every custom Apex Check in source control.
- Keep **Show Diagnostics** off except during an investigation.
- Grant Error Log event access separately and narrowly.
- Store returned results only in a custom object with reviewed access and retention.
- Review every external `https://` Action URL and every Flow or Apex process that receives a
  Platform Event.
- Report suspected vulnerabilities privately through the process in
  [`.github/SECURITY.md`](../../../.github/SECURITY.md).

## Related

- [Install and verify](../../installation/install-and-verify.md)
- [Operate in production](../../guides/operate-in-production.md)
- [Reason Codes](../contracts/reason-codes.md)
- [Lifecycle events](../../integration/lifecycle-events.md)
- [Create a custom Apex Check](../evaluation/apex-check-contract.md)
- [Configure action links](../../guides/configure-action-links.md)
- [Troubleshoot Record Health Check](../../guides/troubleshoot-with-show-diagnostics.md)
- [Security policy](../../../.github/SECURITY.md)
