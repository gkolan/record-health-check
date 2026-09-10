/** Subscriber-owned plugin used to verify unmanaged dispatch across the rhc namespace boundary. */
global with sharing class RHCSubscriberPlugin implements rhc.RecordHealthCheckPlugin {
  global static Integer constructorCount = 0;
  global static Integer evaluateCount = 0;

  global RHCSubscriberPlugin() {
    constructorCount++;
  }

  global Map<Id, rhc.RecordHealthCheckOutcome> evaluate(
    rhc.RecordHealthCheckScope scope
  ) {
    evaluateCount++;
    Map<Id, rhc.RecordHealthCheckOutcome> outcomes = new Map<Id, rhc.RecordHealthCheckOutcome>();
    Map<Id, Account> accounts = new Map<Id, Account>(
      [
        SELECT Id, Name
        FROM Account
        WHERE Id IN :scope.recordIds
        WITH USER_MODE
      ]
    );
    for (Id recordId : scope.recordIds) {
      Account accountRecord = accounts.get(recordId);
      if (accountRecord == null || accountRecord.Name.contains('[UNABLE]')) {
        outcomes.put(
          recordId,
          rhc.RecordHealthCheckOutcome.unableToEvaluate(
            'SUBSCRIBER_PLUGIN_DATA_UNAVAILABLE'
          )
        );
      } else if (accountRecord.Name.contains('[SKIP]')) {
        outcomes.put(
          recordId,
          rhc.RecordHealthCheckOutcome.skipped(
            'SUBSCRIBER_PLUGIN_NOT_APPLICABLE'
          )
        );
      } else if (accountRecord.Name.contains('[FAIL]')) {
        outcomes.put(
          recordId,
          rhc.RecordHealthCheckOutcome.fail('SUBSCRIBER_PLUGIN_NEEDS_REVIEW')
            .withFound(rhc.RecordHealthCheckValue.ofCount(0))
            .withComparison('EQUALS', rhc.RecordHealthCheckValue.ofCount(1))
        );
      } else {
        outcomes.put(
          recordId,
          rhc.RecordHealthCheckOutcome.pass('SUBSCRIBER_PLUGIN_PASS')
            .withFound(rhc.RecordHealthCheckValue.ofCount(1))
            .withComparison('EQUALS', rhc.RecordHealthCheckValue.ofCount(1))
        );
      }
    }
    return outcomes;
  }
}
