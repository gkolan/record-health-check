/** Integration-only plugin that deterministically throws during evaluation. */
global with sharing class RHCDiagnosticThrowingPlugin implements RecordHealthCheckPlugin {
  global Map<Id, RecordHealthCheckOutcome> evaluate(
    RecordHealthCheckScope scope
  ) {
    throw new DiagnosticFixtureException(
      'Deliberate diagnostic fixture failure: invalid configured field.'
    );
  }

  global class DiagnosticFixtureException extends Exception {
  }
}
