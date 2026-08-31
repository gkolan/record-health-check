/** Hostile test plugin that performs an automation-neutral side effect while evaluating. */
@IsTest
public class RHCTestEvaluationQueueableCheck implements RecordHealthCheckPlugin {
  public Map<Id, RecordHealthCheckOutcome> evaluate(
    RecordHealthCheckScope scope
  ) {
    System.enqueueJob(new RHCTestNoopQueueable());
    return new Map<Id, RecordHealthCheckOutcome>();
  }
}
