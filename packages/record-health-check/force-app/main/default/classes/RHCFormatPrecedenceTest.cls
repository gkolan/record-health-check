/** Exact metadata-vs-plugin formatting precedence; no record queries or DML. */
@IsTest
private class RHCFormatPrecedenceTest {
  @IsTest
  static void configuredRatioWinsForPass() {
    verify('RATIO_PERCENT', 'NUMBER', 'PASS', '75%', '75%');
  }
  @IsTest
  static void configuredRatioWinsForFail() {
    verify('RATIO_PERCENT', 'NUMBER', 'FAIL', '75%', '80%');
  }
  @IsTest
  static void configuredRawWins() {
    verify('RAW', 'RATIO_PERCENT', 'FAIL', '0.75', '0.80');
  }
  @IsTest
  static void automaticRetainsPluginFormat() {
    verify('AUTO', 'RATIO_PERCENT', 'PASS', '75%', '75%');
  }
  @IsTest
  static void blankRetainsPluginFormat() {
    verify(null, 'RATIO_PERCENT', 'FAIL', '75%', '80%');
  }
  @IsTest
  static void explicitFormatIgnoresStructuredComparison() {
    RecordHealthCheckInternalResult result = numbers('FAIL');
    result.presentationOverride = new RecordHealthCheckDisplayOverride()
      .withFound(new RecordHealthCheckDisplayText().text('Plugin found'))
      .withExpected(new RecordHealthCheckDisplayText().text('Plugin expected'));
    result.displayContent = new RecordHealthCheckDisplayContent();
    result.displayContent.found = result.presentationOverride.found.copyNodes();
    result.displayContent.expected = result.presentationOverride.expected.copyNodes();
    Test.startTest();
    RecordHealthCheckPresentationResolver.apply(
      configured('RATIO_PERCENT'),
      result
    );
    Test.stopTest();
    Assert.areEqual(
      '75%',
      result.actualValue,
      'Explicit format must render the machine Found value.'
    );
    Assert.areEqual(
      '80%',
      result.expectedValue,
      'Explicit format must render the machine Expected value.'
    );
    Assert.isNull(
      result.displayContent.found,
      'Stale plugin nodes must not mask configured formatting.'
    );
    Assert.isNull(
      result.displayContent.expected,
      'Stale plugin nodes must not mask configured formatting.'
    );
  }
  @IsTest
  static void emptyOperandStaysAbsent() {
    RecordHealthCheckInternalResult result = numbers('UNABLE_TO_EVALUATE');
    result.evaluationFound = null;
    result.actualValue = null;
    Test.startTest();
    RecordHealthCheckPresentationResolver.apply(configured('NUMBER'), result);
    Test.stopTest();
    Assert.isNull(
      result.actualValue,
      'A format must not fabricate a missing operand.'
    );
    Assert.areEqual(
      'UNABLE_TO_EVALUATE',
      result.status,
      'Missing operands retain their outcome.'
    );
  }
  @IsTest
  static void configuredCurrencyWinsOverPluginCurrency() {
    Record_Health_Check__mdt check = configured('CURRENCY');
    check.ExpectedCurrencyIsoCode__c = 'EUR';
    RecordHealthCheckInternalResult result = numbers('FAIL');
    result.presentationOverride = new RecordHealthCheckDisplayOverride()
      .withExpectedFormat('CURRENCY', 'USD');
    Test.startTest();
    RecordHealthCheckPresentationResolver.apply(check, result);
    Test.stopTest();
    Assert.areEqual(
      'EUR',
      result.expectedCurrencyIsoCode,
      'Configured Expected currency must win with an explicit format.'
    );
  }
  private static void verify(
    String formatName,
    String pluginFormat,
    String status,
    String found,
    String expected
  ) {
    RecordHealthCheckInternalResult result = numbers(status);
    result.presentationOverride = new RecordHealthCheckDisplayOverride()
      .withFoundFormat(pluginFormat, null)
      .withExpectedFormat(pluginFormat, null);
    Test.startTest();
    RecordHealthCheckPresentationResolver.apply(configured(formatName), result);
    Test.stopTest();
    Assert.areEqual(
      found,
      result.actualValue,
      'Configured format wins unless Automatic.'
    );
    Assert.areEqual(
      expected,
      result.expectedValue,
      'Both sides must use the selected units.'
    );
    Assert.areEqual(
      status,
      result.status,
      'Formatting must not change the independently selected business outcome.'
    );
    Assert.areEqual(
      '0.75',
      result.evaluationFound.storedValue,
      'The raw Found operand must remain unchanged.'
    );
    Assert.areEqual(
      status == 'PASS' ? '0.75' : '0.80',
      result.evaluationExpected.storedValue,
      'The raw Expected operand must remain unchanged.'
    );
  }
  private static Record_Health_Check__mdt configured(String formatName) {
    return RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'Format_Precedence',
        'EvaluationType__c' => 'APEX',
        'DisplayValueFormat__c' => formatName
      }
    );
  }
  private static RecordHealthCheckInternalResult numbers(String status) {
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.status = status;
    result.evaluationFound = RecordHealthCheckValue.ofNumber(
      Decimal.valueOf('0.75')
    );
    result.evaluationExpected = RecordHealthCheckValue.ofNumber(
      Decimal.valueOf(status == 'PASS' ? '0.75' : '0.80')
    );
    result.actualValue = '0.75';
    result.expectedValue = status == 'PASS' ? '0.75' : '0.80';
    result.operandsRecorded = true;
    return result;
  }
}
