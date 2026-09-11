/** Disclosure-safe exception coordinates in diagnostic contract 2.0. */
global class RecordHealthCheckDiagnosticErrorDetail {
  /** Sanitized exception type. */
  global String type;
  /** Framework-approved message or the fixed withheld marker. */
  global String message;
  /** Most useful stack-frame class. */
  global String topFrameClass;
  /** Most useful stack-frame method. */
  global String topFrameMethod;
  /** Most useful stack-frame line, or null when unknown. */
  global Integer topFrameLine;
  /** Configured plugin class. */
  global String pluginClass;
  /** Operation active when the exception was observed. */
  global String operation;
  /** Number of records affected by the exception. */
  global Integer affectedRecordCount;
}
