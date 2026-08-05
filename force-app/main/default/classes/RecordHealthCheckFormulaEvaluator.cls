/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

public with sharing class RecordHealthCheckFormulaEvaluator {
  private RecordHealthCheckRunContext runContext;
  // Track FormulaEval calls for the whole Apex transaction to avoid hitting
  // Salesforce's 100-call platform limit, which is itself transaction-wide
  // and uncatchable. This static accumulates for the life of the transaction and
  // is intentionally NEVER reset per check: resetting a framework counter mid
  // transaction made the guard lie when a caller loops evaluate() (Flow, batch
  // anonymous Apex). Each real LWC request is its own transaction, so the counter
  // naturally starts at zero there without any reset. A 5-call safety margin
  // leaves room for applicability checks on the remaining checks to still resolve.
  // Tests reset this counter directly to isolate per-method counts.
  @TestVisible
  private static Integer formulaEvalCallCount = 0;
  private static final Integer FORMULA_EVAL_TX_LIMIT = 100;
  private static final Integer FORMULA_EVAL_SAFETY_MARGIN = 5;
  public static final Integer FORMULA_CALL_BUDGET =
    FORMULA_EVAL_TX_LIMIT - FORMULA_EVAL_SAFETY_MARGIN;

  // evaluateFormulaAnyType tries up to 8 return types and every failed
  // attempt consumes a real, platform-counted FormulaEval call. When a caller
  // loops evaluate() over many records in one transaction (Flow, batch, anonymous
  // Apex), retrying the same single-value formula per record multiplies that cost and
  // can exhaust the 100-call budget. Caching the return type that first resolved a
  // given formula (keyed by SObject type + expression) lets the second and later
  // records resolve in a single call. Cached for the current transaction, like formulaEvalCallCount.
  @TestVisible
  private static Map<String, formulaeval.FormulaReturnType> resolvedReturnTypeByFormula = new Map<String, formulaeval.FormulaReturnType>();

  /** Returns FormulaEval calls consumed by this framework transaction. */
  public static Integer callsUsed() {
    return formulaEvalCallCount;
  }

  public RecordHealthCheckFormulaEvaluator withRunContext(
    RecordHealthCheckRunContext value
  ) {
    runContext = value;
    return this;
  }

  /**
   * Evaluates a Formula check (EvaluationType__c = Formula).
   * Also used internally by the SOQL evaluator for:
   * - ApplicabilityFormula__c evaluation;
   * - ExpectedRecordFormula__c comparison-side resolution; and
   * - FindInListFormula__c as the primary value for list-membership checks.
   */
  public RecordHealthCheckInternalResult evaluate(
    Record_Health_Check_Rule__mdt rule,
    Id recordId,
    SObject record
  ) {
    Long startMs = System.currentTimeMillis();
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.ruleDeveloperName = rule.DeveloperName;
    result.label = rule.CheckTitle__c;
    result.priority = rule.EvaluationOrder__c;
    result.evaluatorType = 'FORMULA';

    try {
      // FLS / accessibility check on fields referenced in the formula
      // FormulaEval will surface an exception if a field is inaccessible;
      // we catch that below and map it to FIELD_NOT_ACCESSIBLE.
      Boolean evalResult = (Boolean) evaluateFormula(
        rule.PassConditionFormula__c,
        record
      );
      result = applyEvaluationResult(rule, record, result, evalResult);
    } catch (Exception ex) {
      result = applyEvaluationException(rule, result, ex);
    }

    result.durationMs = System.currentTimeMillis() - startMs;
    return result;
  }

  private RecordHealthCheckInternalResult applyEvaluationException(
    Record_Health_Check_Rule__mdt rule,
    RecordHealthCheckInternalResult result,
    Exception ex
  ) {
    result.status = 'UNABLE_TO_EVALUATE';
    if (ex instanceof System.NoAccessException) {
      result.reasonCode = 'FIELD_NOT_ACCESSIBLE';
    } else if (ex instanceof FormulaEvaluationException) {
      // Preserve the specific reason (e.g. FORMULA_EVAL_LIMIT) so a transaction
      // hitting the FormulaEval budget is not mislabeled as INVALID_FORMULA.
      result.reasonCode = ((FormulaEvaluationException) ex).reasonCode;
    } else {
      result.reasonCode = 'INVALID_FORMULA';
    }
    result.message = safeCannotEvaluateMessage(rule);
    result.detailMessage = ex.getMessage();
    return result;
  }

  private RecordHealthCheckInternalResult applyEvaluationResult(
    Record_Health_Check_Rule__mdt rule,
    SObject record,
    RecordHealthCheckInternalResult result,
    Boolean evalResult
  ) {
    if (evalResult == null) {
      // Null from FormulaEval means the formula could not resolve — typically
      // a null relationship traversal (e.g. Parent.Field when Parent is null)
      // or an inaccessible field. Treating null as FAIL produces false failures
      // so we surface it as UNABLE_TO_EVALUATE instead.
      result.status = 'UNABLE_TO_EVALUATE';
      result.reasonCode = 'INVALID_FORMULA';
      result.message = safeCannotEvaluateMessage(rule);
      result.detailMessage = 'Formula returned null. The formula may reference a null relationship or an inaccessible field.';
    } else {
      Boolean passed = evalResult;
      // Set Found / Expected for display. By default a Formula check has no
      // separable record value vs operand — the condition lives inside the
      // expression — so we echo the formula as the pass/fail condition under a
      // "Passes when" key (e.g. Passes when ISBLANK(BillingCity)). When the admin
      // has declared explicit Found/Expected single-value formulas, those resolved
      // values replace the echo so a balance check can show readable numbers.
      RecordHealthCheckFormulaDisplay.apply(
        rule,
        record,
        result,
        this,
        runContext
      );
      if (passed) {
        result.status = 'PASS';
      } else {
        result.status = 'FAIL';
        result.severity = rule.FailureSeverity__c;
        result.message = resolveMergeFields(
          rule.FailureMessage__c,
          record,
          rule,
          result,
          true
        );
      }
    }
    return result;
  }

  /**
   * Evaluates the applicability formula for a rule.
   * Returns
   * true — gate passes, main evaluator should run
   * false — gate fails, return SKIPPED
   * null — gate could not be evaluated, return UNABLE_TO_EVALUATE
   * The out-param reasonCode[0] is set when null is returned.
   */
  public Boolean evaluateApplicabilityFormula(
    String formulaExpression,
    SObject record,
    String[] reasonCodeOut
  ) {
    try {
      Object result = evaluateFormula(formulaExpression, record);
      if (result instanceof Boolean) {
        return (Boolean) result;
      }
      // Non-boolean from applicability formula is a config error
      reasonCodeOut[0] = 'INVALID_FORMULA';
      return null;
    } catch (FormulaEvaluationException fex) {
      // preserve the typed reason (e.g. FORMULA_EVAL_LIMIT) instead of
      // re-deriving it from the message, which would collapse it to
      // INVALID_FORMULA and hide the real cause from the admin. Mirrors the
      // resolveFormulaSingleValue path, which already preserves the typed reason code.
      reasonCodeOut[0] = fex.reasonCode;
      return null;
    } catch (Exception ex) {
      reasonCodeOut[0] = classifyFormulaException(ex);
      return null;
    }
  }

  /**
   * Resolves a formula expression to a single-value value for use as the primary
   * operand in list-membership checks or as a formula-derived comparison value.
   * Returns null if the formula resolves to null (blank parent traversal etc.).
   * Throws RecordHealthCheckFormulaException if the formula cannot be evaluated.
   */
  public Object resolveFormulaSingleValue(
    String formulaExpression,
    SObject record
  ) {
    return resolveFormulaSingleValue(formulaExpression, record, 'AUTO');
  }

  /**
   * overload accepting the admin-declared return type (the
   * FormulaResultType__c picklist value). An explicit type is evaluated once.
   * Only AUTO may probe the supported return types.
   */
  public Object resolveFormulaSingleValue(
    String formulaExpression,
    SObject record,
    String declaredReturnType
  ) {
    try {
      return evaluateFormulaAnyType(
        formulaExpression,
        record,
        mapDeclaredReturnType(declaredReturnType)
      );
    } catch (FormulaEvaluationException fex) {
      throw fex;
    } catch (Exception ex) {
      throw new FormulaEvaluationException(
        classifyFormulaException(ex),
        ex.getMessage()
      );
    }
  }

  /**
   * Maps FormulaResultType__c. Only explicit AUTO tries supported types.
   */
  @TestVisible
  private formulaeval.FormulaReturnType mapDeclaredReturnType(
    String declaredReturnType
  ) {
    if (declaredReturnType == 'AUTO') {
      return null;
    }
    switch on declaredReturnType {
      when 'BOOLEAN' {
        return formulaeval.FormulaReturnType.BOOLEAN;
      }
      when 'NUMBER' {
        return formulaeval.FormulaReturnType.DECIMAL;
      }
      when 'DATE' {
        return formulaeval.FormulaReturnType.DATE;
      }
      when 'DATETIME' {
        return formulaeval.FormulaReturnType.DATETIME;
      }
      when 'TEXT' {
        return formulaeval.FormulaReturnType.STRING;
      }
      when else {
        throw new FormulaEvaluationException(
          'INVALID_CONFIG',
          'Formula Result Type is required and must be AUTO, BOOLEAN, NUMBER, DATE, DATETIME, or TEXT.'
        );
      }
    }
  }

  // ─── Internal evaluation ──────────────────────────────────────────────────

  /**
   * Calls the FormulaEval API (requires API v63.0+, Spring '25 GA).
   * Null parent traversal returns null rather than throwing — the caller
   * is responsible for treating null as false / no-match as appropriate.
   * withReturnType() is required by the FormulaBuilder API; defaults to Boolean
   * for all formula-check and applicability paths.
   */
  private Object evaluateFormula(String formulaExpression, SObject record) {
    return evaluateFormula(
      formulaExpression,
      record,
      formulaeval.FormulaReturnType.BOOLEAN
    );
  }

  private Object evaluateFormula(
    String formulaExpression,
    SObject record,
    formulaeval.FormulaReturnType returnType
  ) {
    // guard against the 100-call-per-transaction FormulaEval platform limit
    if (formulaEvalCallCount >= FORMULA_CALL_BUDGET) {
      throw new FormulaEvaluationException(
        'FORMULA_EVAL_LIMIT',
        'FormulaEval transaction limit approaching (' +
          formulaEvalCallCount +
          ' calls used). Split this Check Set or replace formula-based checks with SOQL checks.'
      );
    }
    formulaEvalCallCount++;
    return Formula.builder()
      .withType(record.getSObjectType())
      .withReturnType(returnType)
      .withFormula(formulaExpression)
      .treatNumericNullAsZero(true)
      .build()
      .evaluate(record);
  }

  private Object evaluateFormulaAnyType(
    String formulaExpression,
    SObject record,
    formulaeval.FormulaReturnType declaredType
  ) {
    // An administrator-declared type is a strict contract. Do not reinterpret a
    // mismatch as AUTO because that hides configuration errors.
    if (declaredType != null) {
      return evaluateFormula(formulaExpression, record, declaredType);
    }

    // AUTO may reuse a type that already resolved this formula in this
    // transaction, then probe the supported types if that cached choice fails.
    String cacheKey =
      String.valueOf(record.getSObjectType()) +
      '|' +
      formulaExpression;
    formulaeval.FormulaReturnType preferredType = resolvedReturnTypeByFormula.get(
      cacheKey
    );
    if (preferredType != null) {
      try {
        Object value = evaluateFormula(
          formulaExpression,
          record,
          preferredType
        );
        resolvedReturnTypeByFormula.put(cacheKey, preferredType);
        return value;
      } catch (Exception ex) {
        resolvedReturnTypeByFormula.remove(cacheKey);
      }
    }

    // Order matters: each failed attempt burns a FormulaEval API call (limit 100/tx).
    // BOOLEAN first (most formula checks), DECIMAL next (numbers/currency/percent)
    // DATE/DATETIME before STRING so temporal fields resolve in 3–4 calls rather than 7–8.
    // STRING is a catch-all that can convert almost any type, so it comes after specifics.
    List<formulaeval.FormulaReturnType> typesToTry = new List<formulaeval.FormulaReturnType>{
      formulaeval.FormulaReturnType.BOOLEAN,
      formulaeval.FormulaReturnType.DECIMAL,
      formulaeval.FormulaReturnType.DATE,
      formulaeval.FormulaReturnType.DATETIME,
      formulaeval.FormulaReturnType.STRING,
      formulaeval.FormulaReturnType.DOUBLE,
      formulaeval.FormulaReturnType.INTEGER,
      formulaeval.FormulaReturnType.LONG
    };
    Exception lastException;
    for (formulaeval.FormulaReturnType rt : typesToTry) {
      try {
        Object value = evaluateFormula(formulaExpression, record, rt);
        resolvedReturnTypeByFormula.put(cacheKey, rt);
        return value;
      } catch (Exception ex) {
        lastException = ex;
      }
    }
    throw lastException;
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  private String classifyFormulaException(Exception fex) {
    String msg = fex.getMessage();
    if (msg != null && msg.containsIgnoreCase('access')) {
      return 'FIELD_NOT_ACCESSIBLE';
    }
    return 'INVALID_FORMULA';
  }

  /**
   * Resolves {!record.FieldName} merge tokens in a message string using the record's
   * field values. Valid tokens whose field value is null render as an empty string;
   * malformed or unsupported tokens are rejected during rule loading.
   */
  public String resolveMergeFields(String template, SObject record) {
    return RecordHealthCheckTemplateService.resolveDisplay(
      template,
      new RecordHealthCheckMergeContext().withRecord(record).withRun(runContext)
    );
  }

  public String resolveMergeFields(
    String template,
    SObject record,
    Record_Health_Check_Rule__mdt rule,
    RecordHealthCheckInternalResult result,
    Boolean resultFinalized
  ) {
    return RecordHealthCheckTemplateService.resolveDisplay(
      template,
      new RecordHealthCheckMergeContext()
        .withRecord(record)
        .withRule(rule)
        .withResult(result, resultFinalized)
        .withRun(runContext)
    );
  }

  /**
   * Like resolveMergeFields, but URL-encodes each substituted value so a token
   * such as {!record.Name} (which may contain spaces or reserved characters) is safe to
   * drop into a URL query string. The surrounding URL template is left untouched;
   * only the resolved token values are encoded. Used for remediation deep links.
   */
  public String resolveUrlMergeFields(String template, SObject record) {
    return RecordHealthCheckTemplateService.resolveUrl(
      template,
      new RecordHealthCheckMergeContext().withRecord(record).withRun(runContext)
    );
  }

  public String resolveUrlMergeFields(
    String template,
    SObject record,
    Record_Health_Check_Rule__mdt rule,
    RecordHealthCheckInternalResult result
  ) {
    return RecordHealthCheckTemplateService.resolveUrl(
      template,
      new RecordHealthCheckMergeContext()
        .withRecord(record)
        .withRule(rule)
        .withResult(result, true)
        .withRun(runContext)
    );
  }

  private String safeCannotEvaluateMessage(Record_Health_Check_Rule__mdt rule) {
    return String.isNotBlank(rule.UnableToEvaluateMessage__c)
      ? rule.UnableToEvaluateMessage__c
      : 'This check could not be evaluated. Contact your administrator.';
  }

  // ─── Exception for single-value resolution failures ─────────────────────────────

  public class FormulaEvaluationException extends Exception {
    public String reasonCode;
    public FormulaEvaluationException(String reasonCode, String message) {
      this(message);
      this.reasonCode = reasonCode;
    }
  }
}
