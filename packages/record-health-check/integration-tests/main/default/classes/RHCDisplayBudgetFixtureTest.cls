/** Runs administrator metadata fixtures through the real evaluation pipeline. */
@IsTest
private class RHCDisplayBudgetFixtureTest {
  @IsTest
  static void fixtureOutcomesAndBudgetFallbackRemainConsistent() {
    List<Account> records = new List<Account>{
      fixture('Healthy', 0, 'RHC_BUDGET_FIXTURE'),
      fixture('Needs Review', 1, 'RHC_BUDGET_FIXTURE'),
      fixture('Missing Data', null, 'RHC_BUDGET_FIXTURE'),
      fixture('Out of Scope', 0, 'OTHER')
    };
    RHCIntegrationTestDataFactory.createAccounts(records);
    List<String> expectedStatuses = new List<String>{
      'PASS',
      'FAIL',
      'UNABLE_TO_EVALUATE',
      'SKIPPED'
    };
    Test.startTest();
    for (Integer index = 0; index < records.size(); index++) {
      RecordHealthCheckResponse response = RecordHealthCheck.evaluate(
        RecordHealthCheckRequest.forCheckSet(
            RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
              'RHC_Display_Budget'
            ),
            new List<Id>{ records[index].Id }
          )
          .withResultMode(RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY)
      );
      Assert.areEqual(
        2,
        response.results.size(),
        'The complete fixture Check Set must return both ordered Checks.'
      );
      for (RecordHealthCheckResultItem item : response.results) {
        Assert.areEqual(
          expectedStatuses[index],
          item.evaluation.status,
          records[index].Name +
          ': presentation allocation must preserve the expected verdict.'
        );
      }
      if (index < 2) {
        Assert.isNotNull(
          response.results[0].display.displayContent,
          'The first Check must retain structured presentation.'
        );
        Assert.isNull(
          response.results[1].display.displayContent?.found,
          'The second Check Found field must fall back after the shared response budget is exhausted.'
        );
        Assert.isNull(
          response.results[1].display.displayContent?.expected,
          'The later Expected field must also fall back after exhaustion.'
        );
        Assert.areEqual(
          String.valueOf(index),
          response.results[1].display.foundDisplayValue,
          'The omitted structured value must restore the original numeric Found fallback.'
        );
        Assert.areEqual(
          '0',
          response.results[1].display.expectedDisplayValue,
          'The omitted structured value must restore the original numeric Expected fallback.'
        );
        Integer warnings = 0;
        for (RecordHealthCheckResultItem item : response.results) {
          if (
            item.display.adminDetail
              ?.message
              ?.contains('Some optional presentation was omitted') == true
          ) {
            warnings++;
          }
        }
        Assert.areEqual(
          RecordHealthCheckAccess.canViewDetails() ? 1 : 0,
          warnings,
          'Budget diagnostics must follow the actual viewer entitlement and remain bounded.'
        );
      }
    }
    Test.stopTest();
  }

  private static Account fixture(
    String suffix,
    Integer employees,
    String site
  ) {
    return RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Name' => 'RHC Display Budget ' + suffix,
        'NumberOfEmployees' => employees,
        'Site' => site
      }
    );
  }
}
