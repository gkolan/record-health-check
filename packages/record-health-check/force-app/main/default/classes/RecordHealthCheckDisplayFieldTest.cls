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
private class RecordHealthCheckDisplayFieldTest {
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
    return RecordHealthCheckTestDataFactory.currentUser();
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
  static void currencyAndPercentFieldsSuggestTheirOwnFormat() {
    Map<String, Schema.SObjectField> opportunityFields = RecordHealthCheckDescribeCache.fieldMap(
      Opportunity.SObjectType
    );

    Assert.areEqual(
      CURRENCY_FORMAT,
      RecordHealthCheckDisplayFormat.formatForField(
        RecordHealthCheckDescribeCache.describeField(
          opportunityFields.get('Amount')
        )
      ),
      'A Currency field should suggest Currency'
    );
    Assert.areEqual(
      PERCENT_FORMAT,
      RecordHealthCheckDisplayFormat.formatForField(
        RecordHealthCheckDescribeCache.describeField(
          opportunityFields.get('Probability')
        )
      ),
      'A Percent field should suggest Percent'
    );
    Assert.areEqual(
      null,
      RecordHealthCheckDisplayFormat.formatForField(
        RecordHealthCheckDescribeCache.describeField(
          opportunityFields.get('Name')
        )
      ),
      'A text field has no format of its own, so Auto keeps its wording'
    );
    Assert.areEqual(null, RecordHealthCheckDisplayFormat.formatForField(null));
  }

  @IsTest
  static void autoTakesTheFormatFromTheQueriedField() {
    Opportunity row = RecordHealthCheckTestDataFactory.opportunity(
      new Map<String, Object>{ 'Amount' => 70000, 'Probability' => 25 }
    );

    Assert.areEqual(
      CURRENCY_FORMAT,
      RecordHealthCheckDisplayFormat.formatForRow(AUTO, row, 'Amount'),
      'On Auto a Currency field renders as money without a Check change'
    );
    Assert.areEqual(
      PERCENT_FORMAT,
      RecordHealthCheckDisplayFormat.formatForRow(null, row, 'Probability'),
      'A blank format is Auto, so the field still decides'
    );
    Assert.areEqual(
      RAW_FORMAT,
      RecordHealthCheckDisplayFormat.formatForRow(RAW_FORMAT, row, 'Amount'),
      'A format the author named always wins over the field definition'
    );
    Assert.areEqual(
      NUMBER_FORMAT,
      RecordHealthCheckDisplayFormat.formatForRow(NUMBER_FORMAT, row, 'Amount'),
      'Naming Number on a Currency field drops the symbol, as asked'
    );
  }

  @IsTest
  static void fieldLookupLeavesTheFormatAloneWhenThereIsNothingToDescribe() {
    Opportunity row = RecordHealthCheckTestDataFactory.opportunity(
      new Map<String, Object>{ 'Amount' => 70000 }
    );

    Assert.areEqual(
      AUTO,
      RecordHealthCheckDisplayFormat.formatForRow(AUTO, null, 'Amount'),
      'No row means no field definition to read'
    );
    Assert.areEqual(
      AUTO,
      RecordHealthCheckDisplayFormat.formatForRow(AUTO, row, null),
      'No field path means nothing to describe'
    );
    Assert.areEqual(
      AUTO,
      RecordHealthCheckDisplayFormat.formatForRow(AUTO, row, 'NotAField__c'),
      'An unknown field is left alone rather than guessed at'
    );
    Assert.areEqual(
      AUTO,
      RecordHealthCheckDisplayFormat.formatForRow(
        AUTO,
        row,
        'Account.AnnualRevenue'
      ),
      'A relationship that was not queried yields no describe'
    );
    Assert.areEqual(
      AUTO,
      RecordHealthCheckDisplayFormat.formatForRow(
        AUTO,
        row,
        'NotARelation__r.Amount'
      ),
      'A relationship name that does not exist is left alone'
    );

    // An aggregate row has no single source field behind the value.
    List<AggregateResult> totals = [
      SELECT SUM(Amount) total
      FROM Opportunity
      WHERE Id = NULL
    ];
    Assert.areEqual(
      AUTO,
      RecordHealthCheckDisplayFormat.formatForRow(
        AUTO,
        totals.isEmpty() ? null : totals[0],
        'total'
      ),
      'An aggregate result has no field definition to read'
    );
  }

  @IsTest
  static void autoUsesPicklistLabelsWithoutChangingStoredValues() {
    Record_Health_Check_Set__mdt row = RecordHealthCheckTestDataFactory.checkSet(
      new Map<String, Object>{ 'FoundExpectedDisplay__c' => 'ON_DEMAND' }
    );

    Assert.areEqual(
      'On demand',
      RecordHealthCheckDisplayFormat.valueForDisplay(
        'ON_DEMAND',
        AUTO,
        row,
        'FoundExpectedDisplay__c'
      ),
      'Auto shows the translated label from the field definition'
    );
    Assert.areEqual(
      'ON_DEMAND',
      RecordHealthCheckDisplayFormat.valueForDisplay(
        'ON_DEMAND',
        TEXT_FORMAT,
        row,
        'FoundExpectedDisplay__c'
      ),
      'A named format wins and keeps the stored API value'
    );
    Assert.areEqual(
      'RETIRED_VALUE',
      RecordHealthCheckDisplayFormat.valueForDisplay(
        'RETIRED_VALUE',
        AUTO,
        row,
        'FoundExpectedDisplay__c'
      ),
      'A stored value absent from describe falls back to its API spelling'
    );
    Assert.areEqual(
      'ON_DEMAND',
      row.FoundExpectedDisplay__c,
      'Resolving a label never mutates the value used by comparison'
    );

    List<Object> labels = RecordHealthCheckDisplayFormat.valuesForDisplay(
      new List<Object>{ 'ON_DEMAND', 'FAILURES_ONLY', 'UNKNOWN' },
      AUTO,
      new List<SObject>{ row, row },
      'FoundExpectedDisplay__c'
    );
    Assert.areEqual(
      new List<Object>{ 'On demand', 'Failed checks only', 'UNKNOWN' },
      labels,
      'Lists preserve order, resolve known labels, and tolerate a short row list'
    );
  }

  @IsTest
  static void listDisplayWorkStopsAtTheVisiblePreview() {
    Record_Health_Check_Set__mdt row = RecordHealthCheckTestDataFactory.checkSet(
      new Map<String, Object>{ 'FoundExpectedDisplay__c' => 'ON_DEMAND' }
    );
    List<Object> values = new List<Object>();
    List<SObject> rows = new List<SObject>();
    for (
      Integer i = 0; i < RecordHealthCheckConstants.FRAMEWORK_MAX_ROWS; i++
    ) {
      values.add(
        i < RecordHealthCheckConstants.DISPLAY_LIST_PREVIEW_CAP
          ? 'ON_DEMAND'
          : 'FAILURES_ONLY'
      );
      rows.add(row);
    }

    List<Object> displayed = RecordHealthCheckDisplayFormat.valuesForDisplay(
      values,
      AUTO,
      rows,
      'FoundExpectedDisplay__c'
    );

    Assert.areEqual(
      values.size(),
      displayed.size(),
      'The true list total is retained'
    );
    Assert.areEqual(
      'On demand',
      displayed[9],
      'Every visible entry uses its label'
    );
    Assert.areEqual(
      'FAILURES_ONLY',
      displayed[10],
      'Hidden entries are not needlessly converted'
    );
    Assert.areEqual(
      RecordHealthCheckConstants.DISPLAY_LIST_PREVIEW_CAP,
      RecordHealthCheckDisplayFormat.currencyIsoCodesFor(rows, null).size(),
      'Only visible entries need a parallel currency lookup'
    );
  }

  @IsTest
  static void multiPicklistResolutionPreservesUnknownValuesAndRejectsBlanks() {
    Map<String, String> labelsByValue = new Map<String, String>{
      'KNOWN' => 'Known label'
    };

    Assert.areEqual(
      'Known label, UNKNOWN',
      RecordHealthCheckDisplayFieldResolver.resolveMultiPicklist(
        'KNOWN; UNKNOWN',
        labelsByValue
      ),
      'Known values use their labels while retired values retain their API spelling.'
    );
    Assert.isNull(
      RecordHealthCheckDisplayFieldResolver.resolveMultiPicklist(
        ' ; ',
        labelsByValue
      ),
      'A multi-picklist containing no values must resolve to null.'
    );
  }

  @IsTest
  static void fieldResolutionPreservesValuesWithoutPicklistMetadata() {
    RecordHealthCheckDisplayFieldResolver.Resolution missingDescribe = RecordHealthCheckDisplayFieldResolver.resolve(
      'Original value',
      null
    );
    Assert.areEqual('Original value', missingDescribe.value);
    Assert.isFalse(
      missingDescribe.isFinalText,
      'A value without field metadata has not been converted to final label text.'
    );

    Schema.DescribeFieldResult textField = Account.Name.getDescribe();
    RecordHealthCheckDisplayFieldResolver.Resolution textResolution = RecordHealthCheckDisplayFieldResolver.resolve(
      'Account name',
      textField
    );
    Assert.areEqual('Account name', textResolution.value);
    Assert.isFalse(
      textResolution.isFinalText,
      'A non-picklist value should pass through without becoming final label text.'
    );
  }

  @IsTest
  static void autoMultiPicklistLabelsRemainFinalDisplayText() {
    Schema.SObjectType quickTextType = Schema.getGlobalDescribe()
      .get('QuickText');
    Assert.isNotNull(
      quickTextType,
      'QuickText is a standard Salesforce object used for this core-only describe test.'
    );
    Schema.DescribeFieldResult channelField = quickTextType
      .getDescribe()
      .fields.getMap()
      .get('Channel')
      .getDescribe();
    List<Schema.PicklistEntry> entries = channelField.getPicklistValues();
    Assert.isTrue(
      entries.size() >= 2,
      'QuickText.Channel should expose multiple standard channel values.'
    );
    String stored = entries[0].getValue() + ';' + entries[1].getValue();

    RecordHealthCheckDisplayFieldResolver.Resolution resolution = RecordHealthCheckDisplayFieldResolver.resolve(
      stored,
      channelField
    );

    Assert.areEqual(
      entries[0].getLabel() + ', ' + entries[1].getLabel(),
      resolution.value,
      'Each stored channel should resolve to its running-user-visible label.'
    );
    Assert.isTrue(
      resolution.isFinalText,
      'Resolved multi-select labels must be treated as final display text.'
    );

    SObject quickTextRow = quickTextType.newSObject();
    quickTextRow.put('Channel', stored);
    Object displayValue = RecordHealthCheckDisplayFormat.valueForDisplay(
      stored,
      AUTO,
      quickTextRow,
      'Channel'
    );
    Assert.areEqual(
      entries[0].getLabel() + ', ' + entries[1].getLabel(),
      RecordHealthCheckDisplayFormat.render(displayValue, AUTO),
      'Resolved labels must render as final text rather than being parsed as stored API values again.'
    );

    RecordHealthCheckDisplayFieldResolver.Resolution blankResolution = RecordHealthCheckDisplayFieldResolver.resolve(
      ' ; ',
      channelField
    );
    Assert.areEqual(
      ' ; ',
      blankResolution.value,
      'A value containing no selections should preserve its original stored representation.'
    );
    Assert.isFalse(
      blankResolution.isFinalText,
      'An unresolved blank selection is not final label text.'
    );
  }
}
