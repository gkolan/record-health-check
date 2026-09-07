/** Regression coverage for unique lifecycle-event identifiers. */
@IsTest
private class RecordHealthCheckEventIdTest {
  @IsTest
  static void reusedRunIdProducesUniqueEventIds() {
    Test.startTest();
    String first = RecordHealthCheckEventId.newId('nightly-2026-08-19');
    String second = RecordHealthCheckEventId.newId('nightly-2026-08-19');
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
    Assert.isTrue(
      Pattern.matches('^nightly-2026-08-19-[0-9]+-[0-9a-fA-F]{32}$', first),
      'The suffix must preserve all 128 random bits as unsigned hex.'
    );
  }

  @IsTest
  static void longAndNullRunIdsRemainBounded() {
    Test.startTest();
    String longId = RecordHealthCheckEventId.newId(
      '012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789'
    );
    String nullId = RecordHealthCheckEventId.newId(null);
    Test.stopTest();

    Assert.areEqual(
      80,
      longId.length(),
      'Long run IDs must fill but not exceed the field.'
    );
    Assert.isTrue(nullId.length() <= 80, 'Null inputs must remain safe.');
    Assert.isTrue(
      Pattern.matches('^[0-9]{45}-[0-9]+-[0-9a-fA-F]{32}$', longId),
      'Only the caller prefix should be shortened to preserve the sequence and full random suffix.'
    );
  }
}
