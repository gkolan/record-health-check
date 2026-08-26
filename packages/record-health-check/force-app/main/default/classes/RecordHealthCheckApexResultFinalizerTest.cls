@IsTest
private class RecordHealthCheckApexResultFinalizerTest {
  @IsTest
  static void rejectsUnsupportedPluginStatus() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'ApexClass__c' => 'ExamplePlugin',
        'UnableToEvaluateMessage__c' => 'Safe plugin error'
      }
    );
    RecordHealthCheckInternalResult pluginResult = new RecordHealthCheckInternalResult();
    pluginResult.status = 'UNKNOWN';

    Test.startTest();
    RecordHealthCheckInternalResult result = RecordHealthCheckApexResultFinalizer.finalizeResult(
      check,
      RecordHealthCheckTestDataFactory.account(null),
      new RecordHealthCheckInternalResult(),
      pluginResult,
      new RecordHealthCheckFormulaEvaluator()
    );
    Test.stopTest();

    Assert.areEqual(
      'ERROR',
      result.status,
      'An unsupported plugin status must become a contained framework error.'
    );
    Assert.areEqual(
      RecordHealthCheckReasonCodes.PLUGIN_STATUS_INVALID,
      result.reasonCode,
      'The stable plugin contract reason code must be retained.'
    );
    Assert.areEqual(
      'Safe plugin error',
      result.message,
      'Subscriber-visible output must use the configured safe message.'
    );
  }

  @IsTest
  static void rejectsOverlongPluginReasonCode() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'ApexClass__c' => 'ExamplePlugin',
        'UnableToEvaluateMessage__c' => 'Safe plugin error'
      }
    );
    RecordHealthCheckInternalResult pluginResult = new RecordHealthCheckInternalResult();
    pluginResult.status = RecordHealthCheckStatus.SKIPPED;
    pluginResult.reasonCode = ''.leftPad(81, 'R');

    RecordHealthCheckInternalResult result = RecordHealthCheckApexResultFinalizer.finalizeResult(
      check,
      RecordHealthCheckTestDataFactory.account(null),
      new RecordHealthCheckInternalResult(),
      pluginResult,
      new RecordHealthCheckFormulaEvaluator()
    );

    Assert.areEqual('ERROR', result.status);
    Assert.areEqual(
      RecordHealthCheckReasonCodes.PLUGIN_REASON_CODE_INVALID,
      result.reasonCode,
      'An overlong plugin reason code must be contained before publication or serialization.'
    );
  }

  @IsTest
  static void acceptsPluginReasonCodeAtWireLimit() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{ 'ApexClass__c' => 'ExamplePlugin' }
    );
    RecordHealthCheckInternalResult pluginResult = new RecordHealthCheckInternalResult();
    pluginResult.status = RecordHealthCheckStatus.SKIPPED;
    pluginResult.reasonCode = ''.leftPad(80, 'R');

    RecordHealthCheckInternalResult result = RecordHealthCheckApexResultFinalizer.finalizeResult(
      check,
      RecordHealthCheckTestDataFactory.account(null),
      new RecordHealthCheckInternalResult(),
      pluginResult,
      new RecordHealthCheckFormulaEvaluator()
    );

    Assert.areEqual(RecordHealthCheckStatus.SKIPPED, result.status);
    Assert.areEqual(80, result.reasonCode.length());
  }
}
