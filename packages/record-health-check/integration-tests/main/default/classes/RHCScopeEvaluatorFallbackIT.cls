/** Focused coverage for future evaluator fallback behavior. */
@IsTest
private class RHCScopeEvaluatorFallbackIT {
  @IsTest
  static void unmigratedEvaluatorProducesAlignedUnableResult() {
    Account accountRecord = RHCIntegrationTestDataFactory.createAccount(
      'Unmigrated evaluator'
    );
    RecordHealthCheckScopePipeline.SelectionContext context = new RecordHealthCheckScopePipeline.SelectionContext();
    context.objectApiName = 'Account';
    context.showDiagnostics = false;
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'Unmigrated',
        'QualifiedApiName' => 'Unmigrated',
        'MasterLabel' => 'Unmigrated',
        'CheckTitle__c' => 'Unmigrated',
        'EvaluationOrder__c' => 1,
        'EvaluationType__c' => 'FUTURE_TYPE',
        'FailureSeverity__c' => 'WARNING',
        'FailureMessage__c' => 'Failed.',
        'UnableToEvaluateMessage__c' => 'Unable.'
      }
    );
    Map<String, RecordHealthCheckResultItem> items = new Map<String, RecordHealthCheckResultItem>();

    new RecordHealthCheckScopePipeline()
      .evaluateCheck(
        check,
        context,
        new List<Id>{ accountRecord.Id },
        new Map<Id, SObject>{ accountRecord.Id => accountRecord },
        false,
        false,
        RecordHealthCheckResultMode.EVALUATION,
        'unmigrated-run',
        items
      );

    Assert.areEqual(
      1,
      items.size(),
      'The evaluator must return one aligned item.'
    );
    Assert.areEqual(
      'INVALID_CHECK_TYPE',
      items.values()[0].evaluation.reasonCode,
      'Unknown future evaluators must fail validation with a stable reason.'
    );
  }
}
