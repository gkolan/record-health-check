/**
 * Immutable selection and record scope for one Record Health Check evaluation.
 */
global class RecordHealthCheckRequest {
  /** Qualified Check or Check Set selection. */
  global RecordHealthCheckSelection selection { get; private set; }
  /** Immutable execution options. */
  global RecordHealthCheckOptions options { get; private set; }

  private List<Id> recordIdsInternal;

  /** Detached record scope supplied by the caller. */
  global List<Id> recordIds {
    get {
      return new List<Id>(recordIdsInternal);
    }
  }

  private RecordHealthCheckRequest(
    RecordHealthCheckSelection selection,
    List<Id> recordIds,
    RecordHealthCheckOptions options
  ) {
    if (recordIds == null) {
      throw new RecordHealthCheckRequestException('Record IDs are required.');
    }
    this.selection = selection;
    this.recordIdsInternal = new List<Id>(recordIds);
    this.options = options;
  }

  /** Creates a single-record Check Set request. */
  global static RecordHealthCheckRequest forCheckSet(
    String qualifiedApiName,
    Id recordId
  ) {
    return forCheckSet(qualifiedApiName, new List<Id>{ recordId });
  }

  /** Creates a multi-record Check Set request. */
  global static RecordHealthCheckRequest forCheckSet(
    String qualifiedApiName,
    List<Id> recordIds
  ) {
    return new RecordHealthCheckRequest(
      RecordHealthCheckSelection.forCheckSet(qualifiedApiName),
      recordIds,
      RecordHealthCheckOptions.defaults()
    );
  }

  /** Creates a single-record Check request. */
  global static RecordHealthCheckRequest forCheck(
    String qualifiedApiName,
    Id recordId
  ) {
    return forCheck(qualifiedApiName, new List<Id>{ recordId });
  }

  /** Creates a multi-record Check request. */
  global static RecordHealthCheckRequest forCheck(
    String qualifiedApiName,
    List<Id> recordIds
  ) {
    return new RecordHealthCheckRequest(
      RecordHealthCheckSelection.forCheck(qualifiedApiName),
      recordIds,
      RecordHealthCheckOptions.defaults()
    );
  }

  /** Returns a copy with the requested response-content mode. */
  global RecordHealthCheckRequest withResultMode(
    RecordHealthCheckResultMode value
  ) {
    return copyWith(options.withResultMode(value));
  }

  /** Returns a copy with the requested event-publication policy. */
  global RecordHealthCheckRequest withEventPublication(
    RecordHealthCheckEventPublication value
  ) {
    return copyWith(options.withEventPublication(value));
  }

  /** Returns a copy with a normalized caller correlation identifier. */
  global RecordHealthCheckRequest withRunId(String value) {
    return copyWith(options.withRunId(value));
  }

  /**
   * @param value Caller context attributed to lifecycle events.
   * @return A copied request carrying the execution origin.
   */
  global RecordHealthCheckRequest withExecutionOrigin(
    RecordHealthCheckExecutionOrigin value
  ) {
    return copyWith(options.withExecutionOrigin(value));
  }

  private RecordHealthCheckRequest copyWith(RecordHealthCheckOptions value) {
    return new RecordHealthCheckRequest(selection, recordIdsInternal, value);
  }

  /** Invalid immutable-request construction. */
  global class RecordHealthCheckRequestException extends Exception {
  }
}
