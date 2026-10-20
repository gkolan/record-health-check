/**
 * Immutable selection and record scope for one Record Health Check evaluation.
 */
global class RecordHealthCheckRequest {
  /** Qualified Check or Check Set selection. */
  global RecordHealthCheckSelection selection { get; private set; }
  /** Immutable execution options. */
  global RecordHealthCheckOptions options { get; private set; }

  private List<Id> recordIdsInternal;
  private Boolean evidenceOmitted = false;
  private Boolean prerequisitesEnforcedByCaller = false;

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

  /** Returns a copy requesting an explicit diagnostic projection version. */
  global RecordHealthCheckRequest withDiagnosticContractVersion(String value) {
    return copyWith(options.withDiagnosticContractVersion(value));
  }

  /**
   * Package-internal: returns a copy whose response carries no evidence, so
   * evidence never spends or reports the optional presentation byte budget.
   */
  public RecordHealthCheckRequest withoutEvidence() {
    RecordHealthCheckRequest copy = copyWith(options);
    copy.evidenceOmitted = true;
    return copy;
  }

  /** Package-internal: whether this request's response omits evidence. */
  public Boolean omitsEvidence() {
    return evidenceOmitted;
  }

  /**
   * Package-internal: returns a copy for a caller that has already enforced the
   * Check's prerequisites, so a single-Check request evaluates only that Check.
   */
  public RecordHealthCheckRequest withPrerequisitesEnforcedByCaller() {
    RecordHealthCheckRequest copy = copyWith(options);
    copy.prerequisitesEnforcedByCaller = true;
    return copy;
  }

  /** Package-internal: whether the caller has already enforced prerequisites. */
  public Boolean callerEnforcesPrerequisites() {
    return prerequisitesEnforcedByCaller;
  }

  private RecordHealthCheckRequest copyWith(RecordHealthCheckOptions value) {
    RecordHealthCheckRequest copy = new RecordHealthCheckRequest(
      selection,
      recordIdsInternal,
      value
    );
    copy.evidenceOmitted = evidenceOmitted;
    copy.prerequisitesEnforcedByCaller = prerequisitesEnforcedByCaller;
    return copy;
  }

  /** Invalid immutable-request construction. */
  global class RecordHealthCheckRequestException extends Exception {
  }
}
