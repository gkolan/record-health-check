/**
 * One response item containing evaluation data and optional display content.
 */
global class RecordHealthCheckResultItem {
  /** Server-only source for opt-in diagnostic projection. */
  public transient RecordHealthCheckInternalResult diagnosticSource;
  @AuraEnabled
  /** Stable evaluation data. */
  global RecordHealthCheckEvaluationResult evaluation;
  @AuraEnabled
  /** Optional human-facing rendering. */
  global RecordHealthCheckResultDisplay display;
}
