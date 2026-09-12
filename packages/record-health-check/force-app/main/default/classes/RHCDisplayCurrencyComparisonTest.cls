/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Covers Display: Value Format rendering for Found and Expected values.
 *
 * Numeric expectations use native platform separators for the running user.
 * Integration personas exercise the list contract in English and German.
 */
@IsTest
private class RHCDisplayCurrencyComparisonTest {
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
    if (symbol == null || UserInfo.isMultiCurrencyOrganization()) {
      return isoCode + ' ' + amount;
    }
    return amount.startsWith('-')
      ? '-' + symbol + amount.substring(1)
      : symbol + amount;
  }

  /** Localize expected numeric punctuation using independent platform samples. */
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
  static void listEntriesKeepTheCurrencyOfTheRowTheyCameFrom() {
    System.runAs(RecordHealthCheckTestDataFactory.currentUser()) {
      String mixed = RecordHealthCheckComparisonDisplay.formatList(
        new List<Object>{ 70000, 50000 },
        CURRENCY_FORMAT,
        new List<String>{ 'EUR', 'JPY' }
      );
      Assert.areEqual(
        '[' +
          money('EUR', '70,000.00') +
          ', JPY ' +
          localizedAmount('50,000') +
          ']',
        mixed,
        'Each entry is labelled with its own row currency, minor units included'
      );

      // A row with no currency of its own falls back to the running user's,
      // the same as a single value.
      Assert.areEqual(
        '[' +
          money('EUR', '70,000.00') +
          ', ' +
          RecordHealthCheckDisplayFormat.render(50000, CURRENCY_FORMAT, null) +
          ']',
        RecordHealthCheckComparisonDisplay.formatList(
          new List<Object>{ 70000, 50000 },
          CURRENCY_FORMAT,
          new List<String>{ 'EUR', null }
        ),
        'An entry with no currency reads in the running user currency'
      );

      Assert.areEqual(
        'at least ' +
        RecordHealthCheckComparisonDisplay.formatList(
          new List<Object>{ 70000 },
          CURRENCY_FORMAT,
          new List<String>{ 'EUR' }
        ),
        RecordHealthCheckComparisonDisplay.describeExpectedList(
          'GREATER_THAN_OR_EQUAL',
          new List<Object>{ 70000 },
          CURRENCY_FORMAT,
          new List<String>{ 'EUR' }
        ),
        'The Expected list carries per-row currencies through the operator phrase'
      );

      Assert.areEqual(
        '[' +
          money('EUR', '70,000.00') +
          ', ' +
          RecordHealthCheckDisplayFormat.render(
            '50000',
            CURRENCY_FORMAT,
            null
          ) +
          ']',
        RecordHealthCheckComparisonDisplay.formatList(
          new List<Object>{ 70000, '50000' },
          CURRENCY_FORMAT,
          new List<String>{ 'EUR' }
        ),
        'A short ISO list safely falls back to the running user currency'
      );

      List<Object> elevenValues = new List<Object>();
      List<String> elevenIsoCodes = new List<String>();
      for (Integer i = 0; i < 11; i++) {
        elevenValues.add(i == 1 ? null : i + 1);
        elevenIsoCodes.add(i == 0 ? 'JPY' : 'EUR');
      }
      String capped = RecordHealthCheckComparisonDisplay.formatList(
        elevenValues,
        CURRENCY_FORMAT,
        elevenIsoCodes
      );
      Assert.areEqual(
        true,
        capped.startsWith('[JPY 1, (blank), '),
        'Row order, a null entry, and its currency position survive list formatting'
      );
      Assert.areEqual(
        true,
        capped.endsWith(' … (11 total)]'),
        'Per-row currency lists keep the shared ten-entry preview cap'
      );
    }
  }

  @IsTest
  static void defensiveListCurrencyAndRelationshipPathsAreDeterministic() {
    AggregateResult aggregate = [SELECT COUNT(Id) total FROM Account];
    RecordHealthCheckDisplayCurrencyResolver.multiCurrency = true;
    RecordHealthCheckDisplayCurrencyResolver.corporateCurrencyLoaded = false;
    RecordHealthCheckDisplayCurrencyResolver.corporateCurrencyCode = null;

    Test.startTest();
    String typedList = RecordHealthCheckDisplayFormat.render(
      new List<Date>{ Date.today() },
      DATE_FORMAT
    );
    Boolean blankOne = RecordHealthCheckDisplayFormat.isDisplayedNumberOne(
      null
    );
    Boolean numericOne = RecordHealthCheckDisplayFormat.isDisplayedNumberOne(
      '1'
    );
    Boolean invalidOne = RecordHealthCheckDisplayFormat.isDisplayedNumberOne(
      'not a number'
    );
    Boolean knownFormat = RecordHealthCheckDisplayFormat.isFormatApiName(
      NUMBER_FORMAT
    );
    Boolean blankFormat = RecordHealthCheckDisplayFormat.isFormatApiName(null);
    Object plainField = RecordHealthCheckDisplayFormat.valueForDisplay(
      'Acme',
      AUTO,
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'Name' => 'Acme' }
      ),
      'Name'
    );
    String aggregateIso = RecordHealthCheckDisplayFormat.currencyIsoCodeFrom(
      aggregate
    );
    String rowIso = RecordHealthCheckDisplayFormat.currencyIsoCodeFrom(
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'Name' => 'No currency field' }
      )
    );
    SObject invalidRelationship = RecordHealthCheckDisplayCurrencyResolver.rowForFieldPath(
      RecordHealthCheckTestDataFactory.account(new Map<String, Object>()),
      'MissingRelationship.Name'
    );
    SObject nullRelationship = RecordHealthCheckDisplayCurrencyResolver.rowForFieldPath(
      RecordHealthCheckTestDataFactory.account(new Map<String, Object>()),
      'Parent.Name'
    );
    String cachedCorporate = RecordHealthCheckDisplayCurrencyResolver.corporateCurrency();
    RecordHealthCheckDisplayCurrencyResolver.corporateCurrencyLoaded = false;
    RecordHealthCheckDisplayCurrencyResolver.multiCurrency = false;
    String singleCurrencyCorporate = RecordHealthCheckDisplayCurrencyResolver.corporateCurrency();
    String nullAmount = RecordHealthCheckDisplayCurrencyRenderer.render(
      null,
      'USD',
      false
    );
    String unnamedCurrency = RecordHealthCheckDisplayCurrencyRenderer.render(
      12,
      null,
      false
    );
    RecordHealthCheckDisplayCurrencyResolver.multiCurrency = false;
    String singleCurrency = RecordHealthCheckDisplayCurrencyRenderer.render(
      12,
      'USD',
      false
    );
    RecordHealthCheckDisplayCurrencyResolver.multiCurrency = true;
    String multipleCurrency = RecordHealthCheckDisplayCurrencyRenderer.render(
      12,
      'USD',
      true
    );
    Test.stopTest();

    Assert.isTrue(
      typedList.startsWith('[') && typedList.endsWith(']'),
      'A strongly typed Date list must retain a stable list-shaped representation.'
    );
    Assert.isFalse(blankOne, 'Blank text must not be interpreted as one.');
    Assert.isTrue(numericOne, 'Localized numeric one must be recognized.');
    Assert.isFalse(
      invalidOne,
      'Nonnumeric text must not be interpreted as one.'
    );
    Assert.isTrue(knownFormat, 'A canonical format API name must be accepted.');
    Assert.isFalse(
      blankFormat,
      'A blank format is Auto, not a canonical API name.'
    );
    Assert.areEqual(
      'Acme',
      plainField,
      'Auto formatting must retain a plain text field value.'
    );
    Assert.areEqual(
      cachedCorporate,
      aggregateIso,
      'An aggregate without row ISO evidence must use the cached corporate currency.'
    );
    Assert.isNull(
      singleCurrencyCorporate,
      'A single-currency org must not require a corporate currency lookup.'
    );
    Assert.isNull(
      rowIso,
      'An unloaded row currency must not manufacture an ISO value.'
    );
    Assert.isNull(
      invalidRelationship,
      'An invalid relationship path must not resolve a row.'
    );
    Assert.isNull(
      nullRelationship,
      'An unloaded parent relationship must not resolve a row.'
    );
    Assert.areEqual(
      RecordHealthCheckDisplayFormat.BLANK_TEXT,
      nullAmount,
      'A null currency amount must retain the blank display marker.'
    );
    Assert.areEqual(
      '12',
      unnamedCurrency,
      'An unnamed currency must render only the numeric amount.'
    );
    Assert.isTrue(
      singleCurrency.contains('$'),
      'Single-currency USD rendering must include the dollar symbol.'
    );
    Assert.isTrue(
      multipleCurrency.startsWith('USD '),
      'Multicurrency USD rendering must lead with the explicit ISO code.'
    );
  }
}
