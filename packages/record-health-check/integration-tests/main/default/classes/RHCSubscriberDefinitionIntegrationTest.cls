/** Integration acceptance overlay for subscriber plugin definitions. */
@IsTest
private with sharing class RHCSubscriberDefinitionIntegrationTest {
  static {
    RecordHealthCheckAccess.setRunPermissionForTest(true);
  }

  @IsTest
  static void definitionFixtureOutcomesMatchIndependentExpectations() {
    List<Account> fixtures = new List<Account>{
      account('SP-P-Healthy', 'Manufacturing', 'https://example.test'),
      account('SP-P-Unhealthy', 'Manufacturing', 'http://example.test'),
      account('SP-P-Skipped', 'Banking', 'https://example.test'),
      account('SP-P-Missing', 'Manufacturing', null)
    };
    RHCIntegrationTestDataFactory.createAccounts(fixtures);
    Map<Id, String> expectedStatus = new Map<Id, String>{
      fixtures[0].Id => RecordHealthCheckStatus.PASS,
      fixtures[1].Id => RecordHealthCheckStatus.FAIL,
      fixtures[2].Id => RecordHealthCheckStatus.SKIPPED,
      fixtures[3].Id => RecordHealthCheckStatus.UNABLE_TO_EVALUATE
    };
    Map<Id, String> expectedReason = new Map<Id, String>{
      fixtures[0].Id => 'SP_OK',
      fixtures[1].Id => 'SP_REVIEW',
      fixtures[2].Id => RecordHealthCheckReasonCodes.APPLICABILITY_NOT_MET,
      fixtures[3].Id => 'SP_DATA_MISSING'
    };
    RHCSPPPlugin.definitionCount = 0;
    RHCSPPPlugin.evaluateCount = 0;

    Test.startTest();
    RecordHealthCheckResponse response = run(fixtures);
    Test.stopTest();

    Assert.areEqual(4, response.results.size());
    for (RecordHealthCheckResultItem item : response.results) {
      Assert.areEqual(
        expectedStatus.get(item.evaluation.recordId),
        item.evaluation.status
      );
      Assert.areEqual(
        expectedReason.get(item.evaluation.recordId),
        item.evaluation.reasonCode
      );
    }
    Assert.areEqual(1, response.summary.passed);
    Assert.areEqual(1, response.summary.failed);
    Assert.areEqual(1, response.summary.skipped);
    Assert.areEqual(1, response.summary.unable);
    Assert.areEqual(0, response.summary.systemError);
    Assert.areEqual(1, RHCSPPPlugin.definitionCount);
    Assert.areEqual(1, RHCSPPPlugin.evaluateCount);
    Assert.areEqual(5, RHCSPPPlugin.seenParameters.get('maxPreviewRecords'));
    Assert.areEqual('nameId', RHCSPPPlugin.seenParameters.get('displayFormat'));
    Assert.areEqual(
      'QuoteInactiveApproverPreviewService',
      RHCSPPPlugin.seenParameters.get('previewService')
    );
  }

  @IsTest
  static void sameCheckTransition() {
    Account fixture = RHCIntegrationTestDataFactory.createAccount(
      account('SP-P-Transition', 'Manufacturing', 'https://example.test')
    );

    Test.startTest();
    RecordHealthCheckResponse first = run(new List<Account>{ fixture });
    fixture.Website = 'http://example.test';
    RHCIntegrationTestDataFactory.updateAccount(fixture);
    RecordHealthCheckResponse second = run(new List<Account>{ fixture });
    fixture.Website = 'https://example.test';
    RHCIntegrationTestDataFactory.updateAccount(fixture);
    RecordHealthCheckResponse third = run(new List<Account>{ fixture });
    Test.stopTest();

    assertSingle(first, RecordHealthCheckStatus.PASS, 'SP_OK');
    assertSingle(second, RecordHealthCheckStatus.FAIL, 'SP_REVIEW');
    assertSingle(third, RecordHealthCheckStatus.PASS, 'SP_OK');
  }

  @IsTest
  static void capacityFiveAndSix() {
    List<Account> five = accounts(5, false);
    RHCIntegrationTestDataFactory.createAccounts(five);
    RHCSPPPlugin.definitionCount = 0;
    RHCSPPPlugin.evaluateCount = 0;
    RecordHealthCheckResponse accepted = run(five);
    Assert.areEqual(5, accepted.summary.passed);
    Assert.areEqual(1, RHCSPPPlugin.definitionCount);
    Assert.areEqual(1, RHCSPPPlugin.evaluateCount);

    List<Account> six = accounts(6, false);
    RHCIntegrationTestDataFactory.createAccounts(six);
    RHCSPPPlugin.definitionCount = 0;
    RHCSPPPlugin.evaluateCount = 0;
    RecordHealthCheckResponse rejected = run(six);
    Assert.areEqual(6, rejected.summary.unable);
    for (RecordHealthCheckResultItem item : rejected.results) {
      Assert.areEqual(
        RecordHealthCheckReasonCodes.PLUGIN_SCOPE_LIMIT_EXCEEDED,
        item.evaluation.reasonCode
      );
    }
    Assert.areEqual(1, RHCSPPPlugin.definitionCount);
    Assert.areEqual(0, RHCSPPPlugin.evaluateCount);
  }

  @IsTest
  static void applicabilityBeforeCapacity() {
    List<Account> six = accounts(6, true);
    RHCIntegrationTestDataFactory.createAccounts(six);
    RHCSPPPlugin.definitionCount = 0;
    RHCSPPPlugin.evaluateCount = 0;

    RecordHealthCheckResponse response = run(six);

    Assert.areEqual(5, response.summary.passed);
    Assert.areEqual(1, response.summary.skipped);
    Assert.areEqual(0, response.summary.unable);
    Assert.areEqual(1, RHCSPPPlugin.definitionCount);
    Assert.areEqual(1, RHCSPPPlugin.evaluateCount);
  }

  @IsTest
  static void outerScopeAndDuplicates() {
    assertOuterLimit(201);
    assertOuterLimit(251);

    List<Account> five = accounts(5, false);
    RHCIntegrationTestDataFactory.createAccounts(five);
    List<Account> withDuplicate = new List<Account>(five);
    withDuplicate.add(five[0]);
    RHCSPPPlugin.definitionCount = 0;
    RHCSPPPlugin.evaluateCount = 0;
    Integer queueablesBefore = Limits.getQueueableJobs();

    RecordHealthCheckResponse response = run(withDuplicate);

    Assert.areEqual(5, response.recordIds.size());
    Assert.areEqual(5, response.summary.passed);
    Assert.areEqual(1, RHCSPPPlugin.definitionCount);
    Assert.areEqual(1, RHCSPPPlugin.evaluateCount);
    Assert.areEqual(queueablesBefore, Limits.getQueueableJobs());
  }

  @IsTest
  static void isolateOneRecord() {
    List<Account> fixtures = new List<Account>{
      account('SP-P-Isolate-Pass', 'Manufacturing', 'https://example.test'),
      account('SP-P-Isolate-Throw', 'Manufacturing', 'throw'),
      account('SP-P-Isolate-Fail', 'Manufacturing', 'http://example.test')
    };
    RHCIntegrationTestDataFactory.createAccounts(fixtures);
    resetPluginCounters();

    RecordHealthCheckResponse response = run(fixtures);

    Assert.areEqual(3, response.results.size());
    Assert.areEqual(1, response.summary.passed);
    Assert.areEqual(1, response.summary.failed);
    Assert.areEqual(1, response.summary.unable);
    Map<Id, RecordHealthCheckEvaluationResult> byId = evaluationsById(response);
    Assert.areEqual(
      RecordHealthCheckStatus.PASS,
      byId.get(fixtures[0].Id).status
    );
    Assert.areEqual(
      'RECORD_EVALUATION_FAILED',
      byId.get(fixtures[1].Id).reasonCode
    );
    Assert.areEqual(
      RecordHealthCheckStatus.FAIL,
      byId.get(fixtures[2].Id).status
    );
    Assert.areEqual(1, RHCSPPPlugin.preloadCount);
    Assert.areEqual(3, RHCSPPPlugin.recordEvaluationCount);
  }

  @IsTest
  static void fatalNotSwallowed() {
    Account fixture = RHCIntegrationTestDataFactory.createAccount(
      account('SP-P-Isolate-DML', 'Manufacturing', 'dml')
    );
    resetPluginCounters();
    Boolean escaped = false;

    try {
      run(new List<Account>{ fixture });
    } catch (RecordHealthCheckPluginDispatch.SideEffectException expected) {
      escaped = true;
    }

    Assert.isTrue(escaped);
    Assert.areEqual(1, RHCSPPPlugin.recordEvaluationCount);
    Assert.areNotEqual(
      'Forbidden per-record DML',
      [SELECT Name FROM Account WHERE Id = :fixture.Id].Name
    );
  }

  @IsTest
  static void sharedPreloadFailure() {
    List<Account> fixtures = accounts(3, false);
    RHCIntegrationTestDataFactory.createAccounts(fixtures);
    resetPluginCounters();
    RHCSPPPlugin.failPreload = true;

    RecordHealthCheckResponse response = run(fixtures);

    Assert.areEqual(3, response.summary.systemError);
    for (RecordHealthCheckResultItem item : response.results) {
      Assert.areEqual(
        RecordHealthCheckReasonCodes.PLUGIN_THREW,
        item.evaluation.reasonCode
      );
    }
    Assert.areEqual(1, RHCSPPPlugin.evaluateCount);
    Assert.areEqual(1, RHCSPPPlugin.preloadCount);
    Assert.areEqual(0, RHCSPPPlugin.recordEvaluationCount);
  }

  private static Account account(String name, String industry, String website) {
    return RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Name' => name,
        'Industry' => industry,
        'Website' => website
      }
    );
  }

  private static List<Account> accounts(Integer size, Boolean lastIsSkipped) {
    List<Account> result = new List<Account>();
    for (Integer index = 0; index < size; index++) {
      result.add(
        account(
          'SP-P-Scope-' + size + '-' + index,
          lastIsSkipped && index == size - 1 ? 'Banking' : 'Manufacturing',
          'https://example.test'
        )
      );
    }
    return result;
  }

  private static void resetPluginCounters() {
    RHCSPPPlugin.definitionCount = 0;
    RHCSPPPlugin.evaluateCount = 0;
    RHCSPPPlugin.preloadCount = 0;
    RHCSPPPlugin.recordEvaluationCount = 0;
    RHCSPPPlugin.failPreload = false;
  }

  private static Map<Id, RecordHealthCheckEvaluationResult> evaluationsById(
    RecordHealthCheckResponse response
  ) {
    Map<Id, RecordHealthCheckEvaluationResult> result = new Map<Id, RecordHealthCheckEvaluationResult>();
    for (RecordHealthCheckResultItem item : response.results) {
      result.put(item.evaluation.recordId, item.evaluation);
    }
    return result;
  }

  private static void assertOuterLimit(Integer size) {
    List<Id> recordIds = new List<Id>();
    for (Integer index = 0; index < size; index++) {
      recordIds.add(
        RecordHealthCheckTestDataFactory.syntheticId(Account.SObjectType, index)
      );
    }
    Boolean rejected = false;
    try {
      RecordHealthCheck.evaluate(
        RecordHealthCheckRequest.forCheckSet(
          RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
            'RHC_SP_Definition'
          ),
          recordIds
        )
      );
    } catch (RecordHealthCheckScopePipeline.ScopePipelineException expected) {
      rejected = expected.getMessage()
        .contains('MAX_RECORDS_PER_SCOPE_EXCEEDED');
    }
    Assert.isTrue(rejected, size + ' unique IDs must fail the outer cap.');
  }

  private static RecordHealthCheckResponse run(List<Account> fixtures) {
    List<Id> recordIds = new List<Id>();
    for (Account fixture : fixtures) {
      recordIds.add(fixture.Id);
    }
    return RecordHealthCheck.evaluate(
      RecordHealthCheckRequest.forCheckSet(
          RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
            'RHC_SP_Definition'
          ),
          recordIds
        )
        .withResultMode(RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY)
    );
  }

  private static void assertSingle(
    RecordHealthCheckResponse response,
    String status,
    String reason
  ) {
    Assert.areEqual(1, response.results.size());
    Assert.areEqual(status, response.results[0].evaluation.status);
    Assert.areEqual(reason, response.results[0].evaluation.reasonCode);
  }
}
