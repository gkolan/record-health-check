/** Subscriber-owned plugin used to verify unmanaged dispatch across the rhc namespace boundary. */
global with sharing class RHCSubscriberPlugin implements rhc.RecordHealthCheckPlugin {
  global Map<Id, rhc.RecordHealthCheckOutcome> evaluate(
    rhc.RecordHealthCheckScope scope
  ) {
    Map<Id, rhc.RecordHealthCheckOutcome> outcomes = new Map<Id, rhc.RecordHealthCheckOutcome>();
    for (Id recordId : scope.recordIds) {
      outcomes.put(
        recordId,
        rhc.RecordHealthCheckOutcome.pass('SUBSCRIBER_PLUGIN_PASS')
          .withFound(rhc.RecordHealthCheckValue.ofCount(1))
          .withComparison('EQUALS', rhc.RecordHealthCheckValue.ofCount(1))
      );
    }
    return outcomes;
  }
}
