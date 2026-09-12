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

    Assert.areEqual(
      'Dynamic failure',
      result.message,
      'A valid failure-message override must replace the configured message.'
    );
    Assert.areEqual(
      'Dynamic fix',
      result.fixInstructions,
      'A valid failure-fix override must replace the configured fix.'
    );
    Assert.areEqual(
      'Dynamic action',
      result.actionLabel,
      'A valid action override must replace the configured action label.'
    );
    Assert.areEqual(
      '/dynamic',
      result.actionUrl,
      'A valid action override must replace the configured destination.'
    );
    Assert.areEqual(
      'Target',
      result.expectedValueLabel,
      'A valid semantic Expected label must be retained.'
    );
    Assert.areEqual(
      '75%',
      result.actualValue,
      'The Found ratio override must render as a percentage.'
    );
    Assert.areEqual(
      '80%',
      result.expectedValue,
      'The Expected ratio override must render as a percentage.'
    );
    Assert.areEqual(
      'RATIO_PERCENT',
      result.actualDisplayFormat,
      'The Found override must retain its declared ratio-percent format.'
    );
    Assert.areEqual(
      'RATIO_PERCENT',
      result.expectedDisplayFormat,
      'The Expected override must retain its declared ratio-percent format.'
    );
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

    Assert.areEqual(
      '75%',
      result.actualValue,
      'An omitted Found format override must inherit configured percentage rendering.'
    );
    Assert.areEqual(
      '80%',
      result.expectedValue,
      'An omitted Expected format override must inherit configured percentage rendering.'
    );
    Assert.areEqual(
      'RATIO_PERCENT',
      result.actualDisplayFormat,
      'Found must retain the inherited configured format token.'
    );
    Assert.areEqual(
      'RATIO_PERCENT',
      result.expectedDisplayFormat,
      'Expected must retain the inherited configured format token.'
    );
    Assert.areEqual(
      '0.75',
      result.evaluationFound.storedValue,
      'Display formatting must not rewrite the machine Found operand.'
    );
    Assert.areEqual(
      '0.80',
      result.evaluationExpected.storedValue,
      'Display formatting must not rewrite the machine Expected operand.'
    );
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

    Assert.areEqual(
      'Configured failure',
      result.message,
      'An empty override must preserve the configured failure message.'
    );
    Assert.areEqual(
      'Configured fix',
      result.fixInstructions,
      'An empty override must preserve the configured fix.'
    );
    Assert.areEqual(
      'Configured action',
      result.actionLabel,
      'An empty override must preserve the configured action label.'
    );
    Assert.areEqual(
      '/configured',
      result.actionUrl,
      'An empty override must preserve the configured action destination.'
    );
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

    Assert.areEqual(
      'Healthy',
      result.message,
      'A PASS outcome may retain its valid informational message override.'
    );
    Assert.isNull(
      result.fixInstructions,
      'A PASS outcome must not receive failure-only fix instructions.'
    );
    Assert.isNull(
      result.actionLabel,
      'A PASS outcome must not receive a failure-only action label.'
    );
    Assert.isNull(
      result.actionUrl,
      'A PASS outcome must not receive a failure-only action destination.'
    );
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

    Assert.areEqual(
      'Dynamic failure',
      result.message,
      'Invalid sibling fields must not discard a valid message override.'
    );
    Assert.areEqual(
      'Configured action',
      result.actionLabel,
      'An unsafe action destination must preserve the configured action label.'
    );
    Assert.areEqual(
      '/configured',
      result.actionUrl,
      'An unsafe action destination must preserve the configured safe URL.'
    );
    Assert.areEqual(
      '0.75',
      result.actualValue,
      'An invalid format override must fall back to configured numeric rendering.'
    );
    Assert.areEqual(
      'NUMBER',
      result.actualDisplayFormat,
      'The fallback must retain the configured NUMBER format token.'
    );
    Assert.isTrue(
      result.detailMessage.contains(
        RecordHealthCheckReasonCodes.PLUGIN_DISPLAY_INVALID
      ),
      'Rejected presentation fields must produce the stable display-invalid detail.'
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

    Assert.areEqual(
      'EUR',
      result.expectedCurrencyIsoCode,
      'An invalid currency override must inherit the configured Expected currency.'
    );
    Assert.isTrue(
      result.detailMessage.contains(
        RecordHealthCheckReasonCodes.PLUGIN_DISPLAY_INVALID
      ),
      'Invalid currency syntax must produce the stable display-invalid detail.'
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
