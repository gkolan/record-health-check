/** Integration-only plugin that violates the one-result-per-record contract. */
global with sharing class RHCDiagnosticMissingResultPlugin implements RecordHealthCheckPlugin {
  global Map<Id, RecordHealthCheckOutcome> evaluate(
    RecordHealthCheckScope scope
  ) {
    return new Map<Id, RecordHealthCheckOutcome>();
  }
}
