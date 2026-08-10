/** Verifies scope evaluators preserve verdicts while query cost stays constant. */
@IsTest
private with sharing class RecordHealthCheckBulkEvaluatorsTest {
  @IsTest
  static void queryEvaluatorRunsOneQueryAndTreatsMissingCountGroupAsZero() {
    Account withContact = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'With Contact' }
    );
    Account withoutContact = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Without Contact' }
    );
    RecordHealthCheckTestDataFactory.createAccounts(
      new List<Account>{ withContact, withoutContact }
    );
    RecordHealthCheckTestDataFactory.createContact(
      RecordHealthCheckTestDataFactory.contact(
        new Map<String, Object>{
          'LastName' => 'One',
          'AccountId' => withContact.Id
        }
      )
    );
    List<Id> recordIds = new List<Id>{ withContact.Id, withoutContact.Id };
    Map<Id, SObject> records = loadAccounts(recordIds);
    Record_Health_Check__mdt check = countCheck('QUERY');
    check.ExpectedValueSource__c = 'FIXED_VALUE';
    check.ExpectedFixedValue__c = '0';
    check.ComparisonOperator__c = 'GREATER_THAN';

    RecordHealthCheckDisplayCurrencyResolver.corporateCurrency();
    Integer beforeQueries = Limits.getQueries();
    Map<Id, RecordHealthCheckInternalResult> results = new RecordHealthCheckSoqlEvaluator()
      .evaluateScope(check, recordIds, records);

    Assert.areEqual(
      1,
      Limits.getQueries() - beforeQueries,
      'A QUERY Check should execute once for the full scope.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.PASS,
      results.get(withContact.Id).status,
      'A count of one should be greater than zero.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.FAIL,
      results.get(withoutContact.Id).status,
      'A missing aggregate group must be evaluated as count zero.'
    );
  }

  @IsTest
  static void compareEvaluatorRunsExactlyTwoQueriesAndSeedsBothZeroCounts() {
    Account balancedZero = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Balanced Zero' }
    );
    Account unbalanced = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Unbalanced' }
    );
    RecordHealthCheckTestDataFactory.createAccounts(
      new List<Account>{ balancedZero, unbalanced }
    );
    RecordHealthCheckTestDataFactory.createContact(
      RecordHealthCheckTestDataFactory.contact(
        new Map<String, Object>{
          'LastName' => 'One',
          'AccountId' => unbalanced.Id
        }
      )
    );
    List<Id> recordIds = new List<Id>{ balancedZero.Id, unbalanced.Id };
    Map<Id, SObject> records = loadAccounts(recordIds);
    Record_Health_Check__mdt check = countCheck('COMPARE_TWO_QUERIES');
    check.ComparisonQuery__c = 'SELECT COUNT() total FROM Opportunity WHERE AccountId = {!record.Id}';
    check.ComparisonQueryField__c = 'total';
    check.ComparisonOperator__c = 'EQUALS';

    RecordHealthCheckDisplayCurrencyResolver.corporateCurrency();
    Integer beforeQueries = Limits.getQueries();
    Map<Id, RecordHealthCheckInternalResult> results = new RecordHealthCheckCompareQueriesEvaluator()
      .evaluateScope(check, recordIds, records);

    Assert.areEqual(
      2,
      Limits.getQueries() - beforeQueries,
      'COMPARE_TWO_QUERIES should execute each side once.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.PASS,
      results.get(balancedZero.Id).status,
      'Zero contacts should equal zero opportunities.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.FAIL,
      results.get(unbalanced.Id).status,
      'One contact should not equal zero opportunities.'
    );
  }

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
