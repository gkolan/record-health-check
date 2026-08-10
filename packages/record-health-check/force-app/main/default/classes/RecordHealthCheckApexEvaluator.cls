/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

public with sharing class RecordHealthCheckApexEvaluator {
  private RecordHealthCheckFormulaEvaluator formulaEvaluator = new RecordHealthCheckFormulaEvaluator();

  public RecordHealthCheckApexEvaluator withRunContext(
    RecordHealthCheckRunContext value
  ) {
    formulaEvaluator.withRunContext(value);
    return this;
  }

  // ─── Public entry point ───────────────────────────────────────────────────

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

  /** Instantiates and invokes one Apex plugin exactly once for a complete scope. */
  public Map<Id, RecordHealthCheckInternalResult> evaluateScope(
    Record_Health_Check__mdt check,
    List<Id> recordIds,
    Map<Id, SObject> loadedRecords,
    String objectApiName,
    String checkSetDeveloperName,
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
      return scopeError(check, recordIds, ex.reasonCode, ex.getMessage());
    }

    RecordHealthCheckScope scope = new RecordHealthCheckScope(
      objectApiName,
      recordIds,
      parameters,
      check.DeveloperName,
      checkSetDeveloperName,
      runId
    );
    Map<Id, RecordHealthCheckOutcome> outcomes;
    try {
      outcomes = RecordHealthCheckPluginDispatch.run(plugin, scope);
    } catch (RecordHealthCheckPluginDispatch.ContractException ex) {
      return scopeError(check, recordIds, ex.reasonCode, ex.getMessage());
    }

    return finalizeOutcomes(check, recordIds, loadedRecords, outcomes);
  }

  private Map<Id, RecordHealthCheckInternalResult> finalizeOutcomes(
    Record_Health_Check__mdt check,
    List<Id> recordIds,
    Map<Id, SObject> loadedRecords,
    Map<Id, RecordHealthCheckOutcome> outcomes
  ) {
    Map<Id, RecordHealthCheckInternalResult> results = new Map<Id, RecordHealthCheckInternalResult>();
    for (Id recordId : recordIds) {
      results.put(
        recordId,
        finalizeOutcome(
          check,
          loadedRecords.get(recordId),
          outcomes.get(recordId)
        )
      );
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

  private Map<Id, RecordHealthCheckInternalResult> scopeError(
    Record_Health_Check__mdt check,
    List<Id> recordIds,
    String reasonCode,
    String detail
  ) {
    Map<Id, RecordHealthCheckInternalResult> results = new Map<Id, RecordHealthCheckInternalResult>();
    for (Id recordId : recordIds) {
      RecordHealthCheckInternalResult result = baseResult(check);
      result.status = reasonCode != null && reasonCode.startsWith('PLUGIN_')
        ? RecordHealthCheckStatus.ERROR
        : RecordHealthCheckStatus.UNABLE_TO_EVALUATE;
      result.reasonCode = reasonCode;
      result.message = safeCannotEvaluateMessage(check);
      result.detailMessage = detail;
      results.put(recordId, result);
    }
    return results;
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
