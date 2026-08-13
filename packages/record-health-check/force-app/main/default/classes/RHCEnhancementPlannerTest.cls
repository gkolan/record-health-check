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
      plan.formulaDependenciesTruncated,
      'A dependency beyond the hard ceiling must make the plan explicitly incomplete.'
    );
    Assert.isFalse(
      plan.selectedFields.contains('CloseDate'),
      'The field beyond the ceiling must not be presented as fully planned.'
    );
  }
}
