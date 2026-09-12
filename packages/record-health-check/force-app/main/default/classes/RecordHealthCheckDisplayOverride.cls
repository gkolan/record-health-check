/** Optional human-facing presentation returned by a display-capable plugin. */
global class RecordHealthCheckDisplayOverride {
  public RecordHealthCheckDisplayText found;
  public RecordHealthCheckDisplayText expected;
  public RecordHealthCheckDisplayText message;
  public RecordHealthCheckDisplayText fix;
  public RecordHealthCheckDisplayAction action;
  public String expectedLabel;
  public String foundFormat;
  public String foundCurrencyIsoCode;
  public String expectedFormat;
  public String expectedCurrencyIsoCode;
  public transient Set<String> invalidFields = new Set<String>();

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

  /** Supplies optional rich outcome-message content. */
  global RecordHealthCheckDisplayOverride withMessage(
    RecordHealthCheckDisplayText value
  ) {
    message = value;
    return this;
  }

  /** Supplies optional rich remediation guidance. */
  global RecordHealthCheckDisplayOverride withFix(
    RecordHealthCheckDisplayText value
  ) {
    fix = value;
    return this;
  }

  /** Supplies one atomic remediation label-and-destination pair. */
  global RecordHealthCheckDisplayOverride withAction(
    RecordHealthCheckDisplayAction value
  ) {
    action = value;
    return this;
  }

  /** Supplies a semantic label for the Expected side. */
  global RecordHealthCheckDisplayOverride withExpectedLabel(String value) {
    expectedLabel = value;
    return this;
  }

  /** Supplies the Found display format and optional currency ISO code. */
  global RecordHealthCheckDisplayOverride withFoundFormat(
    String format,
    String currencyIsoCode
  ) {
    foundFormat = format;
    foundCurrencyIsoCode = currencyIsoCode;
    return this;
  }

  /** Supplies the Expected display format and optional currency ISO code. */
  global RecordHealthCheckDisplayOverride withExpectedFormat(
    String format,
    String currencyIsoCode
  ) {
    expectedFormat = format;
    expectedCurrencyIsoCode = currencyIsoCode;
    return this;
  }
}
