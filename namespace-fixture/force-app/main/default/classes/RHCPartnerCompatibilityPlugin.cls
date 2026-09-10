/** Minimal partner-package plugin used to prove the real NS-03 boundary. */
global with sharing class RHCPartnerCompatibilityPlugin implements rhc.RecordHealthCheckPlugin {
  global static Integer constructorCount = 0;
  global static Integer evaluateCount = 0;

  global RHCPartnerCompatibilityPlugin() {
    constructorCount++;
  }

  global Map<Id, rhc.RecordHealthCheckOutcome> evaluate(
    rhc.RecordHealthCheckScope scope
  ) {
    evaluateCount++;
    Map<Id, rhc.RecordHealthCheckOutcome> outcomes = new Map<Id, rhc.RecordHealthCheckOutcome>();
    for (Id recordId : scope.recordIds) {
      outcomes.put(
        recordId,
        rhc.RecordHealthCheckOutcome.pass('PARTNER_NAMESPACE_PLUGIN_PASS')
          .withFound(rhc.RecordHealthCheckValue.ofCount(scope.size()))
          .withComparison(
            'GREATER_THAN_OR_EQUAL',
            rhc.RecordHealthCheckValue.ofCount(1)
          )
      );
    }
    return outcomes;
  }
}
