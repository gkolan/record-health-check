/** Authorized, versioned diagnostic projection for one Check and record. */
global class RecordHealthCheckDiagnosticEnvelope {
  /** Diagnostic contract version. */
  global String contractVersion;
  /** Evaluation run correlation. */
  global String runId;
  /** Qualified Check identity. */
  global String checkIdentity;
  /** Evaluated record identity. */
  global Id recordId;
  /** Operation active at terminal outcome. */
  global String phase;
  /** Whether plugin evaluation was entered. */
  global Boolean pluginInvoked;
  /** Stable terminal reason. */
  global String reasonCode;
  /** Framework or plugin producer. */
  global String reasonOrigin;
  /** Metadata field containing the authored issue. */
  global String configurationField;
  /** Bounded and redacted authored token. */
  global String offendingToken;
  /** Zero-based token start offset. */
  global Integer tokenStart;
  /** Exclusive token end offset. */
  global Integer tokenEnd;
  /** Formula base object API name. */
  global String baseObject;
  /** Resolved dependency path when authorized. */
  global String dependencyPath;
  /** Disclosure-safe causal exception. */
  global RecordHealthCheckDiagnosticErrorDetail exceptionDetail;
  /** Ordered value-free lifecycle stages. */
  global List<RecordHealthCheckDiagnosticTraceEntry> trace = new List<RecordHealthCheckDiagnosticTraceEntry>();
  /** Whether trace entries exceeded the per-record cap. */
  global Boolean traceTruncated = false;
  /** Terminal failure retained independently of trace truncation. */
  global String terminalFailure;
}
