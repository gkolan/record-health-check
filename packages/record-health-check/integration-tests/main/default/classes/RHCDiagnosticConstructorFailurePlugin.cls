/** Integration-only plugin whose constructor fails before evaluation. */
global with sharing class RHCDiagnosticConstructorFailurePlugin implements RecordHealthCheckPlugin {
  global RHCDiagnosticConstructorFailurePlugin() {
    throw new DiagnosticFixtureException(
      'Deliberate diagnostic fixture constructor failure.'
    );
  }

  global Map<Id, RecordHealthCheckOutcome> evaluate(
    RecordHealthCheckScope scope
  ) {
    return new Map<Id, RecordHealthCheckOutcome>();
  }

  global class DiagnosticFixtureException extends Exception {
  }
}
