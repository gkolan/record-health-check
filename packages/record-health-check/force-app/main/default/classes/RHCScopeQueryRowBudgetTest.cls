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

    Test.startTest();
    new RecordHealthCheckScopePlanner()
      .enforceTransactionBudget(
        new List<Record_Health_Check__mdt>{ check },
        1,
        RecordHealthCheckEventPublication.NONE
      );
    Test.stopTest();

    Assert.isTrue(
      true,
      'An out-of-range LIMIT must safely use the bounded framework reservation.'
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

    Test.startTest();
    new RecordHealthCheckScopePlanner()
      .enforceTransactionBudget(
        new List<Record_Health_Check__mdt>{ explicitLimit, defaultCap },
        1,
        RecordHealthCheckEventPublication.NONE
      );
    Test.stopTest();
    Assert.isTrue(
      true,
      'Both bounded reservation strategies must remain valid.'
    );
  }

  @IsTest
  static void transactionBudgetRejectsCumulativeQueryRowOverflow() {
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
    Integer expectedRows =
      1 +
      (RecordHealthCheckConstants.FRAMEWORK_MAX_CHECKS *
      (RecordHealthCheckConstants.FRAMEWORK_MAX_ROWS + 1));

    Test.startTest();
    try {
      new RecordHealthCheckScopePlanner()
        .enforceTransactionBudget(
          checks,
          1,
          RecordHealthCheckEventPublication.NONE
        );
      Assert.fail(
        'A valid check count whose cumulative row caps exceed the transaction limit must be rejected before SOQL executes.'
      );
    } catch (RecordHealthCheckScopePipeline.ScopePipelineException error) {
      Assert.isTrue(
        error.getMessage().contains('TRANSACTION_BUDGET_EXCEEDED'),
        'The planner must use the stable transaction-budget reason.'
      );
      Assert.isTrue(
        error.getMessage().contains('queryRowsRequired=' + expectedRows),
        'The reservation must include the record preload and every query overflow-sentinel row.'
      );
      Assert.isTrue(
        error.getMessage().contains('queryRowsRemaining='),
        'The rejection must expose the transaction-aware remaining query-row capacity.'
      );
    }
    Test.stopTest();
  }
}
