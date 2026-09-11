/** Exact shared-planner depth boundaries for calculated-field expansion. */
@IsTest
private class RHCFormulaDependencyBoundaryTest {
  private static final List<String> OPPORTUNITY_FIELDS = new List<String>{
    'ExpectedRevenue',
    'Amount',
    'Probability',
    'TotalOpportunityQuantity',
    'PushCount',
    'FiscalYear',
    'FiscalQuarter',
    'ForecastCategoryName',
    'NextStep',
    'Description',
    'Name',
    'StageName',
    'CloseDate'
  };

  @IsTest
  static void sharedDependencyDepthNineTenEleven() {
    Test.startTest();
    RecordHealthCheckFormulaPlanService.FormulaPlan atNine = planAtDepth(9);
    RecordHealthCheckFormulaPlanService.FormulaPlan atTen = planAtDepth(10);
    RecordHealthCheckFormulaPlanService.FormulaPlan atEleven = planAtDepth(11);
    Test.stopTest();

    Assert.areEqual(
      0,
      countDepthFindings(atNine),
      'Nine calculated dependency levels must produce a complete plan.'
    );
    Assert.areEqual(
      0,
      countDepthFindings(atTen),
      'Ten calculated dependency levels must remain inside the product limit.'
    );
    Assert.areEqual(
      1,
      countDepthFindings(atEleven),
      'The eleventh calculated dependency level must produce the stable depth finding.'
    );
  }

  private static RecordHealthCheckFormulaPlanService.FormulaPlan planAtDepth(
    Integer levels
  ) {
    RecordHealthCheckFieldPlanner resolver = new RecordHealthCheckFieldPlanner();
    resolver.calculatedFormulaOverrideByField = new Map<String, String>();
    for (Integer index = 0; index < levels; index++) {
      resolver.calculatedFormulaOverrideByField.put(
        OPPORTUNITY_FIELDS[index],
        OPPORTUNITY_FIELDS[index + 1]
      );
    }
    return RecordHealthCheckFormulaPlanService.plan(
      'ExpectedRevenue > 0',
      Opportunity.SObjectType,
      'PassConditionFormula__c',
      'BOOLEAN',
      resolver
    );
  }

  private static Integer countDepthFindings(
    RecordHealthCheckFormulaPlanService.FormulaPlan plan
  ) {
    Integer count = 0;
    for (RecordHealthCheckFormulaPlanService.Finding finding : plan.findings) {
      if (
        finding.code ==
        RecordHealthCheckReasonCodes.FORMULA_DEPENDENCY_DEPTH_EXCEEDED
      ) {
        count++;
      }
    }
    return count;
  }
}
