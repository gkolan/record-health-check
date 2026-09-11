/** Bounded authorized response for diagnostic contract 2.0. */
global class RecordHealthCheckDiagnosticResponse {
  /** Selected diagnostic contract version. */
  global String contractVersion = '2.0';
  /** Ordered whole diagnostic envelopes retained within the request budget. */
  global List<RecordHealthCheckDiagnosticEnvelope> diagnostics = new List<RecordHealthCheckDiagnosticEnvelope>();
  /** Authorized requested envelopes omitted after the byte budget was reached. */
  global Integer omittedDiagnosticCount = 0;
}
