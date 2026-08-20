/** Regression coverage for unique lifecycle-event identifiers. */
@IsTest
private class RecordHealthCheckEventIdTest {
  @IsTest
  static void reusedRunIdProducesUniqueEventIds() {
    Test.startTest();
    String first = RecordHealthCheckEventId.newId(
      'nightly-2026-08-19',
      'Account_DQ_BillingCity-001000000000001AAA'
    );
    String second = RecordHealthCheckEventId.newId(
      'nightly-2026-08-19',
      'Account_DQ_BillingCity-001000000000001AAA'
    );
    Test.stopTest();

    Assert.areNotEqual(
      first,
      second,
      'Separate publications must remain unique when callers reuse a run ID.'
    );
    Assert.isTrue(
      first.startsWith('nightly-2026-08-19-'),
      'The event ID should retain a recognizable run correlation prefix.'
    );
    Assert.isTrue(
      first.length() <= 80 && second.length() <= 80,
      'Generated IDs must fit the platform event EventId field.'
    );
  }

  @IsTest
  static void longAndNullRunIdsRemainBounded() {
    Test.startTest();
    String longId = RecordHealthCheckEventId.newId(
      '012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789',
      'check-record'
    );
    String nullId = RecordHealthCheckEventId.newId(null, null);
    Test.stopTest();

    Assert.isTrue(longId.length() <= 80, 'Long run IDs must be bounded.');
    Assert.isTrue(nullId.length() <= 80, 'Null inputs must remain safe.');
  }
}
