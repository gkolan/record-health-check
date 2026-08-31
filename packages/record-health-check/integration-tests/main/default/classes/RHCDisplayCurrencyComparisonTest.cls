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
  static void compareTwoQueriesLabelsEachSideWithItsOwnCurrency() {
    Account card = RHCIntegrationTestDataFactory.createAccount(
      'DVF Compare Queries Account'
    );
    RHCIntegrationTestDataFactory.createOpportunity(
      card.Id,
      'DVF Compare Queries Opportunity',
      70000
    );

    // Found: an aggregate, which Salesforce converts to the corporate currency.
    List<AggregateResult> totals = [
      SELECT SUM(Amount) total
      FROM Opportunity
      WHERE AccountId = :card.Id
    ];
    List<SObject> primaryRows = new List<SObject>{ totals[0] };

    // Expected: a row carrying its own currency, which is not the corporate one.
    Boolean multiCurrency = UserInfo.isMultiCurrencyOrganization();
    SObject comparisonRow;
    if (multiCurrency) {
      comparisonRow = (SObject) Type.forName('Account').newInstance();
      comparisonRow.put('AnnualRevenue', 50000);
      comparisonRow.put('CurrencyIsoCode', 'EUR');
    } else {
      comparisonRow = RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'AnnualRevenue' => 50000 }
      );
    }

    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'DVF_Compare_Queries_Currency',
        'MasterLabel' => 'DVF_Compare_Queries_Currency',
        'CheckTitle__c' => 'Pipeline covers revenue',
        'EvaluationType__c' => 'COMPARE_TWO_QUERIES',
        'SourceQueryField__c' => 'total',
        'ComparisonQueryField__c' => 'AnnualRevenue',
        'ComparisonOperator__c' => 'GREATER_THAN_OR_EQUAL',
        'QueryResultHandling__c' => 'ONE_RESULT',
        'DisplayValueFormat__c' => CURRENCY_FORMAT
      }
    );

    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    RecordHealthCheckCompareQuerySupport.setComparisonValues(
      check,
      card,
      result,
      primaryRows,
      new List<SObject>{ comparisonRow },
      'ONE_RESULT'
    );

    String foundIsoCode = multiCurrency ? corporateIsoCode() : null;
    String expectedIsoCode = multiCurrency ? 'EUR' : null;

    Assert.areEqual(
      RecordHealthCheckDisplayFormat.render(
        70000,
        CURRENCY_FORMAT,
        foundIsoCode
      ),
      result.actualValue,
      'The Found side keeps the currency the aggregate is in'
    );
    Assert.areEqual(
      true,
      result.expectedValue.contains(
        RecordHealthCheckDisplayFormat.render(
          50000,
          CURRENCY_FORMAT,
          expectedIsoCode
        )
      ),
      'The Expected side keeps its own row currency: ' + result.expectedValue
    );
  }

  @IsTest
  static void aComparisonQueryLabelsTheExpectedSideWithItsOwnCurrency() {
    Boolean multiCurrency = UserInfo.isMultiCurrencyOrganization();
    String corporateIso = corporateIsoCode();
    Account card = RHCIntegrationTestDataFactory.createAccount(
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{
          'Name' => 'DVF Query Account',
          'AnnualRevenue' => 100000
        }
      )
    );
    RHCIntegrationTestDataFactory.createOpportunity(
      card.Id,
      'DVF Query Opportunity',
      70000
    );
    Id cardId = card.Id;
    Account record = multiCurrency
      ? (Account) Database.query(
          'SELECT Id, Name, AnnualRevenue, CurrencyIsoCode FROM Account WHERE Id = :cardId'
        )
      : [SELECT Id, Name, AnnualRevenue FROM Account WHERE Id = :card.Id];
    String sourceQuery = multiCurrency
      ? 'SELECT AnnualRevenue, CurrencyIsoCode FROM Account WHERE Id = {!record.Id}'
      : 'SELECT AnnualRevenue FROM Account WHERE Id = {!record.Id}';
    String comparisonQuery = multiCurrency
      ? 'SELECT SUM(Amount) total FROM Opportunity WHERE AccountId = {!record.Id} AND CurrencyIsoCode = \'' +
        String.escapeSingleQuotes(corporateIso) +
        '\''
      : 'SELECT SUM(Amount) total FROM Opportunity WHERE AccountId = {!record.Id}';

    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'DVF_Query_Comparison_Currency',
        'MasterLabel' => 'DVF_Query_Comparison_Currency',
        'CheckTitle__c' => 'Revenue covers pipeline',
        'EvaluationType__c' => 'QUERY',
        'SourceQuery__c' => sourceQuery,
        'SourceQueryField__c' => 'AnnualRevenue',
        'QueryResultHandling__c' => 'ONE_RESULT',
        'ComparisonOperator__c' => 'GREATER_THAN_OR_EQUAL',
        'ExpectedValueSource__c' => 'COMPARISON_QUERY',
        'ComparisonQuery__c' => comparisonQuery,
        'ComparisonQueryField__c' => 'total',
        'NoRowsResult__c' => 'FAIL',
        'EmptyValueHandling__c' => 'SKIP_RECORD',
        'DisplayValueFormat__c' => CURRENCY_FORMAT
      }
    );

    RecordHealthCheckInternalResult result = new RecordHealthCheckSoqlEvaluator()
      .evaluate(check, card.Id, record);

    Assert.areEqual(
      'PASS',
      result.status,
      'The check should evaluate: ' + result.detailMessage
    );
    // The Found side is the card record's own amount; the Expected side is an
    // aggregate, so it carries the corporate currency rather than the Found
    // side's. Sharing one currency across both sides would mislabel it.
    Assert.areEqual(
      RecordHealthCheckDisplayFormat.render(
        100000,
        CURRENCY_FORMAT,
        multiCurrency ? String.valueOf(record.get('CurrencyIsoCode')) : null
      ),
      result.actualValue,
      'The Found side reads in the record currency'
    );
    Assert.areEqual(
      true,
      result.expectedValue.contains(
        RecordHealthCheckDisplayFormat.render(
          70000,
          CURRENCY_FORMAT,
          corporateIso
        )
      ),
      'The Expected side keeps the comparison query currency: ' +
      result.expectedValue
    );
  }

  @IsTest
  static void listEntriesKeepTheCurrencyOfTheRowTheyCameFrom() {
    System.runAs(userWithLocale('en_US', 'rhciso')) {
      String mixed = RecordHealthCheckComparisonDisplay.formatList(
        new List<Object>{ 70000, 50000 },
        CURRENCY_FORMAT,
        new List<String>{ 'EUR', 'JPY' }
      );
      Assert.areEqual(
        '[' + money('EUR', '70,000.00') + ', JPY 50,000]',
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
    Assert.areEqual('Acme', plainField);
    Assert.areEqual(cachedCorporate, aggregateIso);
    Assert.isNull(singleCurrencyCorporate);
    Assert.isNull(rowIso);
    Assert.isNull(invalidRelationship);
    Assert.isNull(nullRelationship);
    Assert.areEqual(RecordHealthCheckDisplayFormat.BLANK_TEXT, nullAmount);
    Assert.areEqual('12', unnamedCurrency);
    Assert.isTrue(singleCurrency.contains('$'));
    Assert.isTrue(multipleCurrency.startsWith('USD '));
  }
}
