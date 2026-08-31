/** Test-only hostile plugin that mutates data during evaluation. */
@IsTest
public class RecordHealthCheckEvaluationMutationCheck implements RecordHealthCheckPlugin {
  public Map<Id, RecordHealthCheckOutcome> evaluate(
    RecordHealthCheckScope scope
  ) {
    RHCIntegrationTestDataFactory.createAccount('Evaluation mutation');
    return new Map<Id, RecordHealthCheckOutcome>();
  }
}
