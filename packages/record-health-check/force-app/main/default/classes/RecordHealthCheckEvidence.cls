/** Additive builder for ordered, typed plugin evidence. */
global class RecordHealthCheckEvidence {
  /** Concise plain-text summary. */
  global String summary { get; private set; }
  /** Ordered column declarations. */
  global List<RecordHealthCheckEvidenceColumn> columns { get; private set; }
  /** Ordered typed rows. */
  global List<List<RecordHealthCheckEvidenceCell>> rows { get; private set; }
  /** Optional numeric grouping key. */
  global String stepGroupKey { get; private set; }
  /** Optional string or ID grouping key. */
  global String ruleGroupKey { get; private set; }

  /** Creates an empty evidence builder with its concise summary. */
  global RecordHealthCheckEvidence(String summary) {
    this.summary = summary;
    this.columns = new List<RecordHealthCheckEvidenceColumn>();
    this.rows = new List<List<RecordHealthCheckEvidenceCell>>();
  }

  /** Appends one ordered column declaration. */
  global RecordHealthCheckEvidence column(
    String key,
    String label,
    String dataType
  ) {
    columns.add(new RecordHealthCheckEvidenceColumn(key, label, dataType));
    return this;
  }

  /** Appends one row in declared-column order. */
  global RecordHealthCheckEvidence row(
    List<RecordHealthCheckEvidenceCell> cells
  ) {
    rows.add(
      cells == null ? null : new List<RecordHealthCheckEvidenceCell>(cells)
    );
    return this;
  }

  /** Selects numeric-step and string-or-ID rule grouping keys. */
  global RecordHealthCheckEvidence groupBy(String stepKey, String ruleKey) {
    stepGroupKey = stepKey;
    ruleGroupKey = ruleKey;
    return this;
  }

  public RecordHealthCheckEvidence snapshot() {
    RecordHealthCheckEvidence copy = new RecordHealthCheckEvidence(summary);
    for (RecordHealthCheckEvidenceColumn columnValue : columns) {
      copy.columns.add(columnValue?.snapshot());
    }
    for (List<RecordHealthCheckEvidenceCell> rowValue : rows) {
      if (rowValue == null) {
        copy.rows.add(null);
        continue;
      }
      List<RecordHealthCheckEvidenceCell> rowCopy = new List<RecordHealthCheckEvidenceCell>();
      for (RecordHealthCheckEvidenceCell cell : rowValue) {
        rowCopy.add(cell?.snapshot());
      }
      copy.rows.add(rowCopy);
    }
    copy.stepGroupKey = stepGroupKey;
    copy.ruleGroupKey = ruleGroupKey;
    return copy;
  }
}
