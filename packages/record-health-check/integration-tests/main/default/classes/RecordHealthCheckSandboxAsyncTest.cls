@IsTest
private class RecordHealthCheckSandboxAsyncTest {
  private static final String CHECK_SET = 'Example_Account_Check_Builder_Guide';

  @IsTest
  static void synchronousRunnerReturnsResults() {
    Account accountRecord = RecordHealthCheckTestDataFactory.createAccount(
      'Sandbox synchronous test'
    );

    Test.startTest();
    RecordHealthCheckResponse response = RecordHealthCheckSandboxRunner.runCheckSet(
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(CHECK_SET),
      new List<Id>{ accountRecord.Id },
      'sandbox-sync-test'
    );
    Test.stopTest();

    Assert.areEqual(
      1,
      response.recordIds.size(),
      'One Account should be evaluated.'
    );
    Assert.isFalse(
      response.results.isEmpty(),
      'The Check Set should return Check results.'
    );
    Assert.isTrue(
      RecordHealthCheckSandboxRunner.summarize(response)
        .contains('sandbox-sync-test'),
      'The summary should retain the supplied correlation ID.'
    );
  }

  @IsTest
  static void synchronousRunnerBrandsGeneratedRunId() {
    Account accountRecord = RecordHealthCheckTestDataFactory.createAccount(
      'Sandbox generated run ID test'
    );

    Test.startTest();
    RecordHealthCheckResponse response = RecordHealthCheckSandboxRunner.runCheckSet(
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(CHECK_SET),
      new List<Id>{ accountRecord.Id },
      null
    );
    Test.stopTest();

    Assert.isTrue(
      response.runId.startsWith('rhc-sandbox-'),
      'Framework-generated sandbox run IDs should carry RHC branding.'
    );
  }

  @IsTest
  static void synchronousRunnerRejectsEmptyScope() {
    Test.startTest();
    try {
      RecordHealthCheckSandboxRunner.runCheckSet(
        RecordHealthCheckTestDataFactory.qualifiedCheckSetName(CHECK_SET),
        new List<Id>(),
        'sandbox-empty-test'
      );
      Assert.fail('An empty scope should be rejected.');
    } catch (RecordHealthCheckSandboxRunner.SandboxRunException ex) {
      Assert.isTrue(
        ex.getMessage().contains('record ID'),
        'The exception should identify the missing record scope.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void queueableCompletes() {
    Account accountRecord = RecordHealthCheckTestDataFactory.createAccount(
      'Sandbox Queueable test'
    );

    Test.startTest();
    Id jobId = RecordHealthCheckSandboxQueueable.enqueue(
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(CHECK_SET),
      new List<Id>{ accountRecord.Id }
    );
    Test.stopTest();

    AsyncApexJob job = [
      SELECT Status, NumberOfErrors
      FROM AsyncApexJob
      WHERE Id = :jobId
    ];
    Assert.areEqual('Completed', job.Status, 'The Queueable should complete.');
    Assert.areEqual(
      0,
      job.NumberOfErrors,
      'The Queueable should have no errors.'
    );
  }

  @IsTest
  static void queueableReportsInvalidRequest() {
    Test.startTest();
    try {
      new RecordHealthCheckSandboxQueueable(
          RecordHealthCheckTestDataFactory.qualifiedCheckSetName(CHECK_SET),
          new List<Id>()
        )
        .execute(new FakeQueueableContext());
      Assert.fail('An invalid Queueable request should fail loudly.');
    } catch (RecordHealthCheckSandboxQueueable.SandboxQueueableException ex) {
      Assert.isTrue(
        ex.getMessage().contains('verification failed'),
        'The Queueable should provide a stable failure message.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void queueableFinalizerObservesUnhandledFailure() {
    Test.startTest();
    Id jobId = RecordHealthCheckSandboxQueueable.enqueue(
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(CHECK_SET),
      new List<Id>()
    );
    Assert.isNotNull(jobId, 'The invalid request should still enqueue a job.');
    Boolean failureObserved = false;
    try {
      Test.stopTest();
    } catch (RecordHealthCheckSandboxQueueable.SandboxQueueableException ex) {
      failureObserved = true;
      Assert.isTrue(
        ex.getMessage().contains('verification failed'),
        'The asynchronous failure should retain the stable Queueable message.'
      );
    }
    Assert.isTrue(
      failureObserved,
      'The asynchronous Queueable exception should reach the test boundary.'
    );
  }

  @IsTest
  static void batchCompletes() {
    Account accountRecord = RecordHealthCheckTestDataFactory.createAccount(
      'Sandbox Batch test'
    );

    Test.startTest();
    Id jobId = RecordHealthCheckSandboxBatch.run(
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(CHECK_SET),
      new List<Id>{ accountRecord.Id }
    );
    Test.stopTest();

    AsyncApexJob job = [
      SELECT Status, NumberOfErrors
      FROM AsyncApexJob
      WHERE Id = :jobId
    ];
    Assert.areEqual('Completed', job.Status, 'The Batch should complete.');
    Assert.areEqual(0, job.NumberOfErrors, 'The Batch should have no errors.');
  }

  private class FakeQueueableContext implements QueueableContext {
    public Id getJobId() {
      return UserInfo.getUserId();
    }
  }
}
