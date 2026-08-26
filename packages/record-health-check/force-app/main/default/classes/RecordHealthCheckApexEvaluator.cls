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
    try {
      plugin = RecordHealthCheckApexPluginResolver.resolve(check);
      parameters = RecordHealthCheckApexPluginResolver.parameters(check);
    } catch (RecordHealthCheckPluginDispatch.SideEffectException ex) {
      throw ex;
    } catch (RecordHealthCheckApexPluginResolver.PluginConfigurationException ex) {
      RecordHealthCheckDiagnosticContext configurationContext = diagnosticContext(
        check,
        checkSetQualifiedApiName,
        runId,
        ex.reasonCode,
        ex.reasonCode == 'INVALID_APEX_PARAMETERS'
          ? 'PLUGIN_PARAMETERS'
          : ex.reasonCode ==
              RecordHealthCheckReasonCodes.PLUGIN_CONSTRUCTOR_FAILED
              ? 'PLUGIN_CONSTRUCT'
              : 'PLUGIN_RESOLVE'
      );
      configurationContext.status = RecordHealthCheckStatus.UNABLE_TO_EVALUATE;
      configurationContext.severity = 'WARNING';
      return RecordHealthCheckIncidentRecorder.recordScopeFailure(
        check,
        recordIds,
        configurationContext,
        ex
      );
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
      outcomes = RecordHealthCheckPluginDispatch.run(plugin, scope);
    } catch (RecordHealthCheckPluginDispatch.ContractException ex) {
      return RecordHealthCheckIncidentRecorder.recordScopeFailure(
        check,
        recordIds,
        diagnosticContext(
          check,
          checkSetQualifiedApiName,
          runId,
          ex.reasonCode,
          ex.reasonCode == RecordHealthCheckReasonCodes.PLUGIN_THREW
            ? 'PLUGIN_EXECUTE'
            : 'PLUGIN_VALIDATE'
        ),
        ex
      );
    }

    return finalizeOutcomes(
      check,
      recordIds,
      loadedRecords,
      outcomes,
      checkSetQualifiedApiName,
      runId
    );
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
        (result.reasonCode ==
        RecordHealthCheckReasonCodes.PLUGIN_RESULT_MISSING ||
        result.reasonCode ==
        RecordHealthCheckReasonCodes.PLUGIN_STATUS_INVALID ||
        result.reasonCode ==
        RecordHealthCheckReasonCodes.PLUGIN_REASON_CODE_INVALID ||
        result.reasonCode ==
        RecordHealthCheckReasonCodes.PLUGIN_VALUES_MISSING ||
        result.reasonCode ==
        RecordHealthCheckReasonCodes.PLUGIN_DISPLAY_INVALID)
      ) {
        RecordHealthCheckDiagnosticContext contractContext = diagnosticContext(
          check,
          checkSetDeveloperName,
          runId,
          result.reasonCode,
          'PLUGIN_VALIDATE'
        );
        contractContext.technicalMessage = result.detailMessage;
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
