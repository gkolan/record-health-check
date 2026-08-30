/** Covers SOQL scope execution defaults and comparison-query edge behavior. */
@IsTest
private with sharing class RecordHealthCheckSoqlScopeEdgeTest {
  @IsTest
  static void scopeDefaultsRowCapAndIgnoresBlankComparisonQuery() {
    Account accountRecord = RecordHealthCheckTestDataFactory.accountFixture(
      'Scope default cap'
    );
    Map<Id, SObject> loadedRecords = new Map<Id, SObject>{
      accountRecord.Id => accountRecord
    };
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'Blank_Comparison',
        'MasterLabel' => 'Blank comparison',
        'CheckTitle__c' => 'Blank comparison',
        'ComparisonOperator__c' => 'LIST_CONTAINS_ANY',
        'ComparisonQuery__c' => null,
        'FailureSeverity__c' => 'WARNING',
        'FailureMessage__c' => 'Failed.',
        'UnableToEvaluateMessage__c' => 'Unable.',
        'MaxQueryRows__c' => null
      }
    );

    Test.startTest();
    Map<Id, RecordHealthCheckInternalResult> results = new RecordHealthCheckSoqlEvaluator()
      .evaluateScope(check, new List<Id>{ accountRecord.Id }, loadedRecords);
    Test.stopTest();

    Assert.areEqual(
      1,
      results.size(),
      'A blank comparison query must still return one aligned terminal result.'
    );
  }

  @IsTest
  static void emptyComparisonListUsesTheConfiguredNoRowsResult() {
    Account accountRecord = RecordHealthCheckTestDataFactory.accountFixture(
      'No comparison rows'
    );
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'Empty_Comparison_List',
        'MasterLabel' => 'Empty comparison list',
        'CheckTitle__c' => 'Empty comparison list',
        'ComparisonOperator__c' => 'LIST_CONTAINS_ANY',
        'FindInListFormula__c' => 'NULL',
        'FormulaResultType__c' => 'AUTO',
        'QueryResultHandling__c' => 'COMPARE_AS_LISTS',
        'ComparisonQuery__c' => 'SELECT Name FROM Contact WHERE AccountId = {!record.Id}',
        'ComparisonQueryField__c' => 'Name',
        'NoRowsResult__c' => 'SKIP',
        'FailureSeverity__c' => 'WARNING',
        'FailureMessage__c' => 'Failed.',
        'UnableToEvaluateMessage__c' => 'Unable.'
      }
    );

    Test.startTest();
    RecordHealthCheckInternalResult result = new RecordHealthCheckSoqlEvaluator()
      .evaluate(check, accountRecord.Id, accountRecord);
    Test.stopTest();

    Assert.areEqual(
      'SKIPPED',
      result.status,
      'An empty comparison query must follow the Check no-rows behavior.'
    );
  }

  @IsTest
  static void missingRelationshipUsesStringFallbackType() {
    Test.startTest();
    Schema.DisplayType fieldType = RecordHealthCheckSoqlBindValueResolver.terminalFieldType(
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'Name' => 'No relationship' }
      ),
      'BogusRelationship.Name'
    );
    Test.stopTest();

    Assert.areEqual(
      Schema.DisplayType.STRING,
      fieldType,
      'An unknown relationship path must use the safe String fallback.'
    );
  }
}
