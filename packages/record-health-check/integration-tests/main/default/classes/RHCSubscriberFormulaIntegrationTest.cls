/** Integration-only acceptance overlay for subscriber formula planning. */
@IsTest
private with sharing class RHCSubscriberFormulaIntegrationTest {
  static {
    RecordHealthCheckAccess.setRunPermissionForTest(true);
  }

  @IsTest
  static void sameCheckTransition() {
    Account fixture = RHCIntegrationTestDataFactory.createAccount(
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{
          'Name' => 'SP-F-Transition',
          'Industry' => 'Manufacturing',
          'Website' => 'https://example.test'
        }
      )
    );
    String setName = RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
      'RHC_SP_Formula'
    );

    Test.startTest();
    RecordHealthCheckResponse first = runSet(
      setName,
      new List<Id>{ fixture.Id }
    );
    fixture.Website = 'http://example.test';
    RHCIntegrationTestDataFactory.updateAccount(fixture);
    RecordHealthCheckResponse second = runSet(
      setName,
      new List<Id>{ fixture.Id }
    );
    fixture.Website = 'https://example.test';
    RHCIntegrationTestDataFactory.updateAccount(fixture);
    RecordHealthCheckResponse third = runSet(
      setName,
      new List<Id>{ fixture.Id }
    );
    Test.stopTest();

    assertSingle(first, RecordHealthCheckStatus.PASS);
    assertSingle(second, RecordHealthCheckStatus.FAIL);
    assertSingle(third, RecordHealthCheckStatus.PASS);
  }

  @IsTest
  static void formulaFixtureOutcomesMatchIndependentExpectations() {
    List<Account> fixtures = new List<Account>{
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{
          'Name' => 'SP-F-Healthy',
          'Industry' => 'Manufacturing',
          'Website' => 'https://example.test'
        }
      ),
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{
          'Name' => 'SP-F-Unhealthy',
          'Industry' => 'Manufacturing',
          'Website' => 'http://example.test'
        }
      ),
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{
          'Name' => 'SP-F-Skipped',
          'Industry' => 'Banking',
          'Website' => 'https://example.test'
        }
      ),
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{
          'Name' => 'SP-F-Missing',
          'Industry' => 'Manufacturing'
        }
      )
    };
    RHCIntegrationTestDataFactory.createAccounts(fixtures);
    Map<Id, String> expected = new Map<Id, String>{
      fixtures[0].Id => RecordHealthCheckStatus.PASS,
      fixtures[1].Id => RecordHealthCheckStatus.FAIL,
      fixtures[2].Id => RecordHealthCheckStatus.SKIPPED,
      fixtures[3].Id => RecordHealthCheckStatus.FAIL
    };

    Test.startTest();
    RecordHealthCheckResponse response = runSet(
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName('RHC_SP_Formula'),
      new List<Id>{
        fixtures[0].Id,
        fixtures[1].Id,
        fixtures[2].Id,
        fixtures[3].Id
      }
    );
    Test.stopTest();

    Assert.areEqual(
      4,
      response.results.size(),
      'Exactly one result per owned record is required.'
    );
    for (RecordHealthCheckResultItem item : response.results) {
      Assert.areEqual(
        expected.get(item.evaluation.recordId),
        item.evaluation.status,
        'Each owned record must match its independent expected status.'
      );
    }
    Assert.areEqual(1, response.summary.passed, 'Aggregate PASS count.');
    Assert.areEqual(2, response.summary.failed, 'Aggregate FAIL count.');
    Assert.areEqual(1, response.summary.skipped, 'Aggregate SKIPPED count.');
    Assert.areEqual(0, response.summary.unable, 'Aggregate UNABLE count.');
    Assert.areEqual(0, response.summary.systemError, 'Aggregate ERROR count.');
  }

  @IsTest
  static void restrictedFieldParity() {
    User restricted = RecordHealthCheckPersonaTestDataFactory.createMinimumAccessUser(
      'spfacc'
    );
    RecordHealthCheckTestDataFactory.assignPermissionSet(
      restricted,
      'RHC_SP_Formula_Access'
    );
    Record_Health_Check__mdt check = new RecordHealthCheckConfigService()
      .loadCheck(
        'RHC_SP_Formula_Website_Access',
        'RHC_SP_Formula_Access',
        true
      );
    List<String> validationReasons;
    List<String> runtimeReasons;

    Test.startTest();
    System.runAs(restricted) {
      RecordHealthCheckDescribeCache.clearForTest();
      validationReasons = reasons(
        RecordHealthCheckFormulaPlanService.plan(
            check.ApplicabilityFormula__c,
            Account.SObjectType,
            'ApplicabilityFormula__c'
          )
          .findings
      );
      runtimeReasons = reasons(
        new RecordHealthCheckFieldPlanner()
          .planRecordFields(check, Account.SObjectType)
          .formulaFindings
      );
    }
    RecordHealthCheckTestDataFactory.assignPermissionSet(
      restricted,
      'RHC_SP_Formula_Access_Restore'
    );
    List<RecordHealthCheckFormulaPlanService.Finding> restored;
    System.runAs(restricted) {
      RecordHealthCheckDescribeCache.clearForTest();
      restored = RecordHealthCheckFormulaPlanService.plan(
          check.ApplicabilityFormula__c,
          Account.SObjectType,
          'ApplicabilityFormula__c'
        )
        .findings;
    }
    Test.stopTest();

    Assert.areEqual(
      validationReasons,
      runtimeReasons,
      'Validation and runtime must report the same restricted-field reason.'
    );
    Assert.areEqual(
      new List<String>{ RecordHealthCheckReasonCodes.FIELD_NOT_ACCESSIBLE },
      validationReasons,
      'The denied field must remain inaccessible, not unresolved.'
    );
    Assert.isTrue(
      restored.isEmpty(),
      'Restoring AnnualRevenue read access must clear the same Check finding without activation changes.'
    );
  }

  private static RecordHealthCheckResponse runSet(
    String setName,
    List<Id> recordIds
  ) {
    return RecordHealthCheck.evaluate(
      RecordHealthCheckRequest.forCheckSet(setName, recordIds)
        .withResultMode(RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY)
    );
  }

  private static void assertSingle(
    RecordHealthCheckResponse response,
    String status
  ) {
    Assert.areEqual(
      1,
      response.results.size(),
      'The fixture Set must contain exactly one Check.'
    );
    Assert.areEqual(
      status,
      response.results[0].evaluation.status,
      'The same Check identity must follow the record transition.'
    );
    Assert.areEqual(
      1,
      response.summary.total(),
      'Each run must summarize one Check exactly once.'
    );
  }

  private static List<String> reasons(
    List<RecordHealthCheckFormulaPlanService.Finding> findings
  ) {
    List<String> result = new List<String>();
    for (RecordHealthCheckFormulaPlanService.Finding finding : findings) {
      result.add(finding.code);
    }
    return result;
  }
}
