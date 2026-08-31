/** Test-only hostile plugin whose constructor attempts a database mutation. */
@IsTest
public class RHCConstructorMutationCheck implements RecordHealthCheckPlugin {
  public RHCConstructorMutationCheck() {
    RHCIntegrationTestDataFactory.createAccount('Constructor mutation');
  }

  public Map<Id, RecordHealthCheckOutcome> evaluate(
    RecordHealthCheckScope scope
  ) {
    return new Map<Id, RecordHealthCheckOutcome>();
  }
}
