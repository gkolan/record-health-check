/** Replace ExampleBulkCheck and the query fields for your object. */
global with sharing class ExampleBulkCheck implements RecordHealthCheckPlugin {
  global Map<Id, RecordHealthCheckOutcome> evaluate(
    RecordHealthCheckScope scope
  ) {
    Map<Id, RecordHealthCheckOutcome> outcomes = new Map<Id, RecordHealthCheckOutcome>();
    if (scope == null || scope.recordIds == null || scope.recordIds.isEmpty()) {
      return outcomes;
    }
    Set<Id> recordIds = new Set<Id>(scope.recordIds);

    // Seed every requested ID so zero related rows still produce an outcome.
    for (Id recordId : recordIds) {
      outcomes.put(recordId, unable('NOT_EVALUATED'));
    }

    // Query once for the complete scope, then overlay grouped facts by record ID.
    Map<Id, Integer> countsByRecordId = new Map<Id, Integer>();
    for (AggregateResult row : [
      SELECT AccountId parentId, COUNT(Id) total
      FROM Contact
      WHERE AccountId IN :recordIds
      WITH USER_MODE
      GROUP BY AccountId
    ]) {
      countsByRecordId.put(
        (Id) row.get('parentId'),
        (Integer) row.get('total')
      );
    }

    for (Id recordId : recordIds) {
      try {
        Integer total = countsByRecordId.containsKey(recordId)
          ? countsByRecordId.get(recordId)
          : 0;
        outcomes.put(recordId, total > 0 ? pass(total) : fail(total));
      } catch (Exception ex) {
        outcomes.put(recordId, unable('PLUGIN_RECORD_ERROR'));
      }
    }
    return outcomes;
  }

  private static RecordHealthCheckOutcome pass(Integer total) {
    return outcome(RecordHealthCheckStatus.PASS, 'CONTACT_FOUND', total);
  }

  private static RecordHealthCheckOutcome fail(Integer total) {
    return outcome(RecordHealthCheckStatus.FAIL, 'CONTACT_MISSING', total);
  }

  private static RecordHealthCheckOutcome unable(String reasonCode) {
    return outcome(
      RecordHealthCheckStatus.UNABLE_TO_EVALUATE,
      reasonCode,
      null
    );
  }

  private static RecordHealthCheckOutcome outcome(
    String status,
    String reasonCode,
    Integer total
  ) {
    RecordHealthCheckOutcome value = status == RecordHealthCheckStatus.PASS
      ? RecordHealthCheckOutcome.pass(reasonCode)
      : status == RecordHealthCheckStatus.FAIL
          ? RecordHealthCheckOutcome.fail(reasonCode)
          : RecordHealthCheckOutcome.unableToEvaluate(reasonCode);
    return total == null
      ? value
      : value.withFound(RecordHealthCheckValue.ofCount(total));
  }
}
