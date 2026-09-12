/** One value-free observed lifecycle entry in diagnostic contract 2.0. */
global class RecordHealthCheckDiagnosticTraceEntry {
  /** One-based observed ordering. */
  global Integer sequence;
  /** Stable completed or failed stage name. */
  global String stage;
  /** Measured duration, or null when no supported measurement was taken. */
  global Long durationMs;
}
