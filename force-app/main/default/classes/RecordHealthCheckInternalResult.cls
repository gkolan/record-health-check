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
  // labels) behind Record_Health_Check_View_Diagnostics — business users see the
  // failure message and any display-formula Found/Expected chips only.
  @AuraEnabled
  public String ruleDeveloperName;
  // Server-side only (not @AuraEnabled): the record this result was evaluated
  // against; stamped onto the lifecycle and diagnostics platform events when set.
  public Id recordId;
  @AuraEnabled
  public String label;
  @AuraEnabled
  public String status; // PASS, FAIL, UNABLE_TO_EVALUATE, SKIPPED, ERROR
  @AuraEnabled
  public String severity; // CRITICAL, WARNING, INFO — only when status == FAIL
  @AuraEnabled
  public String message;
  @AuraEnabled
  public String actualValue; // what the record/query produced — set on a determinate PASS/FAIL
  @AuraEnabled
  public String expectedValue; // the operator + comparison operand the value was tested against
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
  public String actualValueDetail; // value-source note for the Found side — only when Record_Health_Check_View_Diagnostics is held
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
  public RecordHealthCheckValue evaluationFound;
  public RecordHealthCheckValue evaluationExpected;
  public String evaluationComparisonOperator;
}
