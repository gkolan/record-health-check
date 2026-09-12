public with sharing class RecordHealthCheckScopePipeline {
  private RecordHealthCheckEvaluatorRegistry evaluatorRegistry = new RecordHealthCheckEvaluatorRegistry();
  private RecordHealthCheckConfigService configService = new RecordHealthCheckConfigService();
  private RecordHealthCheckScopePlanner scopePlanner = new RecordHealthCheckScopePlanner();
  private RecordHealthCheckScopeResultSupport resultSupport = new RecordHealthCheckScopeResultSupport();
  private RecordHealthCheckScopeRuntime scopeRuntime;
  @TestVisible
  private Boolean planningFailureOverride = false;
  @TestVisible
  private static String evaluatorFailureOverride;

  /**
   * @param request Immutable qualified selection, record IDs, and options.
   */
  public RecordHealthCheckResponse evaluate(RecordHealthCheckRequest request) {
    List<Id> recordIds = prepare(request);
    SelectionContext context = scopePlanner.resolveSelection(request.selection);
    return evaluatePrepared(request, recordIds, context);
  }

  /** Evaluates an already authorized detached definition context. */
  public RecordHealthCheckResponse evaluateResolvedContext(
    RecordHealthCheckRequest request,
    SelectionContext context
  ) {
    return evaluatePrepared(request, prepare(request), context);
  }

  private List<Id> prepare(RecordHealthCheckRequest request) {
    if (request == null) {
      throw new ScopePipelineException(
        'A Record Health Check request is required.'
      );
    }
    RecordHealthCheckDiagnosticRuntime.validateVersion(
      request.options.diagnosticContractVersion
    );
    scopeRuntime = new RecordHealthCheckScopeRuntime(
      request.options.diagnosticContractVersion
    );
    if (evaluatorFailureOverride == 'REST_SIDE_EFFECT') {
      RecordHealthCheckPluginDispatch.SideEffectException sideEffect = new RecordHealthCheckPluginDispatch.SideEffectException(
        'Synthetic plugin side effect.'
      );
      sideEffect.reasonCode = RecordHealthCheckReasonCodes.PLUGIN_SIDE_EFFECT_DETECTED;
      sideEffect.effect = 'DML';
      sideEffect.reversible = true;
      throw sideEffect;
    }

    List<Id> recordIds = RecordHealthCheckScopeRuntime.dedupe(
      request.recordIds
    );
    Integer dedupedCount = recordIds.size();
    if (dedupedCount > RecordHealthCheckConstants.MAX_RECORDS_PER_SCOPE) {
      throw new ScopePipelineException(
        'MAX_RECORDS_PER_SCOPE_EXCEEDED: uniqueCount=' +
          dedupedCount +
          ', ceiling=' +
          RecordHealthCheckConstants.MAX_RECORDS_PER_SCOPE
      );
    }
    return recordIds;
  }

  private RecordHealthCheckResponse evaluatePrepared(
    RecordHealthCheckRequest request,
    List<Id> recordIds,
    SelectionContext context
  ) {
    if (context == null) {
      throw new ScopePipelineException(
        'A resolved selection context is required.'
      );
    }
    scopeRuntime.initializeTraces(context.checks, recordIds);
    scopePlanner.validateScope(context, recordIds);
    scopePlanner.enforceFormulaBudget(context.checks, recordIds.size());
    scopePlanner.enforceTransactionBudget(
      context.checks,
      recordIds.size(),
      request.options.eventPublication
    );

    RecordHealthCheckResponse response = new RecordHealthCheckResponse();
    response.runId = String.isBlank(request.options.runId)
      ? RecordHealthCheckScopeRuntime.newRunId()
      : request.options.runId;
    context.executionOrigin = String.valueOf(request.options.executionOrigin);
    response.recordIds.addAll(recordIds);
    for (Record_Health_Check__mdt check : context.checks) {
      response.checkQualifiedApiNames.add(check.QualifiedApiName);
    }
    if (recordIds.isEmpty() || context.checks.isEmpty()) {
      RecordHealthCheckDiagnosticRuntime.attach(
        response,
        new List<RecordHealthCheckResultItem>(),
        request.options.diagnosticContractVersion,
        context.showDiagnostics
      );
      return response;
    }

    Map<String, RecordHealthCheckInternalResult> invalidConfigurationByCheck = new Map<String, RecordHealthCheckInternalResult>();
    List<Record_Health_Check__mdt> plannableChecks = new List<Record_Health_Check__mdt>();
    Set<String> cycleMembers = context.fullCheckSetSelection
      ? RHCDefinitionDependencyIdentity.cycleMembers(context.checks)
      : new Set<String>();
    for (Record_Health_Check__mdt check : context.checks) {
      Map<Id, RecordHealthCheckExecutionTrace> traces = scopeRuntime.traces(
        check.QualifiedApiName
      );
      scopeRuntime.begin(traces, recordIds, 'CONFIG_VALIDATE');
      RecordHealthCheckInternalResult invalidConfiguration = configService.validateCheckForEvaluation(
        check
      );
      if (invalidConfiguration == null) {
        scopeRuntime.configurationCompleted(
          traces,
          recordIds,
          check,
          RecordHealthCheckConfigValidator.validatedDefinitionWasProvided(check)
        );
        if (cycleMembers.contains(check.QualifiedApiName)) {
          RecordHealthCheckConfigValidator.discardValidatedPlugin(check);
          invalidConfigurationByCheck.put(
            check.QualifiedApiName,
            resultSupport.unavailableResult(
              check,
              RecordHealthCheckReasonCodes.CIRCULAR_DEPENDENCY
            )
          );
        } else {
          plannableChecks.add(check);
        }
      } else {
        scopeRuntime.configurationFailed(
          traces,
          recordIds,
          invalidConfiguration
        );
        RecordHealthCheckConfigValidator.discardValidatedPlugin(check);
        invalidConfigurationByCheck.put(
          check.QualifiedApiName,
          invalidConfiguration
        );
      }
    }
    RecordHealthCheckScopeRecordLoader.Plan recordLoad = loadRecords(
      context.objectApiName,
      recordIds,
      plannableChecks
    );
    Map<Id, SObject> recordsById = recordLoad.recordsById;
    Map<String, RecordHealthCheckResultItem> itemsByIdentity = new Map<String, RecordHealthCheckResultItem>();
    for (Record_Health_Check__mdt check : context.checks) {
      evaluateCheck(
        check,
        context,
        recordIds,
        recordsById,
        invalidConfigurationByCheck.get(check.QualifiedApiName),
        recordLoad.inaccessibleCheckNames.contains(check.QualifiedApiName),
        recordLoad.unresolvedReasonCodeByCheckName.get(check.QualifiedApiName),
        recordLoad.primaryFormulaFindingByCheckName.get(check.QualifiedApiName),
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

  private RecordHealthCheckScopeRecordLoader.Plan loadRecords(
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

  private RecordHealthCheckScopeRecordLoader.Plan loadRecords(
    String objectApiName,
    List<Id> recordIds,
    List<Record_Health_Check__mdt> checks,
    RecordHealthCheckFieldPlanner fieldPlanner
  ) {
    scopeRuntime = scopeRuntime == null
      ? new RecordHealthCheckScopeRuntime(null)
      : scopeRuntime;
    return new RecordHealthCheckScopeRecordLoader(
        scopeRuntime,
        planningFailureOverride
      )
      .load(objectApiName, recordIds, checks, fieldPlanner);
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
      configService.validateCheckForEvaluation(check),
      fieldAccessDenied,
      null,
      null,
      formulaPlanningIncomplete,
      resultMode,
      runId,
      itemsByIdentity
    );
  }

  @TestVisible
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
    evaluateCheck(
      check,
      context,
      recordIds,
      recordsById,
      configService.validateCheckForEvaluation(check),
      fieldAccessDenied,
      unresolvedReasonCode,
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
    RecordHealthCheckInternalResult invalidConfiguration,
    Boolean fieldAccessDenied,
    String unresolvedReasonCode,
    RecordHealthCheckFormulaPlanService.Finding primaryFormulaFinding,
    Boolean formulaPlanningIncomplete,
    RecordHealthCheckResultMode resultMode,
    String runId,
    Map<String, RecordHealthCheckResultItem> itemsByIdentity
  ) {
    scopeRuntime = scopeRuntime == null
      ? new RecordHealthCheckScopeRuntime(null)
      : scopeRuntime;
    RecordHealthCheckRunContext runContext = new RecordHealthCheckRunContext(
      runId,
      context.executionOrigin
    );
    resultSupport.withRunContext(runContext);
    List<Id> applicableIds = new List<Id>();
    Map<Id, RecordHealthCheckInternalResult> internalByRecordId = new Map<Id, RecordHealthCheckInternalResult>();
    Map<Id, RecordHealthCheckExecutionTrace> traces = scopeRuntime.traces(
      check.QualifiedApiName
    );
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
    Boolean canEvaluateApplicability =
      invalidConfiguration == null &&
      !formulaPlanningIncomplete &&
      unresolvedReasonCode == null &&
      !fieldAccessDenied;
    List<Id> eligibleIds = new List<Id>();
    Map<Id, SObject> eligibleRecordsById = new Map<Id, SObject>();
    if (canEvaluateApplicability) {
      RecordHealthCheckPrerequisiteEligibility.Selection eligibility = RecordHealthCheckPrerequisiteEligibility.selectEligible(
        check,
        recordIds,
        recordsById,
        itemsByIdentity,
        context.fullCheckSetSelection,
        resultSupport
      );
      eligibleIds = eligibility.recordIds;
      eligibleRecordsById = eligibility.recordsById;
      internalByRecordId.putAll(eligibility.blockedByRecordId);
    }
    if (!eligibleIds.isEmpty()) {
      scopeRuntime.begin(traces, eligibleIds, 'APPLICABILITY_EVALUATE');
    }
    Map<Id, RecordHealthCheckInternalResult> applicabilityByRecordId = canEvaluateApplicability
      ? resultSupport.applicabilityResults(
          check,
          eligibleIds,
          eligibleRecordsById
        )
      : new Map<Id, RecordHealthCheckInternalResult>();
    scopeRuntime.completeApplicability(
      traces,
      eligibleIds,
      eligibleRecordsById,
      applicabilityByRecordId,
      !eligibleIds.isEmpty()
    );
    for (Id recordId : eligibleIds) {
      RecordHealthCheckInternalResult applicability = applicabilityByRecordId.get(
        recordId
      );
      if (applicability == null) {
        applicableIds.add(recordId);
      } else {
        internalByRecordId.put(recordId, applicability);
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
          throw new ScopePipelineException('Synthetic evaluator failure.');
        }
        scopeRuntime.begin(
          traces,
          applicableIds,
          RecordHealthCheckDiagContextBuilder.evaluatorPhase(check)
        );
        context.activeExecutionTraces = traces;
        context.resultMode = resultMode;
        internalByRecordId.putAll(
          evaluatorRegistry.evaluateScope(
            check,
            applicableIds,
            recordsById,
            context,
            runId
          )
        );
        if (check.EvaluationType__c != 'APEX') {
          scopeRuntime.complete(traces, applicableIds, 'RESULT_VALIDATED');
        }
      } catch (RecordHealthCheckResourcePlan.BudgetException ex) {
        throw ex;
      } catch (RecordHealthCheckPluginDispatch.SideEffectException ex) {
        scopeRuntime.fail(traces, applicableIds, 'PLUGIN_EXECUTE');
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
        scopeRuntime.fail(
          traces,
          applicableIds,
          RecordHealthCheckDiagContextBuilder.evaluatorPhase(check)
        );
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
        scopeRuntime.fail(
          traces,
          applicableIds,
          RecordHealthCheckDiagContextBuilder.evaluatorPhase(check)
        );
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

    new RecordHealthCheckScopeResultCoordinator(
        resultSupport,
        context,
        runId,
        resultMode,
        primaryFormulaFinding,
        traces
      )
      .finish(
        check,
        recordIds,
        recordsById,
        internalByRecordId,
        itemsByIdentity
      );
  }

  public class SelectionContext {
    public String checkSetQualifiedApiName;
    public String checkSetDeveloperName;
    public Boolean checkSetActive;
    public String objectApiName;
    public Boolean showDiagnostics;
    public Boolean fullCheckSetSelection = false;
    public String executionOrigin;
    public RecordHealthCheckResultMode resultMode;
    public Map<Id, RecordHealthCheckExecutionTrace> activeExecutionTraces;
    public List<Record_Health_Check__mdt> checks = new List<Record_Health_Check__mdt>();
  }

  public class ScopePipelineException extends Exception {
  }
}
