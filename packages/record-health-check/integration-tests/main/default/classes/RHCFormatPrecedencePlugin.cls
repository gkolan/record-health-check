/** Integration fixture for metadata precedence over plugin value formats. */
global with sharing class RHCFormatPrecedencePlugin implements RecordHealthCheckPlugin, RecordHealthCheckDisplayPlugin {
  global Map<Id, RecordHealthCheckOutcome> evaluate(
    RecordHealthCheckScope scope
  ) {
    Boolean passing = scope.parameters.get('passing') == true;
    Boolean unable = scope.parameters.get('unable') == true;
    Map<Id, RecordHealthCheckOutcome> results = new Map<Id, RecordHealthCheckOutcome>();
    for (Id recordId : scope.recordIds) {
      if (unable) {
        // No operands: only the display hook names the Found and Expected values.
        results.put(
          recordId,
          RecordHealthCheckOutcome.unableToEvaluate('FORMAT_NO_OPERAND')
        );
        continue;
      }
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
    Boolean unable = scope.parameters.get('unable') == true;
    Map<Id, RecordHealthCheckDisplayOverride> results = new Map<Id, RecordHealthCheckDisplayOverride>();
    for (Id recordId : scope.recordIds) {
      RecordHealthCheckDisplayOverride display = new RecordHealthCheckDisplayOverride()
        .withFoundFormat('NUMBER', null)
        .withExpectedFormat('NUMBER', null)
        .withExpectedLabel('Plugin target');
      if (unable) {
        display
          .withFound(
            new RecordHealthCheckDisplayText()
              .text('Source: ')
              .link('Open record', '/lightning/r/Account/' + recordId + '/view')
          )
          .withExpected(
            new RecordHealthCheckDisplayText()
              .text('Target: ')
              .link('Open Accounts', '/lightning/o/Account/home')
          );
      }
      results.put(recordId, display);
    }
    return results;
  }
}
