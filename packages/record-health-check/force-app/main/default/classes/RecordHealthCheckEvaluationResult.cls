/**
 * Stable result for one Check evaluated against one record.
 */
global class RecordHealthCheckEvaluationResult {
  @AuraEnabled
  /** Record evaluated by this result. */
  global Id recordId;
  @AuraEnabled
  /** Qualified Check identity. */
  global String checkQualifiedApiName;
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
  /** Typed value observed by the Check. */
  global RecordHealthCheckValue found;
  @AuraEnabled
  /** Comparison operator applied to Found and Expected. */
  global String comparisonOperator;
  @AuraEnabled
  /** Typed target value used by the Check. */
  global RecordHealthCheckValue expected;
  @AuraEnabled
  /** Safe correlation ID for a technical diagnosis, when one was recorded. */
  global String diagnosticId;
  @AuraEnabled
  /** Broad safe category for a technical diagnosis. */
  global String diagnosticCategory;
  @AuraEnabled
  /** Plain-language, disclosure-safe diagnosis summary. */
  global String diagnosticSummary;
  @AuraEnabled
  /** First disclosure-safe corrective action for automation surfaces. */
  global String recommendedAction;
}
