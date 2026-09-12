/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */
/**
 * Runs configured Apex Checks through safety checks that reject DML, callouts,
 * email, events, and background work. Setup, returned-value, and execution
 * problems are reported as Record Health Check results.
 */
public with sharing class RecordHealthCheckApexEvaluator {
  private RecordHealthCheckFormulaEvaluator formulaEvaluator = new RecordHealthCheckFormulaEvaluator();
  private Map<Id, RecordHealthCheckExecutionTrace> executionTraces = new Map<Id, RecordHealthCheckExecutionTrace>();
  private Boolean cardPresentation = false;
  /**
   * Applies the current Run ID and related run details to Formula display work.
   *
   * @param value Current evaluation run context.
   * @return This evaluator so the caller can continue the same setup statement.
   */
  public RecordHealthCheckApexEvaluator withRunContext(
    RecordHealthCheckRunContext value
  ) {
    formulaEvaluator.withRunContext(value);
    return this;
  }
  /** Supplies per-record traces created by the scope pipeline. */
  public RecordHealthCheckApexEvaluator withExecutionTraces(
    Map<Id, RecordHealthCheckExecutionTrace> value
  ) {
    executionTraces = value == null
      ? new Map<Id, RecordHealthCheckExecutionTrace>()
      : value;
    return this;
  }
  /** Enables the optional plugin display phase for a display-capable result. */
  public RecordHealthCheckApexEvaluator withCardPresentation(Boolean value) {
    cardPresentation = value == true;
    return this;
  }
  // ─── Public evaluation method ─────────────────────────────────────────────
  /**
   * Evaluates one record through the same Apex Check path used for multiple records.
   * A missing record ID becomes an ERROR result for that Check instead of
   * calling Apex without a record.
   *
   * @param check Apex Check metadata selected for this run.
   * @param recordId Record being evaluated.
   * @param record User-visible record already loaded for the result display.
   * @return One internal result for the requested record.
   * @throws RecordHealthCheckPluginDispatch.SideEffectException when plugin work must be rolled back to prevent a prohibited side effect.
   */
  public RecordHealthCheckInternalResult evaluate(
    Record_Health_Check__mdt check,
    Id recordId,
    SObject record
  ) {
    if (recordId == null) {
      RecordHealthCheckInternalResult result = baseResult(check);
      result.status = RecordHealthCheckStatus.ERROR;
      result.reasonCode = 'APEX_EVALUATOR_ERROR';
      result.message = safeCannotEvaluateMessage(check);
      result.detailMessage = 'No record context was provided to the Apex evaluator.';
      return result;
    }
    Map<Id, RecordHealthCheckInternalResult> results = evaluateScope(
      check,
      new List<Id>{ recordId },
      new Map<Id, SObject>{ recordId => record },
      RecordHealthCheckDescribeCache.objectApiName(recordId),
      null,
      null
    );
    return results.get(recordId);
  }
  /**
   * Creates and invokes one Apex Check exactly once for all requested records.
   * Setup and ordinary Apex Check failures become matching results for the
   * affected records. If the Check tries to change data or start other work,
   * the exception is rethrown so Salesforce rolls back the transaction.
   *
   * @param check Apex Check metadata selected for this run.
   * @param recordIds Requested record IDs within the framework limit.
   * @param loadedRecords User-visible records keyed by ID for the result display.
   * @param objectApiName Validated scope object API name.
   * @param checkSetDeveloperName Owning Set identity for diagnostics and logging.
   * @param runId Optional Run ID used to match logs and results.
   * @return One result for each requested record ID.
   * @throws RecordHealthCheckPluginDispatch.SideEffectException when plugin work must be rolled back to prevent a prohibited side effect.
   */
  public Map<Id, RecordHealthCheckInternalResult> evaluateScope(
    Record_Health_Check__mdt check,
    List<Id> recordIds,
    Map<Id, SObject> loadedRecords,
    String objectApiName,
    String checkSetDeveloperName,
    String runId
  ) {
    return evaluateScope(
      check,
      recordIds,
      loadedRecords,
      objectApiName,
      checkSetDeveloperName,
      checkSetDeveloperName,
      runId
    );
  }
  /** Evaluates an Apex Check with unqualified and qualified Set identities. */
  public Map<Id, RecordHealthCheckInternalResult> evaluateScope(
    Record_Health_Check__mdt check,
    List<Id> recordIds,
    Map<Id, SObject> loadedRecords,
    String objectApiName,
    String checkSetDeveloperName,
    String checkSetQualifiedApiName,
    String runId
  ) {
    RecordHealthCheckPlugin plugin;
    Map<String, Object> parameters;
    RecordHealthCheckApexPluginResolver.PluginConfiguration pluginConfiguration;
    try {
      beginTraces(recordIds, 'PLUGIN_RESOLVE');
      plugin = RecordHealthCheckApexPluginResolver.resolve(check);
      completeTraces(recordIds, 'PLUGIN_RESOLVED');
      completeTraces(recordIds, 'PLUGIN_CONSTRUCTED');
      pluginConfiguration = RecordHealthCheckConfigValidator.takeValidatedConfiguration(
        check
      );
      if (
        pluginConfiguration == null &&
        plugin instanceof RecordHealthCheckPluginDefinitionSource
      ) {
        beginTraces(recordIds, 'PLUGIN_DEFINE');
      }
      pluginConfiguration = pluginConfiguration == null
        ? RecordHealthCheckApexPluginResolver.configuration(check, plugin)
        : pluginConfiguration;
      if (pluginConfiguration.definition != null) {
        completeTraces(recordIds, 'PLUGIN_DEFINED');
      }
      parameters = pluginConfiguration.parameters;
    } catch (RecordHealthCheckPluginDispatch.SideEffectException ex) {
      throw ex;
    } catch (RecordHealthCheckApexPluginResolver.PluginConfigurationException ex) {
      return configurationFailure(
        check,
        recordIds,
        checkSetQualifiedApiName,
        runId,
        ex
      );
    }
    Integer maxScopeSize = pluginConfiguration.definition?.maxScopeSize();
    if (maxScopeSize != null && recordIds.size() > maxScopeSize) {
      return capacityFailure(check, recordIds, checkSetQualifiedApiName, runId);
    }
    String checkQualifiedApiName = String.isBlank(check.QualifiedApiName)
      ? check.DeveloperName
      : check.QualifiedApiName;
    RecordHealthCheckScope scope = new RecordHealthCheckScope(
      objectApiName,
      recordIds,
      parameters,
      check.DeveloperName,
      checkSetDeveloperName,
      runId,
      checkQualifiedApiName,
      checkSetQualifiedApiName
    );
    Map<Id, RecordHealthCheckOutcome> outcomes;
    try {
      beginTraces(recordIds, 'PLUGIN_EXECUTE');
      outcomes = RecordHealthCheckPluginDispatch.run(plugin, scope);
      completeTraces(recordIds, 'PLUGIN_EXECUTED');
    } catch (RecordHealthCheckPluginDispatch.ContractException ex) {
      return executionFailure(
        check,
        recordIds,
        checkSetQualifiedApiName,
        runId,
        ex
      );
    }
    beginTraces(recordIds, 'PLUGIN_VALIDATE_RESULT');
    Map<Id, RecordHealthCheckInternalResult> finalized = finalizeOutcomes(
      check,
      recordIds,
      loadedRecords,
      outcomes,
      checkSetQualifiedApiName,
      runId
    );
    return presentAndTrace(plugin, scope, recordIds, finalized);
  }
  private Map<Id, RecordHealthCheckInternalResult> presentAndTrace(
    RecordHealthCheckPlugin plugin,
    RecordHealthCheckScope scope,
    List<Id> recordIds,
    Map<Id, RecordHealthCheckInternalResult> finalized
  ) {
    if (
      cardPresentation &&
      RecordHealthCheckApexDisplaySupport.hasValidEvaluation(finalized)
    ) {
      try {
        Map<Id, RecordHealthCheckDisplayOverride> displayByRecord = RecordHealthCheckPluginDisplayDispatch.run(
          plugin,
          scope
        );
        RecordHealthCheckApexDisplaySupport.attach(finalized, displayByRecord);
      } catch (RecordHealthCheckPluginDispatch.SideEffectException ex) {
        throw ex;
      } catch (RecordHealthCheckPluginDisplayDispatch.DisplayException ex) {
        for (RecordHealthCheckInternalResult result : finalized.values()) {
          result.detailMessage = ex.reasonCode;
        }
      }
    }
    for (Id recordId : recordIds) {
      RecordHealthCheckInternalResult result = finalized.get(recordId);
      if (isInvalidPluginResult(result?.reasonCode)) {
        failTrace(recordId, 'PLUGIN_VALIDATE_RESULT');
      } else {
        completeTrace(recordId, 'RESULT_VALIDATED');
      }
    }
    attachTraces(finalized);
    return finalized;
  }
  private Map<Id, RecordHealthCheckInternalResult> configurationFailure(
    Record_Health_Check__mdt check,
    List<Id> recordIds,
    String checkSetQualifiedApiName,
    String runId,
    RecordHealthCheckApexPluginResolver.PluginConfigurationException ex
  ) {
    RecordHealthCheckDiagnosticContext configurationContext = diagnosticContext(
      check,
      checkSetQualifiedApiName,
      runId,
      ex.reasonCode,
      ex.reasonCode == RecordHealthCheckReasonCodes.INVALID_APEX_PARAMETERS
        ? 'PLUGIN_PARAMETERS'
        : ex.reasonCode ==
            RecordHealthCheckReasonCodes.PLUGIN_DEFINITION_INVALID
            ? 'PLUGIN_DEFINE'
            : ex.reasonCode ==
                RecordHealthCheckReasonCodes.PLUGIN_CONSTRUCTOR_FAILED
                ? 'PLUGIN_CONSTRUCT'
                : 'PLUGIN_RESOLVE'
    );
    configurationContext.status = RecordHealthCheckStatus.UNABLE_TO_EVALUATE;
    configurationContext.severity = 'WARNING';
    configurationContext.pluginInvoked = false;
    configurationContext.reasonOrigin = 'FRAMEWORK';
    failTraces(recordIds, configurationPhase(ex.reasonCode));
    Map<Id, RecordHealthCheckInternalResult> failed = RecordHealthCheckIncidentRecorder.recordScopeFailure(
      check,
      recordIds,
      configurationContext,
      ex
    );
    attachTraces(failed);
    return failed;
  }
  private Map<Id, RecordHealthCheckInternalResult> executionFailure(
    Record_Health_Check__mdt check,
    List<Id> recordIds,
    String checkSetQualifiedApiName,
    String runId,
    RecordHealthCheckPluginDispatch.ContractException ex
  ) {
    RecordHealthCheckDiagnosticContext executionContext = diagnosticContext(
      check,
      checkSetQualifiedApiName,
      runId,
      ex.reasonCode,
      ex.reasonCode == RecordHealthCheckReasonCodes.PLUGIN_THREW
        ? 'PLUGIN_EXECUTE'
        : 'PLUGIN_VALIDATE_RESULT'
    );
    executionContext.pluginInvoked = true;
    executionContext.reasonOrigin = 'FRAMEWORK';
    String failurePhase = ex.reasonCode ==
      RecordHealthCheckReasonCodes.PLUGIN_THREW
      ? 'PLUGIN_EXECUTE'
      : 'PLUGIN_VALIDATE_RESULT';
    failTraces(recordIds, failurePhase);
    Map<Id, RecordHealthCheckInternalResult> failed = RecordHealthCheckIncidentRecorder.recordScopeFailure(
      check,
      recordIds,
      executionContext,
      ex
    );
    attachTraces(failed);
    return failed;
  }
  private Map<Id, RecordHealthCheckInternalResult> capacityFailure(
    Record_Health_Check__mdt check,
    List<Id> recordIds,
    String checkSetQualifiedApiName,
    String runId
  ) {
    RecordHealthCheckDiagnosticContext capacityContext = diagnosticContext(
      check,
      checkSetQualifiedApiName,
      runId,
      RecordHealthCheckReasonCodes.PLUGIN_SCOPE_LIMIT_EXCEEDED,
      'PLUGIN_CAPACITY'
    );
    capacityContext.status = RecordHealthCheckStatus.UNABLE_TO_EVALUATE;
    capacityContext.severity = 'WARNING';
    capacityContext.pluginInvoked = false;
    capacityContext.reasonOrigin = 'FRAMEWORK';
    failTraces(recordIds, 'PLUGIN_CAPACITY');
    Map<Id, RecordHealthCheckInternalResult> rejected = RecordHealthCheckIncidentRecorder.recordScopeFailure(
      check,
      recordIds,
      capacityContext,
      null
    );
    attachTraces(rejected);
    return rejected;
  }
  private static String configurationPhase(String reasonCode) {
    if (reasonCode == RecordHealthCheckReasonCodes.INVALID_APEX_PARAMETERS) {
      return 'PLUGIN_PARAMETERS';
    }
    if (reasonCode == RecordHealthCheckReasonCodes.PLUGIN_DEFINITION_INVALID) {
      return 'PLUGIN_DEFINE';
    }
    if (reasonCode == RecordHealthCheckReasonCodes.PLUGIN_CONSTRUCTOR_FAILED) {
      return 'PLUGIN_CONSTRUCT';
    }
    return 'PLUGIN_RESOLVE';
  }
  private static Boolean isInvalidPluginResult(String reasonCode) {
    return reasonCode == RecordHealthCheckReasonCodes.PLUGIN_RESULT_MISSING ||
      reasonCode == RecordHealthCheckReasonCodes.PLUGIN_STATUS_INVALID ||
      reasonCode == RecordHealthCheckReasonCodes.PLUGIN_REASON_CODE_INVALID ||
      reasonCode == RecordHealthCheckReasonCodes.PLUGIN_VALUES_MISSING ||
      reasonCode == RecordHealthCheckReasonCodes.PLUGIN_DISPLAY_INVALID;
  }
  private void completeTraces(List<Id> recordIds, String stage) {
    for (Id recordId : recordIds) {
      completeTrace(recordId, stage);
    }
  }

  private void beginTraces(List<Id> recordIds, String phase) {
    for (Id recordId : recordIds) {
      executionTraces.get(recordId)?.begin(phase);
    }
  }

  private void completeTrace(Id recordId, String stage) {
    executionTraces.get(recordId)?.complete(stage);
  }

  private void failTraces(List<Id> recordIds, String phase) {
    for (Id recordId : recordIds) {
      failTrace(recordId, phase);
    }
  }

  private void failTrace(Id recordId, String phase) {
    executionTraces.get(recordId)?.fail(phase);
  }

  private void attachTraces(Map<Id, RecordHealthCheckInternalResult> results) {
    for (Id recordId : results.keySet()) {
      results.get(recordId).executionTrace = executionTraces.get(recordId);
    }
  }

  private Map<Id, RecordHealthCheckInternalResult> finalizeOutcomes(
    Record_Health_Check__mdt check,
    List<Id> recordIds,
    Map<Id, SObject> loadedRecords,
    Map<Id, RecordHealthCheckOutcome> outcomes,
    String checkSetDeveloperName,
    String runId
  ) {
    Map<Id, RecordHealthCheckInternalResult> results = new Map<Id, RecordHealthCheckInternalResult>();
    for (Id recordId : recordIds) {
      RecordHealthCheckInternalResult result = finalizeOutcome(
        check,
        loadedRecords.get(recordId),
        outcomes.get(recordId)
      );
      if (
        result.status == RecordHealthCheckStatus.ERROR &&
        isInvalidPluginResult(result.reasonCode)
      ) {
        RecordHealthCheckDiagnosticContext contractContext = diagnosticContext(
          check,
          checkSetDeveloperName,
          runId,
          result.reasonCode,
          'PLUGIN_VALIDATE_RESULT'
        );
        contractContext.pluginInvoked = true;
        contractContext.reasonOrigin = 'FRAMEWORK';
        contractContext.priorReasonCode = result.priorReasonCode;
        contractContext.technicalMessage = result.detailMessage;
        contractContext.valueSide = result.pluginValueViolation?.side;
        contractContext.valueDeclaredType = result.pluginValueViolation
          ?.declaredType;
        contractContext.valueMemberCount = result.pluginValueViolation
          ?.memberCount;
        contractContext.valueRenderedBlank = result.pluginValueViolation
          ?.renderedBlank;
        results.putAll(
          RecordHealthCheckIncidentRecorder.recordScopeFailure(
            check,
            new List<Id>{ recordId },
            contractContext,
            null
          )
        );
      } else {
        results.put(recordId, result);
      }
    }
    return results;
  }

  private RecordHealthCheckInternalResult finalizeOutcome(
    Record_Health_Check__mdt check,
    SObject loadedRecord,
    RecordHealthCheckOutcome outcome
  ) {
    RecordHealthCheckInternalResult fallback = baseResult(check);
    if (
      outcome != null &&
      RecordHealthCheckStatus.ERROR.equals(outcome.status) &&
      RecordHealthCheckReasonCodes.PLUGIN_RESULT_MISSING.equals(
        outcome.reasonCode
      )
    ) {
      fallback.status = RecordHealthCheckStatus.ERROR;
      fallback.reasonCode = outcome.reasonCode;
      fallback.reasonOrigin = 'FRAMEWORK';
      fallback.pluginInvoked = true;
      fallback.message = safeCannotEvaluateMessage(check);
      fallback.detailMessage = 'The plugin returned no result for this record.';
      return fallback;
    }
    return RecordHealthCheckApexResultFinalizer.finalizeResult(
      check,
      loadedRecord,
      fallback,
      RecordHealthCheckApexResultFinalizer.toInternalResult(outcome, fallback),
      formulaEvaluator
    );
  }

  private RecordHealthCheckDiagnosticContext diagnosticContext(
    Record_Health_Check__mdt check,
    String checkSetQualifiedApiName,
    String runId,
    String reasonCode,
    String phase
  ) {
    RecordHealthCheckDiagnosticContext context = new RecordHealthCheckDiagnosticContext();
    context.runId = runId;
    context.checkSetQualifiedApiName = checkSetQualifiedApiName;
    context.checkQualifiedApiName = check.QualifiedApiName;
    context.evaluatorType = 'APEX';
    context.phase = phase;
    context.component = check.ApexClass__c;
    context.reasonCode = reasonCode;
    context.configurationField = phase == 'PLUGIN_PARAMETERS'
      ? 'ApexParametersJson__c'
      : phase == 'PLUGIN_RESOLVE' ||
          phase == 'PLUGIN_CONSTRUCT'
          ? 'ApexClass__c'
          : null;
    return context;
  }

  private RecordHealthCheckInternalResult baseResult(
    Record_Health_Check__mdt check
  ) {
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.checkDeveloperName = check.DeveloperName;
    result.label = check.CheckTitle__c;
    result.priority = check.EvaluationOrder__c;
    result.evaluatorType = 'APEX';
    return result;
  }

  // ─── Helper ───────────────────────────────────────────────────────────────

  private String safeCannotEvaluateMessage(Record_Health_Check__mdt check) {
    return String.isNotBlank(check.UnableToEvaluateMessage__c)
      ? check.UnableToEvaluateMessage__c
      : 'This check could not be evaluated. Contact your administrator.';
  }
}
