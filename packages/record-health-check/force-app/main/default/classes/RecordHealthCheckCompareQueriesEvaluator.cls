/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

public with sharing class RecordHealthCheckCompareQueriesEvaluator {
  private static final Integer DEFAULT_MAX_ROWS = RecordHealthCheckConstants.FRAMEWORK_MAX_ROWS;

  // Delegate token binding and query execution to the existing SOQL evaluator
  private RecordHealthCheckSoqlEvaluator soqlEvaluator = new RecordHealthCheckSoqlEvaluator();
  @TestVisible
  private Map<String, List<SObject>> scopeRowsByBoundSoql;
  @TestVisible
  private Set<String> scopeZeroCountSoql;
  @TestVisible
  private Boolean scopeExecutionActive = false;

  public RecordHealthCheckCompareQueriesEvaluator withRunContext(
    RecordHealthCheckRunContext value
  ) {
    soqlEvaluator.withRunContext(value);
    return this;
  }

  // ─── Public entry point ───────────────────────────────────────────────────

  public RecordHealthCheckInternalResult evaluate(
    Record_Health_Check__mdt check,
    Id recordId,
    SObject record
  ) {
    Long startMs = System.currentTimeMillis();
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.checkDeveloperName = check.DeveloperName;
    result.label = check.CheckTitle__c;
    result.priority = check.EvaluationOrder__c;
    result.evaluatorType = 'COMPARE_TWO_QUERIES';

    try {
      result = doEvaluate(check, recordId, record, result);
    } catch (Exception ex) {
      result = applyEvaluationException(check, result, ex);
    }

    result.durationMs = System.currentTimeMillis() - startMs;
    return result;
  }

  /** Evaluates both query sides once each for a complete record scope. */
  public Map<Id, RecordHealthCheckInternalResult> evaluateScope(
    Record_Health_Check__mdt check,
    List<Id> recordIds,
    Map<Id, SObject> loadedRecords
  ) {
    Integer maxRows = check.MaxQueryRows__c != null
      ? (Integer) check.MaxQueryRows__c
      : DEFAULT_MAX_ROWS;
    scopeRowsByBoundSoql = new Map<String, List<SObject>>();
    scopeZeroCountSoql = new Set<String>();
    scopeExecutionActive = true;
    try {
      cacheScopeRows(check.SourceQuery__c, recordIds, loadedRecords, maxRows);
      cacheScopeRows(
        check.ComparisonQuery__c,
        recordIds,
        loadedRecords,
        maxRows
      );
      Map<Id, RecordHealthCheckInternalResult> results = new Map<Id, RecordHealthCheckInternalResult>();
      for (Id recordId : recordIds) {
        results.put(
          recordId,
          evaluate(check, recordId, loadedRecords.get(recordId))
        );
      }
      return results;
    } finally {
      scopeRowsByBoundSoql = null;
      scopeZeroCountSoql = null;
      scopeExecutionActive = false;
    }
  }

  private void cacheScopeRows(
    String template,
    List<Id> recordIds,
    Map<Id, SObject> loadedRecords,
    Integer maxRows
  ) {
    if (String.isBlank(template)) {
      return;
    }
    RecordHealthCheckBulkQuerySupport.Result bulkResult = RecordHealthCheckBulkQuerySupport.execute(
      template,
      loadedRecords,
      maxRows
    );
    for (Id recordId : recordIds) {
      SObject record = loadedRecords.get(recordId);
      if (record != null) {
        String boundSoql = soqlEvaluator.bindTokens(template, record);
        scopeRowsByBoundSoql.put(
          boundSoql,
          bulkResult.rowsByRecordId.get(recordId)
        );
        if (
          RecordHealthCheckSoqlTemplate.isSingleCountQuery(template) &&
          bulkResult.rowsByRecordId.get(recordId).isEmpty()
        ) {
          scopeZeroCountSoql.add(boundSoql);
        }
      }
    }
  }

  private RecordHealthCheckInternalResult applyEvaluationException(
    Record_Health_Check__mdt check,
    RecordHealthCheckInternalResult result,
    Exception ex
  ) {
    if (ex instanceof RecordHealthCheckEvaluatorException) {
      RecordHealthCheckEvaluatorException evaluatorException = (RecordHealthCheckEvaluatorException) ex;
      result.status = 'UNABLE_TO_EVALUATE';
      result.reasonCode = evaluatorException.reasonCode;
    } else {
      result.status = 'ERROR';
      result.reasonCode = 'APEX_EVALUATOR_ERROR';
    }
    result.message = RecordHealthCheckQueryEvaluatorSupport.safeCannotEvaluateMessage(
      check
    );
    result.detailMessage = ex.getMessage();
    return result;
  }

  // ─── Framework evaluation ──────────────────────────────────────────────────────

  private RecordHealthCheckInternalResult doEvaluate(
    Record_Health_Check__mdt check,
    Id recordId,
    SObject record,
    RecordHealthCheckInternalResult result
  ) {
    Integer maxRows = check.MaxQueryRows__c != null
      ? (Integer) check.MaxQueryRows__c
      : DEFAULT_MAX_ROWS;

    RecordHealthCheckQuerySchemaValidator.validateConfiguredField(
      check.SourceQuery__c,
      check.SourceQueryField__c
    );
    RecordHealthCheckQuerySchemaValidator.validateConfiguredField(
      check.ComparisonQuery__c,
      check.ComparisonQueryField__c
    );

    String primarySoql = soqlEvaluator.bindTokens(check.SourceQuery__c, record);
    String comparisonSoql = soqlEvaluator.bindTokens(
      check.ComparisonQuery__c,
      record
    );

    List<SObject> primaryRows = runQuery(primarySoql, maxRows);
    List<SObject> comparisonRows = runQuery(comparisonSoql, maxRows);
    Boolean primaryIsZeroCount = isScopeZeroCount(primarySoql);
    Boolean comparisonIsZeroCount = isScopeZeroCount(comparisonSoql);

    String mode = check.QueryResultHandling__c;
    Boolean passed;

    if (mode == 'ONE_RESULT') {
      // Single-result mode: both sides resolve to one value.
      // a zero-row query is governed by NoRowsResult__c, NOT by the
      // null-value behavior (EmptyValueHandling__c). evaluateSingleVsSingle
      // collapses an empty query and a present-but-null field to the same null
      // so without this early route an empty side with Treat as not matching (AS_NO_MATCH) would
      // wrongly FAIL (and TreatMissingAsBlank would wrongly compare '') instead
      // of honoring NoRowsResult__c. Mirrors the single-query evaluator, which
      // routes an empty primary to buildEmptyOrNullResult up front.
      if (
        (primaryRows.isEmpty() && !primaryIsZeroCount) ||
        (comparisonRows.isEmpty() && !comparisonIsZeroCount)
      ) {
        return RecordHealthCheckQueryEvaluatorSupport.buildEmptyResult(
          check,
          result,
          null
        );
      }
      passed = RecordHealthCheckCompareQuerySupport.evaluateSingleVsSingle(
        check,
        primaryRows,
        comparisonRows,
        primaryIsZeroCount,
        comparisonIsZeroCount
      );
    } else if (mode == 'COMPARE_AS_LISTS') {
      // List-result mode: both sides resolve to lists; list set operations
      passed = RecordHealthCheckCompareQuerySupport.evaluateListVsList(
        check,
        primaryRows,
        comparisonRows
      );
    } else {
      throw new RecordHealthCheckEvaluatorException(
        'INVALID_OPERATOR',
        'Compare two queries does not support How To Interpret Query Results "' +
          mode +
          '".' +
          ' Use Expect one row or aggregate result, or Compare query results as lists.'
      );
    }

    if (passed == null) {
      // Separate a genuine zero-row result (governed by NoRowsResult__c) from a
      // present-row null value (governed by EmptyValueHandling__c). OneResult
      // routes empty queries above; CompareAsLists returns null for an empty side.
      Boolean zeroRows =
        (primaryRows.isEmpty() && !primaryIsZeroCount) ||
        (comparisonRows.isEmpty() && !comparisonIsZeroCount);
      return zeroRows
        ? RecordHealthCheckQueryEvaluatorSupport.buildEmptyResult(
            check,
            result,
            null
          )
        : RecordHealthCheckQueryEvaluatorSupport.buildNullIndeterminateResult(
            result
          );
    }

    // Capture actual vs expected from the rows already fetched (no extra query)
    // so the UI can show the comparison on a non-passing row.
    RecordHealthCheckCompareQuerySupport.setComparisonValues(
      check,
      record,
      result,
      primaryRows,
      comparisonRows,
      mode,
      primaryIsZeroCount,
      comparisonIsZeroCount
    );

    if (passed) {
      result.status = 'PASS';
    } else {
      result.status = 'FAIL';
      result.severity = check.FailureSeverity__c;
      // Merge-field resolution is handled by the engine; this evaluator still
      // supplies the unresolved template for the shared finalization path.
      result.message = String.isNotBlank(check.FailureMessage__c)
        ? check.FailureMessage__c
        : 'Check failed.';
    }
    return result;
  }

  // ─── Query execution with row-cap safety ─────────────────────────────────

  private List<SObject> runQuery(String soql, Integer maxRows) {
    if (
      scopeRowsByBoundSoql != null && scopeRowsByBoundSoql.containsKey(soql)
    ) {
      return scopeRowsByBoundSoql.get(soql);
    }
    if (scopeExecutionActive) {
      // Blank templates are rejected by token binding before query execution,
      // so every uncached value here represents an unplanned query shape.
      throw new RecordHealthCheckEvaluatorException(
        'UNSUPPORTED_BULK_QUERY_SHAPE',
        'A scope evaluation attempted an unplanned record-level query.'
      );
    }
    return RecordHealthCheckQueryEvaluatorSupport.runQuery(soql, maxRows);
  }

  private Boolean isScopeZeroCount(String soql) {
    return scopeZeroCountSoql != null && scopeZeroCountSoql.contains(soql);
  }
}
