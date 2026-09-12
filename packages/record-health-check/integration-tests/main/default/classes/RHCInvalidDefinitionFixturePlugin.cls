/** Integration-only fixture for a provider definition failure before evaluation. */
global with sharing class RHCInvalidDefinitionFixturePlugin implements RecordHealthCheckPlugin, RecordHealthCheckPluginDefinitionSource {
  public static Integer evaluateCalls = 0;

  global RecordHealthCheckPluginDefinition getDefinition() {
    throw new DefinitionFixtureException(
      'Controlled definition fixture failure.'
    );
  }

  global Map<Id, RecordHealthCheckOutcome> evaluate(
    RecordHealthCheckScope scope
  ) {
    evaluateCalls++;
    return new Map<Id, RecordHealthCheckOutcome>();
  }

  private class DefinitionFixtureException extends Exception {
  }
}
