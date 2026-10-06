/** Subscriber fixture for metadata precedence over plugin value formats. */
global with sharing class RHCSubscriberFormatPlugin implements rhc.RecordHealthCheckPlugin, rhc.RecordHealthCheckDisplayPlugin {
  global Map<Id, rhc.RecordHealthCheckOutcome> evaluate(
    rhc.RecordHealthCheckScope scope
  ) {
    Boolean passing = scope.parameters.get('passing') == true;
    Map<Id, rhc.RecordHealthCheckOutcome> results = new Map<Id, rhc.RecordHealthCheckOutcome>();
    for (Id recordId : scope.recordIds) {
      rhc.RecordHealthCheckValue found = rhc.RecordHealthCheckValue.ofNumber(
        Decimal.valueOf('0.75')
      );
      rhc.RecordHealthCheckValue expected = rhc.RecordHealthCheckValue.ofNumber(
        Decimal.valueOf(passing ? '0.75' : '0.80')
      );
      results.put(
        recordId,
        passing
          ? rhc.RecordHealthCheckOutcome.passEquals(
              'FORMAT_OK',
              found,
              expected
            )
          : rhc.RecordHealthCheckOutcome.failEquals(
              'FORMAT_REVIEW',
              found,
              expected
            )
      );
    }
    return results;
  }
  global Map<Id, rhc.RecordHealthCheckDisplayOverride> getDisplay(
    rhc.RecordHealthCheckScope scope
  ) {
    Map<Id, rhc.RecordHealthCheckDisplayOverride> results = new Map<Id, rhc.RecordHealthCheckDisplayOverride>();
    // A currency parameter makes the plugin declare the unit of both values.
    Object unit = scope.parameters.get('currency');
    String format = unit == null ? 'NUMBER' : 'CURRENCY';
    String isoCode = unit == null ? null : String.valueOf(unit);
    for (Id recordId : scope.recordIds) {
      results.put(
        recordId,
        new rhc.RecordHealthCheckDisplayOverride()
          .withFoundFormat(format, isoCode)
          .withExpectedFormat(format, isoCode)
          .withExpectedLabel('Plugin target')
      );
    }
    return results;
  }
}
