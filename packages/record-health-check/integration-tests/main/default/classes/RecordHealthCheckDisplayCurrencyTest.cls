/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Covers Display: Value Format rendering for Found and Expected values.
 *
 * Expected numeric separators come from native platform formatting.
 * Integration personas exercise these same contracts in English and German.
 */
@IsTest
private class RecordHealthCheckDisplayCurrencyTest {
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
    amount = localizedAmount(amount);
    String symbol = symbols.get(isoCode);
    if (
      symbol == null ||
      UserInfo.isMultiCurrencyOrganization() ||
      new Set<String>{ 'JPY', 'CNY' }.contains(isoCode)
    ) {
      return isoCode + ' ' + amount;
    }
    return amount.startsWith('-')
      ? '-' + symbol + amount.substring(1)
      : symbol + amount;
  }

  /** Translate the literal expected US separators using native platform samples. */
  private static String localizedAmount(String expectedUsAmount) {
    String groupingMark = Decimal.valueOf('1000')
      .format()
      .replace('1', '')
      .replace('0', '');
    String decimalMark = Decimal.valueOf('1.5')
      .format()
      .replace('1', '')
      .replace('5', '');
    return expectedUsAmount.replace('.', '|')
      .replace(',', groupingMark)
      .replace('|', decimalMark);
  }

  // ─── Auto ─────────────────────────────────────────────────────────────────

  /** The org's corporate currency, or null when the org has a single currency. */
  private static String corporateIsoCode() {
    if (!UserInfo.isMultiCurrencyOrganization()) {
      return null;
    }
    List<SObject> corporate = Database.query(
      'SELECT IsoCode FROM CurrencyType WHERE IsCorporate = TRUE LIMIT 1'
    );
    return corporate.isEmpty()
      ? null
      : String.valueOf(corporate[0].get('IsoCode'));
  }

  @IsTest
  static void currencyDefaultsToRunningUser() {
    System.runAs(RecordHealthCheckTestDataFactory.currentUser()) {
      String iso = UserInfo.getDefaultCurrency();
      for (Object amount : new List<Object>{ 70000, -1250.5, 0, '50000' }) {
        Assert.areEqual(
          RecordHealthCheckDisplayFormat.render(amount, CURRENCY_FORMAT, iso),
          RecordHealthCheckDisplayFormat.render(amount, CURRENCY_FORMAT),
          'An omitted currency must route to the running user currency for positive, negative, zero and metadata values.'
        );
      }
    }
  }

  @IsTest
  static void currencyHonoursSymbolIsoStyleAndMinorUnits() {
    // Rendering per currency code rather than only the org's own currency, so
    // the symbol table, the ISO fallback, and the minor-unit checks are all
    // exercised in a single-currency org.
    System.runAs(RecordHealthCheckTestDataFactory.currentUser()) {
      Assert.areEqual(
        money('USD', '70,000.00'),
        RecordHealthCheckDisplayFormat.render(70000, CURRENCY_FORMAT, 'USD'),
        'An explicit USD amount must use its expected label and two minor units.'
      );
      Assert.areEqual(
        money('EUR', '1,234.56'),
        RecordHealthCheckDisplayFormat.render(1234.56, CURRENCY_FORMAT, 'EUR'),
        'An explicit EUR amount must preserve its fraction and native separators.'
      );
      Assert.areEqual(
        money('JPY', '70,000'),
        RecordHealthCheckDisplayFormat.render(70000, CURRENCY_FORMAT, 'JPY'),
        'Yen has no minor unit, so no decimal places are shown'
      );
      Assert.areEqual(
        money('KRW', '1,500'),
        RecordHealthCheckDisplayFormat.render(1500, CURRENCY_FORMAT, 'KRW'),
        'An explicit KRW amount must omit fractional minor units.'
      );
      Assert.areEqual(
        'SAR ' + localizedAmount('70,000.00'),
        RecordHealthCheckDisplayFormat.render(70000, CURRENCY_FORMAT, 'SAR'),
        'A currency with no symbol on file renders in ISO style'
      );
      Assert.areEqual(
        'SAR ' + localizedAmount('70,000.00'),
        RecordHealthCheckDisplayFormat.render(70000, CURRENCY_FORMAT, ' sar '),
        'The currency code is trimmed and matched without regard to case'
      );
      Assert.areEqual(
        money('USD', '-1,250.50'),
        RecordHealthCheckDisplayFormat.render(-1250.5, CURRENCY_FORMAT, 'USD'),
        'A negative amount keeps its minus sign'
      );
      Assert.areEqual(
        money('USD', '0.00'),
        RecordHealthCheckDisplayFormat.render(0, CURRENCY_FORMAT, 'USD'),
        'Explicit USD zero must remain a formatted amount rather than blank.'
      );
      Assert.areEqual(
        money('USD', '99.90'),
        RecordHealthCheckDisplayFormat.render(99.9, CURRENCY_FORMAT, 'USD'),
        'A short fraction is padded out to the minor unit'
      );
      Assert.areEqual(
        money('USD', '1.24'),
        RecordHealthCheckDisplayFormat.render(1.235, CURRENCY_FORMAT, 'USD'),
        'A sub-cent amount is rounded for display only'
      );
      Assert.areEqual(
        RecordHealthCheckDisplayFormat.render(
          70000,
          CURRENCY_FORMAT,
          UserInfo.getDefaultCurrency()
        ),
        RecordHealthCheckDisplayFormat.render(70000, CURRENCY_FORMAT, null),
        'A blank currency input uses the running user currency'
      );
      Assert.areEqual(
        '(blank)',
        RecordHealthCheckDisplayFormat.render(null, CURRENCY_FORMAT, 'USD'),
        'An absent amount must display blank even with an explicit currency.'
      );
    }
  }

  @IsTest
  static void currencyFollowsTheRunningUserLocale() {
    System.runAs(RecordHealthCheckTestDataFactory.createUserWithLocale(
      'de_DE',
      'rhccde'
    )) {
      Assert.areEqual(
        money('EUR', '1,234.56'),
        RecordHealthCheckDisplayFormat.render(1234.56, CURRENCY_FORMAT, 'EUR'),
        'A German (Germany) user sees the locale grouping and decimal mark'
      );
    }
  }

  @IsTest
  static void currencyKeepsValuesThatAreNotAmounts() {
    System.runAs(RecordHealthCheckTestDataFactory.currentUser()) {
      Assert.areEqual(
        '001A2B3C4D5E6F7G',
        RecordHealthCheckDisplayFormat.render(
          '001A2B3C4D5E6F7G',
          CURRENCY_FORMAT
        ),
        'Currency on an Id keeps the original spelling'
      );
      Assert.areEqual(
        'true',
        RecordHealthCheckDisplayFormat.render(true, CURRENCY_FORMAT),
        'Currency must preserve a boolean as text rather than treat it as money.'
      );
      Assert.areEqual(
        '$70,000',
        RecordHealthCheckDisplayFormat.render('$70,000', CURRENCY_FORMAT),
        'An already-formatted amount is not formatted a second time'
      );
      Assert.areEqual(
        '(blank)',
        RecordHealthCheckDisplayFormat.render(null, CURRENCY_FORMAT),
        'An absent amount must display blank under the default currency.'
      );
    }
  }

  @IsTest
  static void textStartingWithCollectionPunctuationRemainsText() {
    Test.startTest();
    String parenthesized = RecordHealthCheckDisplayFormat.render(
      '(555) 867-5309',
      'TEXT'
    );
    String bracketed = RecordHealthCheckDisplayFormat.render(
      '[Legacy] Record',
      'AUTO'
    );
    Test.stopTest();

    Assert.areEqual(
      '(555) 867-5309',
      parenthesized,
      'A parenthesized Phone or Text value must not be cast to a List.'
    );
    Assert.areEqual(
      '[Legacy] Record',
      bracketed,
      'A bracket-prefixed Text value must not be cast to a List.'
    );
  }

  @IsTest
  static void aggregateAmountsAreLabelledWithTheCorporateCurrency() {
    List<AggregateResult> totals = [
      SELECT SUM(Amount) total
      FROM Opportunity
      WHERE Id = NULL
    ];
    SObject aggregate = totals.isEmpty() ? null : totals[0];
    String iso = RecordHealthCheckDisplayFormat.currencyIsoCodeFrom(aggregate);

    if (!UserInfo.isMultiCurrencyOrganization()) {
      Assert.areEqual(
        null,
        iso,
        'A single-currency org has one currency, so there is nothing to resolve'
      );
      return;
    }

    // Salesforce converts an aggregate into the corporate currency, so the chip
    // has to say corporate rather than whichever currency the reader uses.
    List<SObject> corporate = Database.query(
      'SELECT IsoCode FROM CurrencyType WHERE IsCorporate = TRUE LIMIT 1'
    );
    Assert.areEqual(
      String.valueOf(corporate[0].get('IsoCode')),
      iso,
      'An aggregate is labelled with the corporate currency'
    );
  }

  @IsTest
  static void contractsFollowExplicitLocales() {
    User english = RecordHealthCheckTestDataFactory.createUserWithLocale(
      'en_US',
      'rhceng'
    );
    User german = RecordHealthCheckTestDataFactory.createUserWithLocale(
      'de_DE',
      'rhcger'
    );
    assertContractsForPersona(english, 'en_US');
    assertContractsForPersona(german, 'de_DE');
  }

  private static void assertContractsForPersona(
    User persona,
    String expectedLocale
  ) {
    System.runAs(persona) {
      Assert.areEqual(
        expectedLocale,
        UserInfo.getLocale(),
        'The integration persona must honor its explicitly requested locale.'
      );
      currencyDefaultsToRunningUser();
      currencyHonoursSymbolIsoStyleAndMinorUnits();
      currencyKeepsValuesThatAreNotAmounts();
      aggregateAmountsAreLabelledWithTheCorporateCurrency();
    }
  }
}
