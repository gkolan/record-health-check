/** Resolves SOQL evaluation inputs while retaining rows before cardinality errors. */
public with sharing class RecordHealthCheckSoqlValueResolver {
  public class Side {
    public Object value;
    public List<Object> values;
    public SObject row;
    public List<SObject> rows;
    public Boolean queryWasEmpty = false;
    public RecordHealthCheckInternalResult earlyResult;
  }
  public static Side primary(
    Record_Health_Check__mdt check,
    SObject record,
    RecordHealthCheckInternalResult result,
    RecordHealthCheckSoqlEvaluator evaluator,
    Boolean isListOperator,
    Integer maxRows
  ) {
    Side side = new Side();
    // ── Resolve primary value / list ──────────────────────────────────────
    if (isListOperator) {
      // List-membership mode: primary side comes from FindInListFormula__c.
      try {
        side.value = evaluator.formulaEvaluatorForEvaluation()
          .resolveFormulaSingleValue(
            check.FindInListFormula__c,
            record,
            check.FormulaResultType__c
          );
      } catch (RecordHealthCheckFormulaEvaluator.FormulaEvaluationException fex) {
        throw new RecordHealthCheckEvaluatorException(
          fex.reasonCode,
          fex.getMessage()
        );
      }
    } else {
      // Tiers 3–5, 8: primary side from SourceQuery__c
      String soql = evaluator.bindTokens(check.SourceQuery__c, record);
      List<SObject> rows = evaluator.runQueryForEvaluation(soql, maxRows);
      side.rows = rows;
      // Attached here rather than at the end, because the branches below can
      // throw on cardinality after the rows are already in hand. An unable
      // message that says how many rows were found, or names the first, has to
      // still be able to read them.
      result.querySourceRows = rows;
      if (check.QueryResultHandling__c == 'ONE_RESULT') {
        if (rows.isEmpty() && evaluator.isScopeZeroCountForEvaluation(soql)) {
          side.value = 0;
        } else if (rows.isEmpty()) {
          // Aggregate COUNT() always returns 1 row (with count=0), so this branch
          // is only reached by non-aggregate queries with no matching rows.
          // Route through configured EmptyResultBehavior rather than returning 0.
          side.earlyResult = evaluator.buildEmptyOrNullResult(
            check,
            result,
            null
          );
          return side;
        } else if (rows.size() > 1) {
          throw new RecordHealthCheckEvaluatorException(
            'MULTIPLE_ROWS_RETURNED',
            'OneResult check returned ' + rows.size() + ' rows.'
          );
        } else {
          side.row = rows[0];
          side.value = evaluator.readQueryFieldValue(
            rows[0],
            check.SourceQueryField__c
          );
        }
      } else {
        // AnyRowPasses, AllRowsPass, CompareAsLists
        side.values = evaluator.resolveFieldList(
          rows,
          check.SourceQueryField__c
        );
        side.rows = rows;
        side.row = rows.isEmpty() ? null : rows[0];
      }
    }
    return side;
  }
  public static Side comparison(
    Record_Health_Check__mdt check,
    SObject record,
    RecordHealthCheckInternalResult result,
    RecordHealthCheckSoqlEvaluator evaluator,
    Boolean isListOperator,
    Boolean isUnaryOperator,
    Integer maxRows
  ) {
    Side side = new Side();
    // ── Resolve comparison value / list ───────────────────────────────────
    // The Expected side can come from its own query and currency.
    // Distinguishes a comparison query returning zero rows from one where the field was
    // simply null on a present row (→ null-value, handled by EmptyValueHandling__c).
    if (!isUnaryOperator) {
      if (isListOperator) {
        // Comparison side: query result list
        String compSoql = evaluator.bindTokens(
          check.ComparisonQuery__c,
          record
        );
        List<SObject> compRows = evaluator.runQueryForEvaluation(
          compSoql,
          maxRows
        );
        side.values = evaluator.resolveFieldList(
          compRows,
          check.ComparisonQueryField__c
        );
        side.rows = compRows;
        result.queryComparisonRows = compRows;
        side.row = compRows.isEmpty() ? null : compRows[0];
      } else if (check.ExpectedValueSource__c == 'FIXED_VALUE') {
        side.value = check.ExpectedFixedValue__c;
      } else if (check.ExpectedValueSource__c == 'RECORD_FORMULA') {
        try {
          side.value = evaluator.formulaEvaluatorForEvaluation()
            .resolveFormulaSingleValue(
              check.ExpectedRecordFormula__c,
              record,
              check.FormulaResultType__c
            );
        } catch (RecordHealthCheckFormulaEvaluator.FormulaEvaluationException fex) {
          throw new RecordHealthCheckEvaluatorException(
            fex.reasonCode,
            fex.getMessage()
          );
        }
      } else if (check.ExpectedValueSource__c == 'COMPARISON_QUERY') {
        resolveComparisonQuery(check, record, result, evaluator, maxRows, side);
      }
    }
    return side;
  }
  private static void resolveComparisonQuery(
    Record_Health_Check__mdt check,
    SObject record,
    RecordHealthCheckInternalResult result,
    RecordHealthCheckSoqlEvaluator evaluator,
    Integer maxRows,
    Side side
  ) {
    String compSoql = evaluator.bindTokens(check.ComparisonQuery__c, record);
    List<SObject> compRows = evaluator.runQueryForEvaluation(compSoql, maxRows);
    side.rows = compRows;
    result.queryComparisonRows = compRows;
    if (
      compRows.isEmpty() && evaluator.isScopeZeroCountForEvaluation(compSoql)
    ) {
      side.value = 0;
    } else if (compRows.isEmpty()) {
      side.value = null;
      side.queryWasEmpty = true;
    } else if (compRows.size() == 1) {
      side.row = compRows[0];
      side.value = evaluator.readQueryFieldValue(
        compRows[0],
        check.ComparisonQueryField__c
      );
    } else {
      throw new RecordHealthCheckEvaluatorException(
        'MULTIPLE_ROWS_RETURNED',
        'Comparison Query returned ' +
          compRows.size() +
          ' rows for a single-value comparison. ' +
          'Add a LIMIT 1 clause or use AnyRowPasses/AllRowsPass mode.'
      );
    }
  }
}
