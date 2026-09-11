/** Attaches diagnostics, renders display, and maps one Check's scope results. */
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
        resultMode == RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY &&
        (context.executionOrigin == 'USER_INITIATED' ||
        context.executionOrigin == 'RUN_ON_LOAD')
      );
      traces.get(recordId)?.complete('DISPLAY_RENDERED');
      itemsByIdentity.put(
        RecordHealthCheckScopeRuntime.itemKey(recordId, check.QualifiedApiName),
        resultSupport.toItem(check, recordId, internalResult, resultMode)
      );
    }
  }
}
