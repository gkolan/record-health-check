/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Covers Display: Value Format rendering for Found and Expected values.
 *
 * Numeric expectations use native platform formatting for the running user.
 * The integration variant additionally exercises these same contracts under
 * explicit English and German personas; package tests create no users.
 */
@IsTest
private class RecordHealthCheckDisplayFormatTest {
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

  // ─── Auto ─────────────────────────────────────────────────────────────────

  @IsTest
  static void autoKeepsTheShippedHumanizeBehavior() {
    System.runAs(RecordHealthCheckTestDataFactory.currentUser()) {
      Assert.areEqual(
        '(blank)',
        RecordHealthCheckDisplayFormat.render(null, AUTO),
        'A null value should read as the blank placeholder'
      );
      Assert.areEqual(
        '(blank)',
        RecordHealthCheckDisplayFormat.render('   ', AUTO),
        'Whitespace-only text should read as the blank placeholder'
      );
      Assert.areEqual(
        'Technology',
        RecordHealthCheckDisplayFormat.render('Technology', AUTO),
        'Auto must preserve ordinary text without reinterpretation.'
      );
      Assert.areEqual(
        'Yes',
        RecordHealthCheckDisplayFormat.render(true, AUTO),
        'Auto must render a typed true value as Yes.'
      );
      Assert.areEqual(
        'No',
        RecordHealthCheckDisplayFormat.render(false, AUTO),
        'Auto must render a typed false value as No.'
      );
      Assert.areEqual(
        'Yes',
        RecordHealthCheckDisplayFormat.render('true', AUTO),
        'Boolean-shaped text is recognized on Auto'
      );
      Assert.areEqual(
        'No',
        RecordHealthCheckDisplayFormat.render('False', AUTO),
        'Boolean text match is case-insensitive'
      );
      Assert.areEqual(
        Decimal.valueOf('70000').format(),
        RecordHealthCheckDisplayFormat.render(70000.0, AUTO),
        'An all-zero fractional part is dropped'
      );
      Assert.areEqual(
        Decimal.valueOf('70000.5').format(),
        RecordHealthCheckDisplayFormat.render(70000.5, AUTO),
        'A real fraction keeps its digits'
      );
      Assert.areEqual(
        '-' + Decimal.valueOf('1234567').format(),
        RecordHealthCheckDisplayFormat.render(-1234567, AUTO),
        'Auto must preserve ASCII minus while applying native numeric grouping.'
      );
      Assert.areEqual(
        '1',
        RecordHealthCheckDisplayFormat.render(1, AUTO),
        'Auto must render numeric one as a number rather than a checkbox.'
      );
      Assert.areEqual(
        '0',
        RecordHealthCheckDisplayFormat.render(0, AUTO),
        'Auto must render numeric zero as a number rather than a checkbox.'
      );
      Assert.areEqual(
        '1',
        RecordHealthCheckDisplayFormat.render('1', AUTO),
        'Auto must preserve numeric text that could be a count'
      );
      Assert.areEqual(
        '0',
        RecordHealthCheckDisplayFormat.render('0', AUTO),
        'Auto must preserve numeric text that could be a count'
      );
      Assert.areEqual(
        'Hot, Warm, Cold',
        RecordHealthCheckDisplayFormat.render('Hot;Warm;Cold', AUTO),
        'Multi-select text becomes a comma-separated list'
      );

      Date july4 = Date.newInstance(2026, 7, 4);
      Datetime july4Evening = Datetime.newInstance(2026, 7, 4, 17, 30, 0);
      Assert.areEqual(
        july4.format(),
        RecordHealthCheckDisplayFormat.render(july4, AUTO),
        'A typed Date renders in the running user locale'
      );
      Assert.areEqual(
        july4Evening.format(),
        RecordHealthCheckDisplayFormat.render(july4Evening, AUTO),
        'A typed Datetime renders in the running user locale and time zone'
      );
      Assert.areEqual(
        july4.format(),
        RecordHealthCheckDisplayFormat.render('2026-07-04', AUTO),
        'ISO date text is recognized on Auto'
      );
      Assert.areEqual(
        july4Evening.format(),
        RecordHealthCheckDisplayFormat.render('2026-07-04 17:30:00', AUTO),
        'ISO date/time text is recognized on Auto'
      );
    }
  }

  @IsTest
  static void autoLeavesIdentifierShapedTextAlone() {
    System.runAs(RecordHealthCheckTestDataFactory.currentUser()) {
      // Digit-only text may be a postal code, a year, or an Id. Grouping it or
      // dropping leading zeros would change what the value means.
      Assert.areEqual(
        '500000',
        RecordHealthCheckDisplayFormat.render('500000', AUTO),
        'Auto must not group digit-only identifier text.'
      );
      Assert.areEqual(
        '0012345',
        RecordHealthCheckDisplayFormat.render('0012345', AUTO),
        'Auto must retain every leading zero in identifier text.'
      );
      Assert.areEqual(
        '90210',
        RecordHealthCheckDisplayFormat.render('90210', AUTO),
        'Auto must preserve a postal-code-shaped string.'
      );
      Assert.areEqual(
        '1-800-CALL',
        RecordHealthCheckDisplayFormat.render('1-800-CALL', AUTO),
        'Auto must preserve a phone-shaped identifier verbatim.'
      );
      Assert.areEqual(
        'ACM-0092',
        RecordHealthCheckDisplayFormat.render('ACM-0092', AUTO),
        'Auto must preserve mixed letters and digits in an identifier.'
      );
    }
  }

  @IsTest
  static void blankAndUnrecognizedFormatsFallBackToAuto() {
    System.runAs(RecordHealthCheckTestDataFactory.currentUser()) {
      Assert.areEqual(
        Decimal.valueOf('70000').format(),
        RecordHealthCheckDisplayFormat.render(70000.0, null),
        'A blank format renders on Auto'
      );
      Assert.areEqual(
        Decimal.valueOf('70000').format(),
        RecordHealthCheckDisplayFormat.render(70000.0, '   '),
        'A whitespace-only format must fall back to native Auto rendering.'
      );
      Assert.areEqual(
        'Yes',
        RecordHealthCheckDisplayFormat.render(true, 'PICKLIST_LABEL'),
        'A format this release does not implement falls back to Auto'
      );
      Assert.areEqual(
        Decimal.valueOf('70000').format(),
        RecordHealthCheckDisplayFormat.render(70000.0, 'number'),
        'Format matching is case-insensitive'
      );
    }
  }

  @IsTest
  static void checkboxForcesYesAndNo() {
    Assert.areEqual(
      'Yes',
      RecordHealthCheckDisplayFormat.render(true, BOOLEAN_FORMAT),
      'Explicit Checkbox must render typed true as Yes.'
    );
    Assert.areEqual(
      'No',
      RecordHealthCheckDisplayFormat.render(false, BOOLEAN_FORMAT),
      'Explicit Checkbox must render typed false as No.'
    );
    Assert.areEqual(
      'Yes',
      RecordHealthCheckDisplayFormat.render('TRUE', BOOLEAN_FORMAT),
      'Explicit Checkbox must recognize uppercase boolean text.'
    );
    Assert.areEqual(
      'No',
      RecordHealthCheckDisplayFormat.render(' false ', BOOLEAN_FORMAT),
      'Surrounding whitespace does not stop the match'
    );
    Assert.areEqual(
      'Technology',
      RecordHealthCheckDisplayFormat.render('Technology', BOOLEAN_FORMAT),
      'Checkbox on text that is not boolean keeps the original spelling'
    );
    Assert.areEqual(
      '(blank)',
      RecordHealthCheckDisplayFormat.render(null, BOOLEAN_FORMAT),
      'A null checkbox reads blank, not No'
    );
    Assert.areEqual(
      'Yes',
      RecordHealthCheckDisplayFormat.render(1, BOOLEAN_FORMAT),
      'A numeric true value reads like a checkbox'
    );
    Assert.areEqual(
      'No',
      RecordHealthCheckDisplayFormat.render(0, BOOLEAN_FORMAT),
      'A numeric false value reads like a checkbox'
    );
    Assert.areEqual(
      'Yes',
      RecordHealthCheckDisplayFormat.render('1', BOOLEAN_FORMAT),
      'Explicit Checkbox opts numeric text into Yes/No rendering'
    );
    Assert.areEqual(
      'No',
      RecordHealthCheckDisplayFormat.render('0', BOOLEAN_FORMAT),
      'Explicit Checkbox opts numeric text into Yes/No rendering'
    );
    Assert.areEqual(
      '42',
      RecordHealthCheckDisplayFormat.render(42, BOOLEAN_FORMAT),
      'Other numbers keep their original spelling'
    );
  }

  @IsTest
  static void aListPassedToTheSingleValueRendererUsesTheListContract() {
    Assert.areEqual(
      '[1, 2, 3]',
      RecordHealthCheckDisplayFormat.render(
        new List<Object>{ 1, 2, 3 },
        NUMBER_FORMAT
      ),
      'A defensive list value is rendered entry by entry, not as Apex syntax'
    );
    Datetime typedDatetime = Datetime.newInstance(2026, 7, 4, 17, 30, 0);
    Assert.areEqual(
      '[' + typedDatetime.format() + ']',
      RecordHealthCheckDisplayFormat.render(
        new List<Object>{ typedDatetime },
        DATETIME_FORMAT
      ),
      'A plugin list keeps typed date/time values and the running user time zone'
    );
  }

  @IsTest
  static void listsRenderEveryEntryWithTheSameFormat() {
    System.runAs(RecordHealthCheckTestDataFactory.currentUser()) {
      Assert.areEqual(
        '(none)',
        RecordHealthCheckComparisonDisplay.formatList(
          new List<Object>(),
          CURRENCY_FORMAT
        ),
        'An empty list must use the none placeholder even under Currency formatting.'
      );
      Assert.areEqual(
        '(none)',
        RecordHealthCheckComparisonDisplay.formatList(null, CURRENCY_FORMAT),
        'An absent list must use the same none placeholder as an empty list.'
      );
      Assert.areEqual(
        '[' +
          Decimal.valueOf('1000').format() +
          ', ' +
          Decimal.valueOf('2000').format() +
          ']',
        RecordHealthCheckComparisonDisplay.formatList(
          new List<Object>{ 1000, 2000 },
          NUMBER_FORMAT
        ),
        'Number formatting must apply native grouping independently to every list entry.'
      );
      Assert.areEqual(
        '[Hot, Warm]',
        RecordHealthCheckComparisonDisplay.formatList(
          new List<Object>{ 'Hot', 'Warm' },
          AUTO
        ),
        'Auto list rendering must preserve entry order and readable separators.'
      );

      List<Object> big = new List<Object>();
      for (Integer i = 0; i < 12; i++) {
        big.add('V' + i);
      }
      String rendered = RecordHealthCheckComparisonDisplay.formatList(
        big,
        RAW_FORMAT
      );
      Assert.areEqual(
        true,
        rendered.contains('(12 total)'),
        'A long list is capped and reports the full count: ' + rendered
      );
      Assert.areEqual(
        false,
        rendered.contains('V11'),
        'Entries past the preview cap are not listed: ' + rendered
      );

      Assert.areEqual(
        'to be one of [Hot, Warm]',
        RecordHealthCheckComparisonDisplay.describeExpectedList(
          'LIST_CONTAINS_ANY',
          new List<Object>{ 'Hot', 'Warm' },
          AUTO
        ),
        'An any-match expected list must retain its explanatory phrase and entry order.'
      );
    }
  }
  @IsTest
  static void formatContractsFollowExplicitLocales() {
    User english = RecordHealthCheckTestDataFactory.createUserWithLocale(
      'en_US',
      'rhceng'
    );
    User german = RecordHealthCheckTestDataFactory.createUserWithLocale(
      'de_DE',
      'rhcger'
    );
    User swedish = RecordHealthCheckTestDataFactory.createUserWithLocale(
      'sv_SE',
      'rhcsv'
    );
    Test.startTest();
    assertFormatContractsForPersona(english, 'en_US');
    assertFormatContractsForPersona(german, 'de_DE');
    assertFormatContractsForPersona(swedish, 'sv_SE');
    Test.stopTest();
  }

  private static void assertFormatContractsForPersona(
    User persona,
    String expectedLocale
  ) {
    System.runAs(persona) {
      Assert.areEqual(
        expectedLocale,
        UserInfo.getLocale(),
        'The integration persona must actually use the requested locale.'
      );
      autoKeepsTheShippedHumanizeBehavior();
      autoLeavesIdentifierShapedTextAlone();
      blankAndUnrecognizedFormatsFallBackToAuto();
      checkboxForcesYesAndNo();
      aListPassedToTheSingleValueRendererUsesTheListContract();
      listsRenderEveryEntryWithTheSameFormat();
    }
  }
}
