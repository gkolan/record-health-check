/** Versioned, validated evidence projection for interactive consumers. */
global class RecordHealthCheckEvidenceEnvelope {
  /** Evidence contract version. */
  @AuraEnabled
  global String version;
  /** Evaluation run identity. */
  @AuraEnabled
  global String runId;
  /** Qualified Check identity. */
  @AuraEnabled
  global String checkIdentity;
  /** Evaluated record identity. */
  @AuraEnabled
  global Id recordId;
  /** Validated plain-text summary. */
  @AuraEnabled
  global String summary;
  /** Ordered validated columns. */
  @AuraEnabled
  global List<RecordHealthCheckEvidenceColumn> columns;
  /** Ordered JSON-scalar rows. */
  @AuraEnabled
  global List<List<Object>> rows;
  /** Number of rows returned. */
  @AuraEnabled
  global Integer returnedItemCount;
  /** Authorized total, or null when unknowable without disclosure. */
  @AuraEnabled
  global Integer totalItemCount;
  /** COMPLETE, TRUNCATED, or UNKNOWN. */
  @AuraEnabled
  global String completeness;
  /** Known authorized omitted count, or null. */
  @AuraEnabled
  global Integer omittedItemCount;
  /** Optional step and rule grouping keys. */
  @AuraEnabled
  global List<String> groupKeys;
}
