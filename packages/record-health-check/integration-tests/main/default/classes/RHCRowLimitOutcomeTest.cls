/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * @description Boundary and independent-side coverage for query row-limit outcomes.
 * SPDX-License-Identifier: Apache-2.0
 */
@IsTest
private class RHCRowLimitOutcomeTest {
  private static final String NAME_PREFIX = 'RHC Row Limit Evidence ';

  @TestSetup
  static void setup() {
    RHCRowLimitTestDataFactory.createAccounts(NAME_PREFIX, 3);
  }

  @IsTest
  static void coversBelowAtAndAboveCap() {
    String query = evidenceQuery();
    Assert.areEqual(
      3,
      RecordHealthCheckQueryEvaluatorSupport.runQuery(query, 4).size(),
      'A below-cap collection remains complete.'
    );
    Assert.areEqual(
      3,
      RecordHealthCheckQueryEvaluatorSupport.runQuery(query, 3).size(),
      'A collection exactly at the cap remains complete.'
    );
    try {
      RecordHealthCheckQueryEvaluatorSupport.runQuery(query, 2);
      Assert.fail('Expected the extra-row probe to refuse a partial result.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.areEqual('ROW_LIMIT_EXCEEDED', ex.reasonCode);
      Assert.isTrue(ex.getMessage().contains('configured row cap of 2'));
      Assert.isFalse(
        ex.getMessage().contains('returned 3'),
        'The detail must not disclose the true row count.'
      );
    }
  }

  @IsTest
  static void capsEachCompareQuerySideIndependently() {
    String contextName = NAME_PREFIX + '0';
    Account contextRecord = [
      SELECT Id, Name
      FROM Account
      WHERE Name = :contextName
      LIMIT 1
    ];
    RecordHealthCheckCompareQueriesEvaluator evaluator = new RecordHealthCheckCompareQueriesEvaluator();

    Record_Health_Check__mdt comparisonOverCap = dualCheck();
    comparisonOverCap.SourceQuery__c = singleEvidenceQuery();
    comparisonOverCap.ComparisonQuery__c = evidenceQuery();
    assertRowLimit(
      evaluator.evaluate(comparisonOverCap, contextRecord.Id, contextRecord)
    );

    Record_Health_Check__mdt sourceOverCap = dualCheck();
    sourceOverCap.SourceQuery__c = evidenceQuery();
    sourceOverCap.ComparisonQuery__c = singleEvidenceQuery();
    assertRowLimit(
      evaluator.evaluate(sourceOverCap, contextRecord.Id, contextRecord)
    );
  }

  private static Record_Health_Check__mdt dualCheck() {
    return RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'NeutralRowLimitShape',
        'MasterLabel' => 'Neutral row limit shape',
        'CheckTitle__c' => 'Neutral row limit shape',
        'EvaluationType__c' => 'COMPARE_TWO_QUERIES',
        'FailureSeverity__c' => 'WARNING',
        'FailureMessage__c' => 'Values differ.',
        'UnableToEvaluateMessage__c' => 'Cannot evaluate this check.',
        'SourceQueryField__c' => 'Name',
        'ComparisonQueryField__c' => 'Name',
        'ComparisonOperator__c' => 'LISTS_MATCH_EXACTLY',
        'QueryResultHandling__c' => 'COMPARE_AS_LISTS',
        'EmptyValueHandling__c' => 'AS_BLANK',
        'NoRowsResult__c' => 'UNABLE_TO_EVALUATE',
        'MaxQueryRows__c' => 2
      }
    );
  }

  private static void assertRowLimit(RecordHealthCheckInternalResult result) {
    Assert.areEqual('UNABLE_TO_EVALUATE', result.status);
    Assert.areEqual('ROW_LIMIT_EXCEEDED', result.reasonCode);
  }

  private static String evidenceQuery() {
    return 'SELECT Name FROM Account WHERE Name LIKE \'RHC Row Limit Evidence %\' ORDER BY Name';
  }

  private static String singleEvidenceQuery() {
    return 'SELECT Name FROM Account WHERE Name = \'RHC Row Limit Evidence 0\'';
  }
}
