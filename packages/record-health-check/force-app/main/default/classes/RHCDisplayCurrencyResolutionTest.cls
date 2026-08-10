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
private class RHCDisplayCurrencyResolutionTest {
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
  static void recordCurrencyIsReadOnlyWhenTheOrgHasMoreThanOne() {
    Assert.areEqual(
      null,
      RecordHealthCheckDisplayFormat.currencyIsoCodeFrom(null),
      'No row means no currency to read'
    );

    if (!UserInfo.isMultiCurrencyOrganization()) {
      Assert.areEqual(
        null,
        RecordHealthCheckDisplayFormat.currencyIsoCodeFrom(
          RecordHealthCheckTestDataFactory.opportunity(
            new Map<String, Object>{ 'Amount' => 70000 }
          )
        ),
        'With one currency in the org there is no per-record currency to read'
      );
      return;
    }

    // With more than one currency, an amount is shown in the currency its own
    // record carries rather than the currency the reader happens to work in.
    SObject row = (SObject) Type.forName('Opportunity').newInstance();
    row.put('Amount', 70000);
    row.put('CurrencyIsoCode', 'EUR');

    Assert.areEqual(
      'EUR',
      RecordHealthCheckDisplayFormat.currencyIsoCodeFrom(row),
      'The row currency is read from CurrencyIsoCode'
    );
    Assert.areEqual(
      'EUR 70,000.00',
      RecordHealthCheckDisplayFormat.render(
        70000,
        CURRENCY_FORMAT,
        RecordHealthCheckDisplayFormat.currencyIsoCodeFrom(row)
      ),
      'A euro record reads in euros even for a user whose currency is different'
    );
    Assert.areEqual(
      UserInfo.getDefaultCurrency() + ' 70,000.00',
      RecordHealthCheckDisplayFormat.render(70000, CURRENCY_FORMAT, null),
      'With no record currency the running user currency is used'
    );

    // An aggregate is covered by aggregateAmountsAreLabelledWithTheCorporateCurrency.
  }

  @IsTest
  static void eachSideBorrowsTheCardRecordCurrencyOnlyForItsOwnObject() {
    Account card = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Card record' }
    );

    Assert.areEqual(
      null,
      RecordHealthCheckDisplayFormat.currencyIsoCodeFor(null, card),
      'No row means no currency to read'
    );
    Assert.areEqual(
      null,
      RecordHealthCheckDisplayFormat.currencyIsoCodeFor(
        RecordHealthCheckTestDataFactory.account(
          new Map<String, Object>{ 'Name' => 'Queried' }
        ),
        null
      ),
      'No card record means there is nothing to fall back to'
    );

    if (!UserInfo.isMultiCurrencyOrganization()) {
      Assert.areEqual(
        null,
        RecordHealthCheckDisplayFormat.currencyIsoCodeFor(
          RecordHealthCheckTestDataFactory.account(
            new Map<String, Object>{ 'Name' => 'Queried' }
          ),
          card
        ),
        'With one currency in the org there is no per-record currency to read'
      );
      return;
    }

    SObject cardRecord = (SObject) Type.forName('Account').newInstance();
    cardRecord.put('Name', 'Card record');
    cardRecord.put('CurrencyIsoCode', 'EUR');

    // A query over the same record the card is on did not have to select
    // CurrencyIsoCode for the amount to be in that record's currency.
    SObject sameObjectRow = (SObject) Type.forName('Account').newInstance();
    sameObjectRow.put('AnnualRevenue', 50000);
    Assert.areEqual(
      'EUR',
      RecordHealthCheckDisplayFormat.currencyIsoCodeFor(
        sameObjectRow,
        cardRecord
      ),
      'The card record supplies the currency for a query over that same record'
    );

    // A row that names its own currency keeps it.
    SObject ownCurrencyRow = (SObject) Type.forName('Account').newInstance();
    ownCurrencyRow.put('CurrencyIsoCode', 'JPY');
    Assert.areEqual(
      'JPY',
      RecordHealthCheckDisplayFormat.currencyIsoCodeFor(
        ownCurrencyRow,
        cardRecord
      ),
      'A row currency wins over the card record currency'
    );

    // A query over a different object is left on the running user's currency
    // rather than borrowing an unrelated record's.
    SObject otherObjectRow = (SObject) Type.forName('Opportunity')
      .newInstance();
    otherObjectRow.put('Amount', 70000);
    Assert.areEqual(
      null,
      RecordHealthCheckDisplayFormat.currencyIsoCodeFor(
        otherObjectRow,
        cardRecord
      ),
      'A different object does not borrow the card record currency'
    );
  }

  @IsTest
  static void relationshipFieldCurrencyComesFromTheRelatedRow() {
    Contact outerRow = RecordHealthCheckTestDataFactory.contact(
      new Map<String, Object>{ 'LastName' => 'Outer' }
    );
    Account related = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Related', 'AnnualRevenue' => 70000 }
    );
    outerRow.putSObject('Account', related);

    if (!UserInfo.isMultiCurrencyOrganization()) {
      Assert.areEqual(
        null,
        RecordHealthCheckDisplayFormat.currencyIsoCodeFor(
          outerRow,
          null,
          'Account.AnnualRevenue'
        )
      );
      return;
    }

    related.put('CurrencyIsoCode', 'EUR');
    outerRow.put('CurrencyIsoCode', 'USD');
    Assert.areEqual(
      'EUR',
      RecordHealthCheckDisplayFormat.currencyIsoCodeFor(
        outerRow,
        null,
        'Account.AnnualRevenue'
      ),
      'The outer row currency must not relabel a related record amount'
    );
    Assert.areEqual(
      null,
      RecordHealthCheckDisplayFormat.currencyIsoCodeFor(
        RecordHealthCheckTestDataFactory.contact(
          new Map<String, Object>{ 'LastName' => 'Relationship not selected' }
        ),
        null,
        'Account.AnnualRevenue'
      ),
      'A missing relationship safely falls back instead of borrowing the outer row'
    );
  }

  @IsTest
  static void rowCurrencyListsFollowRowOrder() {
    Assert.areEqual(
      null,
      RecordHealthCheckDisplayFormat.currencyIsoCodesFor(null, null),
      'No rows means there is nothing to read a currency from'
    );
    Assert.areEqual(
      2,
      RecordHealthCheckDisplayFormat.currencyIsoCodesFor(
          new List<SObject>{
            RecordHealthCheckTestDataFactory.account(
              new Map<String, Object>{ 'Name' => 'One' }
            ),
            RecordHealthCheckTestDataFactory.account(
              new Map<String, Object>{ 'Name' => 'Two' }
            )
          },
          null
        )
        .size(),
      'One entry per row, so the list lines up with the values'
    );
  }

  @IsTest
  static void resolverHandlesNullCurrencyAndUncachedCorporateLookup() {
    RecordHealthCheckDisplayCurrencyResolver.multiCurrency = true;
    RecordHealthCheckDisplayCurrencyResolver.corporateCurrencyLoaded = false;
    RecordHealthCheckDisplayCurrencyResolver.corporateCurrencyCode = null;

    RecordHealthCheckDisplayCurrencyResolver.corporateCurrency();
    Assert.isTrue(
      RecordHealthCheckDisplayCurrencyResolver.corporateCurrencyLoaded,
      'The attempted corporate-currency lookup is cached even when unavailable.'
    );

    RecordHealthCheckDisplayCurrencyResolver.corporateCurrencyLoaded = false;
    RecordHealthCheckTestDataFactory.createAccount('Corporate currency row');
    AggregateResult corporateCurrency = [
      SELECT MIN(Name) IsoCode
      FROM Account
    ];
    RecordHealthCheckDisplayCurrencyResolver.corporateCurrencyRowsOverride = new List<SObject>{
      corporateCurrency
    };
    try {
      Assert.areEqual(
        String.valueOf(corporateCurrency.get('IsoCode')),
        RecordHealthCheckDisplayCurrencyResolver.corporateCurrency(),
        'A visible corporate-currency row must be cached and returned.'
      );
    } finally {
      RecordHealthCheckDisplayCurrencyResolver.corporateCurrencyRowsOverride = null;
    }
  }
}
