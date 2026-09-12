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

    Assert.areEqual(
      4,
      response.results.size(),
      'The definition fixture must return one result for each of its four scenarios.'
    );
    for (RecordHealthCheckResultItem item : response.results) {
      Assert.areEqual(
        expectedStatus.get(item.evaluation.recordId),
        item.evaluation.status,
        'Each fixture record must match its independently declared outcome.'
      );
      Assert.areEqual(
        expectedReason.get(item.evaluation.recordId),
        item.evaluation.reasonCode,
        'Each fixture record must match its independently declared reason.'
      );
    }
    Assert.areEqual(
      1,
      response.summary.passed,
      'The healthy fixture must contribute one passing result.'
    );
    Assert.areEqual(
      1,
      response.summary.failed,
      'The unhealthy fixture must contribute one failing result.'
    );
    Assert.areEqual(
      1,
      response.summary.skipped,
      'The inapplicable fixture must contribute one skipped result.'
    );
    Assert.areEqual(
      1,
      response.summary.unable,
      'The missing-data fixture must contribute one unable result.'
    );
    Assert.areEqual(
      0,
      response.summary.systemError,
      'Ordinary fixture outcomes must not become framework system errors.'
    );
    Assert.areEqual(
      1,
      RHCSPPPlugin.definitionCount,
      'The fixture scope must read the plugin definition once.'
    );
    Assert.areEqual(
      1,
      RHCSPPPlugin.evaluateCount,
      'The applicable fixture scope must evaluate in one bulk invocation.'
    );
    Assert.areEqual(
      5,
      RHCSPPPlugin.seenParameters.get('maxPreviewRecords'),
      'The installed fixture must receive the declared preview-limit default.'
    );
    Assert.areEqual(
      'nameId',
      RHCSPPPlugin.seenParameters.get('displayFormat'),
      'The installed fixture must receive the declared display-format default.'
    );
    Assert.areEqual(
      'QuoteInactiveApproverPreviewService',
      RHCSPPPlugin.seenParameters.get('previewService'),
      'The installed fixture must receive the declared service-name default.'
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
    Assert.areEqual(
      5,
      accepted.summary.passed,
      'Five applicable records must fit the declared plugin capacity.'
    );
    Assert.areEqual(
      1,
      RHCSPPPlugin.definitionCount,
      'An accepted capacity boundary must read the definition once.'
    );
    Assert.areEqual(
      1,
      RHCSPPPlugin.evaluateCount,
      'An accepted capacity boundary must evaluate once in bulk.'
    );

    List<Account> six = accounts(6, false);
    RHCIntegrationTestDataFactory.createAccounts(six);
    RHCSPPPlugin.definitionCount = 0;
    RHCSPPPlugin.evaluateCount = 0;
    RecordHealthCheckResponse rejected = run(six);
    Assert.areEqual(
      6,
      rejected.summary.unable,
      'Six applicable records must all receive capacity rejection outcomes.'
    );
    for (RecordHealthCheckResultItem item : rejected.results) {
      Assert.areEqual(
        RecordHealthCheckReasonCodes.PLUGIN_SCOPE_LIMIT_EXCEEDED,
        item.evaluation.reasonCode,
        'Every oversized-scope result must use the stable plugin capacity reason.'
      );
    }
    Assert.areEqual(
      1,
      RHCSPPPlugin.definitionCount,
      'An oversized scope must still inspect the definition exactly once.'
    );
    Assert.areEqual(
      0,
      RHCSPPPlugin.evaluateCount,
      'An oversized scope must not invoke the plugin evaluator.'
    );
  }

  @IsTest
  static void applicabilityBeforeCapacity() {
    List<Account> six = accounts(6, true);
    RHCIntegrationTestDataFactory.createAccounts(six);
    RHCSPPPlugin.definitionCount = 0;
    RHCSPPPlugin.evaluateCount = 0;

    RecordHealthCheckResponse response = run(six);

    Assert.areEqual(
      5,
      response.summary.passed,
      'Five applicable records must remain eligible when a sixth record is skipped.'
    );
    Assert.areEqual(
      1,
      response.summary.skipped,
      'Applicability must exclude the sixth record before checking capacity.'
    );
    Assert.areEqual(
      0,
      response.summary.unable,
      'A skipped record must not cause a false capacity rejection.'
    );
    Assert.areEqual(
      1,
      RHCSPPPlugin.definitionCount,
      'Applicability filtering must not repeat definition discovery.'
    );
    Assert.areEqual(
      1,
      RHCSPPPlugin.evaluateCount,
      'The remaining eligible records must evaluate once in bulk.'
    );
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

    Assert.areEqual(
      5,
      response.recordIds.size(),
      'Repeated record identities must be normalized before evaluation.'
    );
    Assert.areEqual(
      5,
      response.summary.passed,
      'A duplicate input must not inflate the passing result count.'
    );
    Assert.areEqual(
      1,
      RHCSPPPlugin.definitionCount,
      'Duplicate normalization must not repeat definition discovery.'
    );
    Assert.areEqual(
      1,
      RHCSPPPlugin.evaluateCount,
      'Duplicate normalization must not repeat bulk evaluation.'
    );
    Assert.areEqual(
      queueablesBefore,
      Limits.getQueueableJobs(),
      'Normal scope execution must not enqueue hidden asynchronous work.'
    );
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

    Assert.areEqual(
      3,
      response.results.size(),
      'An isolated record exception must preserve all three response items.'
    );
    Assert.areEqual(
      1,
      response.summary.passed,
      'The passing sibling must remain counted as passed.'
    );
    Assert.areEqual(
      1,
      response.summary.failed,
      'The failing sibling must remain counted as failed.'
    );
    Assert.areEqual(
      1,
      response.summary.unable,
      'Only the throwing record must be counted as unable to evaluate.'
    );
    Map<Id, RecordHealthCheckEvaluationResult> byId = evaluationsById(response);
    Assert.areEqual(
      RecordHealthCheckStatus.PASS,
      byId.get(fixtures[0].Id).status,
      'The healthy sibling must retain its passing machine outcome.'
    );
    Assert.areEqual(
      'RECORD_EVALUATION_FAILED',
      byId.get(fixtures[1].Id).reasonCode,
      'The throwing record must expose a safe stable isolation reason.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.FAIL,
      byId.get(fixtures[2].Id).status,
      'The unhealthy sibling must retain its failing machine outcome.'
    );
    Assert.areEqual(
      1,
      RHCSPPPlugin.preloadCount,
      'Per-record isolation must share one preload across the scope.'
    );
    Assert.areEqual(
      3,
      RHCSPPPlugin.recordEvaluationCount,
      'Per-record isolation must visit each requested record exactly once.'
    );
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

    Assert.isTrue(
      escaped,
      'Forbidden record DML must escape as a fatal side-effect exception.'
    );
    Assert.areEqual(
      1,
      RHCSPPPlugin.recordEvaluationCount,
      'A fatal side effect must not retry the record evaluator.'
    );
    Assert.areNotEqual(
      'Forbidden per-record DML',
      [SELECT Name FROM Account WHERE Id = :fixture.Id].Name,
      'The side-effect fence must roll back the forbidden Account mutation.'
    );
  }

  @IsTest
  static void sharedPreloadFailure() {
    List<Account> fixtures = accounts(3, false);
    RHCIntegrationTestDataFactory.createAccounts(fixtures);
    resetPluginCounters();
    RHCSPPPlugin.failPreload = true;

    RecordHealthCheckResponse response = run(fixtures);

    Assert.areEqual(
      3,
      response.summary.systemError,
      'A failed shared preload must mark every scope result as a system error.'
    );
    for (RecordHealthCheckResultItem item : response.results) {
      Assert.areEqual(
        RecordHealthCheckReasonCodes.PLUGIN_THREW,
        item.evaluation.reasonCode,
        'A shared preload failure must use the stable plugin-threw reason.'
      );
    }
    Assert.areEqual(
      1,
      RHCSPPPlugin.evaluateCount,
      'A preload failure must not retry the bulk evaluator.'
    );
    Assert.areEqual(
      1,
      RHCSPPPlugin.preloadCount,
      'A shared preload must be attempted only once.'
    );
    Assert.areEqual(
      0,
      RHCSPPPlugin.recordEvaluationCount,
      'Record evaluation must not start after shared preload failure.'
    );
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
    Assert.areEqual(
      1,
      response.results.size(),
      'A single-record transition must return exactly one result.'
    );
    Assert.areEqual(
      status,
      response.results[0].evaluation.status,
      'The transition must follow the changed record data and expected outcome.'
    );
    Assert.areEqual(
      reason,
      response.results[0].evaluation.reasonCode,
      'The transition must retain the expected stable reason for that outcome.'
    );
  }
}
