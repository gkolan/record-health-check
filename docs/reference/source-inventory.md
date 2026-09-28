# Source inventory

> This page is generated from package source by `npm run generate:docs:inventory`.
> Do not edit it by hand. `npm run check:docs:inventory` fails when source and this page differ.

Use this inventory to confirm what the package actually ships. Task guides explain how to use these capabilities.

## Package identity

| Item | Source value |
| --- | --- |
| Package | Record Health Check |
| Namespace | `rhc` |
| Metadata API | `66.0` |

## Permission Sets (7)

| Salesforce label | API name | Purpose |
| --- | --- | --- |
| Record Health Check Admin | `Record_Health_Check_Admin` | Configure and validate Record Health Check and view diagnostics. Creating Custom Metadata records also requires Salesforce Customize Application or equivalent access. |
| Record Health Check Card User | `Record_Health_Check_Card_User` | Run the Lightning record-page card, configure its App Builder picker, and publish enabled card lifecycle events. Excludes Flow, Agent, REST, async Apex, and Custom Metadata authoring. |
| Record Health Check Diagnostics Viewer | `Record_Health_Check_Diagnostics_Viewer` | View restricted Record Health Check details, including troubleshooting output when enabled. Assign alongside a packaged runner Permission Set temporarily and narrowly. |
| Record Health Check Error Log Publisher | `Record_Health_Check_Error_Log_Publisher` | Publish restricted Record Health Check Log Platform Events. Assign narrowly: Salesforce requires Read together with Create for Platform Event publishers. |
| Record Health Check MCP Integration | `Record_Health_Check_MCP_Integration` | Run only the versioned Record Health Check Apex REST adapter for dedicated integrations. Excludes UI, Flow, Agentforce, async Apex, lifecycle events, and diagnostics. |
| Record Health Check Readiness Auditor | `Record_Health_Check_Readiness_Auditor` | Read-only access to bounded Record Health Check draft verification receipts. |
| Record Health Check User | `Record_Health_Check_User` | Run Record Health Checks from Lightning, Apex, Flow, or Agentforce. Includes the required entry-point classes and Set Run and Check Result event access. Excludes diagnostic details. |

## Custom Permissions (1)

| Salesforce label | API name | Purpose |
| --- | --- | --- |
| Record Health Check Run | `Record_Health_Check_Run` | Allows a user to run Record Health Checks from supported Lightning, Flow, Apex, and asynchronous entry points. |

## Lightning Web Components (2)

| Salesforce label | Bundle | Available in Lightning App Builder | Purpose |
| --- | --- | --- | --- |
| Record Health Check | `recordHealthCheck` | `lightning__RecordPage` | Runs metadata-driven record health checks with SLDS 1 and SLDS 2 styling. |
| Record Health Check Preview | `recordHealthCheckPreview` | `lightning__AppPage`, `lightning__HomePage`, `lightning__Tab` | Administrator-only detached Check validation and representative-record preview. |

### Lightning App Builder properties

| Component | Salesforce label | Property | Type | Purpose |
| --- | --- | --- | --- | --- |
| Record Health Check | Check Set | `checkSetName` | `String` | Choose the Check Set to run on this record page. The list shows active Check Sets whose Record Object API Name matches this page's object. If the list is empty, create and activate a Check Set for this object under Setup - Custom Metadata Types - Record Health Check Set. |

## Invocable actions (5)

| Surface | Salesforce label | Apex class | Purpose |
| --- | --- | --- | --- |
| Flow | Run Record Health Check | `RecordHealthCheckRunCheckFlowAction` | Runs one qualified Record Health Check for each input record. |
| Agentforce | Run Record Health Check for Agentforce | `RecordHealthCheckRunCheckAgentAction` | Use when a user asks for the actual result of one named Record Health Check on one Salesforce record. FAIL is a completed business finding. UNABLE_TO_EVALUATE and ERROR are not PASS. |
| Flow | Run Record Health Check Set | `RecordHealthCheckRunSetFlowAction` | Runs one qualified Record Health Check Set for each input record. |
| Agentforce | Run Record Health Check Set for Agentforce | `RecordHealthCheckRunSetAgentAction` | Use when a user asks for the actual health of one Salesforce record under one named Record Health Check Set. FAIL is a completed business finding. UNABLE_TO_EVALUATE and ERROR are not PASS. |
| Flow | Validate Record Health Check Configuration | `RecordHealthCheckValidateMetadataAction` | Validates every Record Health Check Set and Check, including inactive drafts, before activation. |

### Invocable action inputs and outputs

| Action | Direction | Salesforce label | Apex variable | Type | Required |
| --- | --- | --- | --- | --- | --- |
| Run Record Health Check | Input | Check Qualified API Name | `checkQualifiedApiName` | `String` | Yes |
| Run Record Health Check | Input | Record ID | `recordId` | `Id` | Yes |
| Run Record Health Check | Input | Event Publication | `eventPublication` | `String` | Yes |
| Run Record Health Check | Output | Success | `isSuccess` | `Boolean` | No |
| Run Record Health Check | Output | Error Message | `errorMessage` | `String` | No |
| Run Record Health Check | Output | Error Type | `errorType` | `String` | No |
| Run Record Health Check | Output | Contract Version | `contractVersion` | `String` | No |
| Run Record Health Check | Output | Status | `status` | `String` | No |
| Run Record Health Check | Output | Reason Code | `reasonCode` | `String` | No |
| Run Record Health Check | Output | Result JSON | `resultJson` | `String` | No |
| Run Record Health Check for Agentforce | Input | Record ID | `recordId` | `Id` | Yes |
| Run Record Health Check for Agentforce | Input | Check Qualified API Name | `qualifiedApiName` | `String` | Yes |
| Run Record Health Check for Agentforce | Input | Correlation ID | `correlationId` | `String` | No |
| Run Record Health Check for Agentforce | Output | Contract Version | `contractVersion` | `String` | No |
| Run Record Health Check for Agentforce | Output | Correlation ID | `correlationId` | `String` | No |
| Run Record Health Check for Agentforce | Output | Success | `success` | `Boolean` | No |
| Run Record Health Check for Agentforce | Output | Operation | `operation` | `String` | No |
| Run Record Health Check for Agentforce | Output | Status | `status` | `String` | No |
| Run Record Health Check for Agentforce | Output | Reason Code | `reasonCode` | `String` | No |
| Run Record Health Check for Agentforce | Output | Error Type | `errorType` | `String` | No |
| Run Record Health Check for Agentforce | Output | Error Message | `errorMessage` | `String` | No |
| Run Record Health Check for Agentforce | Output | Diagnostic ID | `diagnosticId` | `String` | No |
| Run Record Health Check for Agentforce | Output | Diagnostic Category | `diagnosticCategory` | `String` | No |
| Run Record Health Check for Agentforce | Output | Diagnostic Summary | `diagnosticSummary` | `String` | No |
| Run Record Health Check for Agentforce | Output | Recommended Action | `recommendedAction` | `String` | No |
| Run Record Health Check Set | Input | Check Set Qualified API Name | `checkSetQualifiedApiName` | `String` | Yes |
| Run Record Health Check Set | Input | Record ID | `recordId` | `Id` | Yes |
| Run Record Health Check Set | Input | Event Publication | `eventPublication` | `String` | Yes |
| Run Record Health Check Set | Output | Success | `isSuccess` | `Boolean` | No |
| Run Record Health Check Set | Output | Error Message | `errorMessage` | `String` | No |
| Run Record Health Check Set | Output | Error Type | `errorType` | `String` | No |
| Run Record Health Check Set | Output | Contract Version | `contractVersion` | `String` | No |
| Run Record Health Check Set | Output | Status | `status` | `String` | No |
| Run Record Health Check Set | Output | Passed Count | `passedCount` | `Integer` | No |
| Run Record Health Check Set | Output | Failed Count | `failedCount` | `Integer` | No |
| Run Record Health Check Set | Output | Skipped Count | `skippedCount` | `Integer` | No |
| Run Record Health Check Set | Output | Unable Count | `unableCount` | `Integer` | No |
| Run Record Health Check Set | Output | System Error Count | `systemErrorCount` | `Integer` | No |
| Run Record Health Check Set | Output | Result JSON | `resultJson` | `String` | No |
| Run Record Health Check Set for Agentforce | Input | Record ID | `recordId` | `Id` | Yes |
| Run Record Health Check Set for Agentforce | Input | Check Set Qualified API Name | `qualifiedApiName` | `String` | Yes |
| Run Record Health Check Set for Agentforce | Input | Correlation ID | `correlationId` | `String` | No |
| Run Record Health Check Set for Agentforce | Output | Contract Version | `contractVersion` | `String` | No |
| Run Record Health Check Set for Agentforce | Output | Correlation ID | `correlationId` | `String` | No |
| Run Record Health Check Set for Agentforce | Output | Success | `success` | `Boolean` | No |
| Run Record Health Check Set for Agentforce | Output | Operation | `operation` | `String` | No |
| Run Record Health Check Set for Agentforce | Output | Status | `status` | `String` | No |
| Run Record Health Check Set for Agentforce | Output | Passed Count | `passed` | `Integer` | No |
| Run Record Health Check Set for Agentforce | Output | Failed Count | `failed` | `Integer` | No |
| Run Record Health Check Set for Agentforce | Output | Skipped Count | `skipped` | `Integer` | No |
| Run Record Health Check Set for Agentforce | Output | Unable Count | `unable` | `Integer` | No |
| Run Record Health Check Set for Agentforce | Output | System Error Count | `systemError` | `Integer` | No |
| Run Record Health Check Set for Agentforce | Output | Error Type | `errorType` | `String` | No |
| Run Record Health Check Set for Agentforce | Output | Error Message | `errorMessage` | `String` | No |
| Run Record Health Check Set for Agentforce | Output | Diagnostic ID | `diagnosticId` | `String` | No |
| Run Record Health Check Set for Agentforce | Output | Diagnostic Category | `diagnosticCategory` | `String` | No |
| Run Record Health Check Set for Agentforce | Output | Diagnostic Summary | `diagnosticSummary` | `String` | No |
| Run Record Health Check Set for Agentforce | Output | Recommended Action | `recommendedAction` | `String` | No |

## Packaged data definitions (6)

| Kind | Salesforce label | API name | Custom fields |
| --- | --- | --- | ---: |
| Custom Metadata Type | Record Health Check | `Record_Health_Check__mdt` | 45 |
| Platform Event | Record Health Check Log | `Record_Health_Check_Log__e` | 15 |
| Custom Object | Record Health Check Readiness | `Record_Health_Check_Readiness__c` | 17 |
| Platform Event | Record Health Check Result | `Record_Health_Check_Result__e` | 13 |
| Custom Metadata Type | Record Health Check Set | `Record_Health_Check_Set__mdt` | 19 |
| Platform Event | Record Health Check Set Run | `Record_Health_Check_Set_Run__e` | 18 |

## Platform Event fields

### Record Health Check Log (15)

| Salesforce label | API name | Type |
| --- | --- | --- |
| Check Developer Name | `CheckDeveloperName__c` | Text |
| Check Set Developer Name | `CheckSetDeveloperName__c` | Text |
| Code | `Code__c` | Text |
| Contract Version | `ContractVersion__c` | Text |
| Structured Diagnostic Details | `DetailsJson__c` | LongTextArea |
| Event ID | `EventId__c` | Text |
| Exception Type | `ExceptionType__c` | Text |
| Framework Version | `FrameworkVersion__c` | Text |
| Level | `Level__c` | Text |
| Message | `Message__c` | LongTextArea |
| Occurred At | `OccurredAt__c` | DateTime |
| Record ID | `RecordId__c` | Text |
| Run ID | `RunId__c` | Text |
| Stack Trace | `StackTrace__c` | LongTextArea |
| User ID | `UserId__c` | Text |

### Record Health Check Result (13)

| Salesforce label | API name | Type |
| --- | --- | --- |
| Check Qualified API Name | `CheckQualifiedApiName__c` | Text |
| Check Set Qualified API Name | `CheckSetQualifiedApiName__c` | Text |
| Contains Restricted Detail | `ContainsRestrictedDetail__c` | Checkbox |
| Contract Version | `ContractVersion__c` | Text |
| Event ID | `EventId__c` | Text |
| Framework Version | `FrameworkVersion__c` | Text |
| Occurred At | `OccurredAt__c` | DateTime |
| Reason Code | `ReasonCode__c` | Text |
| Record ID | `RecordId__c` | Text |
| Run ID | `RunId__c` | Text |
| Severity | `Severity__c` | Text |
| Source | `Source__c` | Text |
| Status | `Status__c` | Text |

### Record Health Check Set Run (18)

| Salesforce label | API name | Type |
| --- | --- | --- |
| Check Set Qualified API Name | `CheckSetQualifiedApiName__c` | Text |
| Contract Version | `ContractVersion__c` | Text |
| Eligible Check Count | `EligibleCheckCount__c` | Number |
| Evaluated Check Count | `EvaluatedCheckCount__c` | Number |
| Event ID | `EventId__c` | Text |
| Failed Count | `FailedCount__c` | Number |
| Framework Version | `FrameworkVersion__c` | Text |
| Occurred At | `OccurredAt__c` | DateTime |
| Passed Count | `PassedCount__c` | Number |
| Phase | `Phase__c` | Text |
| Processed Record Count | `ProcessedRecordCount__c` | Number |
| Record ID | `RecordId__c` | Text |
| Run ID | `RunId__c` | Text |
| Skipped Count | `SkippedCount__c` | Number |
| Source | `Source__c` | Text |
| Submitted Record Count | `SubmittedRecordCount__c` | Number |
| System Error Count | `SystemErrorCount__c` | Number |
| Unable Count | `UnableCount__c` | Number |

## Installed example Check Sets (4)

| Salesforce label | API name | Object | Active |
| --- | --- | --- | --- |
| Example: Account Check Builder Guide | `Example_Account_Check_Builder_Guide` | `Account` | Yes |
| Example: Account Relationship &amp; Risk | `Example_Account_Relationship_Risk` | `Account` | Yes |
| Example: Contact Relationship Readiness | `Example_Contact_Relationship_Readiness` | `Contact` | Yes |
| Example: Opportunity Deal Readiness | `Example_Opportunity_Deal_Readiness` | `Opportunity` | Yes |

## Installed example Checks (50)

| Salesforce label | API name | Check Set | Evaluation Type | Active |
| --- | --- | --- | --- | --- |
| Example: Account Owner Is Active | `Example_Account_Owner_Active` | `Example_Account_Relationship_Risk` | `FORMULA` | Yes |
| Example: Proposal and Product totals | `Example_Average_Deal_Vs_Largest` | `Example_Account_Check_Builder_Guide` | `COMPARE_TWO_QUERIES` | Yes |
| Example: Find a Technical Buyer role | `Example_Billing_State_In_Contacts` | `Example_Account_Check_Builder_Guide` | `QUERY` | Yes |
| Example: Channel Partner Governance | `Example_Channel_Partner_Governance` | `Example_Account_Relationship_Risk` | `QUERY` | Yes |
| Example: Opportunity Product coverage | `Example_Contact_Cities_Exact_Parent` | `Example_Account_Check_Builder_Guide` | `COMPARE_TWO_QUERIES` | Yes |
| Example: Sales and service Contacts | `Example_Contact_Cities_Overlap_Parent` | `Example_Account_Check_Builder_Guide` | `COMPARE_TWO_QUERIES` | Yes |
| Example: Contact Readiness - Account | `Example_Contact_RR_Account` | `Example_Contact_Relationship_Readiness` | `FORMULA` | Yes |
| Example: Contact Readiness - Email | `Example_Contact_RR_Email` | `Example_Contact_Relationship_Readiness` | `QUERY` | Yes |
| Example: Contact Readiness - City | `Example_Contact_RR_Mailing_City` | `Example_Contact_Relationship_Readiness` | `FORMULA` | Yes |
| Example: Contact - Active Owner | `Example_Contact_RR_Owner_Active` | `Example_Contact_Relationship_Readiness` | `QUERY` | Yes |
| Example: Contact reporting line | `Example_Contact_RR_Phone` | `Example_Contact_Relationship_Readiness` | `FORMULA` | Yes |
| Example: Contact - Email or Phone | `Example_Contact_RR_Reachable_Channel` | `Example_Contact_Relationship_Readiness` | `FORMULA` | Yes |
| Example: Contact - Recent Engagement | `Example_Contact_RR_Recent_Engagement` | `Example_Contact_Relationship_Readiness` | `QUERY` | Yes |
| Example: Contact Readiness - Title | `Example_Contact_RR_Title` | `Example_Contact_Relationship_Readiness` | `FORMULA` | Yes |
| Example: Contact details on open deals | `Example_Contact_States_Match_Billing` | `Example_Account_Check_Builder_Guide` | `QUERY` | Yes |
| Example: Proposal Next Steps | `Example_Contact_Vs_Open_Opp_Count` | `Example_Account_Check_Builder_Guide` | `COMPARE_TWO_QUERIES` | Yes |
| Example: Cases closed vs created | `Example_Contacts_Cover_Open_Cases` | `Example_Account_Check_Builder_Guide` | `QUERY` | Yes |
| Example: Contacts Have Email Addresses | `Example_Contacts_Have_Email` | `Example_Account_Relationship_Risk` | `QUERY` | Yes |
| Example: Customer Engagement Is Current | `Example_Customer_Engagement_Current` | `Example_Account_Relationship_Risk` | `APEX` | Yes |
| Example: Open Opportunity Close Dates | `Example_Distinct_Cities_Vs_Contacts` | `Example_Account_Check_Builder_Guide` | `COMPARE_TWO_QUERIES` | Yes |
| Example: Won Opportunity primary roles | `Example_Earliest_Vs_Latest_Close` | `Example_Account_Check_Builder_Guide` | `COMPARE_TWO_QUERIES` | Yes |
| Example: Executive Sponsorship | `Example_Executive_Sponsorship` | `Example_Account_Relationship_Risk` | `QUERY` | Yes |
| Example: High-priority Case count | `Example_Fewer_Than_Ten_Open_Cases` | `Example_Account_Check_Builder_Guide` | `QUERY` | Yes |
| Example: Escalated Case descriptions | `Example_Guide_Contacts_Have_Email` | `Example_Account_Check_Builder_Guide` | `QUERY` | Yes |
| Example: Parent bill-to alignment | `Example_Guide_Industry_Manufacturing` | `Example_Account_Check_Builder_Guide` | `FORMULA` | Yes |
| Example: Proposal Campaigns | `Example_Guide_Open_Deals_Have_Contacts` | `Example_Account_Check_Builder_Guide` | `COMPARE_TWO_QUERIES` | Yes |
| Example: Verified engagement cadence | `Example_Guide_Recent_Activity` | `Example_Account_Check_Builder_Guide` | `APEX` | Yes |
| Example: Decision Maker roles | `Example_Has_At_Least_One_Contact` | `Example_Account_Check_Builder_Guide` | `QUERY` | Yes |
| Example: Active Opportunity owners | `Example_High_Value_Open_Opp` | `Example_Account_Check_Builder_Guide` | `QUERY` | Yes |
| Example: Industry Aligns With Parent | `Example_Industry_Aligns_With_Parent` | `Example_Account_Relationship_Risk` | `FORMULA` | No |
| Example: No High-Priority Issues | `Example_No_High_Priority_Issues` | `Example_Account_Relationship_Risk` | `QUERY` | Yes |
| Example: Open Opportunity Contact Roles | `Example_Oldest_Contact_City_Matches` | `Example_Account_Check_Builder_Guide` | `COMPARE_TWO_QUERIES` | Yes |
| Example: Open Case Contacts | `Example_Open_Cases_Have_Contacts` | `Example_Account_Check_Builder_Guide` | `QUERY` | Yes |
| Example: Open Deals Have Contacts | `Example_Open_Deals_Have_Contacts` | `Example_Account_Relationship_Risk` | `COMPARE_TWO_QUERIES` | Yes |
| Example: Proposal Amount exceptions | `Example_Open_Opps_Have_Amount` | `Example_Account_Check_Builder_Guide` | `QUERY` | Yes |
| Example: New pipeline vs lost value | `Example_Open_Pipeline_Covers_Revenue` | `Example_Account_Check_Builder_Guide` | `COMPARE_TWO_QUERIES` | Yes |
| Example: Deal Readiness - Account | `Example_Opportunity_DR_Account` | `Example_Opportunity_Deal_Readiness` | `FORMULA` | Yes |
| Example: Deal Readiness - Amount | `Example_Opportunity_DR_Amount` | `Example_Opportunity_Deal_Readiness` | `FORMULA` | Yes |
| Example: Deal Readiness - Buyer Contact | `Example_Opportunity_DR_Buyer_Contact` | `Example_Opportunity_Deal_Readiness` | `QUERY` | Yes |
| Example: Deal Readiness - Close Date | `Example_Opportunity_DR_Close_Date` | `Example_Opportunity_Deal_Readiness` | `FORMULA` | Yes |
| Example: Deal Readiness - Next Step | `Example_Opportunity_DR_Next_Step` | `Example_Opportunity_Deal_Readiness` | `FORMULA` | Yes |
| Example: Deal Readiness - Active Owner | `Example_Opportunity_DR_Owner_Active` | `Example_Opportunity_Deal_Readiness` | `QUERY` | Yes |
| Example: Deal Readiness - Probability | `Example_Opportunity_DR_Probability` | `Example_Opportunity_Deal_Readiness` | `FORMULA` | Yes |
| Example: Deal - Recent Activity | `Example_Opportunity_DR_Recent_Activity` | `Example_Opportunity_Deal_Readiness` | `QUERY` | Yes |
| Example: Won Opportunity Amounts | `Example_Parent_Cities_Require_Data` | `Example_Account_Check_Builder_Guide` | `COMPARE_TWO_QUERIES` | Yes |
| Example: Priority Case Contact coverage | `Example_Parent_Covers_Contact_Cities` | `Example_Account_Check_Builder_Guide` | `COMPARE_TWO_QUERIES` | Yes |
| Example: Pipeline Protects Revenue | `Example_Pipeline_Protects_Revenue` | `Example_Account_Relationship_Risk` | `QUERY` | Yes |
| Example: Account Phone or Website | `Example_Segregation_Of_Duties` | `Example_Account_Check_Builder_Guide` | `FORMULA` | Yes |
| Example: Commit Opportunity count | `Example_Significant_Open_Opp` | `Example_Account_Check_Builder_Guide` | `QUERY` | Yes |
| Example: Account Type is set | `Example_Website_URL_Valid` | `Example_Account_Check_Builder_Guide` | `FORMULA` | Yes |

## Public Apex request and execution options

| Apex type | Global methods |
| --- | --- |
| `RecordHealthCheckRequest` | `forCheck()`, `forCheckSet()`, `withDiagnosticContractVersion()`, `withEventPublication()`, `withExecutionOrigin()`, `withResultMode()`, `withRunId()` |
| `RecordHealthCheckOptions` | `defaults()`, `withDiagnosticContractVersion()`, `withEventPublication()`, `withExecutionOrigin()`, `withResultMode()`, `withRunId()` |
| `RecordHealthCheckPreviewRequest` | `forDraftCheck()`, `withMode()`, `withReadinessReceipt()` |
| `RecordHealthCheckPreviewService` | `deleteExpiredReadinessReceipts()`, `preview()` |
| `RecordHealthCheckQueueable` | `enqueue()`, `execute()` |
| `RecordHealthCheckBatch` | `execute()`, `finish()`, `run()`, `start()` |
| `RecordHealthCheckScheduled` | `execute()`, `scheduleDaily()` |

## Global Apex types (60)

These are the namespace-visible Apex types shipped by the package. A blank method cell means the type is a DTO, enum, exception, or marker whose public contract is its fields, values, inheritance, or interface declaration.

| Apex type | Kind | Global methods declared in source |
| --- | --- | --- |
| `AccountHasRecentActivityCheck` | class | `evaluate()`, `getDefinition()`, `getDisplay()` |
| `RecordHealthCheck` | class | `evaluate()` |
| `RecordHealthCheckAdminDetail` | class | Not applicable |
| `RecordHealthCheckAgentRestResource` | class | `doPost()` |
| `RecordHealthCheckBatch` | class | `execute()`, `finish()`, `run()`, `start()` |
| `RecordHealthCheckContractHarnessTest` | class | `createScope()`, `evaluate()`, `newCheck()`, `testData()` |
| `RecordHealthCheckContractTest` | abstract class | `hasPermissionEvidence()`, `hasStableQueryGrowth()`, `newCheck()`, `testData()`, `verifyContract()` |
| `RecordHealthCheckContractTestData` | abstract class | `createScope()`, `permissionFixture()` |
| `RecordHealthCheckDiagnosticAction` | class | Not applicable |
| `RecordHealthCheckDiagnosticEnvelope` | class | Not applicable |
| `RecordHealthCheckDiagnosticErrorDetail` | class | Not applicable |
| `RecordHealthCheckDiagnosticIncident` | class | Not applicable |
| `RecordHealthCheckDiagnosticResponse` | class | Not applicable |
| `RecordHealthCheckDiagnosticTraceEntry` | class | Not applicable |
| `RecordHealthCheckDisplayAction` | class | Not applicable |
| `RecordHealthCheckDisplayContent` | class | Not applicable |
| `RecordHealthCheckDisplayGroup` | class | `withEmptyState()`, `withItems()`, `withLabel()`, `withSeparator()` |
| `RecordHealthCheckDisplayNode` | class | Not applicable |
| `RecordHealthCheckDisplayOverride` | class | `withAction()`, `withExpected()`, `withExpectedFormat()`, `withExpectedLabel()`, `withFix()`, `withFound()`, `withFoundFormat()`, `withMessage()` |
| `RecordHealthCheckDisplayPlugin` | interface | Not applicable |
| `RecordHealthCheckDisplayText` | class | `groups()`, `isEmpty()`, `lineBreak()`, `link()`, `paragraphBreak()`, `recordLinks()`, `text()` |
| `RecordHealthCheckEvaluationResult` | class | Not applicable |
| `RecordHealthCheckEventPublication` | enum | Not applicable |
| `RecordHealthCheckEvidence` | class | `column()`, `groupBy()`, `row()` |
| `RecordHealthCheckEvidenceCell` | class | `field()`, `value()` |
| `RecordHealthCheckEvidenceColumn` | class | Not applicable |
| `RecordHealthCheckEvidenceEnvelope` | class | Not applicable |
| `RecordHealthCheckExecutionOrigin` | enum | Not applicable |
| `RecordHealthCheckOptions` | class | `defaults()`, `withDiagnosticContractVersion()`, `withEventPublication()`, `withExecutionOrigin()`, `withResultMode()`, `withRunId()` |
| `RecordHealthCheckOutcome` | class | `error()`, `fail()`, `failEquals()`, `itemsFound()`, `noneFound()`, `pass()`, `passEquals()`, `skipped()`, `tryEvaluate()`, `unableToEvaluate()`, `withComparison()`, `withEvidence()`, `withExpected()`, `withFound()` |
| `RecordHealthCheckOutcomeBuilderException` | class | Not applicable |
| `RecordHealthCheckPlugin` | interface | Not applicable |
| `RecordHealthCheckPluginDefinition` | class | `booleanParameter()`, `capacity()`, `choiceParameter()`, `describe()`, `integerParameter()`, `nullable()`, `required()`, `stringParameter()` |
| `RecordHealthCheckPluginDefinitionSource` | interface | Not applicable |
| `RecordHealthCheckPluginTest` | class | `verify()` |
| `RecordHealthCheckPluginVerification` | class | `assertComplete()`, `assertNoSideEffects()`, `assertRenderable()` |
| `RecordHealthCheckPreviewFinding` | class | Not applicable |
| `RecordHealthCheckPreviewParameter` | class | Not applicable |
| `RecordHealthCheckPreviewRequest` | class | `forDraftCheck()`, `withMode()`, `withReadinessReceipt()` |
| `RecordHealthCheckPreviewResponse` | class | Not applicable |
| `RecordHealthCheckPreviewService` | class | `deleteExpiredReadinessReceipts()`, `preview()` |
| `RecordHealthCheckQueueable` | class | `enqueue()`, `execute()` |
| `RecordHealthCheckReadinessReceipt` | class | Not applicable |
| `RecordHealthCheckRecordEvaluator` | interface | Not applicable |
| `RecordHealthCheckRequest` | class | `forCheck()`, `forCheckSet()`, `withDiagnosticContractVersion()`, `withEventPublication()`, `withExecutionOrigin()`, `withResultMode()`, `withRunId()` |
| `RecordHealthCheckResponse` | class | `diagnostics()` |
| `RecordHealthCheckResultDisplay` | class | Not applicable |
| `RecordHealthCheckResultItem` | class | Not applicable |
| `RecordHealthCheckResultMode` | enum | Not applicable |
| `RecordHealthCheckRunCheckAgentAction` | class | `runCheck()` |
| `RecordHealthCheckRunCheckFlowAction` | class | `runCheck()` |
| `RecordHealthCheckRunSetAgentAction` | class | `runSet()` |
| `RecordHealthCheckRunSetFlowAction` | class | `runSet()` |
| `RecordHealthCheckRunSummary` | class | `add()`, `total()` |
| `RecordHealthCheckScheduled` | class | `execute()`, `scheduleDaily()` |
| `RecordHealthCheckScope` | class | `recordIdAt()`, `size()` |
| `RecordHealthCheckSelection` | class | `forCheck()`, `forCheckSet()` |
| `RecordHealthCheckStatus` | abstract class | `isActionable()` |
| `RecordHealthCheckValidateMetadataAction` | class | `validateConfiguration()` |
| `RecordHealthCheckValue` | class | `isList()`, `ofBoolean()`, `ofCount()`, `ofDate()`, `ofDateTime()`, `ofId()`, `ofList()`, `ofNumber()`, `ofString()` |

## External Apex entry classes (13)

- `RecordHealthCheck`
- `RecordHealthCheckAgentRestResource`
- `RecordHealthCheckBatch`
- `RecordHealthCheckController`
- `RecordHealthCheckPreviewController`
- `RecordHealthCheckQueueable`
- `RecordHealthCheckRunCheckAgentAction`
- `RecordHealthCheckRunCheckFlowAction`
- `RecordHealthCheckRunSetAgentAction`
- `RecordHealthCheckRunSetFlowAction`
- `RecordHealthCheckScheduled`
- `RecordHealthCheckSetPicklist`
- `RecordHealthCheckValidateMetadataAction`

## Related

- [Feature catalog](./feature-catalog.md)
- [Permission Sets](./permission-sets.md)
- [Flow action inputs and outputs](../flow-guides/action-inputs-and-outputs.md)
- [Run from Apex](../developer-guides/run-from-apex.md)
