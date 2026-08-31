/** Focused planner regressions for enhancement edge cases. */
@IsTest
private class RHCEnhancementPlannerTest {
  @IsTest
  static void planColonSyntaxWhoLeadReferenceRow23() {
    Set<String> fields = new RecordHealthCheckFieldPlanner()
      .collectRecordFields(
        RecordHealthCheckTestDataFactory.check(
          new Map<String, Object>{
            'EvaluationType__c' => 'FORMULA',
            'PassConditionFormula__c' => 'Who:Lead.Email <> ""'
          }
        ),
        Task.SObjectType
      );

    Assert.isTrue(
      fields.contains('Who.Email'),
      'Who:Lead.Email must use the flat Name-entity-safe Who.Email query path.'
    );
  }

  @IsTest
  static void calculatedDependencyBeyondDepthCapIsExplicitlyIncompleteRow08() {
    RecordHealthCheckFieldPlanner planner = deepOpportunityPlanner();

    RecordHealthCheckFieldPlanner.FieldPlan plan = planner.planRecordFields(
      RecordHealthCheckTestDataFactory.check(
        new Map<String, Object>{
          'EvaluationType__c' => 'FORMULA',
          'PassConditionFormula__c' => 'ExpectedRevenue > 0'
        }
      ),
      Opportunity.SObjectType
    );

    Assert.isTrue(
      plan.verdictDependenciesTruncated,
      'A dependency beyond the hard ceiling must make the plan explicitly incomplete.'
    );
    Assert.isTrue(
      plan.selectedFields.contains('Name'),
      'The last field inside the ceiling must remain planned.'
    );
    Assert.isFalse(
      plan.selectedFields.contains('StageName'),
      'The first field beyond the ceiling must be omitted.'
    );
  }

  @IsTest
  static void displayOnlyDepthOverflowDoesNotSuppressVerdictRow08() {
    RecordHealthCheckFieldPlanner planner = deepOpportunityPlanner();
    RecordHealthCheckFieldPlanner.FieldPlan plan = planner.planRecordFields(
      RecordHealthCheckTestDataFactory.check(
        new Map<String, Object>{
          'EvaluationType__c' => 'FORMULA',
          'PassConditionFormula__c' => 'TRUE',
          'DisplayFoundFormula__c' => 'ExpectedRevenue'
        }
      ),
      Opportunity.SObjectType
    );

    Assert.isFalse(
      plan.verdictDependenciesTruncated,
      'An optional display formula must not suppress a valid verdict.'
    );
  }

  @IsTest
  static void calculatedFieldReachedByDistinctPathsExpandsTwiceRow08() {
    RecordHealthCheckFieldPlanner planner = new RecordHealthCheckFieldPlanner();
    planner.calculatedFormulaOverrideByField = new Map<String, String>{
      'Parent.Name' => 'AnnualRevenue',
      'Parent.Parent.Name' => 'AnnualRevenue'
    };

    Set<String> fields = planner.collectRecordFields(
      RecordHealthCheckTestDataFactory.check(
        new Map<String, Object>{
          'EvaluationType__c' => 'FORMULA',
          'PassConditionFormula__c' => 'Parent.Name <> Parent.Parent.Name'
        }
      ),
      Account.SObjectType
    );

    Assert.isTrue(
      fields.contains('Parent.AnnualRevenue'),
      'The direct calculated-field path must expand its operand.'
    );
    Assert.isTrue(
      fields.contains('Parent.Parent.AnnualRevenue'),
      'The same calculated field reached through a second path must expand independently.'
    );
  }

  @IsTest
  static void pipelineMapsIncompleteVerdictPlanToStableReasonRow08() {
    Account account = RecordHealthCheckTestDataFactory.accountFixture(
      'Incomplete formula plan'
    );
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'QualifiedApiName' => 'Incomplete_Formula_Plan',
        'DeveloperName' => 'Incomplete_Formula_Plan',
        'CheckTitle__c' => 'Incomplete Formula Plan',
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
        'FailureMessage__c' => 'Failed.',
        'UnableToEvaluateMessage__c' => 'Unable.',
        'MaxQueryRows__c' => 100
      }
    );
    RecordHealthCheckScopePipeline.SelectionContext context = new RecordHealthCheckScopePipeline.SelectionContext();
    context.objectApiName = 'Account';
    Map<String, RecordHealthCheckResultItem> items = new Map<String, RecordHealthCheckResultItem>();

    new RecordHealthCheckScopePipeline()
      .evaluateCheck(
        check,
        context,
        new List<Id>{ account.Id },
        new Map<Id, SObject>{ account.Id => account },
        false,
        true,
        RecordHealthCheckResultMode.EVALUATION,
        'incomplete-plan',
        items
      );

    Assert.areEqual(
      RecordHealthCheckReasonCodes.FORMULA_DEPENDENCY_DEPTH_EXCEEDED,
      items.values()[0].evaluation.reasonCode,
      'A verdict-affecting partial plan must never produce a believable PASS or FAIL.'
    );
  }

  private static RecordHealthCheckFieldPlanner deepOpportunityPlanner() {
    RecordHealthCheckFieldPlanner planner = new RecordHealthCheckFieldPlanner();
    planner.calculatedFormulaOverrideByField = new Map<String, String>{
      'ExpectedRevenue' => 'Amount',
      'Amount' => 'Probability',
      'Probability' => 'TotalOpportunityQuantity',
      'TotalOpportunityQuantity' => 'PushCount',
      'PushCount' => 'FiscalYear',
      'FiscalYear' => 'FiscalQuarter',
      'FiscalQuarter' => 'ForecastCategoryName',
      'ForecastCategoryName' => 'NextStep',
      'NextStep' => 'Description',
      'Description' => 'Name',
      'Name' => 'StageName',
      'StageName' => 'CloseDate'
    };
    return planner;
  }
}
