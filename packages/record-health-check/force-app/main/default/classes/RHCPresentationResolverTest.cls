/** Regression coverage for Apex presentation precedence and policy. */
@IsTest
private class RHCPresentationResolverTest {
  @IsTest
  static void appliesValidOverridesToFailDisplay() {
    Record_Health_Check__mdt check = checkWithFormat('AUTO');
    RecordHealthCheckInternalResult result = resultWithNumbers(
      RecordHealthCheckStatus.FAIL
    );
    result.message = 'Configured failure';
    result.fixInstructions = 'Configured fix';
    result.actionLabel = 'Configured action';
    result.actionUrl = '/configured';
    result.presentationOverride = new RecordHealthCheckDisplayOverride()
      .withMessage(new RecordHealthCheckDisplayText().text('Dynamic failure'))
      .withFix(new RecordHealthCheckDisplayText().text('Dynamic fix'))
      .withAction(
        new RecordHealthCheckDisplayAction('Dynamic action', '/dynamic')
      )
      .withExpectedLabel('Target')
      .withFoundFormat('RATIO_PERCENT', null)
      .withExpectedFormat('RATIO_PERCENT', null);

    Test.startTest();
    RecordHealthCheckPresentationResolver.apply(check, result);
    Test.stopTest();

    Assert.areEqual('Dynamic failure', result.message);
    Assert.areEqual('Dynamic fix', result.fixInstructions);
    Assert.areEqual('Dynamic action', result.actionLabel);
    Assert.areEqual('/dynamic', result.actionUrl);
    Assert.areEqual('Target', result.expectedValueLabel);
    Assert.areEqual('75%', result.actualValue);
    Assert.areEqual('80%', result.expectedValue);
    Assert.areEqual('RATIO_PERCENT', result.actualDisplayFormat);
    Assert.areEqual('RATIO_PERCENT', result.expectedDisplayFormat);
  }

  @IsTest
  static void appliesConfiguredFormatWhenOverrideOmitsIt() {
    RecordHealthCheckInternalResult result = resultWithNumbers(
      RecordHealthCheckStatus.PASS
    );

    Test.startTest();
    RecordHealthCheckPresentationResolver.apply(
      checkWithFormat('RATIO_PERCENT'),
      result
    );
    Test.stopTest();

    Assert.areEqual('75%', result.actualValue);
    Assert.areEqual('80%', result.expectedValue);
    Assert.areEqual('RATIO_PERCENT', result.actualDisplayFormat);
    Assert.areEqual('RATIO_PERCENT', result.expectedDisplayFormat);
    Assert.areEqual('0.75', result.evaluationFound.storedValue);
    Assert.areEqual('0.80', result.evaluationExpected.storedValue);
  }

  @IsTest
  static void inheritsConfiguredFieldsForEmptyOverride() {
    RecordHealthCheckInternalResult result = resultWithNumbers(
      RecordHealthCheckStatus.FAIL
    );
    result.message = 'Configured failure';
    result.fixInstructions = 'Configured fix';
    result.actionLabel = 'Configured action';
    result.actionUrl = '/configured';
    result.presentationOverride = new RecordHealthCheckDisplayOverride();

    Test.startTest();
    RecordHealthCheckPresentationResolver.apply(
      checkWithFormat('AUTO'),
      result
    );
    Test.stopTest();

    Assert.areEqual('Configured failure', result.message);
    Assert.areEqual('Configured fix', result.fixInstructions);
    Assert.areEqual('Configured action', result.actionLabel);
    Assert.areEqual('/configured', result.actionUrl);
  }

  @IsTest
  static void omitsFailOnlyFieldsForPassOutcome() {
    RecordHealthCheckInternalResult result = resultWithNumbers(
      RecordHealthCheckStatus.PASS
    );
    result.presentationOverride = new RecordHealthCheckDisplayOverride()
      .withMessage(new RecordHealthCheckDisplayText().text('Healthy'))
      .withFix(new RecordHealthCheckDisplayText().text('Must not appear'))
      .withAction(new RecordHealthCheckDisplayAction('Unsafe status', '/edit'));

    Test.startTest();
    RecordHealthCheckPresentationResolver.apply(
      checkWithFormat('AUTO'),
      result
    );
    Test.stopTest();

    Assert.areEqual('Healthy', result.message);
    Assert.isNull(result.fixInstructions);
    Assert.isNull(result.actionLabel);
    Assert.isNull(result.actionUrl);
  }

  @IsTest
  static void fallsBackInvalidFieldsIndependently() {
    RecordHealthCheckInternalResult result = resultWithNumbers(
      RecordHealthCheckStatus.FAIL
    );
    result.message = 'Configured failure';
    result.actionLabel = 'Configured action';
    result.actionUrl = '/configured';
    result.presentationOverride = new RecordHealthCheckDisplayOverride()
      .withMessage(new RecordHealthCheckDisplayText().text('Dynamic failure'))
      .withAction(
        new RecordHealthCheckDisplayAction('Bad action', 'javascript:alert(1)')
      )
      .withFoundFormat('ratio_percent', null);

    Test.startTest();
    RecordHealthCheckPresentationResolver.apply(
      checkWithFormat('NUMBER'),
      result
    );
    Test.stopTest();

    Assert.areEqual('Dynamic failure', result.message);
    Assert.areEqual('Configured action', result.actionLabel);
    Assert.areEqual('/configured', result.actionUrl);
    Assert.areEqual('0.75', result.actualValue);
    Assert.areEqual('NUMBER', result.actualDisplayFormat);
    Assert.isTrue(
      result.detailMessage.contains(
        RecordHealthCheckReasonCodes.PLUGIN_DISPLAY_INVALID
      )
    );
  }

  @IsTest
  static void inheritsConfiguredCurrencyForInvalidOverride() {
    Record_Health_Check__mdt check = checkWithFormat('CURRENCY');
    check.ExpectedCurrencyIsoCode__c = 'EUR';
    RecordHealthCheckInternalResult result = resultWithNumbers(
      RecordHealthCheckStatus.FAIL
    );
    result.presentationOverride = new RecordHealthCheckDisplayOverride()
      .withExpectedFormat('CURRENCY', 'US');

    Test.startTest();
    RecordHealthCheckPresentationResolver.apply(check, result);
    Test.stopTest();

    Assert.areEqual('EUR', result.expectedCurrencyIsoCode);
    Assert.isTrue(
      result.detailMessage.contains(
        RecordHealthCheckReasonCodes.PLUGIN_DISPLAY_INVALID
      )
    );
  }

  @IsTest
  static void invalidPresentationAppearsInAuthorizedDiagnostics() {
    User diagnosticsUser = RecordHealthCheckTestDataFactory.currentUser();
    RecordHealthCheckTestDataFactory.assignPermissionSet(
      diagnosticsUser,
      'Record_Health_Check_Admin'
    );
    Record_Health_Check__mdt check = checkWithFormat('NUMBER');
    RecordHealthCheckInternalResult result = resultWithNumbers(
      RecordHealthCheckStatus.FAIL
    );
    result.presentationOverride = new RecordHealthCheckDisplayOverride()
      .withFoundFormat('number', null);

    Test.startTest();
    System.runAs(diagnosticsUser) {
      new RecordHealthCheckScopeResultSupport()
        .finalizeDisplay(
          check,
          RecordHealthCheckTestDataFactory.account(
            new Map<String, Object>{ 'Name' => 'Diagnostics ordering' }
          ),
          result,
          true,
          true
        );
    }
    Test.stopTest();

    Assert.isTrue(
      result.adminDetail.message.contains(
        RecordHealthCheckReasonCodes.PLUGIN_DISPLAY_INVALID
      ),
      'Authorized diagnostics must include presentation failures discovered during finalization.'
    );
  }

  private static Record_Health_Check__mdt checkWithFormat(String formatName) {
    return RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'Presentation_Test',
        'CheckTitle__c' => 'Presentation test',
        'EvaluationType__c' => 'APEX',
        'DisplayValueFormat__c' => formatName,
        'FailureSeverity__c' => 'WARNING'
      }
    );
  }

  private static RecordHealthCheckInternalResult resultWithNumbers(
    String status
  ) {
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.status = status;
    result.actualValue = '0.75';
    result.expectedValue = '0.80';
    result.evaluationFound = RecordHealthCheckValue.ofNumber(
      Decimal.valueOf('0.75')
    );
    result.evaluationExpected = RecordHealthCheckValue.ofNumber(
      Decimal.valueOf('0.80')
    );
    result.operandsRecorded = true;
    return result;
  }
}
