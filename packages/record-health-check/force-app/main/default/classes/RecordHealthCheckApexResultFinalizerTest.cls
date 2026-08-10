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
      'APEX_EVALUATOR_ERROR',
      result.reasonCode,
      'The stable plugin contract reason code must be retained.'
    );
    Assert.areEqual(
      'Safe plugin error',
      result.message,
      'Subscriber-visible output must use the configured safe message.'
    );
  }
}
