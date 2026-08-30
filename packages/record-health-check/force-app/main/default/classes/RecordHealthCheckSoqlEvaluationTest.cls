/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * @description Focused tests for extracted SOQL evaluation orchestration.
 * SPDX-License-Identifier: Apache-2.0
 */
@IsTest
private class RecordHealthCheckSoqlEvaluationTest {
  @IsTest
  static void evaluatesUnaryQueryResult() {
    Account record = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Evaluation account' }
    );
    record = RecordHealthCheckTestDataFactory.accountFixture(record);
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'Soql_Evaluation_Unary',
        'MasterLabel' => 'SOQL Evaluation Unary',
        'SourceQuery__c' => 'SELECT Name FROM Account WHERE Id = {!record.Id}',
        'SourceQueryField__c' => 'Name',
        'QueryResultHandling__c' => 'ONE_RESULT',
        'ComparisonOperator__c' => 'IS_NOT_BLANK',
        'NoRowsResult__c' => 'FAIL'
      }
    );
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();

    RecordHealthCheckSoqlEvaluator evaluator = new RecordHealthCheckSoqlEvaluator();
    evaluator.scopeRowsByBoundSoql = new Map<String, List<SObject>>{
      evaluator.bindTokens(check.SourceQuery__c, record) => new List<SObject>{
        record
      }
    };

    Test.startTest();
    result = RecordHealthCheckSoqlEvaluation.evaluate(
      check,
      record.Id,
      record,
      result,
      evaluator
    );
    Test.stopTest();

    Assert.areEqual(
      'PASS',
      result.status,
      'A populated queried name should pass.'
    );
  }
}
