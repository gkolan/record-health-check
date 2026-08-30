/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Covers Display: Value Format rendering for Found and Expected values.
 *
 * Assertions that involve grouping separators run as a user with a pinned
 * locale, so the suite reads the same way in an org whose default locale is not
 * English (US).
 */
@IsTest
private class RecordHealthCheckDisplayNumberTest {
  private static final String AUTO = 'AUTO';
  private static final String NUMBER_FORMAT = 'NUMBER';
  private static final String CURRENCY_FORMAT = 'CURRENCY';
  private static final String PERCENT_FORMAT = 'PERCENT';
  private static final String RATIO_PERCENT_FORMAT = 'RATIO_PERCENT';
  private static final String BOOLEAN_FORMAT = 'BOOLEAN';
  private static final String DATE_FORMAT = 'DATE';
  private static final String DATETIME_FORMAT = 'DATETIME';
  private static final String TEXT_FORMAT = 'TEXT';
  private static final String RAW_FORMAT = 'RAW';

  /** A user pinned to a locale so separator assertions are deterministic. */
  private static User userWithLocale(String locale, String alias) {
    return RecordHealthCheckTestDataFactory.createUserWithLocale(locale, alias);
  }

  /**
   * How an amount reads in this org: an org with more than one currency leads
   * with the ISO code because a bare symbol would be ambiguous, and a
   * single-currency org uses the symbol. Building the expectation the same way
   * the renderer decides keeps these assertions true in both kinds of org.
   */
  private static String money(String isoCode, String amount) {
    Map<String, String> symbols = new Map<String, String>{
      'USD' => '$',
      'EUR' => '€',
      'JPY' => '¥',
      'KRW' => '₩'
    };
    String symbol = symbols.get(isoCode);
    if (symbol == null || UserInfo.isMultiCurrencyOrganization()) {
      return isoCode + ' ' + amount;
    }
    return amount.startsWith('-')
      ? '-' + symbol + amount.substring(1)
      : symbol + amount;
  }

  // ─── Auto ─────────────────────────────────────────────────────────────────

  @IsTest
  static void numberGroupsOptedInDigitStrings() {
    System.runAs(userWithLocale('en_US', 'rhcnum')) {
      Assert.areEqual(
        '500,000',
        RecordHealthCheckDisplayFormat.render('500000', NUMBER_FORMAT),
        'Naming Number opts a digit string into grouping'
      );
      Assert.areEqual(
        '90,210',
        RecordHealthCheckDisplayFormat.render('90210', NUMBER_FORMAT)
      );
      Assert.areEqual(
        '1,234.5',
        RecordHealthCheckDisplayFormat.render('1234.50', NUMBER_FORMAT),
        'Trailing zeros are dropped but a real fraction survives'
      );
      Assert.areEqual(
        '1,000',
        RecordHealthCheckDisplayFormat.render(1000, NUMBER_FORMAT)
      );
    }
  }

  @IsTest
  static void numberKeepsValuesItCannotSafelyGroup() {
    System.runAs(userWithLocale('en_US', 'rhcnumf')) {
      Assert.areEqual(
        '0012345',
        RecordHealthCheckDisplayFormat.render('0012345', NUMBER_FORMAT),
        'Grouping would drop the leading zeros, so the value stays as written'
      );
      Assert.areEqual(
        'Technology',
        RecordHealthCheckDisplayFormat.render('Technology', NUMBER_FORMAT),
        'Number on free text keeps the original spelling'
      );
      Assert.areEqual(
        'true',
        RecordHealthCheckDisplayFormat.render(true, NUMBER_FORMAT),
        'Number on a checkbox keeps the original spelling, it does not read Yes'
      );
      Assert.areEqual(
        '12,345',
        RecordHealthCheckDisplayFormat.render('12,345', NUMBER_FORMAT),
        'Already-grouped text is not parsed and regrouped'
      );
      Assert.areEqual(
        '(blank)',
        RecordHealthCheckDisplayFormat.render(null, NUMBER_FORMAT)
      );
    }
  }

  @IsTest
  static void groupingSeparatorsFollowTheRunningUserLocale() {
    // The headline of the number work: separators come from the running user's
    // locale rather than a hardcoded comma.
    System.runAs(userWithLocale('de_DE', 'rhcde')) {
      String rendered = RecordHealthCheckDisplayFormat.render(
        70000.0,
        NUMBER_FORMAT
      );
      Assert.areEqual(
        '70.000',
        rendered,
        'A German (Germany) user should see a period as the grouping separator'
      );
      Assert.areEqual(
        '70.000,5',
        RecordHealthCheckDisplayFormat.render(70000.5, NUMBER_FORMAT),
        'A German (Germany) user should see a comma as the decimal mark'
      );
    }
  }

  @IsTest
  static void percentAddsTheSymbolWithoutDoublingIt() {
    System.runAs(userWithLocale('en_US', 'rhcpct')) {
      Assert.areEqual(
        '12.5%',
        RecordHealthCheckDisplayFormat.render(12.5, PERCENT_FORMAT)
      );
      Assert.areEqual(
        '80%',
        RecordHealthCheckDisplayFormat.render(80, PERCENT_FORMAT)
      );
      Assert.areEqual(
        '0%',
        RecordHealthCheckDisplayFormat.render(0, PERCENT_FORMAT)
      );
      Assert.areEqual(
        '-5%',
        RecordHealthCheckDisplayFormat.render(-5, PERCENT_FORMAT)
      );
      Assert.areEqual(
        '12%',
        RecordHealthCheckDisplayFormat.render(12.0, PERCENT_FORMAT),
        'An all-zero fractional part is dropped before the symbol'
      );
      Assert.areEqual(
        '12.5%',
        RecordHealthCheckDisplayFormat.render('12.5%', PERCENT_FORMAT),
        'Text that already ends in a percent sign is left alone'
      );
      Assert.areEqual(
        'Technology',
        RecordHealthCheckDisplayFormat.render('Technology', PERCENT_FORMAT)
      );
    }
  }

  @IsTest
  static void ratioPercentMultipliesForDisplayOnly() {
    System.runAs(userWithLocale('en_US', 'rhcratio')) {
      Assert.areEqual(
        '75%',
        RecordHealthCheckDisplayFormat.render(0.75, RATIO_PERCENT_FORMAT)
      );
      Assert.areEqual(
        '100%',
        RecordHealthCheckDisplayFormat.render(1, RATIO_PERCENT_FORMAT)
      );
      Assert.areEqual(
        '-5%',
        RecordHealthCheckDisplayFormat.render(-0.05, RATIO_PERCENT_FORMAT)
      );
      Assert.areEqual(
        '125%',
        RecordHealthCheckDisplayFormat.render(1.25, RATIO_PERCENT_FORMAT)
      );
      Assert.areEqual(
        'already formatted',
        RecordHealthCheckDisplayFormat.render(
          'already formatted',
          RATIO_PERCENT_FORMAT
        )
      );
      Assert.areEqual(
        false,
        RecordHealthCheckComparisonEngine.valuesEqual(0.75, 75),
        'Ratio formatting never changes comparison operands'
      );
    }
  }

  @IsTest
  static void alignedOperandsKeepLeadingZeros() {
    Assert.areEqual(
      '00100',
      (String) RecordHealthCheckDisplayFormat.alignExpectedToFound(
        '00100',
        5.0,
        AUTO
      ),
      'Aligning must not drop leading zeros, matching the Number format'
    );
    Assert.areEqual(
      true,
      RecordHealthCheckDisplayFormat.alignExpectedToFound(
        '100',
        5.0,
        AUTO
      ) instanceof Decimal,
      'A plain numeric operand still aligns'
    );
  }

  @IsTest
  static void expectedAlignsWithFoundOnAuto() {
    // A fixed metadata operand arrives as text. When Found is numeric, Expected
    // is parsed back to a number so the two chips group the same way.
    Object aligned = RecordHealthCheckDisplayFormat.alignExpectedToFound(
      '100000',
      70000.0,
      AUTO
    );
    Assert.areEqual(
      true,
      aligned instanceof Decimal,
      'A numeric operand should align to a number when Found is numeric'
    );

    Assert.areEqual(
      '90210',
      (String) RecordHealthCheckDisplayFormat.alignExpectedToFound(
        '90210',
        'text found',
        AUTO
      ),
      'A text Found value leaves the operand alone'
    );
    Assert.areEqual(
      'Technology',
      (String) RecordHealthCheckDisplayFormat.alignExpectedToFound(
        'Technology',
        70000.0,
        AUTO
      ),
      'An operand that is not a number is left alone even beside a numeric Found'
    );
    Assert.areEqual(
      '100000',
      (String) RecordHealthCheckDisplayFormat.alignExpectedToFound(
        '100000',
        70000.0,
        RAW_FORMAT
      ),
      'Raw asks for the original spelling, so no alignment happens'
    );
    Assert.areEqual(
      '100000',
      (String) RecordHealthCheckDisplayFormat.alignExpectedToFound(
        '100000',
        70000.0,
        CURRENCY_FORMAT
      ),
      'A named format already renders both sides the same way'
    );
  }

  @IsTest
  static void foundAndExpectedReadInTheSameUnits() {
    System.runAs(userWithLocale('en_US', 'rhcsym')) {
      String found = RecordHealthCheckComparisonDisplay.formatValue(
        70000.0,
        CURRENCY_FORMAT
      );
      String expected = RecordHealthCheckComparisonDisplay.describeExpectedForActual(
        'GREATER_THAN_OR_EQUAL',
        '50000',
        70000.0,
        CURRENCY_FORMAT
      );
      Assert.areEqual(
        true,
        expected.startsWith('at least '),
        'The operator phrase still leads the Expected chip: ' + expected
      );
      String iso = UserInfo.getDefaultCurrency();
      Assert.areEqual(money(iso, '70,000.00'), found);
      Assert.areEqual(
        'at least ' + money(iso, '50,000.00'),
        expected,
        'Both chips read in the same currency'
      );

      Assert.areEqual(
        '100,000',
        RecordHealthCheckComparisonDisplay.formatValue(100000.0, AUTO)
      );
      Assert.areEqual(
        'to equal 100,000',
        RecordHealthCheckComparisonDisplay.describeExpectedForActual(
          'EQUALS',
          '100000',
          100000.0,
          AUTO
        ),
        'On Auto a numeric operand groups like the Found value beside it'
      );
      Assert.areEqual(
        'to be blank',
        RecordHealthCheckComparisonDisplay.describeExpected(
          'IS_BLANK',
          null,
          CURRENCY_FORMAT
        ),
        'A unary operator has no operand to format'
      );
    }
  }

  @IsTest
  static void highScaleNumbersAreRoundedForTheChip() {
    System.runAs(userWithLocale('en_US', 'rhcscl')) {
      Assert.areEqual(
        '1.123457',
        RecordHealthCheckDisplayFormat.render(1.123456789, NUMBER_FORMAT),
        'A chip shows at most six decimal places'
      );
      Assert.areEqual(
        '1.123457',
        RecordHealthCheckDisplayFormat.render(1.123456789, AUTO),
        'Auto caps the same way'
      );
      Assert.areEqual(
        '1.12345',
        RecordHealthCheckDisplayFormat.render(1.12345, NUMBER_FORMAT),
        'A number inside the cap keeps every digit it has'
      );
      // Display only: the comparison still reads the full value.
      Assert.areEqual(
        false,
        RecordHealthCheckComparisonEngine.valuesEqual(1.123456789, 1.123457),
        'Rounding for the chip does not make two different numbers equal'
      );
    }
  }

  @IsTest
  static void unsafeNumericSpellingsRemainUnchanged() {
    Assert.isNull(
      RecordHealthCheckDisplayNumberRenderer.toDisplayDecimal('001'),
      'Leading zeros are meaningful text and must not be discarded.'
    );
    Assert.isNull(
      RecordHealthCheckDisplayNumberRenderer.toDisplayDecimal(new Account()),
      'A nonnumeric object must remain unformatted.'
    );
  }
}
