@IsTest
private class RecordHealthCheckExhaustiveSmokeTest {
  private class FakeQueueableContext implements QueueableContext {
    public Id getJobId() {
      return UserInfo.getUserId();
    }
  }

  @IsTest
  static void setAndCheckExecutionsPersistOutcomes() {
    Account accountRecord = RecordHealthCheckTestDataFactory.createAccount(
      'Exhaustive execution'
    );
    String setName = RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
      'Example_Account_Check_Builder_Guide'
    );
    String checkName = RecordHealthCheckTestDataFactory.qualifiedCheckName(
      'Example_Website_URL_Valid'
    );

    Test.startTest();
    new RecordHealthCheckExhaustiveSmoke(accountRecord.Id, setName, 'SET')
      .execute(new FakeQueueableContext());
    new RecordHealthCheckExhaustiveSmoke(accountRecord.Id, checkName, 'CHECK')
      .execute(new FakeQueueableContext());
    Test.stopTest();

    Set<String> expectedIds = new Set<String>{
      'SET:' + setName,
      'CHECK:' + checkName
    };
    List<RHC_Event_Export__c> rows = [
      SELECT EventId__c, Threw__c, Payload__c
      FROM RHC_Event_Export__c
      WHERE EventId__c IN :expectedIds
    ];
    Assert.areEqual(
      2,
      rows.size(),
      'Both exhaustive modes should persist an outcome.'
    );
    for (RHC_Event_Export__c row : rows) {
      Assert.isFalse(
        row.Threw__c,
        'Configured exhaustive evaluations should not throw: ' + row.Payload__c
      );
    }
  }

  @IsTest
  static void invalidCheckPersistsExceptionInsteadOfThrowing() {
    Account accountRecord = RecordHealthCheckTestDataFactory.createAccount(
      'Exhaustive exception'
    );

    Test.startTest();
    new RecordHealthCheckExhaustiveSmoke(
        accountRecord.Id,
        'Missing_Check',
        'CHECK'
      )
      .execute(new FakeQueueableContext());
    Test.stopTest();

    RHC_Event_Export__c row = [
      SELECT Threw__c, ExceptionType__c, Payload__c
      FROM RHC_Event_Export__c
      WHERE EventId__c = 'CHECK:Missing_Check'
    ];
    Assert.isTrue(
      row.Threw__c,
      'A missing Check should be captured as a thrown outcome.'
    );
    Assert.isNotNull(
      row.ExceptionType__c,
      'Captured exceptions should retain their type.'
    );
    Assert.isTrue(
      row.Payload__c.contains('exceptionMessage'),
      'Captured payload should retain exception diagnostics.'
    );
  }

  @IsTest
  static void statusAndSummaryHelpersMapEveryTerminalState() {
    RecordHealthCheckRunSummary summary = new RecordHealthCheckRunSummary();

    Test.startTest();
    summary.systemError = 1;
    String systemError = RecordHealthCheckExhaustiveSmoke.overallStatus(
      summary
    );
    summary.systemError = 0;
    summary.unable = 1;
    String unable = RecordHealthCheckExhaustiveSmoke.overallStatus(summary);
    summary.unable = 0;
    summary.failed = 1;
    String failed = RecordHealthCheckExhaustiveSmoke.overallStatus(summary);
    summary.failed = 0;
    summary.passed = 1;
    String passed = RecordHealthCheckExhaustiveSmoke.overallStatus(summary);
    summary.passed = 0;
    String skipped = RecordHealthCheckExhaustiveSmoke.overallStatus(summary);
    List<Object> empty = RecordHealthCheckExhaustiveSmoke.summarize(
      new List<RecordHealthCheckResultItem>()
    );
    RecordHealthCheckResultItem item = new RecordHealthCheckResultItem();
    item.evaluation = new RecordHealthCheckEvaluationResult();
    item.evaluation.checkQualifiedApiName = 'Coverage_Check';
    item.evaluation.status = RecordHealthCheckStatus.PASS;
    item.evaluation.reasonCode = 'APEX_PASS';
    item.display = new RecordHealthCheckResultDisplay();
    item.display.renderedMessage = 'Passed.';
    RecordHealthCheckResultItem itemWithoutDisplay = new RecordHealthCheckResultItem();
    itemWithoutDisplay.evaluation = new RecordHealthCheckEvaluationResult();
    itemWithoutDisplay.evaluation.checkQualifiedApiName = 'Coverage_Check_No_Display';
    itemWithoutDisplay.evaluation.status = RecordHealthCheckStatus.SKIPPED;
    List<Object> populated = RecordHealthCheckExhaustiveSmoke.summarize(
      new List<RecordHealthCheckResultItem>{ item, itemWithoutDisplay }
    );
    Test.stopTest();

    Assert.areEqual(
      'ERROR',
      systemError,
      'System errors should take precedence.'
    );
    Assert.areEqual(
      'UNABLE_TO_EVALUATE',
      unable,
      'Unable results should map correctly.'
    );
    Assert.areEqual('FAIL', failed, 'Failures should map correctly.');
    Assert.areEqual('PASS', passed, 'Passes should map correctly.');
    Assert.areEqual(
      'SKIPPED',
      skipped,
      'An empty summary should map to skipped.'
    );
    Assert.areEqual(
      0,
      empty.size(),
      'An empty result list should summarize to an empty list.'
    );
    Assert.areEqual(
      2,
      populated.size(),
      'Every result item should produce one summary entry.'
    );
  }

  @IsTest
  static void enqueueEntryPointsReturnTraceableJobs() {
    Account accountRecord = RecordHealthCheckTestDataFactory.createAccount(
      'Exhaustive enqueue'
    );
    RHCIntegrationTestDataFactory.contact(
      accountRecord.Id,
      'Exhaustive enqueue'
    );
    RHCIntegrationTestDataFactory.opportunity(
      accountRecord.Id,
      'Exhaustive enqueue'
    );
    Integer checkCount = [SELECT COUNT() FROM Record_Health_Check__mdt];
    Integer finalCheckOffset = checkCount > 0 ? checkCount - 1 : 0;

    Test.startTest();
    List<Id> setJobs = RecordHealthCheckExhaustiveSmoke.startSets(
      accountRecord.Id
    );
    List<Id> checkJobs = RecordHealthCheckExhaustiveSmoke.startChecks(
      accountRecord.Id,
      finalCheckOffset
    );
    Test.stopTest();

    Assert.isFalse(
      setJobs.isEmpty(),
      'Configured Check Sets should enqueue traceable jobs.'
    );
    Assert.isFalse(
      checkJobs.isEmpty(),
      'The final configured Check should enqueue a traceable job.'
    );
    Assert.isNotNull(
      setJobs[0],
      'A Set job should expose its AsyncApexJob identity.'
    );
    Assert.isNotNull(
      checkJobs[0],
      'A Check job should expose its AsyncApexJob identity.'
    );
  }

  @IsTest
  static void reportReadsConcerningAndHealthyRows() {
    RHCIntegrationTestDataFactory.createRecords(
      new List<SObject>{
        RHCIntegrationTestDataFactory.eventExport(
          new Map<String, Object>{
            'EventId__c' => 'SET:Healthy',
            'Payload__c' => '{"status":"PASS"}'
          }
        ),
        RHCIntegrationTestDataFactory.eventExport(
          new Map<String, Object>{
            'EventId__c' => 'CHECK:Concern',
            'Payload__c' => '{"status":"ERROR","threw":true}'
          }
        )
      }
    );

    Test.startTest();
    RecordHealthCheckExhaustiveSmoke.report();
    Test.stopTest();

    Assert.areEqual(
      2,
      [
        SELECT COUNT()
        FROM RHC_Event_Export__c
        WHERE EventId__c IN ('SET:Healthy', 'CHECK:Concern')
      ],
      'Reporting must not mutate persisted outcomes.'
    );
  }
}
