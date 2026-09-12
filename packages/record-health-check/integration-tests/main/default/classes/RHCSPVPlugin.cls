/** Deterministic integration-only plugin for the subscriber value contract. */
global with sharing class RHCSPVPlugin implements RecordHealthCheckPlugin {
  global Map<Id, RecordHealthCheckOutcome> evaluate(
    RecordHealthCheckScope scope
  ) {
    Map<Id, Account> accounts = new Map<Id, Account>(
      [
        SELECT Id, Website
        FROM Account
        WHERE Id IN :scope.recordIds
        WITH USER_MODE
      ]
    );
    Map<Id, RecordHealthCheckOutcome> outcomes = new Map<Id, RecordHealthCheckOutcome>();
    for (Id recordId : scope.recordIds) {
      Account accountRecord = accounts.get(recordId);
      if (accountRecord == null || String.isBlank(accountRecord.Website)) {
        outcomes.put(
          recordId,
          RecordHealthCheckOutcome.unableToEvaluate('SP_DATA_MISSING')
        );
        continue;
      }
      List<String> found = accountRecord.Website.startsWith('https://')
        ? new List<String>()
        : new List<String>{ 'website' };
      outcomes.put(
        recordId,
        found.isEmpty()
          ? RecordHealthCheckOutcome.noneFound('SP_OK')
          : RecordHealthCheckOutcome.itemsFound('SP_REVIEW', found)
      );
    }
    return outcomes;
  }
}
