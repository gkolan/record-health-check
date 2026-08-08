/** Verifies defensive planning and evaluator failure boundaries. */
@IsTest
private with sharing class RHCScopePipelineFailureTest {
  @TestSetup
  static void setupRunPermission() {
    RecordHealthCheckTestDataFactory.assignRunPermissionToCurrentUser();
  }

  @IsTest
  static void pipelineIsolatesPlanningAndUnexpectedEvaluatorFailures() {
    Account account = RecordHealthCheckTestDataFactory.createAccount(
      'Pipeline defensive boundaries'
    );
    Record_Health_Check__mdt check = queryCountCheck();

    RecordHealthCheckScopePipeline planningPipeline = new RecordHealthCheckScopePipeline();
    planningPipeline.planningFailureOverride = true;
    planningPipeline.loadRecordsForTest(
      'Account',
      new List<Id>{ account.Id },
      new List<Record_Health_Check__mdt>{ check }
    );

    RecordHealthCheckScopePipeline evaluatorPipeline = new RecordHealthCheckScopePipeline();
    RecordHealthCheckScopePipeline.evaluatorFailureOverride = 'EVALUATOR';
    Map<String, RecordHealthCheckResultItem> items = new Map<String, RecordHealthCheckResultItem>();
    try {
      evaluatorPipeline.evaluateCheck(
        check,
        evaluationContext(),
        new List<Id>{ account.Id },
        new Map<Id, SObject>{ account.Id => account },
        false,
        RecordHealthCheckResultMode.EVALUATION,
        'unexpected-evaluator-failure',
        items
      );
    } finally {
      RecordHealthCheckScopePipeline.evaluatorFailureOverride = null;
    }

    Assert.areEqual(1, items.size(), 'The result must remain aligned.');
    Assert.areEqual(
      'APEX_EVALUATOR_ERROR',
      items.values()[0].evaluation.reasonCode,
      'Unexpected evaluator failures must map to the stable framework reason.'
    );
  }

  private static RecordHealthCheckScopePipeline.SelectionContext evaluationContext() {
    RecordHealthCheckScopePipeline.SelectionContext context = new RecordHealthCheckScopePipeline.SelectionContext();
    context.objectApiName = 'Account';
    context.checkSetDeveloperName = 'Synthetic_Set';
    context.showDiagnostics = false;
    return context;
  }

  private static Record_Health_Check__mdt queryCountCheck() {
    return RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'QualifiedApiName' => 'Pipeline_Defensive_Boundaries',
        'DeveloperName' => 'Pipeline_Defensive_Boundaries',
        'CheckTitle__c' => 'Pipeline defensive boundaries',
        'EvaluationOrder__c' => 1,
        'EvaluationType__c' => 'QUERY',
        'ApplicabilityMode__c' => 'ALL_RECORDS',
        'SourceQuery__c' => 'SELECT COUNT() total FROM Contact WHERE AccountId = {!record.Id}',
        'SourceQueryField__c' => 'total',
        'QueryResultHandling__c' => 'ONE_RESULT',
        'ExpectedValueSource__c' => 'FIXED_VALUE',
        'ExpectedFixedValue__c' => '0',
        'ComparisonOperator__c' => 'GREATER_THAN',
        'EmptyValueHandling__c' => 'AS_NO_MATCH',
        'NoRowsResult__c' => 'PASS',
        'FailureSeverity__c' => 'WARNING',
        'FailureMessage__c' => 'Pipeline failure.',
        'UnableToEvaluateMessage__c' => 'Unable.',
        'MaxQueryRows__c' => 100
      }
    );
  }
}
