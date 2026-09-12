/**
 * Defensive evaluator edge-case tests.
 * SPDX-License-Identifier: Apache-2.0
 */
@IsTest
private class RHCComparisonDisplayEdgeBehaviorTest {
  @TestSetup
  static void setup() {
    RecordHealthCheckTestDataFactory.prepareCoverageFixtures();
  }

  @IsTest
  static void comparisonDisplayCoversRemainingEdgeBranches() {
    // ── Actual-vs-expected description helpers ──────────────────────────────
    Assert.areEqual(
      System.Label.RHC_Operator_Equals,
      RecordHealthCheckComparisonDisplay.operatorLabel('EQUALS'),
      'EQUALS must retain its operator label.'
    );
    Assert.areEqual(
      System.Label.RHC_Operator_GreaterThanOrEqual,
      RecordHealthCheckComparisonDisplay.operatorLabel('GREATER_THAN_OR_EQUAL'),
      'GREATER_THAN_OR_EQUAL must retain its operator label.'
    );
    // Unknown operator falls back to the raw API name
    Assert.areEqual(
      'Mystery',
      RecordHealthCheckComparisonDisplay.operatorLabel('Mystery'),
      'An unknown operator must retain its authored spelling.'
    );
    Assert.areEqual(
      '(blank)',
      RecordHealthCheckComparisonDisplay.formatValue(null),
      'A null value must use the blank marker.'
    );
    Assert.areEqual(
      '(blank)',
      RecordHealthCheckComparisonDisplay.formatValue('   '),
      'Whitespace-only text must use the blank marker.'
    );
    Assert.areEqual(
      'Technology',
      RecordHealthCheckComparisonDisplay.formatValue('Technology'),
      'Ordinary text must remain unchanged.'
    );
    // Values are unquoted because the UI chip visually distinguishes them.
    Assert.areEqual(
      '1',
      RecordHealthCheckComparisonDisplay.formatValue(1),
      'Numeric one must render without quoting.'
    );
    // Booleans read Yes/No, whether they arrive as a typed Boolean (checkbox
    // field, boolean formula) or as a metadata operand string.
    Assert.areEqual(
      System.Label.RHC_Yes,
      RecordHealthCheckComparisonDisplay.formatValue(true),
      'A true Boolean must use the affirmative label.'
    );
    Assert.areEqual(
      System.Label.RHC_No,
      RecordHealthCheckComparisonDisplay.formatValue(false),
      'A false Boolean must use the negative label.'
    );
    Assert.areEqual(
      System.Label.RHC_Yes,
      RecordHealthCheckComparisonDisplay.formatValue('true'),
      'A true metadata operand must use the affirmative label.'
    );
    Assert.areEqual(
      System.Label.RHC_No,
      RecordHealthCheckComparisonDisplay.formatValue('False'),
      'A case-insensitive false operand must use the negative label.'
    );
    // Typed numbers gain thousands separators; digit-only strings retain their
    // exact spelling because they may be postal codes, years, or identifiers.
    Assert.areEqual(
      Decimal.valueOf('70000').format(),
      RecordHealthCheckComparisonDisplay.formatValue(70000.0),
      'A typed whole number must receive grouping separators.'
    );
    Assert.areEqual(
      System.Label.RHC_Operator_Equals +
        ' ' +
        Decimal.valueOf('100000').format(),
      RecordHealthCheckComparisonDisplay.describeExpectedForActual(
        'EQUALS',
        '100000',
        Decimal.valueOf('100000')
      ),
      'A numeric actual value must select numeric expected formatting.'
    );
    Assert.areEqual(
      System.Label.RHC_Operator_Equals + ' 0012345',
      RecordHealthCheckComparisonDisplay.describeExpectedForActual(
        'EQUALS',
        '0012345',
        '0012345'
      ),
      'A string actual value must preserve expected leading zeros.'
    );
    Assert.areEqual(
      '500000',
      RecordHealthCheckComparisonDisplay.formatValue('500000'),
      'A digit-only string must retain its spelling.'
    );
    Assert.areEqual(
      '0012345',
      RecordHealthCheckComparisonDisplay.formatValue('0012345'),
      'A leading-zero string must retain every digit.'
    );
    Assert.areEqual(
      '90210',
      RecordHealthCheckComparisonDisplay.formatValue('90210'),
      'A postal-code string must remain text.'
    );
    Assert.areEqual(
      Decimal.valueOf('70000.5').format(),
      RecordHealthCheckComparisonDisplay.formatValue(70000.5),
      'A typed decimal must retain its fraction with grouping.'
    );
    Assert.areEqual(
      '-' + Decimal.valueOf('1234567').format(),
      RecordHealthCheckComparisonDisplay.formatValue(-1234567),
      'A typed negative number must retain its sign with grouping.'
    );
    // Multi-select picklist text (semicolon-delimited) reads comma-separated.
    Assert.areEqual(
      'Hot, Warm, Cold',
      RecordHealthCheckComparisonDisplay.formatValue('Hot;Warm;Cold'),
      'Multi-select text must use visible comma separators.'
    );
    // Native platform formatting supplies the current locale and time zone.
    String typedDate = RecordHealthCheckComparisonDisplay.formatValue(
      Date.newInstance(2026, 7, 4)
    );
    Assert.areEqual(
      Date.newInstance(2026, 7, 4).format(),
      typedDate,
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
    Assert.areEqual(
      Datetime.newInstance(2026, 7, 4, 17, 30, 0).format(),
      typedDatetime,
      'Typed Datetime should be locale-formatted, got ' + typedDatetime
    );
    // Non-numeric, non-temporal text (letters, codes) is left exactly as-is.
    Assert.areEqual(
      '1-800-CALL',
      RecordHealthCheckComparisonDisplay.formatValue('1-800-CALL'),
      'A mixed text and number code must remain unchanged.'
    );
    Assert.areEqual(
      '(none)',
      RecordHealthCheckComparisonDisplay.formatList(new List<Object>()),
      'An empty list must use the none marker.'
    );
    Assert.areEqual(
      '[A, B]',
      RecordHealthCheckComparisonDisplay.formatList(
        new List<Object>{ 'A', 'B' }
      ),
      'A two-item list must retain its order and delimiters.'
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
      System.Label.RHC_Operator_Equals + ' Technology',
      RecordHealthCheckComparisonDisplay.describeExpected(
        'EQUALS',
        'Technology'
      ),
      'A text expectation must retain its operator phrase.'
    );
    // Unary operators have no operand
    Assert.areEqual(
      System.Label.RHC_Operator_IsNotBlank,
      RecordHealthCheckComparisonDisplay.describeExpected('IS_NOT_BLANK', null),
      'A unary expectation must not add an operand.'
    );
    Assert.areEqual(
      System.Label.RHC_Operator_ListContainsAny + ' [North, South]',
      RecordHealthCheckComparisonDisplay.describeExpectedList(
        'LIST_CONTAINS_ANY',
        new List<Object>{ 'North', 'South' }
      ),
      'A list expectation must retain its operator and item order.'
    );
  }
  @IsTest
  static void allOperatorLabelsPreserveCaseAndFallbackContracts() {
    Map<String, String> labels = new Map<String, String>{
      'EQUALS' => System.Label.RHC_Operator_Equals,
      'NOT_EQUALS' => System.Label.RHC_Operator_NotEquals,
      'CONTAINS' => System.Label.RHC_Operator_Contains,
      'DOES_NOT_CONTAIN' => System.Label.RHC_Operator_DoesNotContain,
      'GREATER_THAN' => System.Label.RHC_Operator_GreaterThan,
      'GREATER_THAN_OR_EQUAL' => System.Label.RHC_Operator_GreaterThanOrEqual,
      'LESS_THAN' => System.Label.RHC_Operator_LessThan,
      'LESS_THAN_OR_EQUAL' => System.Label.RHC_Operator_LessThanOrEqual,
      'IS_BLANK' => System.Label.RHC_Operator_IsBlank,
      'IS_NOT_BLANK' => System.Label.RHC_Operator_IsNotBlank,
      'LIST_CONTAINS_ANY' => System.Label.RHC_Operator_ListContainsAny,
      'LIST_CONTAINS_NONE' => System.Label.RHC_Operator_ListContainsNone,
      'LISTS_OVERLAP' => System.Label.RHC_Operator_ListsOverlap,
      'LISTS_CONTAIN_ALL' => System.Label.RHC_Operator_ListsContainAll,
      'LISTS_MATCH_EXACTLY' => System.Label.RHC_Operator_ListsMatchExactly
    };
    for (String operator : labels.keySet()) {
      Assert.areEqual(
        labels.get(operator),
        RecordHealthCheckComparisonDisplay.operatorLabel(operator),
        'The operator must use its corresponding current-user label: ' +
        operator
      );
      Assert.areEqual(
        labels.get(operator),
        RecordHealthCheckComparisonDisplay.operatorLabel(
          operator.toLowerCase()
        ),
        'Case-insensitive Apex operator matching must remain supported: ' +
        operator
      );
    }
    for (
      String unknown : new List<String>{
        null,
        '',
        ' ',
        'Unknown_Operator',
        ' EQUALS '
      }
    ) {
      Assert.areEqual(
        unknown,
        RecordHealthCheckComparisonDisplay.operatorLabel(unknown),
        'Unknown or untrimmed operator text must remain an exact defensive fallback.'
      );
    }
  }
}
