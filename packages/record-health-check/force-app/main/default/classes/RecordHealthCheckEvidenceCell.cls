/** One typed synthetic or field-provenance evidence cell. */
global class RecordHealthCheckEvidenceCell {
  /** Typed cell value. */
  global RecordHealthCheckValue typedValue { get; private set; }
  /** Optional record provenance. */
  global Id recordId { get; private set; }
  /** Optional field provenance. */
  global String fieldPath { get; private set; }

  private RecordHealthCheckEvidenceCell(
    Id recordId,
    String fieldPath,
    RecordHealthCheckValue typedValue
  ) {
    this.recordId = recordId;
    this.fieldPath = fieldPath;
    this.typedValue = typedValue;
  }

  /** Creates a synthetic plugin-authored value cell. */
  global static RecordHealthCheckEvidenceCell value(
    RecordHealthCheckValue typedValue
  ) {
    return new RecordHealthCheckEvidenceCell(null, null, typedValue);
  }

  /** Creates a value with record and field provenance. */
  global static RecordHealthCheckEvidenceCell field(
    Id recordId,
    String fieldPath,
    RecordHealthCheckValue typedValue
  ) {
    return new RecordHealthCheckEvidenceCell(recordId, fieldPath, typedValue);
  }

  public RecordHealthCheckEvidenceCell snapshot() {
    return new RecordHealthCheckEvidenceCell(recordId, fieldPath, typedValue);
  }
}
