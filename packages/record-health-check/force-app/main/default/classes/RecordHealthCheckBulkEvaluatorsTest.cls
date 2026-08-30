/** Verifies scope evaluators preserve verdicts while query cost stays constant. */
@IsTest
private with sharing class RecordHealthCheckBulkEvaluatorsTest {
  private static Record_Health_Check__mdt countCheck(String evaluationType) {
    return RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'Bulk_Count',
        'MasterLabel' => 'Bulk Count',
        'CheckTitle__c' => 'Bulk count',
        'EvaluationType__c' => evaluationType,
        'SourceQuery__c' => 'SELECT COUNT() total FROM Contact WHERE AccountId = {!record.Id}',
        'SourceQueryField__c' => 'total',
        'QueryResultHandling__c' => 'ONE_RESULT',
        'EmptyValueHandling__c' => 'AS_NO_MATCH',
        'NoRowsResult__c' => 'PASS',
        'FailureSeverity__c' => 'WARNING',
        'FailureMessage__c' => 'Count comparison failed.',
        'UnableToEvaluateMessage__c' => 'Count comparison could not run.',
        'MaxQueryRows__c' => 100
      }
    );
  }

  private static Map<Id, SObject> loadAccounts(List<Id> recordIds) {
    return new Map<Id, SObject>(
      [
        SELECT Id, Name
        FROM Account
        WHERE Id IN :recordIds
      ]
    );
  }
}
