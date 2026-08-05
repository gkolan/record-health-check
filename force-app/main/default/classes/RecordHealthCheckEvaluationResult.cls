/**
 * Stable result for one Rule evaluated against one record.
 */
global class RecordHealthCheckEvaluationResult {
  @AuraEnabled
  /** Record evaluated by this result. */
  global Id recordId;
  @AuraEnabled
  /** Qualified Rule identity. */
  global String ruleQualifiedApiName;
  @AuraEnabled
  /** Terminal Record Health Check status. */
  global String status;
  @AuraEnabled
  /** Configured failure severity. */
  global String severity;
  @AuraEnabled
  /** Stable reason code. */
  global String reasonCode;
  @AuraEnabled
  /** Typed value observed by the Rule. */
  global RecordHealthCheckValue found;
  @AuraEnabled
  /** Comparison operator applied to Found and Expected. */
  global String comparisonOperator;
  @AuraEnabled
  /** Typed target value used by the Rule. */
  global RecordHealthCheckValue expected;
}
