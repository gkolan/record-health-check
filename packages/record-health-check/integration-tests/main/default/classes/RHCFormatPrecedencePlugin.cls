/** Integration fixture for metadata precedence over plugin value formats. */
global with sharing class RHCFormatPrecedencePlugin implements RecordHealthCheckPlugin, RecordHealthCheckDisplayPlugin {
  global Map<Id, RecordHealthCheckOutcome> evaluate(
    RecordHealthCheckScope scope
  ) {
    Boolean passing = scope.parameters.get('passing') == true;
    Map<Id, RecordHealthCheckOutcome> results = new Map<Id, RecordHealthCheckOutcome>();
    for (Id recordId : scope.recordIds) {
      RecordHealthCheckValue found = RecordHealthCheckValue.ofNumber(
        Decimal.valueOf('0.75')
      );
      RecordHealthCheckValue expected = RecordHealthCheckValue.ofNumber(
        Decimal.valueOf(passing ? '0.75' : '0.80')
      );
      results.put(
        recordId,
        passing
          ? RecordHealthCheckOutcome.passEquals('FORMAT_OK', found, expected)
          : RecordHealthCheckOutcome.failEquals(
              'FORMAT_REVIEW',
              found,
              expected
            )
      );
    }
    return results;
  }
  global Map<Id, RecordHealthCheckDisplayOverride> getDisplay(
    RecordHealthCheckScope scope
  ) {
    Map<Id, RecordHealthCheckDisplayOverride> results = new Map<Id, RecordHealthCheckDisplayOverride>();
    for (Id recordId : scope.recordIds) {
      results.put(
        recordId,
        new RecordHealthCheckDisplayOverride()
          .withFoundFormat('NUMBER', null)
          .withExpectedFormat('NUMBER', null)
          .withExpectedLabel('Plugin target')
      );
    }
    return results;
  }
}
