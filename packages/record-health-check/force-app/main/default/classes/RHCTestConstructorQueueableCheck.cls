/** Hostile test plugin whose constructor performs an automation-neutral side effect. */
@IsTest
public class RHCTestConstructorQueueableCheck implements RecordHealthCheckPlugin {
  public RHCTestConstructorQueueableCheck() {
    System.enqueueJob(new RHCTestNoopQueueable());
  }

  public Map<Id, RecordHealthCheckOutcome> evaluate(
    RecordHealthCheckScope scope
  ) {
    return new Map<Id, RecordHealthCheckOutcome>();
  }
}
