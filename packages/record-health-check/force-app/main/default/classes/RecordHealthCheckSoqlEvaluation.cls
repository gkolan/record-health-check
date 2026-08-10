/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * @description Coordinates SOQL-backed check evaluation while the facade owns scoped query state.
 * SPDX-License-Identifier: Apache-2.0
 */
public with sharing class RecordHealthCheckSoqlEvaluation {
  private static final Integer DEFAULT_MAX_ROWS = RecordHealthCheckConstants.FRAMEWORK_MAX_ROWS;

  /** Evaluates one SOQL-backed check using the owning evaluator's scoped query state. */
  public static RecordHealthCheckInternalResult evaluate(
    Record_Health_Check__mdt check,
    Id recordId,
    SObject record,
    RecordHealthCheckInternalResult result,
    RecordHealthCheckSoqlEvaluator evaluator
  ) {
    Boolean isListOperator =
      check.ComparisonOperator__c == 'LIST_CONTAINS_ANY' ||
      check.ComparisonOperator__c == 'LIST_CONTAINS_NONE';
    Boolean isUnaryOperator =
      check.ComparisonOperator__c == 'IS_BLANK' ||
      check.ComparisonOperator__c == 'IS_NOT_BLANK';
    Integer maxRows = check.MaxQueryRows__c != null
      ? (Integer) check.MaxQueryRows__c
      : DEFAULT_MAX_ROWS;

    // ── Resolve primary value / list ──────────────────────────────────────
    Object primaryValue = null;
    List<Object> primaryList = null;
    // Kept for the display step: the row tells the formatter how the queried
    // field is defined in Setup, and which currency the row's amounts are in.
    SObject primaryRow = null;
    // A list preview labels each entry with its own row's currency.
    List<SObject> primaryRows = null;

    if (isListOperator) {
      // List-membership mode: primary side comes from FindInListFormula__c.
      try {
        primaryValue = evaluator.formulaEvaluatorForEvaluation()
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

      if (check.QueryResultHandling__c == 'ONE_RESULT') {
        if (rows.isEmpty() && evaluator.isScopeZeroCountForEvaluation(soql)) {
          primaryValue = 0;
        } else if (rows.isEmpty()) {
          // Aggregate COUNT() always returns 1 row (with count=0), so this branch
          // is only reached by non-aggregate queries with no matching rows.
          // Route through configured EmptyResultBehavior rather than returning 0.
          return evaluator.buildEmptyOrNullResult(check, result, null);
        } else if (rows.size() > 1) {
          throw new RecordHealthCheckEvaluatorException(
            'MULTIPLE_ROWS_RETURNED',
            'OneResult check returned ' + rows.size() + ' rows.'
          );
        } else {
          primaryRow = rows[0];
          primaryValue = evaluator.readQueryFieldValue(
            rows[0],
            check.SourceQueryField__c
          );
        }
      } else {
        // AnyRowPasses, AllRowsPass, CompareAsLists
        primaryList = evaluator.resolveFieldList(
          rows,
          check.SourceQueryField__c
        );
        primaryRows = rows;
        primaryRow = rows.isEmpty() ? null : rows[0];
      }
    }

    // ── Resolve comparison value / list ───────────────────────────────────
    Object comparisonValue = null;
    List<Object> comparisonList = null;
    // Kept for the display step, same as primaryRow: the Expected side can come
    // from its own query, in its own currency.
    SObject comparisonRow = null;
    List<SObject> comparisonRows = null;
    // distinguishes a null comparison that came from a comparison
    // query returning zero rows (→ NoRowsResult__c) from one where the field was
    // simply null on a present row (→ null-value, handled by EmptyValueHandling__c).
    Boolean comparisonQueryWasEmpty = false;

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
        comparisonList = evaluator.resolveFieldList(
          compRows,
          check.ComparisonQueryField__c
        );
        comparisonRows = compRows;
        comparisonRow = compRows.isEmpty() ? null : compRows[0];
      } else if (check.ExpectedValueSource__c == 'FIXED_VALUE') {
        comparisonValue = check.ExpectedFixedValue__c;
      } else if (check.ExpectedValueSource__c == 'RECORD_FORMULA') {
        try {
          comparisonValue = evaluator.formulaEvaluatorForEvaluation()
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
        String compSoql = evaluator.bindTokens(
          check.ComparisonQuery__c,
          record
        );
        List<SObject> compRows = evaluator.runQueryForEvaluation(
          compSoql,
          maxRows
        );
        if (
          compRows.isEmpty() &&
          evaluator.isScopeZeroCountForEvaluation(compSoql)
        ) {
          comparisonValue = 0;
        } else if (compRows.isEmpty()) {
          comparisonValue = null;
          comparisonQueryWasEmpty = true;
        } else if (compRows.size() == 1) {
          comparisonRow = compRows[0];
          comparisonValue = evaluator.readQueryFieldValue(
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

    // ── Apply operator ──────────────────────────────────────────────────
    Boolean passed;

    if (isListOperator) {
      passed = RecordHealthCheckComparisonEngine.applyListComparison(
        check.ComparisonOperator__c,
        primaryValue,
        comparisonList,
        check
      );
    } else if (primaryList != null) {
      // Multi-row primary (AnyRowPasses / AllRowsPass / CompareAsLists)
      passed = RecordHealthCheckComparisonEngine.applyMultiRecordComparison(
        check,
        primaryList,
        comparisonValue,
        comparisonList
      );
    } else if (isUnaryOperator) {
      passed = RecordHealthCheckComparisonEngine.applyUnaryComparison(
        check.ComparisonOperator__c,
        primaryValue
      );
    } else {
      passed = RecordHealthCheckComparisonEngine.applySingleComparison(
        check.ComparisonOperator__c,
        primaryValue,
        comparisonValue,
        check
      );
    }

    if (passed == null) {
      // An indeterminate operator result has two distinct causes that must NOT
      // be treated alike. A genuine zero-rows result is governed by
      // NoRowsResult__c; a present-but-null value is governed by the empty-value
      // handling (EmptyValueHandling__c) and resolves to SKIPPED. Routing the
      // second through NoRowsResult__c makes "null value + no-rows = Fail"
      // wrongly FAIL, so the two are separated below.
      Boolean zeroRows;
      if (isListOperator) {
        // List operator's comparison side is a query; the primary is a single-value.
        // Indeterminate is zero-rows only when that query returned no rows.
        zeroRows = (comparisonList == null || comparisonList.isEmpty());
      } else if (primaryList != null) {
        // Multi-row primary: empty list = zero rows; a non-empty list that still
        // resolved to null means every row's value was null-skipped.
        zeroRows = primaryList.isEmpty();
      } else {
        // OneResult / single single-value: an empty PRIMARY result was already routed
        // above, so the only zero-rows cause left is an empty comparison query.
        zeroRows = comparisonQueryWasEmpty;
      }
      return zeroRows
        ? evaluator.buildEmptyOrNullResult(check, result, primaryList)
        : evaluator.buildNullIndeterminateResult(result);
    }

    // How the queried field is defined in Setup fills in the format when the
    // author left Display: Value Format on Auto, and the row names the currency
    // its amounts are in. On a list-membership check the value under test comes
    // from the record rather than a query row, so the field definition is read
    // from the record — a Find in List Formula that names a field, such as
    // AnnualRevenue, reads as money with no Check change. Anything longer than a
    // field path does not resolve and is left on Auto.
    String displayFormat = isListOperator
      ? RecordHealthCheckDisplayFormat.formatForRow(
          check.DisplayValueFormat__c,
          record,
          check.FindInListFormula__c
        )
      : RecordHealthCheckDisplayFormat.formatForRow(
          check.DisplayValueFormat__c,
          primaryRow,
          check.SourceQueryField__c
        );
    // When the query read the same record the card is on, that record's currency
    // is this amount's currency. A query over a different object is left on the
    // running user's currency instead of borrowing an unrelated one.
    String displayIsoCode = isListOperator
      ? RecordHealthCheckDisplayFormat.currencyIsoCodeFrom(record)
      : RecordHealthCheckDisplayFormat.currencyIsoCodeFor(
          primaryRow,
          record,
          check.SourceQueryField__c
        );

    // An Expected side that came from its own query keeps that query's currency,
    // which can differ from the Found side — a corporate-currency aggregate
    // against a record's own amount, for instance. A fixed value or a formula on
    // this record has no second currency, so it stays on the Found side's.
    String comparisonIsoCode = comparisonRow == null
      ? displayIsoCode
      : RecordHealthCheckDisplayFormat.currencyIsoCodeFor(
          comparisonRow,
          record,
          check.ComparisonQueryField__c
        );

    // A list preview labels each entry with the currency of the row it came
    // from, so rows in different currencies do not all read as the first one's.
    List<String> displayIsoCodes = RecordHealthCheckDisplayFormat.currencyIsoCodesFor(
      primaryRows,
      record,
      check.SourceQueryField__c
    );
    List<String> comparisonIsoCodes = RecordHealthCheckDisplayFormat.currencyIsoCodesFor(
      comparisonRows,
      record,
      check.ComparisonQueryField__c
    );

    SObject primaryDisplayRow = isListOperator ? record : primaryRow;
    String primaryDisplayField = isListOperator
      ? check.FindInListFormula__c
      : check.SourceQueryField__c;
    Object displayPrimaryValue = RecordHealthCheckDisplayFormat.valueForDisplay(
      primaryValue,
      check.DisplayValueFormat__c,
      primaryDisplayRow,
      primaryDisplayField
    );
    List<Object> displayPrimaryList = RecordHealthCheckDisplayFormat.valuesForDisplay(
      primaryList,
      check.DisplayValueFormat__c,
      primaryRows,
      check.SourceQueryField__c
    );

    SObject expectedDisplayRow = comparisonRow;
    String expectedDisplayField = check.ComparisonQueryField__c;
    if (expectedDisplayRow == null) {
      if (check.ExpectedValueSource__c == 'RECORD_FORMULA') {
        expectedDisplayRow = record;
        expectedDisplayField = check.ExpectedRecordFormula__c;
      } else {
        expectedDisplayRow = primaryDisplayRow;
        expectedDisplayField = primaryDisplayField;
      }
    }
    Object displayComparisonValue = RecordHealthCheckDisplayFormat.valueForDisplay(
      comparisonValue,
      check.DisplayValueFormat__c,
      expectedDisplayRow,
      expectedDisplayField
    );
    List<Object> displayComparisonList = RecordHealthCheckDisplayFormat.valuesForDisplay(
      comparisonList,
      check.DisplayValueFormat__c,
      comparisonRows,
      check.ComparisonQueryField__c
    );

    // Capture what the record produced vs what the check required so the UI can
    // show the comparison on a non-passing row.
    if (
      primaryList != null &&
      check.QueryResultHandling__c == 'ALL_ROWS_PASS'
    ) {
      // "Every row must pass" over many rows: a raw value dump does not scale, so
      // summarize as a count ("1 of 5 Contacts did not pass"). An admin can
      // override the phrasing per check for friendlier wording.
      Integer totalRows = primaryList.size();
      Integer failingRows = RecordHealthCheckComparisonEngine.countFailingRows(
        check,
        primaryList,
        comparisonValue
      );
      result.actualValue = evaluator.deriveFoundSummary(
        check,
        failingRows,
        totalRows
      );
      result.expectedValue = RecordHealthCheckComparisonDisplay.describeExpectedForActual(
        check.ComparisonOperator__c,
        displayComparisonValue,
        evaluator.firstDisplayValue(displayPrimaryValue, displayPrimaryList),
        displayFormat,
        comparisonIsoCode
      );
      RecordHealthCheckTemplateService.applyFoundExpectedText(
        check,
        record,
        result,
        failingRows,
        totalRows
      );
    } else {
      String rawActualValue = primaryList != null
        ? RecordHealthCheckComparisonDisplay.formatList(
            displayPrimaryList,
            displayFormat,
            displayIsoCodes
          )
        : RecordHealthCheckComparisonDisplay.formatValue(
            displayPrimaryValue,
            displayFormat,
            displayIsoCode
          );
      String rawExpectedValue;
      if (isListOperator) {
        rawExpectedValue = RecordHealthCheckComparisonDisplay.describeExpectedList(
          check.ComparisonOperator__c,
          displayComparisonList,
          displayFormat,
          comparisonIsoCodes
        );
      } else {
        rawExpectedValue = RecordHealthCheckComparisonDisplay.describeExpectedForActual(
          check.ComparisonOperator__c,
          displayComparisonValue,
          evaluator.firstDisplayValue(displayPrimaryValue, displayPrimaryList),
          displayFormat,
          comparisonIsoCode
        );
      }
      result.actualValue = rawActualValue;
      result.expectedValue = rawExpectedValue;
      RecordHealthCheckTemplateService.applyFoundExpectedText(
        check,
        record,
        result
      );
    }

    // Value source — where each side came from and its raw value/row count, so an
    // entitled viewer can tell a true value from an empty/converted one.
    result.actualValueSource = new RecordHealthCheckValueSource.Detail(
      evaluator.describePrimarySource(check),
      primaryList != null
        ? RecordHealthCheckValueSource.rowCount(primaryList.size())
        : evaluator.rawLabel(primaryValue),
      null
    );
    if (isUnaryOperator) {
      // A unary operator has no comparison value or source, so the "source" of
      // the requirement is the operator itself. Labeling it 'Operator' (not
      // 'Expected requirement') avoids the row reading "Expected Expected …" once
      // the UI prefixes it with the "Expected" caption.
      result.expectedValueSource = new RecordHealthCheckValueSource.Detail(
        'Comparison operator',
        result.expectedValue,
        null
      );
    } else {
      result.expectedValueSource = new RecordHealthCheckValueSource.Detail(
        evaluator.describeComparisonSource(check),
        isListOperator
          ? RecordHealthCheckValueSource.rowCount(
              comparisonList == null ? 0 : comparisonList.size()
            )
          : evaluator.rawLabel(comparisonValue),
        null
      );
    }

    applyOutcome(result, check, passed);
    return result;
  }

  private static void applyOutcome(
    RecordHealthCheckInternalResult result,
    Record_Health_Check__mdt check,
    Boolean passed
  ) {
    if (passed) {
      result.status = 'PASS';
      return;
    }
    result.status = 'FAIL';
    result.severity = check.FailureSeverity__c;
    // Display templates are resolved once by ScopePipeline.finalizeDisplay.
    result.message = check.FailureMessage__c;
  }
}
