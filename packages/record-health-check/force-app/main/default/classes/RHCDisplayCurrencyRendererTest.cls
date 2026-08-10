/** Tests currency-specific display rendering. */
@IsTest
private class RHCDisplayCurrencyRendererTest {
  @IsTest
  static void rendersSymbolsIsoCodesAndMinorUnits() {
    User localeUser = RecordHealthCheckTestDataFactory.createUserWithLocale(
      'en_US',
      'rhccur'
    );

    System.runAs(localeUser) {
      Assert.areEqual(
        '$1,234.50',
        RecordHealthCheckDisplayCurrencyRenderer.render(1234.5, 'USD', false),
        'A single-currency display should use a known symbol.'
      );
      Assert.areEqual(
        'USD 1,234.50',
        RecordHealthCheckDisplayCurrencyRenderer.render(1234.5, 'USD', true),
        'A multi-currency display should use the unambiguous ISO code.'
      );
      Assert.areEqual(
        'JPY 1,235',
        RecordHealthCheckDisplayCurrencyRenderer.render(1234.5, 'JPY', false),
        'A disambiguated zero-minor-unit currency should use ISO without decimals.'
      );
      Assert.areEqual(
        'SAR 1,234.50',
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
      '-$10.00',
      RecordHealthCheckDisplayCurrencyRenderer.render(-10, 'USD', false),
      'The minus sign should precede the currency symbol.'
    );
    Assert.areEqual(
      '10',
      RecordHealthCheckDisplayCurrencyRenderer.render(10, null, false),
      'An amount without a currency should remain a plain number.'
    );
  }
}
