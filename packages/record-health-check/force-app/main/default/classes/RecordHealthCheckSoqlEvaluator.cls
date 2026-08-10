/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

public with sharing class RecordHealthCheckSoqlEvaluator {
  private static final Integer DEFAULT_MAX_ROWS = RecordHealthCheckConstants.FRAMEWORK_MAX_ROWS;

  private RecordHealthCheckFormulaEvaluator formulaEvaluator = new RecordHealthCheckFormulaEvaluator();
  @TestVisible
  private Map<String, List<SObject>> scopeRowsByBoundSoql;
  @TestVisible
  private Set<String> scopeZeroCountSoql;
  @TestVisible
  private Boolean scopeExecutionActive = false;

  public RecordHealthCheckSoqlEvaluator withRunContext(
    RecordHealthCheckRunContext value
  ) {
    formulaEvaluator.withRunContext(value);
    return this;
  }

  /** Returns the context-aware formula evaluator used by extracted evaluation logic. */
  public RecordHealthCheckFormulaEvaluator formulaEvaluatorForEvaluation() {
    return formulaEvaluator;
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
    result.evaluatorType = 'QUERY';

    try {
      result = doEvaluate(check, recordId, record, result);
    } catch (Exception ex) {
      result = applyEvaluationException(check, result, ex);
    }

    result.durationMs = System.currentTimeMillis() - startMs;
    return result;
  }

  /** Evaluates one QUERY Check for a complete record scope with constant query cost. */
  public Map<Id, RecordHealthCheckInternalResult> evaluateScope(
    Record_Health_Check__mdt check,
    List<Id> recordIds,
    Map<Id, SObject> loadedRecords
  ) {
    scopeRowsByBoundSoql = new Map<String, List<SObject>>();
    scopeZeroCountSoql = new Set<String>();
    scopeExecutionActive = true;
    Integer maxRows = check.MaxQueryRows__c != null
      ? (Integer) check.MaxQueryRows__c
      : DEFAULT_MAX_ROWS;
    try {
      Boolean isListOperator =
        check.ComparisonOperator__c == 'LIST_CONTAINS_ANY' ||
        check.ComparisonOperator__c == 'LIST_CONTAINS_NONE';
      if (!isListOperator) {
        cacheScopeRows(check.SourceQuery__c, recordIds, loadedRecords, maxRows);
      }
      if (
        isListOperator || check.ExpectedValueSource__c == 'COMPARISON_QUERY'
      ) {
        cacheScopeRows(
          check.ComparisonQuery__c,
          recordIds,
          loadedRecords,
          maxRows
        );
      }

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
        String boundSoql = bindTokens(template, record);
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
    return RecordHealthCheckSoqlEvaluation.evaluate(
      check,
      recordId,
      record,
      result,
      this
    );
  }

  // ─── Token binding ──────────────────────────────────────────

  /** Replaces record tokens with safely formatted SOQL literal values. */
  public String bindTokens(String soqlTemplate, SObject record) {
    return RecordHealthCheckSoqlTokenBinder.bindTokens(soqlTemplate, record);
  }

  // ─── Query execution with row-cap safety ───────────────────

  public List<SObject> runQueryForEvaluation(String soql, Integer maxRows) {
    if (
      scopeRowsByBoundSoql != null && scopeRowsByBoundSoql.containsKey(soql)
    ) {
      return scopeRowsByBoundSoql.get(soql);
    }
    if (scopeExecutionActive) {
      if (String.isBlank(soql)) {
        throw new RecordHealthCheckEvaluatorException(
          'INVALID_SOQL_TEMPLATE',
          'A scope evaluation received a blank SOQL template.'
        );
      }
      throw new RecordHealthCheckEvaluatorException(
        'UNSUPPORTED_BULK_QUERY_SHAPE',
        'A scope evaluation attempted an unplanned record-level query.'
      );
    }
    return RecordHealthCheckQueryEvaluatorSupport.runQuery(soql, maxRows);
  }

  public Boolean isScopeZeroCountForEvaluation(String soql) {
    return scopeZeroCountSoql != null && scopeZeroCountSoql.contains(soql);
  }

  // ─── Value resolution helpers ─────────────────────────────────────────────

  public Object readQueryFieldValue(SObject row, String fieldName) {
    try {
      return RecordHealthCheckValueResolver.singleValueFromRow(row, fieldName);
    } catch (RecordHealthCheckValueResolver.ResolverException ex) {
      throw new RecordHealthCheckEvaluatorException(
        ex.reasonCode,
        ex.getMessage()
      );
    }
  }

  public List<Object> resolveFieldList(List<SObject> rows, String fieldName) {
    try {
      return RecordHealthCheckValueResolver.singleValueList(rows, fieldName);
    } catch (RecordHealthCheckValueResolver.ResolverException ex) {
      throw new RecordHealthCheckEvaluatorException(
        ex.reasonCode,
        ex.getMessage()
      );
    }
  }

  // ─── Empty / null result behavior ────────────────────────────────────────

  public RecordHealthCheckInternalResult buildEmptyOrNullResult(
    Record_Health_Check__mdt check,
    RecordHealthCheckInternalResult result,
    List<Object> primaryList
  ) {
    // A displayed "Found 0" is ambiguous: it could be a real zero or an empty
    // result set. Record which one it was, so the value source note reads e.g.
    // "Contacts → 0 rows (query returned no matching rows)".
    result.actualValueSource = new RecordHealthCheckValueSource.Detail(
      describePrimarySource(check),
      RecordHealthCheckValueSource.rowCount(
        primaryList != null ? primaryList.size() : 0
      ),
      'query returned no matching rows'
    );

    return RecordHealthCheckQueryEvaluatorSupport.buildEmptyResult(
      check,
      result,
      result.actualValueSource
    );
  }

  /**
   * Builds a result for a present-but-null value the operator could not
   * decide. Reaching this point means the empty-value handling (EmptyValueHandling__c)
   * resolved to Skip — Pass/Fail/Treat as not matching (AS_NO_MATCH) all yield a determinate
   * boolean earlier — so the check is reported as SKIPPED. This is deliberately
   * NOT governed by NoRowsResult__c, which applies only to empty result sets.
   */
  public RecordHealthCheckInternalResult buildNullIndeterminateResult(
    RecordHealthCheckInternalResult result
  ) {
    return RecordHealthCheckQueryEvaluatorSupport.buildNullIndeterminateResult(
      result
    );
  }

  // ─── Value source helpers ───────────────────────────────────────────────────

  // Derived Found summary for an "every record must pass" check when the admin
  // authored no override: "1 of 5 Contacts did not pass".
  public String deriveFoundSummary(
    Record_Health_Check__mdt check,
    Integer failing,
    Integer total
  ) {
    return failing +
      ' of ' +
      total +
      ' ' +
      RecordHealthCheckQueryEvaluatorSupport.pluralizeObject(check) +
      ' did not pass';
  }

  // Names the primary/Found source: a field, the value under test, or a generic
  // query-result label when neither is configured.
  public String describePrimarySource(Record_Health_Check__mdt check) {
    if (String.isNotBlank(check.SourceQueryField__c)) {
      return check.SourceQueryField__c;
    }
    if (String.isNotBlank(check.FindInListFormula__c)) {
      return 'Value under test';
    }
    return 'Query result';
  }

  // Names the source of the "Expected" operand.
  public String describeComparisonSource(Record_Health_Check__mdt check) {
    if (check.ExpectedValueSource__c == 'FIXED_VALUE') {
      return 'Fixed value';
    }
    if (check.ExpectedValueSource__c == 'RECORD_FORMULA') {
      return 'Formula on this record';
    }
    if (check.ExpectedValueSource__c == 'COMPARISON_QUERY') {
      return String.isNotBlank(check.ComparisonQueryField__c)
        ? 'Comparison query (' + check.ComparisonQueryField__c + ')'
        : 'Comparison query';
    }
    if (String.isNotBlank(check.ComparisonQueryField__c)) {
      return check.ComparisonQueryField__c;
    }
    return 'Comparison';
  }

  // Raw single-value label that renders null explicitly rather than as an empty string.
  public String rawLabel(Object value) {
    return value == null ? 'null' : String.valueOf(value);
  }

  public Object firstDisplayValue(Object singleValue, List<Object> values) {
    if (singleValue != null) {
      return singleValue;
    }
    if (values != null) {
      for (Object value : values) {
        if (value != null) {
          return value;
        }
      }
    }
    return null;
  }
}
