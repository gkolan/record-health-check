/** Verifies single-record Apex adapter and result-finalization behavior. */
@IsTest
private with sharing class RecordHealthCheckApexAdapterTest {
  @IsTest
  static void evaluateReturnsClassNotFoundWhenClassNameBlank() {
    Account record = RecordHealthCheckTestDataFactory.createAccount(
      'Blank class'
    );

    Test.startTest();
    RecordHealthCheckInternalResult result = new RecordHealthCheckApexEvaluator()
      .evaluate(checkFor(null, null), record.Id, record);
    Test.stopTest();

    assertReason(result, 'APEX_CLASS_NOT_FOUND');
  }

  @IsTest
  static void evaluateReturnsClassNotFoundWhenClassMissing() {
    Account record = RecordHealthCheckTestDataFactory.createAccount(
      'Missing class'
    );

    Test.startTest();
    RecordHealthCheckInternalResult result = new RecordHealthCheckApexEvaluator()
      .evaluate(checkFor('Class_That_Does_Not_Exist', null), record.Id, record);
    Test.stopTest();

    assertReason(result, 'APEX_CLASS_NOT_FOUND');
  }

  @IsTest
  static void evaluateReturnsClassNotFoundWhenClassViolatesContract() {
    Account record = RecordHealthCheckTestDataFactory.createAccount(
      'Wrong contract'
    );

    Test.startTest();
    RecordHealthCheckInternalResult result = new RecordHealthCheckApexEvaluator()
      .evaluate(
        checkFor('RecordHealthCheckConstants', null),
        record.Id,
        record
      );
    Test.stopTest();

    assertReason(result, RecordHealthCheckReasonCodes.PLUGIN_INTERFACE_INVALID);
  }

  @IsTest
  static void evaluateReturnsInvalidParametersWhenJsonIsArray() {
    Account record = RecordHealthCheckTestDataFactory.createAccount(
      'Array parameters'
    );

    Test.startTest();
    RecordHealthCheckInternalResult result = new RecordHealthCheckApexEvaluator()
      .evaluate(
        checkFor('AccountHasRecentActivityCheck', '[1,2]'),
        record.Id,
        record
      );
    Test.stopTest();

    assertReason(result, 'INVALID_APEX_PARAMETERS');
  }

  @IsTest
  static void evaluateReturnsInvalidParametersWhenJsonMalformed() {
    Account record = RecordHealthCheckTestDataFactory.createAccount(
      'Malformed parameters'
    );

    Test.startTest();
    RecordHealthCheckInternalResult result = new RecordHealthCheckApexEvaluator()
      .evaluate(
        checkFor('AccountHasRecentActivityCheck', '{broken'),
        record.Id,
        record
      );
    Test.stopTest();

    assertReason(result, 'INVALID_APEX_PARAMETERS');
  }

  @IsTest
  static void evaluateReturnsErrorWhenRecordContextMissing() {
    Account record = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'No context' }
    );

    Test.startTest();
    RecordHealthCheckInternalResult result = new RecordHealthCheckApexEvaluator()
      .evaluate(checkFor('AccountHasRecentActivityCheck', '{}'), null, record);
    Test.stopTest();

    assertReason(result, 'APEX_EVALUATOR_ERROR');
  }

  @IsTest
  static void evaluateInvokesPluginWhenConfigurationValid() {
    Account record = RecordHealthCheckTestDataFactory.createAccount(
      'Valid plugin'
    );
    RecordHealthCheckApexEvaluator evaluator = new RecordHealthCheckApexEvaluator()
      .withRunContext(new RecordHealthCheckRunContext('run-apex', 'TEST'));

    Test.startTest();
    RecordHealthCheckInternalResult result = evaluator.evaluate(
      checkFor('AccountHasRecentActivityCheck', '{"daysBack":30}'),
      record.Id,
      record
    );
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckStatus.FAIL,
      result.status,
      'An Account without recent activity should receive the plugin failure outcome.'
    );
    Assert.areEqual(
      'APEX',
      result.evaluatorType,
      'The adapter should retain the Apex evaluator identity.'
    );
  }

  @IsTest
  static void evaluateMapsConstructorFailureWithoutAConfiguredMessage() {
    Account accountRecord = RecordHealthCheckTestDataFactory.createAccount(
      'Constructor failure'
    );
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'ApexClass__c' => 'RecordHealthCheckConstructorFailureCheck',
        'UnableToEvaluateMessage__c' => null
      }
    );

    Test.startTest();
    RecordHealthCheckInternalResult result = new RecordHealthCheckApexEvaluator()
      .evaluate(check, accountRecord.Id, accountRecord);
    Test.stopTest();

    Assert.areEqual(RecordHealthCheckStatus.ERROR, result.status);
    Assert.areEqual(
      RecordHealthCheckReasonCodes.PLUGIN_CONSTRUCTOR_FAILED,
      result.reasonCode
    );
    Assert.areEqual(
      'A system error prevented this check from completing. An authorized administrator can open the diagnosis.',
      result.message,
      'A constructor failure must use the safe fallback when no Check message is configured.'
    );
    Assert.isTrue(
      result.detailMessage.contains('Expected constructor failure'),
      'Administrator detail must retain the constructor failure cause.'
    );
  }

  private static void assertReason(
    RecordHealthCheckInternalResult result,
    String expectedReason
  ) {
    Assert.areEqual(
      expectedReason,
      result.reasonCode,
      'The adapter should return the stable reason code for this boundary failure.'
    );
  }

  private static void assertStatus(
    RecordHealthCheckInternalResult result,
    String expectedStatus
  ) {
    Assert.areEqual(
      expectedStatus,
      result.status,
      'The Apex result should retain the expected terminal status.'
    );
  }

  @IsTest
  static void apexDispatcherCoversCorePluginBranches() {
    Account accountRecord = RecordHealthCheckTestDataFactory.createAccount(
      'Apex finalization behavior'
    );
    RecordHealthCheckApexEvaluator evaluator = new RecordHealthCheckApexEvaluator();

    assertReason(
      evaluator.evaluate(
        apexCheck('A_Blank', null, null),
        accountRecord.Id,
        accountRecord
      ),
      'APEX_CLASS_NOT_FOUND'
    );
    assertReason(
      evaluator.evaluate(
        apexCheck('A_Missing', 'MissingClassName', null),
        accountRecord.Id,
        accountRecord
      ),
      'APEX_CLASS_NOT_FOUND'
    );
    assertReason(
      evaluator.evaluate(
        apexCheck('A_Not_Interface', 'RecordHealthCheckInternalResult', null),
        accountRecord.Id,
        accountRecord
      ),
      RecordHealthCheckReasonCodes.PLUGIN_INTERFACE_INVALID
    );
    Record_Health_Check__mdt finalizeCheck = apexCheck(
      'A_Finalize',
      'CoreTestPlugin',
      null
    );
    RecordHealthCheckInternalResult fallback = new RecordHealthCheckInternalResult();
    RecordHealthCheckInternalResult invalidStatus = new RecordHealthCheckInternalResult();
    invalidStatus.status = 'NOT_REAL';
    assertReason(
      finalizeResult(finalizeCheck, accountRecord, fallback, invalidStatus),
      RecordHealthCheckReasonCodes.PLUGIN_STATUS_INVALID
    );

    RecordHealthCheckInternalResult skippedStatus = new RecordHealthCheckInternalResult();
    skippedStatus.status = 'SKIPPED';
    assertStatus(
      finalizeResult(
        finalizeCheck,
        accountRecord,
        new RecordHealthCheckInternalResult(),
        skippedStatus
      ),
      'SKIPPED'
    );
    RecordHealthCheckInternalResult missingActual = new RecordHealthCheckInternalResult();
    missingActual.status = 'PASS';
    missingActual.expectedValue = '0 missing';
    RecordHealthCheckInternalResult missingActualResult = finalizeResult(
      finalizeCheck,
      accountRecord,
      new RecordHealthCheckInternalResult(),
      missingActual
    );
    assertReason(
      missingActualResult,
      RecordHealthCheckReasonCodes.PLUGIN_VALUES_MISSING
    );
    Assert.isTrue(
      missingActualResult.detailMessage.contains('result.actualValue'),
      missingActualResult.detailMessage
    );

    RecordHealthCheckInternalResult missingExpected = new RecordHealthCheckInternalResult();
    missingExpected.status = 'FAIL';
    missingExpected.actualValue = '1 missing';
    RecordHealthCheckInternalResult missingExpectedResult = finalizeResult(
      finalizeCheck,
      accountRecord,
      new RecordHealthCheckInternalResult(),
      missingExpected
    );
    assertReason(
      missingExpectedResult,
      RecordHealthCheckReasonCodes.PLUGIN_VALUES_MISSING
    );
    Assert.isTrue(
      missingExpectedResult.detailMessage.contains('result.expectedValue'),
      missingExpectedResult.detailMessage
    );

    RecordHealthCheckInternalResult typedValues = new RecordHealthCheckInternalResult();
    typedValues.status = 'PASS';
    typedValues.actualDisplayValue = Decimal.valueOf('0.75');
    typedValues.actualDisplayFormat = 'RATIO_PERCENT';
    typedValues.expectedDisplayValue = Decimal.valueOf('0.80');
    typedValues.expectedDisplayFormat = 'RATIO_PERCENT';
    RecordHealthCheckInternalResult typedResult = finalizeResult(
      finalizeCheck,
      accountRecord,
      new RecordHealthCheckInternalResult(),
      typedValues
    );
    Assert.areEqual('75%', typedResult.actualValue);
    Assert.areEqual('80%', typedResult.expectedValue);

    RecordHealthCheckInternalResult explicitStringsWin = new RecordHealthCheckInternalResult();
    explicitStringsWin.status = 'PASS';
    explicitStringsWin.actualValue = 'Plugin Found';
    explicitStringsWin.expectedValue = 'Plugin Expected';
    explicitStringsWin.actualDisplayValue = Decimal.valueOf('0.75');
    explicitStringsWin.actualDisplayFormat = 'not-a-format';
    RecordHealthCheckInternalResult explicitResult = finalizeResult(
      finalizeCheck,
      accountRecord,
      new RecordHealthCheckInternalResult(),
      explicitStringsWin
    );
    Assert.areEqual('Plugin Found', explicitResult.actualValue);
    Assert.areEqual('Plugin Expected', explicitResult.expectedValue);

    RecordHealthCheckInternalResult invalidTypedFormat = new RecordHealthCheckInternalResult();
    invalidTypedFormat.status = 'PASS';
    invalidTypedFormat.actualDisplayValue = Decimal.valueOf('0.75');
    invalidTypedFormat.actualDisplayFormat = 'ratio_percent';
    invalidTypedFormat.expectedValue = '80%';
    RecordHealthCheckInternalResult invalidTypedResult = finalizeResult(
      finalizeCheck,
      accountRecord,
      new RecordHealthCheckInternalResult(),
      invalidTypedFormat
    );
    assertReason(
      invalidTypedResult,
      RecordHealthCheckReasonCodes.PLUGIN_DISPLAY_INVALID
    );
    Assert.isTrue(
      invalidTypedResult.detailMessage.contains('canonical uppercase'),
      invalidTypedResult.detailMessage
    );

    Record_Health_Check__mdt defaultMessagesCheck = apexCheck(
      'A_Default_Messages',
      'CoreTestPlugin',
      null
    );
    defaultMessagesCheck.FailureMessage__c = null;
    defaultMessagesCheck.UnableToEvaluateMessage__c = null;
    RecordHealthCheckInternalResult failed = new RecordHealthCheckInternalResult();
    failed.status = 'FAIL';
    failed.actualValue = 'Found';
    failed.expectedValue = 'Expected';
    RecordHealthCheckInternalResult defaultFailure = finalizeResult(
      defaultMessagesCheck,
      accountRecord,
      new RecordHealthCheckInternalResult(),
      failed
    );
    Assert.areEqual(
      'Check failed.',
      defaultFailure.message,
      'A missing plugin and metadata message should use the safe failure default.'
    );

    RecordHealthCheckInternalResult unsupported = new RecordHealthCheckInternalResult();
    unsupported.status = 'UNSUPPORTED';
    RecordHealthCheckInternalResult defaultUnable = finalizeResult(
      defaultMessagesCheck,
      accountRecord,
      new RecordHealthCheckInternalResult(),
      unsupported
    );
    Assert.areEqual(
      'This check could not be evaluated. Contact your administrator.',
      defaultUnable.message,
      'A missing unable message should use the safe administrator default.'
    );
  }
  private static RecordHealthCheckInternalResult finalizeResult(
    Record_Health_Check__mdt check,
    SObject record,
    RecordHealthCheckInternalResult fallbackResult,
    RecordHealthCheckInternalResult apexResult
  ) {
    return RecordHealthCheckApexResultFinalizer.finalizeResult(
      check,
      record,
      fallbackResult,
      apexResult,
      new RecordHealthCheckFormulaEvaluator()
    );
  }

  private static Record_Health_Check__mdt apexCheck(
    String developerName,
    String className,
    String parametersJson
  ) {
    Record_Health_Check__mdt check = checkFor(className, parametersJson);
    check.DeveloperName = developerName;
    return check;
  }

  private static Record_Health_Check__mdt checkFor(
    String className,
    String parametersJson
  ) {
    return RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'Apex_Scope_Test',
        'MasterLabel' => 'Apex Scope Test',
        'CheckTitle__c' => 'Apex Scope Test',
        'ApexClass__c' => className,
        'ApexParametersJson__c' => parametersJson,
        'FailureSeverity__c' => 'WARNING',
        'FailureMessage__c' => 'Failed.',
        'UnableToEvaluateMessage__c' => 'Unable.'
      }
    );
  }
}
