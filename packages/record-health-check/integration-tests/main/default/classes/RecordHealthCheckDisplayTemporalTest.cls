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
private class RecordHealthCheckDisplayTemporalTest {
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
  static void dateAndDatetimeRenderInTheUserLocale() {
    Date july4 = Date.newInstance(2026, 7, 4);
    Datetime july4Evening = Datetime.newInstance(2026, 7, 4, 17, 30, 0);

    Assert.areEqual(
      july4.format(),
      RecordHealthCheckDisplayFormat.render(july4, DATE_FORMAT)
    );
    Assert.areEqual(
      july4.format(),
      RecordHealthCheckDisplayFormat.render('2026-07-04', DATE_FORMAT),
      'ISO date text renders like a typed Date'
    );
    Assert.areEqual(
      july4.format(),
      RecordHealthCheckDisplayFormat.render('2026-07-04 17:30:00', DATE_FORMAT),
      'Naming Date on a date/time shows just the date part'
    );
    Assert.areEqual(
      july4Evening.format(),
      RecordHealthCheckDisplayFormat.render(july4Evening, DATETIME_FORMAT)
    );
    Assert.areEqual(
      july4Evening.format(),
      RecordHealthCheckDisplayFormat.render(
        '2026-07-04T17:30:00',
        DATETIME_FORMAT
      ),
      'A T separator is accepted'
    );
    Assert.areEqual(
      july4.format(),
      RecordHealthCheckDisplayFormat.render(july4, DATETIME_FORMAT),
      'A Date has no time of day, so it renders as a date'
    );
    Assert.areEqual(
      july4.format(),
      RecordHealthCheckDisplayFormat.render(july4Evening, DATE_FORMAT),
      'Naming Date on a typed Datetime shows just the date part'
    );
    Assert.areEqual(
      july4.format(),
      RecordHealthCheckDisplayFormat.render('2026-07-04', DATETIME_FORMAT),
      'Date-only text under Date/Time has no time of day to show'
    );
    Assert.areEqual(
      'Technology',
      RecordHealthCheckDisplayFormat.render('Technology', DATE_FORMAT),
      'Date on text that is not a date keeps the original spelling'
    );
    Assert.areEqual(
      'Technology',
      RecordHealthCheckDisplayFormat.render('Technology', DATETIME_FORMAT)
    );
  }

  @IsTest
  static void dateShapedTextThatIsNotARealDateStaysAsWritten() {
    // Date.newInstance rolls out-of-range parts over, so without a range check
    // "2026-13-40" would read as 9 February 2027 — a date the record never held.
    for (
      String format : new List<String>{ AUTO, DATE_FORMAT, DATETIME_FORMAT }
    ) {
      Assert.areEqual(
        '2026-13-40',
        RecordHealthCheckDisplayFormat.render('2026-13-40', format),
        format + ' should leave an impossible month and day as written'
      );
      Assert.areEqual(
        '2026-02-30',
        RecordHealthCheckDisplayFormat.render('2026-02-30', format),
        format + ' should leave 30 February as written'
      );
      Assert.areEqual(
        '2026-07-04 99:99:99',
        RecordHealthCheckDisplayFormat.render('2026-07-04 99:99:99', format),
        format + ' should leave an impossible time as written'
      );
    }

    // A real leap day still renders.
    Assert.areEqual(
      Date.newInstance(2028, 2, 29).format(),
      RecordHealthCheckDisplayFormat.render('2028-02-29', AUTO),
      '29 February in a leap year is a real date'
    );
    Assert.areEqual(
      '2027-02-29',
      RecordHealthCheckDisplayFormat.render('2027-02-29', AUTO),
      '29 February outside a leap year is not'
    );
  }

  @IsTest
  static void textAndRawKeepTheOriginalSpelling() {
    for (String format : new List<String>{ TEXT_FORMAT, RAW_FORMAT }) {
      Assert.areEqual(
        'true',
        RecordHealthCheckDisplayFormat.render(true, format),
        format + ' should not turn a checkbox into Yes'
      );
      Assert.areEqual(
        '2026-07-04',
        RecordHealthCheckDisplayFormat.render('2026-07-04', format),
        format + ' should not reformat text that looks like a date'
      );
      Assert.areEqual(
        'Hot;Warm;Cold',
        RecordHealthCheckDisplayFormat.render('Hot;Warm;Cold', format),
        format + ' should not rewrite multi-select delimiters'
      );
      Assert.areEqual(
        '0012345',
        RecordHealthCheckDisplayFormat.render('0012345', format)
      );
      Assert.areEqual(
        '(blank)',
        RecordHealthCheckDisplayFormat.render(null, format),
        format + ' still uses the blank placeholder'
      );
      Assert.areEqual(
        '(blank)',
        RecordHealthCheckDisplayFormat.render('  ', format)
      );
    }
  }

  @IsTest
  static void timeFieldsReadAsAClockTime() {
    // String.valueOf on a Time writes the storage form 17:30:00.000Z, which
    // reads as machine output on a card.
    Assert.areEqual(
      '17:30',
      RecordHealthCheckDisplayFormat.render(
        Time.newInstance(17, 30, 0, 0),
        AUTO
      ),
      'A whole minute drops the seconds'
    );
    Assert.areEqual(
      '09:05',
      RecordHealthCheckDisplayFormat.render(Time.newInstance(9, 5, 0, 0), AUTO),
      'Single digits are padded so times line up'
    );
    Assert.areEqual(
      '17:30:45',
      RecordHealthCheckDisplayFormat.render(
        Time.newInstance(17, 30, 45, 0),
        AUTO
      ),
      'Seconds are kept when the value has them'
    );
    Assert.areEqual(
      '17:30',
      RecordHealthCheckDisplayFormat.render(
        Time.newInstance(17, 30, 0, 0),
        DATETIME_FORMAT
      ),
      'Naming Date/Time on a Time field reads the time of day'
    );
    Assert.areEqual(
      '17:30:00.000Z',
      RecordHealthCheckDisplayFormat.render(
        Time.newInstance(17, 30, 0, 0),
        RAW_FORMAT
      ),
      'Raw still shows the stored value'
    );
  }

  @IsTest
  static void formatChoiceDoesNotChangeTheComparison() {
    // The whole feature is display only. The operator core reads the raw typed
    // values, so no format can move a check between pass and fail.
    Assert.areEqual(
      true,
      RecordHealthCheckComparisonEngine.applySingleValueComparison(
        'GREATER_THAN_OR_EQUAL',
        70000.0,
        50000.0
      )
    );
    Assert.areEqual(
      false,
      RecordHealthCheckComparisonEngine.applySingleValueComparison(
        'GREATER_THAN_OR_EQUAL',
        40000.0,
        50000.0
      )
    );
    Assert.areEqual(
      true,
      RecordHealthCheckComparisonEngine.valuesEqual(70000.0, 70000),
      'Value equality is unaffected by how the values would be written'
    );
  }
}
