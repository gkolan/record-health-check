@IsTest
private with sharing class RecordHealthCheckEvaluatorRegistryTest {
  @IsTest
  static void shouldRejectUnregisteredEvaluationType() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{ 'EvaluationType__c' => 'UNKNOWN' }
    );

    Test.startTest();
    try {
      new RecordHealthCheckEvaluatorRegistry()
        .evaluateScope(
          check,
          new List<Id>(),
          new Map<Id, SObject>(),
          new RecordHealthCheckScopePipeline.SelectionContext(),
          'registry-test'
        );
      Assert.fail('An unregistered evaluation type must fail closed.');
    } catch (RecordHealthCheckEvaluatorException error) {
      Assert.areEqual(
        'INVALID_CHECK_TYPE',
        error.reasonCode,
        'Registry failures must use the stable evaluation-type reason.'
      );
    }
    Test.stopTest();
  }
}
