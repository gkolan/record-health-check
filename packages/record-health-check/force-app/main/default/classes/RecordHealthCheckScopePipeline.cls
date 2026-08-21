/**
 * Scope-based execution pipeline for the public request contract.
 */
public with sharing class RecordHealthCheckScopePipeline {
  private RecordHealthCheckEvaluatorRegistry evaluatorRegistry = new RecordHealthCheckEvaluatorRegistry();
  private RecordHealthCheckConfigService configService = new RecordHealthCheckConfigService();
  private RecordHealthCheckScopePlanner scopePlanner = new RecordHealthCheckScopePlanner();
  private RecordHealthCheckScopeResultSupport resultSupport = new RecordHealthCheckScopeResultSupport();
  @TestVisible
  private Boolean planningFailureOverride = false;
  @TestVisible
  private static String evaluatorFailureOverride;

  /**
   * @param request Immutable qualified selection, record IDs, and options.
   * @return Ordered response with one item per record and selected Check.
   */
  public RecordHealthCheckResponse evaluate(RecordHealthCheckRequest request) {
    if (request == null) {
      throw new ScopePipelineException(
        'A Record Health Check request is required.'
      );
    }

    Integer suppliedCount = request.recordIds.size();
    if (suppliedCount > RecordHealthCheckConstants.MAX_RECORDS_PER_SCOPE) {
      throw new ScopePipelineException(
        'MAX_RECORDS_PER_SCOPE_EXCEEDED: suppliedCount=' +
          suppliedCount +
          ', ceiling=' +
          RecordHealthCheckConstants.MAX_RECORDS_PER_SCOPE
      );
    }
    List<Id> recordIds = dedupeRecordIds(request.recordIds);

    SelectionContext context = scopePlanner.resolveSelection(request.selection);
    scopePlanner.validateScope(context, recordIds);
    scopePlanner.enforceFormulaBudget(context.checks, recordIds.size());
    scopePlanner.enforceTransactionBudget(
      context.checks,
      recordIds.size(),
      request.options.eventPublication
    );

    RecordHealthCheckResponse response = new RecordHealthCheckResponse();
    response.runId = String.isBlank(request.options.runId)
      ? newRunId()
      : request.options.runId;
    context.executionOrigin = String.valueOf(request.options.executionOrigin);
    response.recordIds.addAll(recordIds);
    for (Record_Health_Check__mdt check : context.checks) {
      response.checkQualifiedApiNames.add(check.QualifiedApiName);
    }
    if (recordIds.isEmpty() || context.checks.isEmpty()) {
      return response;
    }

    RecordLoadPlan recordLoad = loadRecords(
      context.objectApiName,
      recordIds,
      context.checks
    );
    Map<Id, SObject> recordsById = recordLoad.recordsById;
    Map<String, RecordHealthCheckResultItem> itemsByIdentity = new Map<String, RecordHealthCheckResultItem>();
    for (Record_Health_Check__mdt check : context.checks) {
      evaluateCheck(
        check,
        context,
        recordIds,
        recordsById,
        recordLoad.inaccessibleCheckNames.contains(check.QualifiedApiName),
        recordLoad.unresolvedReasonCodeByCheckName.get(check.QualifiedApiName),
        recordLoad.incompletePlanningCheckNames.contains(
          check.QualifiedApiName
        ),
        request.options.resultMode,
        response.runId,
        itemsByIdentity
      );
    }

    List<RecordHealthCheckResultItem> allItems = new List<RecordHealthCheckResultItem>();
    for (Id recordId : recordIds) {
      for (Record_Health_Check__mdt check : context.checks) {
        RecordHealthCheckResultItem item = itemsByIdentity.get(
          itemKey(recordId, check.QualifiedApiName)
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
    RecordHealthCheckResponse publicationEnvelope = new RecordHealthCheckResponse();
    publicationEnvelope.runId = response.runId;
    publicationEnvelope.recordIds.addAll(response.recordIds);
    publicationEnvelope.checkQualifiedApiNames.addAll(
      response.checkQualifiedApiNames
    );
    publicationEnvelope.results.addAll(allItems);
    publicationEnvelope.summary = response.summary;
    RecordHealthCheckLifecyclePublisher.publishResponse(
      publicationEnvelope,
      request.options.eventPublication,
      context.checkSetQualifiedApiName,
      String.valueOf(request.options.executionOrigin)
    );
    return response;
  }

  private RecordLoadPlan loadRecords(
    String objectApiName,
    List<Id> recordIds,
    List<Record_Health_Check__mdt> checks
  ) {
    return loadRecords(
      objectApiName,
      recordIds,
      checks,
      new RecordHealthCheckFieldPlanner()
    );
  }

  private RecordLoadPlan loadRecords(
    String objectApiName,
    List<Id> recordIds,
    List<Record_Health_Check__mdt> checks,
    RecordHealthCheckFieldPlanner fieldPlanner
  ) {
    Set<String> fields = new Set<String>{ 'Id' };
    RecordLoadPlan result = new RecordLoadPlan();
    Schema.SObjectType objectType = recordIds[0].getSObjectType();
    for (Record_Health_Check__mdt check : checks) {
      try {
        if (planningFailureOverride) {
          throw new RecordHealthCheckTemplateService.TemplateException(
            'Synthetic planning failure.'
          );
        }
        RecordHealthCheckFieldPlanner.FieldPlan fieldPlan = fieldPlanner.planRecordFields(
          check,
          objectType
        );
        if (!fieldPlan.inaccessibleFields.isEmpty()) {
          result.inaccessibleCheckNames.add(check.QualifiedApiName);
        }
        if (!fieldPlan.unresolvedReasonCodesByField.isEmpty()) {
          result.unresolvedReasonCodeByCheckName.put(
            check.QualifiedApiName,
            primaryUnresolvedReasonCode(fieldPlan.unresolvedReasonCodesByField)
          );
        }
        if (fieldPlan.verdictDependenciesTruncated) {
          result.incompletePlanningCheckNames.add(check.QualifiedApiName);
        }
        // Keep display and message fields even when verdict dependencies are
        // incomplete so the aligned UNABLE result can still be rendered.
        fields.addAll(fieldPlan.selectedFields);
      } catch (RecordHealthCheckTemplateService.TemplateException ex) {
        // Runtime validation turns this Check into INVALID_CONFIG. Planning must
        // skip its fields so one malformed admin template cannot abort the
        // complete scope before per-Check isolation begins.
        continue;
      }
    }
    List<String> orderedFields = new List<String>(fields);
    orderedFields.sort();
    String query =
      'SELECT ' +
      String.join(orderedFields, ', ') +
      ' FROM ' +
      objectApiName +
      ' WHERE Id IN :recordIds WITH USER_MODE';
    // code-analyzer-suppress-next-line ApexSOQLInjection: object and field identifiers are resolved from Schema describe metadata, recordIds is a bind variable, and the query runs WITH USER_MODE.
    List<SObject> records = Database.query(query);
    result.recordsById.putAll(new Map<Id, SObject>(records));
    return result;
  }

  @TestVisible
  private Map<Id, SObject> loadRecordsForTest(
    String objectApiName,
    List<Id> recordIds,
    List<Record_Health_Check__mdt> checks,
    RecordHealthCheckFieldPlanner fieldPlanner
  ) {
    return loadRecords(objectApiName, recordIds, checks, fieldPlanner)
      .recordsById;
  }

  @TestVisible
  private void evaluateCheck(
    Record_Health_Check__mdt check,
    SelectionContext context,
    List<Id> recordIds,
    Map<Id, SObject> recordsById,
    Boolean fieldAccessDenied,
    Boolean formulaPlanningIncomplete,
    RecordHealthCheckResultMode resultMode,
    String runId,
    Map<String, RecordHealthCheckResultItem> itemsByIdentity
  ) {
    evaluateCheck(
      check,
      context,
      recordIds,
      recordsById,
      fieldAccessDenied,
      null,
      formulaPlanningIncomplete,
      resultMode,
      runId,
      itemsByIdentity
    );
  }

  private void evaluateCheck(
    Record_Health_Check__mdt check,
    SelectionContext context,
    List<Id> recordIds,
    Map<Id, SObject> recordsById,
    Boolean fieldAccessDenied,
    String unresolvedReasonCode,
    Boolean formulaPlanningIncomplete,
    RecordHealthCheckResultMode resultMode,
    String runId,
    Map<String, RecordHealthCheckResultItem> itemsByIdentity
  ) {
    RecordHealthCheckRunContext runContext = new RecordHealthCheckRunContext(
      runId,
      context.executionOrigin
    );
    resultSupport.withRunContext(runContext);
    List<Id> applicableIds = new List<Id>();
    Map<Id, RecordHealthCheckInternalResult> internalByRecordId = new Map<Id, RecordHealthCheckInternalResult>();
    RecordHealthCheckInternalResult invalidConfiguration = configService.validateCheckForEvaluation(
      check
    );
    if (invalidConfiguration != null) {
      RecordHealthCheckConfigValidator.discardValidatedPlugin(
        check.ApexClass__c
      );
      for (Id recordId : recordIds) {
        internalByRecordId.put(
          recordId,
          resultSupport.copyResult(invalidConfiguration)
        );
      }
    }
    if (invalidConfiguration == null && formulaPlanningIncomplete) {
      for (Id recordId : recordIds) {
        internalByRecordId.put(
          recordId,
          recordsById.containsKey(recordId)
            ? resultSupport.unavailableResult(
                check,
                RecordHealthCheckReasonCodes.FORMULA_DEPENDENCY_DEPTH_EXCEEDED
              )
            : resultSupport.unavailableResult(check, 'RECORD_NOT_VISIBLE')
        );
      }
    }
    if (
      invalidConfiguration == null &&
      !formulaPlanningIncomplete &&
      unresolvedReasonCode != null
    ) {
      for (Id recordId : recordIds) {
        internalByRecordId.put(
          recordId,
          recordsById.containsKey(recordId)
            ? resultSupport.unavailableResult(check, unresolvedReasonCode)
            : resultSupport.unavailableResult(check, 'RECORD_NOT_VISIBLE')
        );
      }
    }
    if (
      invalidConfiguration == null &&
      !formulaPlanningIncomplete &&
      unresolvedReasonCode == null &&
      fieldAccessDenied
    ) {
      for (Id recordId : recordIds) {
        internalByRecordId.put(
          recordId,
          recordsById.containsKey(recordId)
            ? resultSupport.unavailableResult(
                check,
                RecordHealthCheckReasonCodes.FIELD_NOT_ACCESSIBLE
              )
            : resultSupport.unavailableResult(check, 'RECORD_NOT_VISIBLE')
        );
      }
    }
    Map<Id, RecordHealthCheckInternalResult> applicabilityByRecordId = invalidConfiguration ==
      null &&
      !formulaPlanningIncomplete &&
      unresolvedReasonCode == null &&
      !fieldAccessDenied
      ? resultSupport.applicabilityResults(check, recordIds, recordsById)
      : new Map<Id, RecordHealthCheckInternalResult>();
    for (Id recordId : recordIds) {
      if (
        invalidConfiguration != null ||
        formulaPlanningIncomplete ||
        unresolvedReasonCode != null ||
        fieldAccessDenied
      ) {
        continue;
      }
      SObject record = recordsById.get(recordId);
      if (record == null) {
        internalByRecordId.put(
          recordId,
          resultSupport.unavailableResult(check, 'RECORD_NOT_VISIBLE')
        );
      } else {
        RecordHealthCheckInternalResult prerequisiteBlock = resultSupport.findPrerequisiteBlock(
          check,
          recordId,
          itemsByIdentity,
          context.fullCheckSetSelection
        );
        if (prerequisiteBlock != null) {
          internalByRecordId.put(recordId, prerequisiteBlock);
          continue;
        }
        RecordHealthCheckInternalResult applicability = applicabilityByRecordId.get(
          recordId
        );
        if (applicability == null) {
          applicableIds.add(recordId);
        } else {
          internalByRecordId.put(recordId, applicability);
        }
      }
    }

    if (!applicableIds.isEmpty()) {
      try {
        if (evaluatorFailureOverride == 'SIDE_EFFECT') {
          RecordHealthCheckPluginDispatch.SideEffectException sideEffect = new RecordHealthCheckPluginDispatch.SideEffectException(
            'Synthetic plugin side effect.'
          );
          sideEffect.reasonCode = RecordHealthCheckReasonCodes.PLUGIN_SIDE_EFFECT_DETECTED;
          sideEffect.effect = 'DML';
          sideEffect.reversible = true;
          throw sideEffect;
        }
        if (evaluatorFailureOverride == 'EVALUATOR') {
          throw new SyntheticEvaluatorException('Synthetic evaluator failure.');
        }
        internalByRecordId.putAll(
          evaluatorRegistry.evaluateScope(
            check,
            applicableIds,
            recordsById,
            context,
            runId
          )
        );
      } catch (RecordHealthCheckPluginDispatch.SideEffectException ex) {
        RecordHealthCheckDiagnosticContext diagnosticContext = RecordHealthCheckDiagContextBuilder.forCheck(
          check,
          context.checkSetQualifiedApiName,
          runId,
          RecordHealthCheckReasonCodes.PLUGIN_SIDE_EFFECT_DETECTED,
          'PLUGIN_SIDE_EFFECT'
        );
        diagnosticContext.sideEffect = ex.effect;
        diagnosticContext.sideEffectReversible = ex.reversible;
        RecordHealthCheckIncidentRecorder.recordFatalFailure(
          applicableIds,
          diagnosticContext,
          ex
        );
        throw ex;
      } catch (RecordHealthCheckEvaluatorException ex) {
        internalByRecordId.putAll(
          RecordHealthCheckIncidentRecorder.recordScopeFailure(
            check,
            applicableIds,
            RecordHealthCheckDiagContextBuilder.forCheck(
              check,
              context.checkSetQualifiedApiName,
              runId,
              ex.reasonCode,
              RecordHealthCheckDiagContextBuilder.evaluatorPhase(check)
            ),
            ex
          )
        );
      } catch (Exception ex) {
        internalByRecordId.putAll(
          RecordHealthCheckIncidentRecorder.recordScopeFailure(
            check,
            applicableIds,
            RecordHealthCheckDiagContextBuilder.forCheck(
              check,
              context.checkSetQualifiedApiName,
              runId,
              check.EvaluationType__c == 'APEX'
                ? RecordHealthCheckReasonCodes.PLUGIN_THREW
                : RecordHealthCheckReasonCodes.FRAMEWORK_UNEXPECTED,
              RecordHealthCheckDiagContextBuilder.evaluatorPhase(check)
            ),
            ex
          )
        );
      }
    }

    for (Id recordId : recordIds) {
      RecordHealthCheckInternalResult internalResult = internalByRecordId.get(
        recordId
      );
      RecordHealthCheckIncidentRecorder.attachResultFailure(
        check,
        recordId,
        RecordHealthCheckDiagContextBuilder.forCheck(
          check,
          context.checkSetQualifiedApiName,
          runId,
          internalResult?.reasonCode,
          RecordHealthCheckDiagContextBuilder.evaluatorPhase(check)
        ),
        internalResult
      );
      resultSupport.finalizeDisplay(
        check,
        recordsById.get(recordId),
        internalResult,
        context.showDiagnostics == true &&
          resultMode == RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY
      );
      itemsByIdentity.put(
        itemKey(recordId, check.QualifiedApiName),
        resultSupport.toItem(check, recordId, internalResult, resultMode)
      );
    }
  }

  private List<Id> dedupeRecordIds(List<Id> recordIds) {
    List<Id> ordered = new List<Id>();
    Set<Id> seen = new Set<Id>();
    for (Id recordId : recordIds) {
      if (recordId != null && seen.add(recordId)) {
        ordered.add(recordId);
      }
    }
    return ordered;
  }

  private String itemKey(Id recordId, String checkQualifiedApiName) {
    return String.valueOf(recordId) + '|' + checkQualifiedApiName;
  }

  private String primaryUnresolvedReasonCode(
    Map<String, String> reasonCodesByField
  ) {
    List<String> paths = new List<String>(reasonCodesByField.keySet());
    paths.sort();
    return reasonCodesByField.get(paths[0]);
  }

  private String newRunId() {
    return 'rhc-api-' +
      String.valueOf(Datetime.now().getTime()) +
      '-' +
      String.valueOf(Math.abs(Crypto.getRandomInteger()));
  }

  public class SelectionContext {
    public String checkSetQualifiedApiName;
    public String checkSetDeveloperName;
    public Boolean checkSetActive;
    public String objectApiName;
    public Boolean showDiagnostics;
    public Boolean fullCheckSetSelection = false;
    public String executionOrigin;
    public List<Record_Health_Check__mdt> checks = new List<Record_Health_Check__mdt>();
  }

  public class ScopePipelineException extends Exception {
  }

  private class SyntheticEvaluatorException extends Exception {
  }

  private class RecordLoadPlan {
    private Map<Id, SObject> recordsById = new Map<Id, SObject>();
    private Set<String> inaccessibleCheckNames = new Set<String>();
    private Map<String, String> unresolvedReasonCodeByCheckName = new Map<String, String>();
    private Set<String> incompletePlanningCheckNames = new Set<String>();
  }
}
