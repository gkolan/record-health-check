/**
 * Resolves and formats the optional Found and Expected formulas for Formula
 * checks without changing the already-determined business verdict.
 */
public with sharing class RecordHealthCheckFormulaDisplay {
  private static final Object ABSENT = new Map<String, Object>();

  /**
   * Applies display-only formula values and author-defined display text.
   *
   * @param check Formula Check supplying display configuration.
   * @param record Evaluated record used by FormulaEval and merge tokens.
   * @param result Mutable internal result whose display values are populated.
   * @param evaluator Formula evaluator used for typed single-value resolution.
   * @param runContext Optional correlation context for diagnostic logging.
   */
  public static void apply(
    Record_Health_Check__mdt check,
    SObject record,
    RecordHealthCheckInternalResult result,
    RecordHealthCheckFormulaEvaluator evaluator,
    RecordHealthCheckRunContext runContext
  ) {
    String displayIsoCode = RecordHealthCheckDisplayFormat.currencyIsoCodeFrom(
      record
    );
    applyFound(check, record, result, evaluator, runContext, displayIsoCode);
    applyExpected(check, record, result, evaluator, runContext, displayIsoCode);
    if (result.expectedValue == null) {
      result.expectedValue = check.PassConditionFormula__c;
      result.expectedValueLabel = RecordHealthCheckInternalResult.PASSES_WHEN_LABEL;
      result.expectedValueSource = new RecordHealthCheckValueSource.Detail(
        'Pass/Fail condition',
        check.PassConditionFormula__c,
        null
      );
    }
    RecordHealthCheckTemplateService.applyFoundExpectedText(
      check,
      record,
      result
    );
  }

  private static void applyFound(
    Record_Health_Check__mdt check,
    SObject record,
    RecordHealthCheckInternalResult result,
    RecordHealthCheckFormulaEvaluator evaluator,
    RecordHealthCheckRunContext runContext,
    String displayIsoCode
  ) {
    if (String.isBlank(check.DisplayFoundFormula__c)) {
      return;
    }
    Object found = resolve(
      check.DisplayFoundFormula__c,
      record,
      check.FormulaResultType__c,
      evaluator,
      runContext
    );
    if (found == ABSENT) {
      return;
    }
    Object displayFound = RecordHealthCheckDisplayFormat.valueForDisplay(
      found,
      check.DisplayValueFormat__c,
      record,
      check.DisplayFoundFormula__c
    );
    result.actualValue = RecordHealthCheckComparisonDisplay.formatValue(
      displayFound,
      check.DisplayValueFormat__c,
      displayIsoCode
    );
    result.actualValueSource = new RecordHealthCheckValueSource.Detail(
      'Found formula',
      found == null ? 'null' : String.valueOf(found),
      null
    );
  }

  private static void applyExpected(
    Record_Health_Check__mdt check,
    SObject record,
    RecordHealthCheckInternalResult result,
    RecordHealthCheckFormulaEvaluator evaluator,
    RecordHealthCheckRunContext runContext,
    String displayIsoCode
  ) {
    if (String.isBlank(check.DisplayExpectedFormula__c)) {
      return;
    }
    Object expected = resolve(
      check.DisplayExpectedFormula__c,
      record,
      check.FormulaResultType__c,
      evaluator,
      runContext
    );
    if (expected == ABSENT) {
      return;
    }
    Object displayExpected = RecordHealthCheckDisplayFormat.valueForDisplay(
      expected,
      check.DisplayValueFormat__c,
      record,
      check.DisplayExpectedFormula__c
    );
    result.expectedValue = RecordHealthCheckComparisonDisplay.formatValue(
      displayExpected,
      check.DisplayValueFormat__c,
      displayIsoCode
    );
    result.expectedValueSource = new RecordHealthCheckValueSource.Detail(
      'Expected formula',
      expected == null ? 'null' : String.valueOf(expected),
      null
    );
  }

  private static Object resolve(
    String formulaExpression,
    SObject record,
    String declaredReturnType,
    RecordHealthCheckFormulaEvaluator evaluator,
    RecordHealthCheckRunContext runContext
  ) {
    try {
      return evaluator.resolveFormulaSingleValue(
        formulaExpression,
        record,
        declaredReturnType
      );
    } catch (Exception ex) {
      RecordHealthCheckLogger.log(
        RecordHealthCheckLogger.Level.WARN,
        runContext?.runId,
        null,
        record?.Id,
        null,
        'DISPLAY_FORMULA_INVALID',
        new Map<String, Object>{ 'declaredReturnType' => declaredReturnType },
        ex
      );
      return ABSENT;
    }
  }
}
