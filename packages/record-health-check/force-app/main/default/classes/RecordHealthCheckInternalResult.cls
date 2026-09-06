/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

public class RecordHealthCheckInternalResult {
  public static final String CONTRACT_VERSION = '1.0';
  public static final String PASSES_WHEN_LABEL = 'Passes when';

  @AuraEnabled
  public String contractVersion = CONTRACT_VERSION;
  @AuraEnabled
  public String runId;
  // The expectedValueLabel a Formula check uses when it echoes its raw pass/fail
  // condition instead of a business comparison value. This "Passes when" line is
  // a technical explanation, so the engine gates it (and the raw expectedValue it
  // labels) behind explicit diagnostics permission-set assignment — business users see the
  // failure message and any display-formula Found/Expected chips only.
  @AuraEnabled
  public String checkDeveloperName;
  // Server-side only (not @AuraEnabled): the record this result was evaluated
  // against; stamped onto the lifecycle and diagnostics platform events when set.
  public Id recordId;
  // Server-side only and transient: the rows the Check's own queries returned,
  // held just long enough for {!rhcQuery...} tokens to be resolved into the
  // finished message, label, and URL. Not @AuraEnabled, so they never reach the
  // browser, and transient, so they are excluded from JSON serialization,
  // platform events, and view state. Nothing outside template resolution may
  // read them, and nothing may retain them past this transaction.
  public transient List<SObject> querySourceRows;
  public transient List<SObject> queryComparisonRows;
  @AuraEnabled
  public String label;
  @AuraEnabled
  public String status; // PASS, FAIL, UNABLE_TO_EVALUATE, SKIPPED, ERROR
  @AuraEnabled
  public String severity; // CRITICAL, WARNING, INFO — only when status == FAIL
  @AuraEnabled
  public String message;
  @AuraEnabled
  // The Found text the card reads. It starts as what the record or query
  // produced, and Display: Found Text replaces it. Anything answering "what did
  // this Check find?" calls frameworkFound() instead; anything comparing calls
  // evaluationFound. Reading this field directly reports card wording.
  public String actualValue;
  @AuraEnabled
  // The Expected text the card reads: the operator and the operand together,
  // such as "to equal Manufacturing". It is a sentence, not a value. A caller
  // comparing against the operand reads evaluationExpected, and the operator
  // travels separately on the evaluation result.
  public String expectedValue;
  // Server-side display values used while an evaluator result is shaped for
  // the Lightning response. Named formats use official uppercase API names.
  public Object actualDisplayValue;
  public Object expectedDisplayValue;
  public String actualDisplayFormat;
  public String expectedDisplayFormat;
  public String actualCurrencyIsoCode;
  public String expectedCurrencyIsoCode;
  @AuraEnabled
  public String expectedValueLabel; // overrides the UI's default "Expected" key when set — e.g. "Passes when" for a Formula check echoing its pass/fail condition rather than a comparison value
  @AuraEnabled
  public String actualValueDetail; // value-source note for the Found side — only with explicit diagnostics assignment
  @AuraEnabled
  public String expectedValueDetail; // value-source note for the Expected side — only when the same permission is held
  // Structured value source the evaluators fill in; the engine renders these into
  // the two *Detail strings above and gates them by permission. Intentionally not
  // @AuraEnabled — the public contract is the rendered strings, not this shape.
  public RecordHealthCheckValueSource.Detail actualValueSource;
  public RecordHealthCheckValueSource.Detail expectedValueSource;
  public String detailMessage; // intentionally not @AuraEnabled — raw exception text, internal only
  @AuraEnabled
  public String adminDetailMessage; // set from detailMessage when ShowDiagnostics__c is on
  @AuraEnabled
  public RecordHealthCheckAdminDetail adminDetail; // null unless authorized diagnostics is active
  // Server-only canonical incident. The authorized display adapter exposes it
  // through adminDetail; public evaluation responses never serialize it.
  public RecordHealthCheckDiagnosticIncident diagnosticIncident;
  @AuraEnabled
  public String actionLabel; // label for the read-only remediation link — from ActionLabel__c, shown only on FAIL
  @AuraEnabled
  public String actionUrl; // resolved + sanitized remediation deep link — from ActionUrl__c with {!record.FieldName} tokens bound
  @AuraEnabled
  public String fixInstructions; // optional guidance shown beside the remediation link — from FixMessage__c
  @AuraEnabled
  public String reasonCode;
  @AuraEnabled
  public Decimal priority;
  @AuraEnabled
  public Long durationMs;
  @AuraEnabled
  public String evaluatorType; // Formula, Query, CompareTwoQueries, Apex
  // Typed machine values used to build the public evaluation result. These are
  // never serialized directly to Aura consumers.
  // Server-side only (not @AuraEnabled): the Found and Expected values the
  // framework computed, kept before Display: Found Text or Display: Expected
  // Text replaced them. Display text changes what the card reads, and nothing
  // else: {!rhcResult.foundValue} and the machine result must still see the
  // value the Check actually found.
  public String frameworkActualValue;
  public String frameworkExpectedValue;
  /**
   * True once an evaluator has recorded the operands it compared, even when one
   * side has none: `IS_NOT_BLANK` expects no value, and saying so is the honest
   * answer. Without this, a null typed value was indistinguishable from "not
   * recorded", and the result mapper filled the gap from the card sentence.
   */
  public Boolean operandsRecorded = false;
  public RecordHealthCheckValue evaluationFound;
  public RecordHealthCheckValue evaluationExpected;
  public String evaluationComparisonOperator;

  /**
   * The Found value anything other than the card should read.
   *
   * Display: Found Text replaces what the card reads, so `actualValue` may hold
   * author wording rather than the value the Check found. Every consumer that
   * answers "what did this Check find?" — the machine result, merge tokens,
   * diagnostics — asks here instead of reading the field, so a future surface
   * cannot quietly report the wording as the answer.
   */
  public String frameworkFound() {
    return frameworkActualValue != null ? frameworkActualValue : actualValue;
  }

  /** The Expected value anything other than the card should read. */
  public String frameworkExpected() {
    return frameworkExpectedValue != null
      ? frameworkExpectedValue
      : expectedValue;
  }
}
