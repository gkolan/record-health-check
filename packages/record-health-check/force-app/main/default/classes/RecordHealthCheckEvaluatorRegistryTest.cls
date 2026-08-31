@IsTest
private with sharing class RecordHealthCheckEvaluatorRegistryTest {
  @IsTest
  static void formulaAdapterResolvesRunContextInFailureMessage() {
    Account record = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Id' => RecordHealthCheckTestDataFactory.syntheticId(
          Account.SObjectType,
          901
        ),
        'Name' => 'Run context'
      }
    );
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'EvaluationType__c' => 'FORMULA',
        'PassConditionFormula__c' => 'FALSE',
        'FailureMessage__c' => 'Run {!rhcRun.runId} from {!rhcRun.source}'
      }
    );
    RecordHealthCheckScopePipeline.SelectionContext context = new RecordHealthCheckScopePipeline.SelectionContext();
    context.executionOrigin = 'FLOW';

    Test.startTest();
    RecordHealthCheckInternalResult result = new RecordHealthCheckEvaluatorRegistry()
      .evaluateScope(
        check,
        new List<Id>{ record.Id },
        new Map<Id, SObject>{ record.Id => record },
        context,
        'registry-run-test'
      )
      .get(record.Id);
    Test.stopTest();

    Assert.areEqual(RecordHealthCheckStatus.FAIL, result.status);
    Assert.areEqual(
      'Run registry-run-test from FLOW',
      result.message,
      'The registry must pass run identity and source to formula evaluators.'
    );
  }

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

  @IsTest
  static void apexAdapterPreservesAutomationNeutralFatalSideEffects() {
    Account record = RecordHealthCheckTestDataFactory.accountFixture(
      'Apex adapter side effect'
    );
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'EvaluationType__c' => 'APEX',
        'ApexClass__c' => 'RHCTestEvaluationQueueableCheck'
      }
    );
    RecordHealthCheckScopePipeline.SelectionContext context = new RecordHealthCheckScopePipeline.SelectionContext();
    context.objectApiName = 'Account';
    context.checkSetDeveloperName = 'Safe_Set';
    context.checkSetQualifiedApiName = 'Safe_Set';
    context.executionOrigin = 'APEX_API';

    try {
      new RecordHealthCheckEvaluatorRegistry()
        .evaluateScope(
          check,
          new List<Id>{ record.Id },
          new Map<Id, SObject>{ record.Id => record },
          context,
          'registry-side-effect'
        );
      Assert.fail('The Apex adapter must preserve fatal side effects.');
    } catch (RecordHealthCheckPluginDispatch.SideEffectException error) {
      Assert.areEqual('QUEUEABLE', error.effect);
    }
  }
}
