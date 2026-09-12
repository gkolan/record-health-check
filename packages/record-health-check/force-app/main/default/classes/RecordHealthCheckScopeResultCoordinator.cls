/** Maps planning failures and Check results, then finalizes the scope response. */
public with sharing class RecordHealthCheckScopeResultCoordinator {
  private RecordHealthCheckScopeResultSupport resultSupport;
  private RecordHealthCheckScopePipeline.SelectionContext context;
  private String runId;
  private RecordHealthCheckResultMode resultMode;
  private RecordHealthCheckFormulaPlanService.Finding primaryFormulaFinding;
  private Map<Id, RecordHealthCheckExecutionTrace> traces;

  public RecordHealthCheckScopeResultCoordinator(
    RecordHealthCheckScopeResultSupport resultSupport,
    RecordHealthCheckScopePipeline.SelectionContext context,
    String runId,
    RecordHealthCheckResultMode resultMode,
    RecordHealthCheckFormulaPlanService.Finding primaryFormulaFinding,
    Map<Id, RecordHealthCheckExecutionTrace> traces
  ) {
    this.resultSupport = resultSupport;
    this.context = context;
    this.runId = runId;
    this.resultMode = resultMode;
    this.primaryFormulaFinding = primaryFormulaFinding;
    this.traces = traces;
  }

  public void finish(
    Record_Health_Check__mdt check,
    List<Id> recordIds,
    Map<Id, SObject> recordsById,
    Map<Id, RecordHealthCheckInternalResult> internalByRecordId,
    Map<String, RecordHealthCheckResultItem> itemsByIdentity
  ) {
    for (Id recordId : recordIds) {
      RecordHealthCheckInternalResult internalResult = internalByRecordId.get(
        recordId
      );
      if (
        internalResult != null &&
        check.EvaluationType__c == 'APEX' &&
        internalResult.pluginInvoked == null
      ) {
        internalResult.pluginInvoked = false;
      }
      RecordHealthCheckDiagnosticContext diagnostic = RecordHealthCheckDiagContextSupport.forResult(
        check,
        context.checkSetQualifiedApiName,
        runId,
        internalResult?.reasonCode,
        primaryFormulaFinding
      );
      if (String.isNotBlank(internalResult?.reasonOrigin)) {
        diagnostic.reasonOrigin = internalResult.reasonOrigin;
      }
      diagnostic.priorReasonCode = internalResult?.priorReasonCode;
      if (internalResult?.pluginInvoked != null) {
        diagnostic.pluginInvoked = internalResult.pluginInvoked;
      }
      RecordHealthCheckIncidentRecorder.attachResultFailure(
        check,
        recordId,
        diagnostic,
        internalResult
      );
      internalResult.executionTrace = traces.get(recordId);
      traces.get(recordId)?.begin('DISPLAY_RENDER');
      resultSupport.finalizeDisplay(
        check,
        recordsById.get(recordId),
        internalResult,
        context.showDiagnostics == true &&
          resultMode == RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY,
        resultMode == RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY,
        recordsById
      );
      traces.get(recordId)?.complete('DISPLAY_RENDERED');
      itemsByIdentity.put(
        RecordHealthCheckScopeRuntime.itemKey(recordId, check.QualifiedApiName),
        resultSupport.toItem(check, recordId, internalResult, resultMode)
      );
    }
  }

  /** Adds one visibility-safe unavailable result for each selected record. */
  public static void addUnavailableResults(
    RecordHealthCheckScopeResultSupport resultSupport,
    Record_Health_Check__mdt check,
    List<Id> recordIds,
    Map<Id, SObject> recordsById,
    String reasonCode,
    Map<Id, RecordHealthCheckInternalResult> internalByRecordId
  ) {
    for (Id recordId : recordIds) {
      internalByRecordId.put(
        recordId,
        recordsById.containsKey(recordId)
          ? resultSupport.unavailableResult(check, reasonCode)
          : resultSupport.unavailableResult(check, 'RECORD_NOT_VISIBLE')
      );
    }
  }

  /** Projects complete scope results and applies the response finalizer. */
  public static RecordHealthCheckResponse finishResponse(
    RecordHealthCheckRequest request,
    RecordHealthCheckResponse response,
    List<Id> recordIds,
    RecordHealthCheckScopePipeline.SelectionContext context,
    Map<String, RecordHealthCheckResultItem> itemsByIdentity
  ) {
    List<RecordHealthCheckResultItem> allItems = new List<RecordHealthCheckResultItem>();
    for (Id recordId : recordIds) {
      for (Record_Health_Check__mdt check : context.checks) {
        RecordHealthCheckResultItem item = itemsByIdentity.get(
          RecordHealthCheckScopeRuntime.itemKey(
            recordId,
            check.QualifiedApiName
          )
        );
        allItems.add(item);
        response.summary.add(item.evaluation.status);
        if (
          request.options.resultMode != RecordHealthCheckResultMode.SUMMARY ||
          RecordHealthCheckStatus.isActionable(item.evaluation.status)
        ) {
          response.results.add(item);
        }
      }
    }
    RecordHealthCheckResponseFinalizer.finish(
      response,
      allItems,
      request.options,
      context
    );
    return response;
  }

  /** Preserves configuration and planning-failure precedence before applicability. */
  public static void addPlanningFailures(
    RecordHealthCheckScopeResultSupport resultSupport,
    Record_Health_Check__mdt check,
    List<Id> recordIds,
    Map<Id, SObject> recordsById,
    RecordHealthCheckInternalResult invalidConfiguration,
    Boolean formulaPlanningIncomplete,
    String unresolvedReasonCode,
    Boolean fieldAccessDenied,
    Map<Id, RecordHealthCheckInternalResult> internalByRecordId
  ) {
    if (invalidConfiguration != null) {
      RecordHealthCheckConfigValidator.discardValidatedPlugin(check);
      for (Id recordId : recordIds) {
        internalByRecordId.put(
          recordId,
          resultSupport.copyResult(invalidConfiguration)
        );
      }
    }
    if (invalidConfiguration == null && formulaPlanningIncomplete) {
      RecordHealthCheckScopeResultCoordinator.addUnavailableResults(
        resultSupport,
        check,
        recordIds,
        recordsById,
        RecordHealthCheckReasonCodes.FORMULA_DEPENDENCY_DEPTH_EXCEEDED,
        internalByRecordId
      );
    }
    if (
      invalidConfiguration == null &&
      !formulaPlanningIncomplete &&
      unresolvedReasonCode != null
    ) {
      RecordHealthCheckScopeResultCoordinator.addUnavailableResults(
        resultSupport,
        check,
        recordIds,
        recordsById,
        unresolvedReasonCode,
        internalByRecordId
      );
    }
    if (
      invalidConfiguration == null &&
      !formulaPlanningIncomplete &&
      unresolvedReasonCode == null &&
      fieldAccessDenied
    ) {
      RecordHealthCheckScopeResultCoordinator.addUnavailableResults(
        resultSupport,
        check,
        recordIds,
        recordsById,
        RecordHealthCheckReasonCodes.FIELD_NOT_ACCESSIBLE,
        internalByRecordId
      );
    }
    if (
      invalidConfiguration != null ||
      formulaPlanningIncomplete ||
      unresolvedReasonCode != null ||
      fieldAccessDenied
    ) {
      for (
        RecordHealthCheckInternalResult result : internalByRecordId.values()
      ) {
        result.displayPlanningFailed = true;
      }
    }
  }
}
