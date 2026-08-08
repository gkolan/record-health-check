/** Publication intent tests for the supported response contract. */
@IsTest
private class RecordHealthCheckLifecyclePublisherTest {
  private class FixedSettingsProvider extends RecordHealthCheckSettingsProvider {
    private Boolean publishRun;
    private Set<String> checkNames;
    FixedSettingsProvider(Boolean publishRun, Set<String> checkNames) {
      this.publishRun = publishRun;
      this.checkNames = checkNames;
    }
    public override Boolean isRunPublicationEnabled(
      String checkSetQualifiedApiName
    ) {
      return publishRun;
    }
    public override Set<String> publishedCheckNames(
      String checkSetQualifiedApiName
    ) {
      return checkNames;
    }
  }

  @IsTest
  static void malformedInteractiveItemsAreIgnoredWithoutThrowing() {
    RecordHealthCheckResponse response = new RecordHealthCheckResponse();
    response.runId = 'malformed-interactive';
    RecordHealthCheckResultItem malformed = new RecordHealthCheckResultItem();
    malformed.evaluation = new RecordHealthCheckEvaluationResult();
    malformed.evaluation.status = RecordHealthCheckStatus.FAIL;
    response.results.add(malformed);
    RecordHealthCheckLifecyclePublisher.settingsProvider = new FixedSettingsProvider(
      false,
      new Set<String>{ 'Allowed_Check' }
    );
    Integer beforeDml = Limits.getDmlStatements();

    Test.startTest();
    RecordHealthCheckLifecyclePublisher.publishInteractiveResponse(
      response,
      'Example_Set',
      RecordHealthCheckLifecyclePublisher.SOURCE_USER_INITIATED
    );
    Test.stopTest();

    Assert.areEqual(
      beforeDml,
      Limits.getDmlStatements(),
      'A malformed item must be filtered without publishing.'
    );
  }

  @IsTest
  static void malformedResponseWithoutSummaryIsIgnored() {
    RecordHealthCheckResponse response = new RecordHealthCheckResponse();
    response.summary = null;

    Test.startTest();
    RecordHealthCheckLifecyclePublisher.publishResponse(
      response,
      RecordHealthCheckEventPublication.ALL,
      'Example_Set',
      RecordHealthCheckLifecyclePublisher.SOURCE_APEX_API
    );
    Test.stopTest();

    Assert.isNull(
      response.summary,
      'A malformed caller envelope should be ignored rather than mutated.'
    );
  }
  private static RecordHealthCheckResponse response(String status) {
    RecordHealthCheckEvaluationResult evaluation = new RecordHealthCheckEvaluationResult();
    evaluation.recordId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      1
    );
    evaluation.checkQualifiedApiName = 'Account_DQ_BillingCity';
    evaluation.status = status;
    RecordHealthCheckResultItem item = new RecordHealthCheckResultItem();
    item.evaluation = evaluation;
    RecordHealthCheckResponse result = new RecordHealthCheckResponse();
    result.runId = 'run-test';
    result.recordIds.add(evaluation.recordId);
    result.checkQualifiedApiNames.add(evaluation.checkQualifiedApiName);
    result.results.add(item);
    result.summary.add(status);
    return result;
  }

  @IsTest
  static void noneAndActionablePassPublishNothing() {
    Assert.areEqual(
      '1.0',
      RecordHealthCheckLifecyclePublisher.CONTRACT_VERSION,
      'Lifecycle event publishers must retain the documented event contract version.'
    );
    Integer beforeDml = Limits.getDmlStatements();
    RecordHealthCheckLifecyclePublisher.publishResponse(
      response('FAIL'),
      RecordHealthCheckEventPublication.NONE,
      'Account_Data_Quality',
      null
    );
    RecordHealthCheckLifecyclePublisher.publishResponse(
      response('PASS'),
      RecordHealthCheckEventPublication.ACTIONABLE,
      'Account_Data_Quality',
      'MISSPELLED_SOURCE'
    );
    Assert.areEqual(beforeDml, Limits.getDmlStatements());
  }

  @IsTest
  static void allPublishesAndSourceIsTelemetryOnly() {
    Integer beforeDml = Limits.getDmlStatements();
    RecordHealthCheckLifecyclePublisher.publishResponse(
      response('PASS'),
      RecordHealthCheckEventPublication.ALL,
      'Account_Data_Quality',
      'CUSTOM_TELEMETRY_SOURCE'
    );
    Assert.areEqual(beforeDml + 2, Limits.getDmlStatements());
  }

  @IsTest
  static void subscriberGuardPublishesNothing() {
    RecordHealthCheckLifecyclePublisher.enterSubscriberContext();
    Integer beforeDml = Limits.getDmlStatements();
    RecordHealthCheckLifecyclePublisher.publishResponse(
      response('FAIL'),
      RecordHealthCheckEventPublication.ALL,
      'Account_Data_Quality',
      RecordHealthCheckLifecyclePublisher.SOURCE_APEX_API
    );
    Assert.areEqual(beforeDml, Limits.getDmlStatements());
  }

  @IsTest
  static void onLoadCannotUseInteractivePublication() {
    Integer beforeDml = Limits.getDmlStatements();
    RecordHealthCheckLifecyclePublisher.publishInteractiveResponse(
      response('FAIL'),
      'Account_Data_Quality',
      RecordHealthCheckLifecyclePublisher.SOURCE_RUN_ON_LOAD
    );
    Assert.areEqual(beforeDml, Limits.getDmlStatements());
  }

  @IsTest
  static void checkEventsPublishInBoundedChunks() {
    List<Record_Health_Check_Result__e> events = new List<Record_Health_Check_Result__e>();
    for (
      Integer index = 0;
      index <= RecordHealthCheckLifecyclePublisher.PUBLISH_CHUNK_SIZE;
      index++
    ) {
      events.add(eventRecord('chunk-' + index));
    }
    Integer beforeDml = Limits.getDmlStatements();
    RecordHealthCheckLifecyclePublisher.publishCheckEvents(events);
    Assert.areEqual(beforeDml + 2, Limits.getDmlStatements());
  }

  @IsTest
  static void partialPublishFailureIsInspectedWithoutThrowing() {
    List<Record_Health_Check_Result__e> events = new List<Record_Health_Check_Result__e>{
      eventRecord('valid-event'),
      eventRecord(null)
    };
    RecordHealthCheckLifecyclePublisher.publishCheckEvents(events);
  }

  @IsTest
  static void nullPublishResultsAreIgnoredSafely() {
    Integer dmlBefore = Limits.getDmlStatements();
    Test.startTest();
    RecordHealthCheckLifecyclePublisher.inspect(
      null,
      'SYNTHETIC_PUBLISH_FAILURE'
    );
    Test.stopTest();

    Assert.areEqual(
      dmlBefore,
      Limits.getDmlStatements(),
      'Inspecting an absent publish response must not perform DML.'
    );
  }

  @IsTest
  static void interactivePublicationFiltersChecksAndPublishesMultiRecordRun() {
    RecordHealthCheckResponse result = response('FAIL');
    result.results[0].evaluation.recordId = null;
    result.recordIds.add(
      RecordHealthCheckTestDataFactory.syntheticId(Account.SObjectType, 2)
    );
    result.results.add(null);
    result.results.add(new RecordHealthCheckResultItem());
    RecordHealthCheckLifecyclePublisher.settingsProvider = new FixedSettingsProvider(
      true,
      new Set<String>{ 'Account_DQ_BillingCity' }
    );
    Test.startTest();
    Integer beforeDml = Limits.getDmlStatements();
    RecordHealthCheckLifecyclePublisher.publishInteractiveResponse(
      result,
      'Account_Data_Quality',
      RecordHealthCheckLifecyclePublisher.SOURCE_USER_INITIATED
    );
    Assert.areEqual(
      beforeDml + 2,
      Limits.getDmlStatements(),
      'A selected Check and enabled Check Set must publish both event types.'
    );
    Test.stopTest();
  }

  @IsTest
  static void interactiveMetadataLookupAndDisabledRunRemainSafe() {
    RecordHealthCheckLifecyclePublisher.settingsProvider = new RecordHealthCheckSettingsProvider();

    Test.startTest();
    Boolean enabled = RecordHealthCheckLifecyclePublisher.isRunPublicationEnabled(
      'Check_Set_That_Does_Not_Exist'
    );
    RecordHealthCheckLifecyclePublisher.publishInteractiveResponse(
      response('FAIL'),
      'Check_Set_That_Does_Not_Exist',
      RecordHealthCheckLifecyclePublisher.SOURCE_USER_INITIATED
    );
    RecordHealthCheckLifecyclePublisher.publishInteractiveResponse(
      null,
      'Check_Set_That_Does_Not_Exist',
      RecordHealthCheckLifecyclePublisher.SOURCE_USER_INITIATED
    );
    Test.stopTest();

    Assert.isFalse(
      enabled,
      'Missing Check Set metadata must default publication off.'
    );
  }

  private static Record_Health_Check_Result__e eventRecord(String eventId) {
    return new Record_Health_Check_Result__e(
      ContractVersion__c = RecordHealthCheckLifecyclePublisher.CONTRACT_VERSION,
      EventId__c = eventId,
      RunId__c = 'test-run',
      CheckSetQualifiedApiName__c = 'Test_Set',
      CheckQualifiedApiName__c = 'Test_Check',
      Status__c = 'PASS',
      OccurredAt__c = System.now(),
      Source__c = 'APEX_API',
      FrameworkVersion__c = '2.0.0'
    );
  }
}
