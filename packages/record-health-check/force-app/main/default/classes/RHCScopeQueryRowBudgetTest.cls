/** Regression coverage for cumulative scope-query row reservations. */
@IsTest
private with sharing class RHCScopeQueryRowBudgetTest {
  @IsTest
  static void oversizedOuterLimitFallsBackToFrameworkReservation() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'EvaluationType__c' => 'QUERY',
        'SourceQuery__c' => 'SELECT Id FROM Contact WHERE Id IN (SELECT ContactId FROM OpportunityContactRole LIMIT 1) LIMIT 999999999999999999',
        'MaxQueryRows__c' => null
      }
    );

    RecordHealthCheckScopePlanner planner = new RecordHealthCheckScopePlanner();

    Test.startTest();
    Integer plannedRows = planner.plannedQueryRows(
      check.SourceQuery__c,
      RecordHealthCheckConstants.FRAMEWORK_MAX_ROWS,
      1
    );
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckConstants.FRAMEWORK_MAX_ROWS + 1,
      plannedRows,
      'An out-of-range LIMIT must use the bounded framework reservation.'
    );
  }

  @IsTest
  static void invariantQueriesHonorExplicitAndDefaultRowCaps() {
    Record_Health_Check__mdt explicitLimit = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'EvaluationType__c' => 'QUERY',
        'SourceQuery__c' => 'SELECT Id FROM Contact LIMIT 1',
        'MaxQueryRows__c' => 100
      }
    );
    Record_Health_Check__mdt defaultCap = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'EvaluationType__c' => 'QUERY',
        'SourceQuery__c' => 'SELECT Id FROM Contact',
        'MaxQueryRows__c' => 0
      }
    );

    RecordHealthCheckScopePlanner planner = new RecordHealthCheckScopePlanner();

    Test.startTest();
    Integer explicitRows = planner.plannedQueryRows(
      explicitLimit.SourceQuery__c,
      (Integer) explicitLimit.MaxQueryRows__c,
      1
    );
    Integer defaultRows = planner.plannedQueryRows(
      defaultCap.SourceQuery__c,
      RecordHealthCheckConstants.FRAMEWORK_MAX_ROWS,
      1
    );
    Test.stopTest();

    Assert.areEqual(
      1,
      explicitRows,
      'The outer LIMIT must bound the reservation.'
    );
    Assert.areEqual(
      RecordHealthCheckConstants.FRAMEWORK_MAX_ROWS + 1,
      defaultRows,
      'An invariant query without LIMIT must reserve the default cap plus sentinel.'
    );
    Assert.areEqual(
      1,
      RecordHealthCheckQueryEvaluatorSupport.queryRowReservation(
        explicitLimit.SourceQuery__c,
        (Integer) explicitLimit.MaxQueryRows__c
      ),
      'The runtime gate must honor the same outer LIMIT as planning.'
    );
  }

  @IsTest
  static void dualQueryCheckReservesBothSidesTogether() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'EvaluationType__c' => 'COMPARE_TWO_QUERIES',
        'SourceQuery__c' => 'SELECT Id FROM Contact',
        'ComparisonQuery__c' => 'SELECT Id FROM Opportunity',
        'MaxQueryRows__c' => 30000
      }
    );

    Test.startTest();
    try {
      new RecordHealthCheckScopePlanner()
        .enforceTransactionBudget(
          new List<Record_Health_Check__mdt>{ check },
          1,
          RecordHealthCheckEventPublication.NONE
        );
      Assert.fail('Both query reservations must be planned as one Check unit.');
    } catch (RecordHealthCheckScopePipeline.ScopePipelineException expected) {
      Assert.isTrue(
        expected.getMessage().contains('queryRowsRequired=60003'),
        'The preload and both query caps must be reported.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void queryWithComparisonSourceReservesBothQueriesTogether() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'EvaluationType__c' => 'QUERY',
        'SourceQuery__c' => 'SELECT Id FROM Contact',
        'ExpectedValueSource__c' => 'COMPARISON_QUERY',
        'ComparisonQuery__c' => 'SELECT Id FROM Opportunity',
        'ComparisonOperator__c' => 'EQUALS',
        'MaxQueryRows__c' => 30000
      }
    );

    Test.startTest();
    try {
      new RecordHealthCheckScopePlanner()
        .enforceTransactionBudget(
          new List<Record_Health_Check__mdt>{ check },
          1,
          RecordHealthCheckEventPublication.NONE
        );
      Assert.fail('The source and comparison query must be reserved together.');
    } catch (RecordHealthCheckScopePipeline.ScopePipelineException expected) {
      Assert.isTrue(
        expected.getMessage().contains('queryRowsRequired=60003'),
        'The preload and both query caps must be reported.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void transactionBudgetUsesIncrementalQueryRowReservations() {
    List<Record_Health_Check__mdt> checks = new List<Record_Health_Check__mdt>();
    for (
      Integer index = 0;
      index < RecordHealthCheckConstants.FRAMEWORK_MAX_CHECKS;
      index++
    ) {
      checks.add(
        RecordHealthCheckTestDataFactory.check(
          new Map<String, Object>{
            'EvaluationType__c' => 'QUERY',
            'SourceQuery__c' => 'SELECT COUNT() total FROM Contact WHERE AccountId = {!record.Id}',
            'MaxQueryRows__c' => RecordHealthCheckConstants.FRAMEWORK_MAX_ROWS
          }
        )
      );
    }
    RecordHealthCheckScopePlanner planner = new RecordHealthCheckScopePlanner();

    Test.startTest();
    Integer largestNextQuery = planner.plannedQueryRows(
      checks[0].SourceQuery__c,
      RecordHealthCheckConstants.FRAMEWORK_MAX_ROWS,
      1
    );
    planner.enforceTransactionBudget(
      checks,
      1,
      RecordHealthCheckEventPublication.NONE
    );
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckConstants.FRAMEWORK_MAX_ROWS + 1,
      largestNextQuery,
      'The pre-flight must reserve the preload plus the largest next query, not every Check cap at once.'
    );
  }
}
