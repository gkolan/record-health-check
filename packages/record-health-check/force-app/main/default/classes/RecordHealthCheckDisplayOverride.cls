/** Optional Found and Expected presentation returned by a display-capable plugin. */
global class RecordHealthCheckDisplayOverride {
  public RecordHealthCheckDisplayText found;
  public RecordHealthCheckDisplayText expected;

  /** Creates an override with both fields absent. */
  global RecordHealthCheckDisplayOverride() {
    found = null;
    expected = null;
  }

  /** Supplies or clears the optional Found override. */
  global RecordHealthCheckDisplayOverride withFound(
    RecordHealthCheckDisplayText value
  ) {
    found = value;
    return this;
  }

  /** Supplies or clears the optional Expected override. */
  global RecordHealthCheckDisplayOverride withExpected(
    RecordHealthCheckDisplayText value
  ) {
    expected = value;
    return this;
  }
}
