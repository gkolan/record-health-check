# Permission Sets

Use this reference to choose the least-privilege Record Health Check Permission Set for a person,
automation principal, or integration user.

This reference describes six Permission Sets. In the 2.0.7.2 source, diagnostics requires a direct, active assignment of the packaged Admin or Diagnostics Viewer set. Run is the only packaged Custom Permission. Cloned sets and group-only assignments do not confer diagnostics access. See [version availability](../install/choose-a-package-version.md#documentation-and-installed-version).

Four authorize a specific way to run health
checks. Two are additive: one grants diagnostic viewing and one grants restricted error-log event
publication. These Permission Sets grant package access; they do not grant access to Account,
Opportunity, Case, or any other business object or field used by a Check.

## Choose an installed Permission Set

| I need to… | Assign | Why |
| --- | --- | --- |
| Run or configure only the Lightning record-page card | **Record Health Check Card User** (`rhc__Record_Health_Check_Card_User`) | This is the least-privilege interactive assignment. It grants the card controller, App Builder picker, run authorization, and card lifecycle-event access. |
| Run Checks from Flow, Apex, Agentforce, Queueable, Batch, or Scheduled Apex | **Record Health Check User** (`rhc__Record_Health_Check_User`) | It grants the supported runtime entry points without configuration validation or diagnostic detail. |
| Configure, validate, or troubleshoot Checks | **Record Health Check Admin** (`rhc__Record_Health_Check_Admin`) | It adds Custom Metadata visibility, validation entry points, and diagnostic authorization to the runtime access. |
| Call the versioned REST adapter from a dedicated MCP integration | **Record Health Check MCP Integration** (`rhc__Record_Health_Check_MCP_Integration`) | It grants only the REST adapter and the package metadata access that adapter needs. |
| Let an existing runner view diagnostics without granting Admin | **Record Health Check Diagnostics Viewer** (`rhc__Record_Health_Check_Diagnostics_Viewer`) | Its explicit assignment authorizes diagnostics. Assign it directly and temporarily alongside Card User or User. |
| Publish restricted error-log events | **Record Health Check Error Log Publisher** (`rhc__Record_Health_Check_Error_Log_Publisher`) | It grants Create and Read access only to the restricted Log Platform Event. Assign it in addition to the appropriate runner access. |

Do not assign **Record Health Check Admin** merely to make a card, Flow, Apex class, or integration
run. Choose the runner Permission Set for that entry point and add organization-owned business-data
access separately.

## Compare runner access

This mapping shows the package access contained in each runner Permission Set.

| Capability | Card User | User | Admin | MCP Integration |
| --- | :---: | :---: | :---: | :---: |
| **Record Health Check Run** Custom Permission | Yes | Yes | Yes | Yes |
| Diagnostics authorization through direct assignment | No | No | Yes | No |
| Lightning record-page card controller | Yes | Yes | Yes | No |
| App Builder Check Set picker | Yes | Yes | Yes | No |
| Public Apex API | No | Yes | Yes | No |
| Flow actions | No | Yes | Yes | No |
| Agentforce actions | No | Yes | Yes | No |
| Versioned Apex REST adapter | No | Yes | Yes | Yes |
| Queueable, Batch, and Scheduled Apex entry points | No | Yes | Yes | No |
| Read access to both packaged Custom Metadata Types | No | Yes | Yes | Yes |
| Configuration validation entry points | No | No | Yes | No |
| Create and Read access to Set Run and Check Result events | Yes | Yes | Yes | No |
| Create and Read access to the restricted Log event | No | No | No | No |

## Compare additive access

| Capability | Diagnostics Viewer | Error Log Publisher |
| --- | :---: | :---: |
| **Record Health Check Run** Custom Permission | No | No |
| Diagnostics authorization through direct assignment | Yes | No |
| Package Apex, Custom Metadata, or business-data access | No | No |
| Create and Read access to Set Run and Check Result events | No | No |
| Create and Read access to the restricted Log event | No | Yes |

`Yes` means that the Permission Set includes the package permission or Apex access. Salesforce can
still require separate platform access. For example, a Lightning page builder needs the normal App
Builder privileges, and creating Custom Metadata records requires **Customize Application** or
equivalent access.

## Record Health Check Card User

Assign **Record Health Check Card User** to people who use only the Lightning record-page card. It
includes:

- **Custom Permission label:** Record Health Check Run
- **Custom Permission API name:** `rhc__Record_Health_Check_Run`
- the Lightning controller and App Builder Check Set picker classes; and
- Create and Read access to the Set Run and Check Result Platform Events used by explicitly enabled
  card publication.

It excludes Flow, Agentforce, REST, public and asynchronous Apex, Custom Metadata authoring, and
diagnostic detail. It also excludes the restricted Log Platform Event.

## Record Health Check User

Assign **Record Health Check User** to a user or automation principal that needs one or more of the
broader runtime entry points. It includes:

- the Run Custom Permission;
- Lightning, public Apex, Flow, Agentforce, REST, Queueable, Batch, and Scheduled Apex entry-point
  classes;
- read access to the Record Health Check Set and Record Health Check Custom Metadata Types; and
- Create and Read access to the Set Run and Check Result Platform Events.

It excludes diagnostic detail, configuration-validation entry points, Custom Metadata authoring,
and the restricted Log Platform Event.

## Record Health Check Admin

Assign **Record Health Check Admin** to administrators who maintain Check definitions, validate
configuration, or perform authorized troubleshooting. It includes the package runtime entry points
and adds:

- diagnostics access through this set's direct, active assignment;
- read access to both packaged Custom Metadata Types; and
- the package metadata-validation entry points.

The Permission Set does not grant business-record access. It also does not grant Salesforce's
**Customize Application** permission, which is required to create or edit Custom Metadata through
Setup unless the administrator has equivalent access from another assignment.

Diagnostic detail can contain object names, field names, formula text, SOQL text, record or user
identifiers, and customer data. Keep **Show Diagnostics** off except during an investigation.

## Record Health Check MCP Integration

Assign **Record Health Check MCP Integration** to a dedicated integration user that calls the
versioned Record Health Check REST adapter. It includes only:

- the Run Custom Permission;
- the versioned Apex REST adapter class; and
- read access to both packaged Custom Metadata Types.

It excludes the Lightning UI, Flow, Agentforce, public and asynchronous Apex entry points,
lifecycle events, diagnostics, and restricted error logs. Create a separate organization-owned
Permission Set for only the business objects and fields that the integration must read.

## Record Health Check Diagnostics Viewer

Assign **Record Health Check Diagnostics Viewer** temporarily alongside **Record Health Check Card
User** or **Record Health Check User** when the affected runner must reproduce a problem with
authorized diagnostic detail. It includes only:

- **Authorization:** direct, active assignment of this packaged Permission Set;
- no diagnostic Custom Permission is installed or checked.

It does not include the Run Custom Permission, Apex class access, Custom Metadata access, business
data access, or Platform Event access. The existing runner Permission Set continues to determine how
the user can run a Check. The permission can expose the Formula **Passes when** expression in its
documented display mode. Broader troubleshooting output appears only when **Show Diagnostics** is
also selected on the applicable Check Set.

Remove the assignment and clear **Show Diagnostics** after the investigation. Diagnostic output can
contain object and field names, formula and SOQL text, identifiers, access failures, and customer
data.

## Record Health Check Error Log Publisher

Assign **Record Health Check Error Log Publisher** only to a trusted running identity whose Check
Set explicitly enables error-log publication. It grants Create and Read access to
`rhc__Record_Health_Check_Log__e`; Salesforce requires Read together with Create for a Platform
Event publisher.

This Permission Set does not include the Run Custom Permission or any package Apex entry point. It
must be combined with the runner Permission Set appropriate to the transaction. The event can
contain user and record IDs, error messages, exception types, and stack traces, so do not assign it
as general runtime access.

## Assign and verify access

To keep the list focused on this package, create a Permission Sets view named **Record Health
Check** with **Permission Set Label** starting with `Record Health Check`. Salesforce does not
support deploying this Setup view through ListView metadata, so create it separately in each org.

In Salesforce Setup:

1. Enter `Permission Sets` in **Quick Find**, then select **Permission Sets**.
2. Open the installed Permission Set by its label.
3. Select **Manage Assignments**, then **Add Assignments**.
4. Select the intended users and complete the assignment.
5. Test with a representative non-administrator user in the real entry point and execution context.

An administrator's successful test does not prove that another user can read the records and fields
required by a Check. Record Health Check evaluates business data with the running user's Salesforce
access.

## Related

- [Custom Permissions](./custom-permissions.md)
- [Security and data access](../architecture/security-and-data-access.md)
- [Install and verify](../install/install-in-a-sandbox.md)
- [Troubleshoot Record Health Check](../diagnostics/browser-console.md)
- [Save restricted errors](../save-results/save-restricted-errors.md)
