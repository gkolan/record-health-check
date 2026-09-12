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
    RecordHealthCheckCurrencySupport.requireRuntimeSafeConfiguration(check);
    Boolean isListOperator =
      check.ComparisonOperator__c == 'LIST_CONTAINS_ANY' ||
      check.ComparisonOperator__c == 'LIST_CONTAINS_NONE';
    Boolean isUnaryOperator =
      check.ComparisonOperator__c == 'IS_BLANK' ||
      check.ComparisonOperator__c == 'IS_NOT_BLANK';
    Integer maxRows = check.MaxQueryRows__c != null
      ? (Integer) check.MaxQueryRows__c
      : DEFAULT_MAX_ROWS;
    RecordHealthCheckSoqlValueResolver.Side primary = RecordHealthCheckSoqlValueResolver.primary(
      check,
      record,
      result,
      evaluator,
      isListOperator,
      maxRows
    );
    if (primary.earlyResult != null) {
      return primary.earlyResult;
    }
    Object primaryValue = primary.value;
    List<Object> primaryList = primary.values;
    List<SObject> primaryRows = primary.rows;
    RecordHealthCheckSoqlValueResolver.Side comparison = RecordHealthCheckSoqlValueResolver.comparison(
      check,
      record,
      result,
      evaluator,
      isListOperator,
      isUnaryOperator,
      maxRows
    );
    Object comparisonValue = comparison.value;
    List<Object> comparisonList = comparison.values;
    List<SObject> comparisonRows = comparison.rows;
    Boolean comparisonQueryWasEmpty = comparison.queryWasEmpty;
    // ── Apply operator ──────────────────────────────────────────────────
    Boolean passed;
    if (!isListOperator) {
      requireCompatibleCurrencyUnits(check, primaryRows, comparisonRows);
    }
    passed = applyComparison(
      check,
      primaryValue,
      primaryList,
      comparisonValue,
      comparisonList,
      isListOperator,
      isUnaryOperator
    );
    if (passed == null) {
      // An indeterminate operator result has two distinct causes that must NOT
      // be treated alike. A genuine zero-rows result is governed by
      // NoRowsResult__c; a present-but-null value is governed by the empty-value
      // handling (EmptyValueHandling__c) and resolves to SKIPPED. Routing the
      // second through NoRowsResult__c makes "null value + no-rows = Fail"
      // wrongly FAIL, so the two are separated below.
      Boolean zeroRows = isZeroRows(
        isListOperator,
        comparisonList,
        primaryList,
        comparisonQueryWasEmpty
      );
      return zeroRows
        ? evaluator.buildEmptyOrNullResult(check, result, primaryList)
        : evaluator.buildNullIndeterminateResult(result);
    }
    renderComparison(
      check,
      record,
      result,
      evaluator,
      isListOperator,
      primary,
      comparison
    );
    attachValueSources(
      check,
      result,
      evaluator,
      primaryValue,
      primaryList,
      comparisonValue,
      comparisonList,
      isUnaryOperator,
      isListOperator
    );
    applyOutcome(result, check, passed, primaryValue, comparisonValue);
    return result;
  }
  /** Renders resolved query values while retaining side-specific currency and row context. */
  private static void renderComparison(
    Record_Health_Check__mdt check,
    SObject record,
    RecordHealthCheckInternalResult result,
    RecordHealthCheckSoqlEvaluator evaluator,
    Boolean isListOperator,
    RecordHealthCheckSoqlValueResolver.Side primary,
    RecordHealthCheckSoqlValueResolver.Side comparison
  ) {
    Object primaryValue = primary.value;
    List<Object> primaryList = primary.values;
    SObject primaryRow = primary.row;
    List<SObject> primaryRows = primary.rows;
    Object comparisonValue = comparison.value;
    List<Object> comparisonList = comparison.values;
    SObject comparisonRow = comparison.row;
    List<SObject> comparisonRows = comparison.rows;
    // How the queried field is defined in Setup fills in the format when the
    // author left Display: Value Format on Auto, and the row names the currency
    // its amounts are in. On a list-membership check the value under test comes
    // from the record rather than a query row, so the field definition is read
    // from the record — a Find in List Formula that names a field, such as
    // AnnualRevenue, reads as money with no Check change. Anything longer than a
    // field path does not resolve and is left on Auto.
    String displayFormat = primaryDisplayFormat(
      check,
      record,
      primaryRow,
      isListOperator
    );
    // When the query read the same record the card is on, that record's currency
    // is this amount's currency. A query over a different object is left on the
    // running user's currency instead of borrowing an unrelated one.
    String displayIsoCode = primaryCurrencyIsoCode(
      check,
      record,
      primaryRow,
      isListOperator
    );
    // A comparison query retains its own currency, which may differ from Found.
    // A fixed value or record formula uses the Found currency.
    String comparisonIsoCode = comparisonRow == null
      ? displayIsoCode
      : RecordHealthCheckDisplayFormat.currencyIsoCodeFor(
          comparisonRow,
          record,
          check.ComparisonQueryField__c
        );
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
    if (
      primaryList != null &&
      check.QueryResultHandling__c == 'ALL_ROWS_PASS'
    ) {
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
  }
  private static String primaryDisplayFormat(
    Record_Health_Check__mdt check,
    SObject record,
    SObject primaryRow,
    Boolean isListOperator
  ) {
    return isListOperator
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
  }
  private static String primaryCurrencyIsoCode(
    Record_Health_Check__mdt check,
    SObject record,
    SObject primaryRow,
    Boolean isListOperator
  ) {
    return isListOperator
      ? RecordHealthCheckDisplayFormat.currencyIsoCodeFrom(record)
      : RecordHealthCheckDisplayFormat.currencyIsoCodeFor(
          primaryRow,
          record,
          check.SourceQueryField__c
        );
  }
  /** Selects the configured comparison without changing value-source resolution. */
  private static Boolean applyComparison(
    Record_Health_Check__mdt check,
    Object primaryValue,
    List<Object> primaryList,
    Object comparisonValue,
    List<Object> comparisonList,
    Boolean isListOperator,
    Boolean isUnaryOperator
  ) {
    Boolean passed;
    if (isListOperator) {
      passed = RecordHealthCheckComparisonEngine.applyListComparison(
        check.ComparisonOperator__c,
        primaryValue,
        comparisonList,
        check
      );
    } else if (primaryList != null) {
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
    return passed;
  }
  /** Attaches the original value and row-count provenance after display rendering. */
  private static void attachValueSources(
    Record_Health_Check__mdt check,
    RecordHealthCheckInternalResult result,
    RecordHealthCheckSoqlEvaluator evaluator,
    Object primaryValue,
    List<Object> primaryList,
    Object comparisonValue,
    List<Object> comparisonList,
    Boolean isUnaryOperator,
    Boolean isListOperator
  ) {
    result.actualValueSource = new RecordHealthCheckValueSource.Detail(
      evaluator.describePrimarySource(check),
      primaryList != null
        ? RecordHealthCheckValueSource.rowCount(primaryList.size())
        : evaluator.rawLabel(primaryValue),
      null
    );
    if (isUnaryOperator) {
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
  }
  /**
   * Tells a genuine zero-rows outcome apart from a present-but-null value.
   *
   * The two must not be treated alike: zero rows is governed by
   * NoRowsResult__c, while a null value is governed by EmptyValueHandling__c
   * and resolves to SKIPPED. Routing the second through NoRowsResult__c makes
   * "null value plus no rows" wrongly FAIL.
   */
  private static Boolean isZeroRows(
    Boolean isListOperator,
    List<Object> comparisonList,
    List<Object> primaryList,
    Boolean comparisonQueryWasEmpty
  ) {
    if (isListOperator) {
      return comparisonList == null || comparisonList.isEmpty();
    }
    if (primaryList != null) {
      return primaryList.isEmpty();
    }
    return comparisonQueryWasEmpty;
  }
  private static void requireCompatibleCurrencyUnits(
    Record_Health_Check__mdt check,
    List<SObject> primaryRows,
    List<SObject> comparisonRows
  ) {
    RecordHealthCheckCurrencySupport.requireCompatibleQueryUnits(
      check.SourceQuery__c,
      check.SourceQueryField__c,
      primaryRows,
      check.ComparisonQuery__c,
      check.ComparisonQueryField__c,
      comparisonRows,
      check.ExpectedValueSource__c == 'FIXED_VALUE'
        ? check.ExpectedCurrencyIsoCode__c
        : null
    );
  }
  private static void applyOutcome(
    RecordHealthCheckInternalResult result,
    Record_Health_Check__mdt check,
    Boolean passed,
    Object primaryValue,
    Object comparisonValue
  ) {
    result.evaluationFound = RecordHealthCheckQueryEvaluatorSupport.typedOperand(
      primaryValue
    );
    result.evaluationExpected = RecordHealthCheckQueryEvaluatorSupport.typedOperand(
      comparisonValue
    );
    result.operandsRecorded = true;
    if (passed) {
      result.status = 'PASS';
      return;
    }
    result.status = 'FAIL';
    result.severity = check.FailureSeverity__c;
    result.message = check.FailureMessage__c;
  }
}
