/** One ordered, typed column in plugin evidence. */
global class RecordHealthCheckEvidenceColumn {
  /** Stable machine key. */
  global String key { get; private set; }
  /** Plain-text visible heading. */
  global String label { get; private set; }
  /** Declared scalar type. */
  global String dataType { get; private set; }

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
