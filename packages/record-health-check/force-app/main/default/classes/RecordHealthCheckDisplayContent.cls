/** Versioned structured display envelope for display-capable results. */
global class RecordHealthCheckDisplayContent {
  /** Display schema version. */
  @AuraEnabled
  global Integer version = 1;
  /** Outcome-message nodes. */
  @AuraEnabled
  global List<RecordHealthCheckDisplayNode> message;
  /** Remediation-guidance nodes. */
  @AuraEnabled
  global List<RecordHealthCheckDisplayNode> fix;
  /** Found-value nodes. */
  @AuraEnabled
  global List<RecordHealthCheckDisplayNode> found;
  /** Expected-value nodes. */
  @AuraEnabled
  global List<RecordHealthCheckDisplayNode> expected;
}
