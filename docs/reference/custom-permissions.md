# Custom Permissions

The 2.0.7.2 source packages exactly one Custom Permission: **Record Health Check Run**.
Earlier package versions include a separate View Diagnostics Custom Permission.

A Custom Permission is a Salesforce access flag, not a Permission Set. Administrators normally
grant a Custom Permission by assigning a Permission Set that contains it. Record Health Check uses
one Custom Permission to authorize runs. Diagnostic detail instead requires a direct, active
assignment of the packaged Admin or Diagnostics Viewer Permission Set. Profile grants, cloned
Permission Sets, and Permission Set Group membership alone do not authorize diagnostics.
Their authorization behavior is independent of business-record access.

If **Diagnostics Viewer** or the **Record Health Check** list view is absent from Setup, use the alternatives below and in [Permission Sets](./permission-sets.md). See [documentation and installed version](../install/choose-a-package-version.md#documentation-and-installed-version) when comparing source examples with an installed package.

## Installed Custom Permissions

| Custom Permission label | API name | What it controls |
| --- | --- | --- |
| **Record Health Check Run** | `rhc__Record_Health_Check_Run` | Whether a package entry point may start a Record Health Check run |

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

In the 2.0.7.2 source this is no longer a Custom Permission. Explicit diagnostics access
can reveal the Formula **Passes when** expression when the row uses the documented
Formula comparison display; that specific display does not require **Show Diagnostics**. Broader
troubleshooting detail appears only when both conditions are true:

1. **Show Diagnostics** (`ShowDiagnostics__c`) is selected on the applicable Record Health Check Set
   Custom Metadata record.
2. The running user has a direct, active assignment of the package's **Record Health Check Admin**
   or **Record Health Check Diagnostics Viewer** Permission Set, in the package namespace.

Selecting **Show Diagnostics** alone does not grant access. Assigning a diagnostics Permission Set alone
does not cause a Check Set with **Show Diagnostics** cleared to return the broader troubleshooting
output.

**Record Health Check Admin** and **Record Health Check Diagnostics Viewer** are recognized by their
explicit assignments, not by a second Custom Permission. Admin is appropriate for Check maintainers. Diagnostics Viewer grants no other package
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
2. Use **All** and open **Record Health Check Run**. A fresh 2.0.7.2 installation must have
   no other RHC Custom Permission.
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
