/**
 * Immutable execution options with safe programmatic defaults.
 */
global class RecordHealthCheckOptions {
  /** Requested response-content mode. */
  global RecordHealthCheckResultMode resultMode { get; private set; }
  /** Requested lifecycle-event publication policy. */
  global RecordHealthCheckEventPublication eventPublication {
    get;
    private set;
  }
  /** Optional normalized caller correlation identifier. */
  global String runId { get; private set; }
  /** Caller context attributed to execution monitoring. */
  global RecordHealthCheckExecutionOrigin executionOrigin { get; private set; }

  private RecordHealthCheckOptions(
    RecordHealthCheckResultMode resultMode,
    RecordHealthCheckEventPublication eventPublication,
    String runId,
    RecordHealthCheckExecutionOrigin executionOrigin
  ) {
    this.resultMode = resultMode;
    this.eventPublication = eventPublication;
    this.runId = runId;
    this.executionOrigin = executionOrigin;
  }

  /** @return Options that return evaluation data and publish no events. */
  global static RecordHealthCheckOptions defaults() {
    return new RecordHealthCheckOptions(
      RecordHealthCheckResultMode.EVALUATION,
      RecordHealthCheckEventPublication.NONE,
      null,
      RecordHealthCheckExecutionOrigin.APEX_API
    );
  }

  /**
   * @param value Desired response content mode.
   * @return A copied option set carrying the mode.
   */
  global RecordHealthCheckOptions withResultMode(
    RecordHealthCheckResultMode value
  ) {
    if (value == null) {
      throw new RecordHealthCheckOptionsException('Result mode is required.');
    }
    return new RecordHealthCheckOptions(
      value,
      eventPublication,
      runId,
      executionOrigin
    );
  }

  /**
   * @param value Desired lifecycle event publication policy.
   * @return A copied option set carrying the policy.
   */
  global RecordHealthCheckOptions withEventPublication(
    RecordHealthCheckEventPublication value
  ) {
    if (value == null) {
      throw new RecordHealthCheckOptionsException(
        'Event publication policy is required.'
      );
    }
    return new RecordHealthCheckOptions(
      resultMode,
      value,
      runId,
      executionOrigin
    );
  }

  /**
   * @param value Optional caller-supplied correlation identifier.
   * @return A copied option set carrying the run identifier.
   */
  global RecordHealthCheckOptions withRunId(String value) {
    return new RecordHealthCheckOptions(
      resultMode,
      eventPublication,
      RecordHealthCheckLogger.normalizeIdentifier(value, 120),
      executionOrigin
    );
  }

  /**
   * @param value Caller context attributed to lifecycle events.
   * @return A copied option set carrying the execution origin.
   */
  global RecordHealthCheckOptions withExecutionOrigin(
    RecordHealthCheckExecutionOrigin value
  ) {
    if (value == null) {
      throw new RecordHealthCheckOptionsException(
        'Execution origin is required.'
      );
    }
    return new RecordHealthCheckOptions(
      resultMode,
      eventPublication,
      runId,
      value
    );
  }

  /** Invalid immutable-option construction. */
  global class RecordHealthCheckOptionsException extends Exception {
  }
}
