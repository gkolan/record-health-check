/** One ordered, typed column in plugin evidence. */
global class RecordHealthCheckEvidenceColumn {
  /** Stable machine key. */
  @AuraEnabled
  global String key;
  /** Plain-text visible heading. */
  @AuraEnabled
  global String label;
  /** Declared scalar type. */
  @AuraEnabled
  global String dataType;

  public RecordHealthCheckEvidenceColumn(
    String key,
    String label,
    String dataType
  ) {
    this.key = key;
    this.label = label;
    this.dataType = dataType;
  }

  public RecordHealthCheckEvidenceColumn snapshot() {
    return new RecordHealthCheckEvidenceColumn(key, label, dataType);
  }
}
