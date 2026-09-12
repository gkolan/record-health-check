/** Tests currency-specific display rendering. */
@IsTest
private class RHCDisplayCurrencyRendererTest {
  @IsTest
  static void rendersSymbolsIsoCodesAndMinorUnits() {
    User localeUser = RecordHealthCheckTestDataFactory.currentUser();

    System.runAs(localeUser) {
      Assert.areEqual(
        '$' + localizedAmount('1,234.50'),
        RecordHealthCheckDisplayCurrencyRenderer.render(1234.5, 'USD', false),
        'A single-currency display should use a known symbol.'
      );
      Assert.areEqual(
        'USD ' + localizedAmount('1,234.50'),
        RecordHealthCheckDisplayCurrencyRenderer.render(1234.5, 'USD', true),
        'A multi-currency display should use the unambiguous ISO code.'
      );
      Assert.areEqual(
        'JPY ' + localizedAmount('1,235'),
        RecordHealthCheckDisplayCurrencyRenderer.render(1234.5, 'JPY', false),
        'A disambiguated zero-minor-unit currency should use ISO without decimals.'
      );
      Assert.areEqual(
        'SAR ' + localizedAmount('1,234.50'),
        RecordHealthCheckDisplayCurrencyRenderer.render(1234.5, 'SAR', false),
        'A currency without a known symbol should use its ISO code.'
      );
    }
  }

  @IsTest
  static void keepsBlankAndNegativeBehavior() {
    Assert.areEqual(
      RecordHealthCheckDisplayFormat.BLANK_TEXT,
      RecordHealthCheckDisplayCurrencyRenderer.render(null, 'USD', false),
      'A null amount should use the shared blank placeholder.'
    );
    Assert.areEqual(
      '-$' + localizedAmount('10.00'),
      RecordHealthCheckDisplayCurrencyRenderer.render(-10, 'USD', false),
      'The minus sign should precede the currency symbol.'
    );
    Assert.areEqual(
      '10',
      RecordHealthCheckDisplayCurrencyRenderer.render(10, null, false),
      'An amount without a currency should remain a plain number.'
    );
  }
  @IsTest
  static void rendererContractsFollowGermanLocale() {
    User persona = RecordHealthCheckTestDataFactory.createUserWithLocale(
      'de_DE',
      'rhccurde'
    );
    System.runAs(persona) {
      Assert.areEqual(
        'de_DE',
        UserInfo.getLocale(),
        'The renderer regression must execute under German punctuation.'
      );
      rendersSymbolsIsoCodesAndMinorUnits();
      keepsBlankAndNegativeBehavior();
    }
  }
  /** Native positive samples provide punctuation without assuming the runner's locale. */
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
}
