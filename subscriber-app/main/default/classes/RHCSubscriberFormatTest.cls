/** Black-box installed-package regression: formatting must not change verdicts. */
@IsTest
private class RHCSubscriberFormatTest {
  @TestSetup
  static void authorizeRunner() {
    RHCSubscriberTestDataFactory.assignPackagedPermissionSet(
      UserInfo.getUserId(),
      'Record_Health_Check_User'
    );
  }
  @IsTest
  static void configuredRatioWinsInMixedSet() {
    verifySet();
  }
  @IsTest
  static void configuredRatioWinsAlone() {
    verifyCheck('Subscriber_Format_Ratio_Fail', 'FAIL', '75%', '80%');
  }
  @IsTest
  static void automaticRetainsPluginNumber() {
    verifyCheck('Subscriber_Format_Auto_Pass', 'PASS', '0.75', '0.75');
  }
  private static void verifySet() {
    Account record = RHCSubscriberTestDataFactory.createAccount(
      'Format regression'
    );
    Test.startTest();
    rhc.RecordHealthCheckResponse response = rhc.RecordHealthCheck.evaluate(
      rhc.RecordHealthCheckRequest.forCheckSet(
          'Subscriber_Format_Precedence',
          record.Id
        )
        .withResultMode(rhc.RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY)
    );
    Test.stopTest();
    Assert.areEqual(
      4,
      response.results.size(),
      'All configured Checks must execute.'
    );
    for (rhc.RecordHealthCheckResultItem item : response.results) {
      Boolean ratio = item.evaluation.checkQualifiedApiName.contains('Ratio');
      Boolean passing = item.evaluation.checkQualifiedApiName.endsWith('Pass');
      assertResult(
        item,
        passing ? 'PASS' : 'FAIL',
        ratio ? '75%' : '0.75',
        ratio ? (passing ? '75%' : '80%') : (passing ? '0.75' : '0.8')
      );
    }
  }
  private static void verifyCheck(
    String name,
    String status,
    String found,
    String expected
  ) {
    Account record = RHCSubscriberTestDataFactory.createAccount(
      'Format regression alone'
    );
    Test.startTest();
    rhc.RecordHealthCheckResponse response = rhc.RecordHealthCheck.evaluate(
      rhc.RecordHealthCheckRequest.forCheck(name, record.Id)
        .withResultMode(rhc.RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY)
    );
    Test.stopTest();
    Assert.areEqual(
      1,
      response.results.size(),
      'The selected Check must run alone.'
    );
    assertResult(response.results[0], status, found, expected);
  }
  private static void assertResult(
    rhc.RecordHealthCheckResultItem item,
    String status,
    String found,
    String expected
  ) {
    Assert.areEqual(
      status,
      item.evaluation.status,
      'Formatting must preserve the independently expected verdict.'
    );
    Assert.areEqual(
      '0.75',
      item.evaluation.found.storedValue,
      'Formatting must preserve the machine operand.'
    );
    Assert.areEqual(
      found,
      item.display.foundDisplayValue,
      'Metadata format must win unless Automatic.'
    );
    Assert.areEqual(
      expected,
      item.display.expectedDisplayValue,
      'Expected must use the same configured units.'
    );
  }
}
