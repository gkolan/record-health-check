/**
 * Defensive evaluator edge-case tests.
 * SPDX-License-Identifier: Apache-2.0
 */
@IsTest
private class RHCComparisonDisplayEdgeBehaviorTest {
  @TestSetup
  static void setup() {
    RecordHealthCheckTestDataFactory.createCoverageTestRecords();
  }

  @IsTest
  static void comparisonDisplayCoversRemainingEdgeBranches() {
    // ── Actual-vs-expected description helpers ──────────────────────────────
    Assert.areEqual(
      'to equal',
      RecordHealthCheckComparisonDisplay.operatorLabel('EQUALS')
    );
    Assert.areEqual(
      'at least',
      RecordHealthCheckComparisonDisplay.operatorLabel('GREATER_THAN_OR_EQUAL')
    );
    // Unknown operator falls back to the raw API name
    Assert.areEqual(
      'Mystery',
      RecordHealthCheckComparisonDisplay.operatorLabel('Mystery')
    );
    Assert.areEqual(
      '(blank)',
      RecordHealthCheckComparisonDisplay.formatValue(null)
    );
    Assert.areEqual(
      '(blank)',
      RecordHealthCheckComparisonDisplay.formatValue('   ')
    );
    Assert.areEqual(
      'Technology',
      RecordHealthCheckComparisonDisplay.formatValue('Technology')
    );
    // Values are unquoted because the UI chip visually distinguishes them.
    Assert.areEqual('1', RecordHealthCheckComparisonDisplay.formatValue(1));
    // Booleans read Yes/No, whether they arrive as a typed Boolean (checkbox
    // field, boolean formula) or as a metadata operand string.
    Assert.areEqual(
      'Yes',
      RecordHealthCheckComparisonDisplay.formatValue(true)
    );
    Assert.areEqual(
      'No',
      RecordHealthCheckComparisonDisplay.formatValue(false)
    );
    Assert.areEqual(
      'Yes',
      RecordHealthCheckComparisonDisplay.formatValue('true')
    );
    Assert.areEqual(
      'No',
      RecordHealthCheckComparisonDisplay.formatValue('False')
    );
    // Typed numbers gain thousands separators; digit-only strings retain their
    // exact spelling because they may be postal codes, years, or identifiers.
    Assert.areEqual(
      '70,000',
      RecordHealthCheckComparisonDisplay.formatValue(70000.0)
    );
    Assert.areEqual(
      'to equal 100,000',
      RecordHealthCheckComparisonDisplay.describeExpectedForActual(
        'EQUALS',
        '100000',
        Decimal.valueOf('100000')
      )
    );
    Assert.areEqual(
      'to equal 0012345',
      RecordHealthCheckComparisonDisplay.describeExpectedForActual(
        'EQUALS',
        '0012345',
        '0012345'
      )
    );
    Assert.areEqual(
      '500000',
      RecordHealthCheckComparisonDisplay.formatValue('500000')
    );
    Assert.areEqual(
      '0012345',
      RecordHealthCheckComparisonDisplay.formatValue('0012345')
    );
    Assert.areEqual(
      '90210',
      RecordHealthCheckComparisonDisplay.formatValue('90210')
    );
    Assert.areEqual(
      '70,000.5',
      RecordHealthCheckComparisonDisplay.formatValue(70000.5)
    );
    Assert.areEqual(
      '-1,234,567',
      RecordHealthCheckComparisonDisplay.formatValue(-1234567)
    );
    // Multi-select picklist text (semicolon-delimited) reads comma-separated.
    Assert.areEqual(
      'Hot, Warm, Cold',
      RecordHealthCheckComparisonDisplay.formatValue('Hot;Warm;Cold')
    );
    // Dates/datetimes render in the user's locale — assert the raw ISO shape is
    // gone (no dashes) rather than a locale-specific literal, so the test is not
    // brittle across orgs. Both the typed value and the ISO operand string
    // humanize identically.
    String typedDate = RecordHealthCheckComparisonDisplay.formatValue(
      Date.newInstance(2026, 7, 4)
    );
    Assert.isTrue(
      typedDate.contains('2026') && !typedDate.contains('-'),
      'Typed Date should be locale-formatted, got ' + typedDate
    );
    Assert.areEqual(
      typedDate,
      RecordHealthCheckComparisonDisplay.formatValue('2026-07-04'),
      'ISO date operand string should humanize like the typed Date'
    );
    String typedDatetime = RecordHealthCheckComparisonDisplay.formatValue(
      Datetime.newInstance(2026, 7, 4, 17, 30, 0)
    );
    Assert.isTrue(
      typedDatetime.contains('2026') && !typedDatetime.contains('T'),
      'Typed Datetime should be locale-formatted, got ' + typedDatetime
    );
    // Non-numeric, non-temporal text (letters, codes) is left exactly as-is.
    Assert.areEqual(
      '1-800-CALL',
      RecordHealthCheckComparisonDisplay.formatValue('1-800-CALL')
    );
    Assert.areEqual(
      '(none)',
      RecordHealthCheckComparisonDisplay.formatList(new List<Object>())
    );
    Assert.areEqual(
      '[A, B]',
      RecordHealthCheckComparisonDisplay.formatList(
        new List<Object>{ 'A', 'B' }
      )
    );
    // Over the preview cap, the list is truncated with a total count
    List<Object> big = new List<Object>();
    for (Integer i = 0; i < 12; i++) {
      big.add(i);
    }
    Assert.isTrue(
      RecordHealthCheckComparisonDisplay.formatList(big).contains('(12 total)'),
      'Long lists should show a total count'
    );
    Assert.areEqual(
      'to equal Technology',
      RecordHealthCheckComparisonDisplay.describeExpected(
        'EQUALS',
        'Technology'
      )
    );
    // Unary operators have no operand
    Assert.areEqual(
      'to not be blank',
      RecordHealthCheckComparisonDisplay.describeExpected('IS_NOT_BLANK', null)
    );
    Assert.areEqual(
      'to be one of [North, South]',
      RecordHealthCheckComparisonDisplay.describeExpectedList(
        'LIST_CONTAINS_ANY',
        new List<Object>{ 'North', 'South' }
      )
    );
  }
}
