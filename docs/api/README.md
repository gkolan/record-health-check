# Record Health Check APIs

> [!NOTE]
> Use this section when a Flow, Apex class, or scheduled process must run Record Health Check. Start
> here to choose the correct API, then follow the linked guide from setup through verification.

## What these APIs do

The APIs run an existing **Check** or **Check Set** against one or more Salesforce records.

- A **Check** answers one health question, such as whether an Account has a primary contact.
- A **Check Set** groups related Checks so they can run together.
- A **result** is returned for each record and Check.
- Optional **Platform Events** can send results to a Flow, Apex trigger, or external integration.

The APIs do not create Checks or automatically store a result history. Configure Checks in Custom
Metadata first, and decide where results should go before choosing a background process.

## Terms used in the examples

| Term | Plain-language meaning |
| --- | --- |
| `rhc.` | The Record Health Check managed-package namespace used before an Apex class or type, such as `rhc.RecordHealthCheckResponse`. |
| `rhc__` | The prefix used inside the API name of a Check or Check Set included with the installed Record Health Check package, such as `rhc__Account_Data_Quality`. It uses two underscores because that is Salesforce metadata naming syntax. |
| Qualified API Name | The exact API name Salesforce assigns to a Check or Check Set Custom Metadata record. Copy this value from Setup. |
| Platform Event | A Salesforce message sent after a health check so a Flow, Apex trigger, or external integration can receive the result. |
| Run ID | Text used to connect related results and jobs during troubleshooting. It does not identify a Salesforce record. |
| Custom Permission | A Salesforce access flag used by Apex or Flow. Administrators normally grant it through a Permission Set. **Record Health Check Run** is the Custom Permission; **Record Health Check User** and **Record Health Check Admin** are the packaged Permission Sets that include it. |

The two prefixes have different purposes:

```apex
// rhc. identifies a packaged Apex type.
rhc.RecordHealthCheckResponse response;

// Qualified API Name for a Check Set created in your org.
String checkSetName = 'My_Account_Checks';

// Qualified API Name for a Check Set included with the installed package.
// String checkSetName = 'rhc__Account_Data_Quality';
```

In **Setup**, open **Custom Metadata Types → Record Health Check Set → Manage Records** and copy the
exact **Qualified API Name**. Do not add or remove `rhc__` yourself.

## Choose the simplest option that fits

| Need | Use | Why |
| --- | --- | --- |
| A Flow must make a decision immediately | [Flow API](flow.md) | The action returns statuses that a Decision element can use in the same transaction. |
| Apex must make a decision immediately | [Apex API](apex-api.md) | The response is available to the calling code immediately. |
| Up to 200 known record IDs can run later | [Queueable Apex](queueable.md) | One separate transaction processes the complete request and provides an Apex job ID. |
| Many records must be checked after a change or on a schedule | [Batch Apex](batch.md) | Salesforce checks the records in smaller groups. |
| The same work must run on a schedule | [Scheduled Apex](scheduled.md) | A scheduler starts Queueable or Batch work with a known record limit. |
| Existing code uses a future method | [Move from Future to Queueable](future.md) | Queueable Apex provides better inputs, monitoring, and failure handling. |

> [!TIP]
> Use Flow or Apex when the current process needs the answer immediately. Use Queueable when up to
> 200 known records can run later. Use Batch when many records must be checked in smaller groups.

## Before you start

Confirm all of the following:

1. The Check or Check Set is active and has been tested from the Record Health Check user interface.
2. Assign the running user one packaged Permission Set:
   - **Record Health Check User** for running Checks from Lightning, Flow, or Apex.
   - **Record Health Check Admin** when the user also configures Checks or views diagnostics.

   Both Permission Sets include the **Custom Permission label:** Record Health Check Run,
   **Custom Permission API name:** `rhc__Record_Health_Check_Run`, and the required package Apex
   class access.
   **Record Health Check Run** is a Custom Permission, not the name of a Permission Set.
3. The running user can access the target records, fields, Apex classes, and Record Health Check
   Custom Metadata required by the selected Checks.
4. You know the Custom Metadata **Qualified API Name** of the Check or Check Set. Records created by
   an administrator normally do not include a prefix, for example `My_Account_Checks`. Records
   included with the installed package normally include `rhc__`, for example
   `rhc__Account_Data_Quality`.
5. You know what should happen after a result is returned: branch immediately, publish Platform
   events, save an approved history record, notify monitoring, or only monitor job completion.

Test with the same permissions and data access as the user who will run the real automation.

To assign the normal user access, open **Setup → Permission Sets → Record Health Check User →
Manage Assignments → Add Assignments**, select the user, and save.

## Understand the shared request

Every Apex example builds an `rhc.RecordHealthCheckRequest` and calls:

```apex
rhc.RecordHealthCheckResponse response =
  rhc.RecordHealthCheck.evaluate(request);
```

A request supplies:

| Input | Meaning |
| --- | --- |
| Check or Check Set | The exact Qualified API Name copied from Setup |
| Record IDs | The complete list of records for this request, within the documented limit |
| Result mode | How much result detail the response should contain |
| Event publication | Whether Platform Events should be published |
| Run ID | Optional text used to connect related jobs and results during troubleshooting |
| Execution origin | The type of process that started the run |

### Choose what results to publish as events

The response and events are two different ways to receive results:

- An Apex or Flow call returns results directly to the code or Flow that ran it.
- Event publication sends an additional Platform Event message for another automation to receive.
- The default Apex result mode, `EVALUATION`, returns every result, including `PASS`, even when event
  publication is `NONE` or `ACTIONABLE`.
- The packaged Queueable, Batch, and Scheduled classes do not give their response back to the code
  that submitted the job. Use events when those classes must send health results somewhere.

| Mode | Events published | Use it when |
| --- | --- | --- |
| `NONE` | No result events | Apex or Flow reads the response directly, or only background-job completion is needed. This is the default. |
| `ACTIONABLE` | `FAIL`, `UNABLE_TO_EVALUATE`, and `ERROR`; plus a completed Set Run heartbeat | Another automation receives only Check results that need attention while still seeing that every record was scanned. `PASS` Check Result events are not published. |
| `ALL` | `PASS`, `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, and `ERROR` | Another automation must receive every result, including successful Checks. |

Publishing an event does not save a permanent history by itself. A Flow, Apex trigger, or external
integration must receive the event and decide what to do with it.

### Example result choices

| Workflow | Result choice |
| --- | --- |
| A record-triggered Flow needs to branch immediately | Use the Flow action, read its returned status, and leave publication as `NONE`. |
| Apex needs to decide whether to continue immediately | Read `response.results`; use `NONE` unless another automation also needs an event. |
| An overnight job should create work only for problems | Use `ACTIONABLE` and configure an event receiver for the failure statuses. |
| An audit process must record successes and problems | Use `ALL` and configure an event receiver that saves every required result. |
| An administrator needs to know only whether the Apex job ran | Use `NONE` and monitor **Setup → Apex Jobs**. The packaged background class will not save individual health results. |

## Read statuses correctly

| Status | Meaning | Typical handling |
| --- | --- | --- |
| `PASS` | The record met the Check condition. | Continue the process. |
| `FAIL` | The record did not meet the business condition. | Show guidance or start approved follow-up. This is not an Apex or Flow fault. |
| `SKIPPED` | The Check did not apply to this record. | Continue or report separately, according to the business process. |
| `UNABLE_TO_EVALUATE` | Access, data, or configuration prevented a reliable answer. | Review the reason code and correct the underlying issue. |
| `ERROR` | The Framework contained an evaluator or system problem as result data. | Send the result to operational monitoring. |

Some request, authorization, or fatal plugin failures are thrown instead of returned as statuses.
Each guide explains the correct fault or job-monitoring path.

## Limits that affect the design

- A public evaluation request accepts at most 200 records.
- Formula-heavy Check Sets can require fewer records per transaction because formula evaluations
  have a limit.
- `MaxQueryRows__c` limits the query rows used while checking one group of records.
- Batch and Scheduled Apex have separate submission limits documented in their guides.
- Preserve `runId` when work crosses a transaction or system boundary.
- Do not place record data, credentials, access tokens, or unfiltered stack traces in logs or
  user-visible error fields.

## Related

- [Platform Event subscriptions](../platform-events/README.md)
- [Integration overview](../integration/README.md)
- [Reason Codes](../reference/contracts/reason-codes.md)
- [Architecture](../reference/framework/architecture.md)
