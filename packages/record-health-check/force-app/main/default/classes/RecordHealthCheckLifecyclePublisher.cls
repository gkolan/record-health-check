/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** Best-effort, optional lifecycle publication for deliberately initiated runs. */
public with sharing class RecordHealthCheckLifecyclePublisher {
  public static final String CONTRACT_VERSION = '1.0';
  public static final String FRAMEWORK_VERSION = '2.0.5';
  public static final String SOURCE_APEX_API = 'APEX_API';
  public static final String SOURCE_FLOW = 'FLOW';
  public static final String SOURCE_USER_INITIATED = 'USER_INITIATED';
  public static final String SOURCE_SCHEDULED = 'SCHEDULED';
  public static final String SOURCE_BATCH = 'BATCH';
  public static final String SOURCE_QUEUEABLE = 'QUEUEABLE';
  public static final String SOURCE_FUTURE = 'FUTURE';
  public static final String SOURCE_RUN_ON_LOAD = 'RUN_ON_LOAD';
  public static final String SOURCE_AGENT = 'AGENT';
  public static final Integer PUBLISH_CHUNK_SIZE = 100;

  @TestVisible
  private static RecordHealthCheckSettingsProvider settingsProvider = new RecordHealthCheckSettingsProvider();
  private static Boolean inSubscriberContext = false;

  /** Publishes a response according to caller intent, never metadata. */
  public static void publishResponse(
    RecordHealthCheckResponse response,
    RecordHealthCheckEventPublication publication,
    String checkSetQualifiedApiName,
    String source
  ) {
    publishResponseInternal(
      response,
      publication,
      checkSetQualifiedApiName,
      source,
      true
    );
  }

  /** Applies administrator publication choices only to a user-pressed LWC run. */
  public static void publishInteractiveResponse(
    RecordHealthCheckResponse response,
    String checkSetQualifiedApiName,
    String source
  ) {
    if (
      response == null ||
      source != SOURCE_USER_INITIATED ||
      inSubscriberContext
    ) {
      return;
    }
    Boolean publishSet = isRunPublicationEnabled(checkSetQualifiedApiName);
    Set<String> enabledChecks = settingsProvider.publishedCheckNames(
      checkSetQualifiedApiName
    );
    RecordHealthCheckResponse filtered = new RecordHealthCheckResponse();
    filtered.runId = response.runId;
    filtered.recordIds.addAll(response.recordIds);
    filtered.checkQualifiedApiNames.addAll(response.checkQualifiedApiNames);
    filtered.summary = response.summary;
    for (RecordHealthCheckResultItem item : response.results) {
      if (
        item != null &&
        item.evaluation != null &&
        String.isNotBlank(item.evaluation.checkQualifiedApiName) &&
        (enabledChecks.contains(item.evaluation.checkQualifiedApiName) ||
        enabledChecks.contains(
          item.evaluation.checkQualifiedApiName.substringAfter('__')
        ))
      ) {
        filtered.results.add(item);
      }
    }
    publishResponseInternal(
      filtered,
      RecordHealthCheckEventPublication.ALL,
      checkSetQualifiedApiName,
      source,
      false
    );
    if (publishSet) {
      publishSetEvents(
        buildSetEvents(response, checkSetQualifiedApiName, source)
      );
    }
  }

  private static void publishResponseInternal(
    RecordHealthCheckResponse response,
    RecordHealthCheckEventPublication publication,
    String checkSetQualifiedApiName,
    String source,
    Boolean publishSet
  ) {
    if (
      response == null ||
      response.summary == null ||
      publication == null ||
      publication == RecordHealthCheckEventPublication.NONE ||
      inSubscriberContext
    ) {
      return;
    }

    List<RecordHealthCheckResultItem> selected = new List<RecordHealthCheckResultItem>();
    for (RecordHealthCheckResultItem item : response.results) {
      if (
        item == null ||
        item.evaluation == null ||
        (publication == RecordHealthCheckEventPublication.ACTIONABLE &&
        !RecordHealthCheckStatus.isActionable(item.evaluation.status))
      ) {
        continue;
      }
      selected.add(item);
    }
    List<Record_Health_Check_Result__e> checkEvents = new List<Record_Health_Check_Result__e>();
    for (RecordHealthCheckResultItem item : selected) {
      RecordHealthCheckEvaluationResult evaluation = item.evaluation;
      checkEvents.add(
        new Record_Health_Check_Result__e(
          ContractVersion__c = CONTRACT_VERSION,
          EventId__c = RecordHealthCheckEventId.newId(
            response.runId,
            evaluation.checkQualifiedApiName + '-' + evaluation.recordId
          ),
          RunId__c = response.runId,
          CheckSetQualifiedApiName__c = checkSetQualifiedApiName,
          CheckQualifiedApiName__c = evaluation.checkQualifiedApiName,
          Status__c = evaluation.status,
          ReasonCode__c = evaluation.reasonCode,
          Severity__c = evaluation.severity,
          OccurredAt__c = System.now(),
          Source__c = source,
          FrameworkVersion__c = FRAMEWORK_VERSION,
          ContainsRestrictedDetail__c = false,
          RecordId__c = evaluation.recordId == null
            ? null
            : String.valueOf(evaluation.recordId)
        )
      );
    }
    publishCheckEvents(checkEvents);

    if (publishSet != true) {
      return;
    }
    publishSetEvents(
      buildSetEvents(response, checkSetQualifiedApiName, source)
    );
  }

  public static Boolean isRunPublicationEnabled(
    String checkSetQualifiedApiName
  ) {
    return settingsProvider.isRunPublicationEnabled(checkSetQualifiedApiName);
  }

  /** Publishes one terminal envelope for an asynchronous adapter job. */
  public static void publishAsyncJobTerminal(
    String runId,
    String checkSetQualifiedApiName,
    String source,
    RecordHealthCheckEventPublication publication,
    Boolean succeeded,
    Integer submittedRecordCount,
    Integer processedRecordCount
  ) {
    if (
      publication == null ||
      publication == RecordHealthCheckEventPublication.NONE ||
      inSubscriberContext
    ) {
      return;
    }
    publishSetEvents(
      new List<Record_Health_Check_Set_Run__e>{
        new Record_Health_Check_Set_Run__e(
          ContractVersion__c = CONTRACT_VERSION,
          EventId__c = RecordHealthCheckEventId.newId(runId, 'JOB-TERMINAL'),
          RunId__c = runId,
          Phase__c = succeeded == true ? 'COMPLETED' : 'FAILED',
          CheckSetQualifiedApiName__c = checkSetQualifiedApiName,
          OccurredAt__c = System.now(),
          Source__c = source,
          FrameworkVersion__c = FRAMEWORK_VERSION,
          SubmittedRecordCount__c = submittedRecordCount,
          ProcessedRecordCount__c = processedRecordCount
        )
      }
    );
  }

  /** Prevents event subscribers from recursively publishing lifecycle events. */
  public static void enterSubscriberContext() {
    inSubscriberContext = true;
  }

  private static List<Record_Health_Check_Set_Run__e> buildSetEvents(
    RecordHealthCheckResponse response,
    String checkSetQualifiedApiName,
    String source
  ) {
    Map<Id, RecordHealthCheckRunSummary> summariesByRecord = new Map<Id, RecordHealthCheckRunSummary>();
    for (Id recordId : response.recordIds) {
      summariesByRecord.put(recordId, new RecordHealthCheckRunSummary());
    }
    for (RecordHealthCheckResultItem item : response.results) {
      Id recordId = item?.evaluation?.recordId;
      if (recordId != null && summariesByRecord.containsKey(recordId)) {
        summariesByRecord.get(recordId).add(item.evaluation.status);
      }
    }
    List<Record_Health_Check_Set_Run__e> events = new List<Record_Health_Check_Set_Run__e>();
    for (Id recordId : response.recordIds) {
      RecordHealthCheckRunSummary summary = summariesByRecord.get(recordId);
      events.add(
        new Record_Health_Check_Set_Run__e(
          ContractVersion__c = CONTRACT_VERSION,
          EventId__c = RecordHealthCheckEventId.newId(
            response.runId,
            'SET-' + recordId
          ),
          RunId__c = response.runId,
          Phase__c = 'COMPLETED',
          CheckSetQualifiedApiName__c = checkSetQualifiedApiName,
          OccurredAt__c = System.now(),
          Source__c = source,
          FrameworkVersion__c = FRAMEWORK_VERSION,
          EligibleCheckCount__c = response.checkQualifiedApiNames.size(),
          EvaluatedCheckCount__c = summary.total(),
          PassedCount__c = summary.passed,
          FailedCount__c = summary.failed,
          SkippedCount__c = summary.skipped,
          UnableCount__c = summary.unable,
          SystemErrorCount__c = summary.systemError,
          RecordId__c = String.valueOf(recordId)
        )
      );
    }
    return events;
  }

  private static void publishSetEvents(
    List<Record_Health_Check_Set_Run__e> events
  ) {
    for (
      Integer start = 0; start < events.size(); start += PUBLISH_CHUNK_SIZE
    ) {
      Integer finish = Math.min(start + PUBLISH_CHUNK_SIZE, events.size());
      List<Record_Health_Check_Set_Run__e> chunk = new List<Record_Health_Check_Set_Run__e>();
      for (Integer index = start; index < finish; index++) {
        chunk.add(events[index]);
      }
      inspect(EventBus.publish(chunk), 'SET_RUN_PUBLISH_FAILED');
    }
  }

  @TestVisible
  private static void publishCheckEvents(
    List<Record_Health_Check_Result__e> events
  ) {
    for (
      Integer start = 0; start < events.size(); start += PUBLISH_CHUNK_SIZE
    ) {
      Integer finish = Math.min(start + PUBLISH_CHUNK_SIZE, events.size());
      List<Record_Health_Check_Result__e> chunk = new List<Record_Health_Check_Result__e>();
      for (Integer index = start; index < finish; index++) {
        chunk.add(events[index]);
      }
      inspect(EventBus.publish(chunk), 'CHECK_RESULT_PUBLISH_FAILED');
    }
  }

  @TestVisible
  private static void inspect(
    List<Database.SaveResult> saveResults,
    String logCode
  ) {
    if (saveResults == null) {
      return;
    }
    for (Database.SaveResult saveResult : saveResults) {
      if (saveResult.isSuccess()) {
        continue;
      }
      RecordHealthCheckLogger.log(
        RecordHealthCheckLogger.Level.WARN,
        null,
        null,
        null,
        null,
        logCode,
        new Map<String, Object>{
          'errorCount' => saveResult.getErrors().size()
        },
        null
      );
    }
  }
}
