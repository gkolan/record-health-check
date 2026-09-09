/** Deterministic Apex plugin used only by the compatibility integration Check Set. */
global with sharing class RHCPluginCompatibilityFixture implements RecordHealthCheckPlugin {
  global static Integer constructorCount = 0;
  global static Integer evaluateCount = 0;

  global RHCPluginCompatibilityFixture() {
    constructorCount++;
  }

  global Map<Id, RecordHealthCheckOutcome> evaluate(
    RecordHealthCheckScope scope
  ) {
    evaluateCount++;
    Map<Id, RecordHealthCheckOutcome> outcomes = new Map<Id, RecordHealthCheckOutcome>();
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
          RecordHealthCheckOutcome.unableToEvaluate(
            'PLUGIN_COMPATIBILITY_DATA_UNAVAILABLE'
          )
        );
      } else if (accountRecord.Name.contains('[SKIP]')) {
        outcomes.put(
          recordId,
          RecordHealthCheckOutcome.skipped(
            'PLUGIN_COMPATIBILITY_NOT_APPLICABLE'
          )
        );
      } else if (accountRecord.Name.contains('[FAIL]')) {
        outcomes.put(
          recordId,
          RecordHealthCheckOutcome.fail('PLUGIN_COMPATIBILITY_NEEDS_REVIEW')
            .withFound(RecordHealthCheckValue.ofCount(0))
            .withComparison('EQUALS', RecordHealthCheckValue.ofCount(1))
        );
      } else {
        outcomes.put(
          recordId,
          RecordHealthCheckOutcome.pass('PLUGIN_COMPATIBILITY_PASS')
            .withFound(RecordHealthCheckValue.ofCount(1))
            .withComparison('EQUALS', RecordHealthCheckValue.ofCount(1))
        );
      }
    }
    return outcomes;
  }
}
