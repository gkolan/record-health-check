# Custom Permissions

Use this reference to understand the two authorization gates installed by Record Health Check and
which packaged Permission Sets grant them.

A Custom Permission is a Salesforce access flag, not a Permission Set. Administrators normally
grant a Custom Permission by assigning a Permission Set that contains it. Record Health Check uses
one Custom Permission to authorize runs and another to protect diagnostic detail. Their
authorization behavior is independent of business-record access.

If **Diagnostics Viewer** or the **Record Health Check** list view is absent from Setup, use the alternatives below and in [Permission Sets](./permission-sets.md). See [documentation and installed version](../install/choose-a-package-version.md#documentation-and-installed-version) when comparing source examples with an installed package.

## Installed Custom Permissions

| Custom Permission label | API name | What it controls |
| --- | --- | --- |
| **Record Health Check Run** | `rhc__Record_Health_Check_Run` | Whether a package entry point may start a Record Health Check run |
| **Record Health Check View Diagnostics** | `rhc__Record_Health_Check_View_Diagnostics` | Whether the running user may receive restricted advanced detail, including troubleshooting output when the selected Check Set also enables **Show Diagnostics** |

The `rhc__` prefix is the installed package namespace. Copy the API name shown in Setup or package
documentation; do not add or remove the namespace yourself.

## Record Health Check Run

Every supported Lightning, Flow, Apex, Agentforce, REST, and asynchronous entry point checks
**Record Health Check Run** before starting evaluation. Missing authorization can stop the request
before an individual Check result exists.

The Custom Permission is necessary but not sufficient by itself. The running user also needs access
to the Apex entry-point class for the selected surface. The packaged runner Permission Sets combine
the Custom Permission with the appropriate class access:

| Packaged Permission Set | Contains Run | Authorized surface |
| --- | :---: | --- |
| **Record Health Check Card User** | Yes | Lightning record-page card and App Builder picker |
| **Record Health Check User** | Yes | Lightning, Flow, Apex, Agentforce, REST, Queueable, Batch, and Scheduled Apex |
| **Record Health Check Admin** | Yes | Runtime surfaces plus administration and diagnostics |
| **Record Health Check MCP Integration** | Yes | Versioned Apex REST adapter only |
| **Record Health Check Diagnostics Viewer** | No | Diagnostic authorization only; combine it with a runner Permission Set |
| **Record Health Check Error Log Publisher** | No | Restricted Log Platform Event publication only; it cannot start a run |

The Run Custom Permission does not grant access to business records or fields. Record Health Check
continues to enforce the running user's object, field, record-sharing, restriction-rule, and
scoping-rule access while evaluating a Check.

## Record Health Check View Diagnostics

The permission can reveal the Formula **Passes when** expression when the row uses the documented
Formula comparison display; that specific display does not require **Show Diagnostics**. Broader
troubleshooting detail appears only when both conditions are true:

1. **Show Diagnostics** (`ShowDiagnostics__c`) is selected on the applicable Record Health Check Set
   Custom Metadata record.
2. The running user has **Record Health Check View Diagnostics**
   (`rhc__Record_Health_Check_View_Diagnostics`).

Selecting **Show Diagnostics** alone does not grant access. Assigning the Custom Permission alone
does not cause a Check Set with **Show Diagnostics** cleared to return the broader troubleshooting
output.

**Record Health Check Admin** and **Record Health Check Diagnostics Viewer** contain this Custom
Permission. Admin is appropriate for Check maintainers. Diagnostics Viewer grants no other package
access and is the least-privilege choice to add temporarily to an affected Card User or User.

Authorized diagnostic output can include object and field names, formula and SOQL text, access
failures, identifiers, and customer data. The output belongs to the current run: Show Diagnostics
does not save history or make another administrator's browser display the affected user's result.
Test as the affected user when possible, review copied support evidence before sharing it, and turn
**Show Diagnostics** off after the investigation.

## Check an assignment in Setup

To see which packaged Permission Set grants a Custom Permission:

1. In Salesforce Setup, enter `Custom Permissions` in **Quick Find**, then select **Custom
   Permissions**.
2. Select the **Record Health Check** list view, which filters permission labels starting with
   `Record Health Check`, then open **Record Health Check Run** or **Record Health Check View
   Diagnostics**. If that view is absent, use **All** and find the same names.
3. Review the Permission Sets that enable the Custom Permission.
4. Return to **Permission Sets**, open the appropriate installed Permission Set, and use **Manage
   Assignments** to review its users.

When a run still fails, confirm both the Custom Permission and the Apex class access supplied by the
selected Permission Set. For diagnostics, also confirm the Check Set's **Show Diagnostics** value
and refresh the Lightning record page after changing metadata or assignments.

## Related

- [Permission Sets](./permission-sets.md)
- [Security and data access](../architecture/security-and-data-access.md)
- [Show Diagnostics field reference](./custom-metadata/check-set-fields.md#show-diagnostics-showdiagnostics__c)
- [Browser-console diagnostics](../diagnostics/browser-console.md)
- [Run from Apex](../developer-guides/run-from-apex.md)
