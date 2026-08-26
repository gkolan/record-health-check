@IsTest
private with sharing class RecordHealthCheckAsyncTest {
  private static final String VALID_CHECK_SET = RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
    'Example_Account_Check_Builder_Guide'
  );
  static {
    RecordHealthCheckAccess.setRunPermissionForTest(true);
  }

  private class EnabledLogSettingsProvider extends RecordHealthCheckSettingsProvider {
    public override Boolean isErrorEventPublicationEnabled(
      String checkSetQualifiedApiName
    ) {
      return true;
    }
  }
  @IsTest
  static void shouldRejectQueueableWithNullScope() {
    Test.startTest();
    try {
      RecordHealthCheckQueueable.enqueue('Any_Set', null, null);
      Assert.fail('An empty Queueable scope must be rejected before enqueue.');
    } catch (IllegalArgumentException expected) {
      Assert.isTrue(
        expected.getMessage().contains('suppliedCount=0'),
        'The rejection must identify the empty scope.'
      );
    }
    Test.stopTest();
  }
  @IsTest
  static void shouldHandleEmptyBatchExecuteScopeSafely() {
    Id recordId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      1
    );
    RecordHealthCheckBatch batch = new RecordHealthCheckBatch(
      VALID_CHECK_SET,
      new List<Id>{ recordId },
      null
    );

    Test.startTest();
    Iterator<Id> recordIterator = batch.start(null).iterator();
    batch.execute(null, new List<Id>());
    batch.finish(null);
    Test.stopTest();

    Assert.isTrue(
      recordIterator.hasNext(),
      'The valid Batch population must remain iterable.'
    );
  }

  @IsTest
  static void shouldLogUnhandledQueueableFinalizerFailure() {
    Id recordId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      1
    );
    RecordHealthCheckQueueable queueable = new RecordHealthCheckQueueable(
      VALID_CHECK_SET,
      new List<Id>{ recordId },
      RecordHealthCheckEventPublication.NONE
    );
    Id jobId = RecordHealthCheckTestDataFactory.syntheticId(
      AsyncApexJob.SObjectType,
      1
    );
    RecordHealthCheckLogger.settingsProvider = new EnabledLogSettingsProvider();
    Test.startTest();
    RecordHealthCheckLogger.log(
      RecordHealthCheckLogger.Level.ERROR,
      'pre-finalizer',
      VALID_CHECK_SET,
      null,
      null,
      'PRE_FINALIZER_ERROR',
      null,
      new IllegalArgumentException('Synthetic buffered failure')
    );
    Assert.areEqual(
      1,
      RecordHealthCheckLogger.pendingEventCount(),
      'The test precondition must include one buffered event.'
    );
    queueable.handleFinalizerResult(
      ParentJobResult.UNHANDLED_EXCEPTION,
      jobId,
      new IllegalArgumentException('Synthetic queueable failure')
    );
    Assert.areEqual(
      0,
      RecordHealthCheckLogger.pendingEventCount(),
      'An unhandled Queueable failure must flush all buffered log events.'
    );
    Test.stopTest();
  }

  @IsTest
  static void shouldRegisterDailySchedule() {
    Account accountRecord = RecordHealthCheckTestDataFactory.createAccount(
      'Scheduled authorization'
    );
    Test.startTest();
    String jobId = RecordHealthCheckScheduled.scheduleDaily(
      'RHC Async Test',
      VALID_CHECK_SET,
      new List<Id>{ accountRecord.Id },
      null
    );
    CronTrigger scheduled = [
      SELECT CronExpression, State
      FROM CronTrigger
      WHERE Id = :jobId
    ];
    System.abortJob(jobId);
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckScheduled.CRON_DAILY_2AM,
      scheduled.CronExpression,
      'Daily scheduling must use the documented CRON expression.'
    );
  }

  @IsTest
  static void shouldExecuteScheduledRequestThroughBatchAdapter() {
    Account accountRecord = RecordHealthCheckTestDataFactory.createAccount(
      'Scheduled execution contract'
    );
    RecordHealthCheckScheduled scheduled = new RecordHealthCheckScheduled(
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
        'Example_Account_Check_Builder_Guide'
      ),
      new List<Id>{ accountRecord.Id },
      RecordHealthCheckEventPublication.NONE
    );

    Test.startTest();
    scheduled.execute((SchedulableContext) null);
    Test.stopTest();

    List<AsyncApexJob> batchJobs = [
      SELECT Status, NumberOfErrors
      FROM AsyncApexJob
      WHERE ApexClass.Name = 'RecordHealthCheckBatch'
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];
    Assert.areEqual(
      1,
      batchJobs.size(),
      'Scheduled execution must submit exactly one observable framework Batch job.'
    );
    Assert.areEqual(
      'Completed',
      batchJobs[0].Status,
      'The scheduled framework Batch must complete.'
    );
    Assert.areEqual(
      0,
      batchJobs[0].NumberOfErrors,
      'The scheduled framework Batch must finish without errors.'
    );
  }

  @IsTest
  static void frameworkQueueableCompletesAgainstARealCheckSet() {
    Account accountRecord = RecordHealthCheckTestDataFactory.createAccount(
      'Framework Queueable happy path'
    );

    Test.startTest();
    Id jobId = RecordHealthCheckQueueable.enqueue(
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
        'Example_Account_Check_Builder_Guide'
      ),
      new List<Id>{ accountRecord.Id },
      RecordHealthCheckEventPublication.NONE
    );
    Test.stopTest();

    AsyncApexJob job = [
      SELECT Status, NumberOfErrors
      FROM AsyncApexJob
      WHERE Id = :jobId
    ];
    Assert.areEqual('Completed', job.Status, 'The Queueable must complete.');
    Assert.areEqual(
      0,
      job.NumberOfErrors,
      'The Queueable must have no errors.'
    );
  }

  @IsTest
  static void frameworkBatchCompletesAgainstARealCheckSet() {
    Account accountRecord = RecordHealthCheckTestDataFactory.createAccount(
      'Framework Batch happy path'
    );

    Test.startTest();
    Id jobId = RecordHealthCheckBatch.run(
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
        'Example_Account_Check_Builder_Guide'
      ),
      new List<Id>{ accountRecord.Id },
      RecordHealthCheckEventPublication.NONE
    );
    Test.stopTest();

    AsyncApexJob job = [
      SELECT Status, NumberOfErrors
      FROM AsyncApexJob
      WHERE Id = :jobId
    ];
    Assert.areEqual('Completed', job.Status, 'The Batch must complete.');
    Assert.areEqual(0, job.NumberOfErrors, 'The Batch must have no errors.');
  }

  @IsTest
  static void asyncValidationRejectsBlankIdentitiesAndNames() {
    Id recordId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      1
    );
    assertIllegalArgument('QUEUEABLE', recordId);
    assertIllegalArgument('BATCH', recordId);
    assertIllegalArgument('SCHEDULED_SET', recordId);
    assertIllegalArgument('SCHEDULED_NAME', recordId);
  }

  @IsTest
  static void asyncValidationRejectsOverlongQualifiedIdentities() {
    Id recordId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      1
    );
    String identity = overlongIdentity();

    assertQualifiedIdentityRejected('QUEUEABLE', identity, recordId);
    assertQualifiedIdentityRejected('BATCH', identity, recordId);
    assertQualifiedIdentityRejected('SCHEDULED', identity, recordId);
  }

  @IsTest
  static void scheduledExecutionRejectsBlankIdentity() {
    try {
      new RecordHealthCheckScheduled(
          ' ',
          new List<Id>(),
          RecordHealthCheckEventPublication.NONE
        )
        .execute((SchedulableContext) null);
      Assert.fail('Delayed execution must reject a blank Check Set identity.');
    } catch (IllegalArgumentException expected) {
      Assert.isTrue(
        expected.getMessage().contains('Check Set QualifiedApiName'),
        'The delayed failure must identify the missing Check Set.'
      );
    }
  }

  @IsTest
  static void shouldEnforceAsyncPopulationBoundariesAfterDeduplication() {
    List<Id> queueBoundary = syntheticAccountIds(
      RecordHealthCheckConstants.MAX_RECORDS_PER_SCOPE
    );
    List<Id> batchBoundary = syntheticAccountIds(
      RecordHealthCheckConstants.MAX_ASYNC_RECORDS
    );

    RecordHealthCheckQueueable.validateScope(VALID_CHECK_SET, queueBoundary);
    RecordHealthCheckBatch.validatePopulation(VALID_CHECK_SET, batchBoundary);
    RecordHealthCheckScheduled.validateSubmission(
      'RHC boundary',
      VALID_CHECK_SET,
      batchBoundary
    );

    List<Id> duplicates = new List<Id>();
    for (Integer index = 0; index < 500; index++) {
      duplicates.add(queueBoundary[0]);
    }
    duplicates.add(null);
    RecordHealthCheckQueueable.validateScope(VALID_CHECK_SET, duplicates);

    assertQueueScopeRejected(
      syntheticAccountIds(RecordHealthCheckConstants.MAX_RECORDS_PER_SCOPE + 1)
    );
    assertBatchPopulationRejected(
      syntheticAccountIds(RecordHealthCheckConstants.MAX_ASYNC_RECORDS + 1)
    );
    assertScheduledPopulationRejected(
      syntheticAccountIds(RecordHealthCheckConstants.MAX_ASYNC_RECORDS + 1)
    );
  }

  @IsTest
  static void shouldDenyAsyncSubmissionsBeforeCreatingJobs() {
    Id recordId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      1
    );
    RecordHealthCheckAccess.setRunPermissionForTest(false);
    Integer jobsBefore = [SELECT COUNT() FROM AsyncApexJob];
    Integer schedulesBefore = [SELECT COUNT() FROM CronTrigger];

    assertAuthorizationDenied('QUEUEABLE', recordId);
    assertAuthorizationDenied('BATCH', recordId);
    assertAuthorizationDenied('SCHEDULED', recordId);

    Assert.areEqual(
      jobsBefore,
      [SELECT COUNT() FROM AsyncApexJob],
      'Denied submissions must not create async jobs.'
    );
    Assert.areEqual(
      schedulesBefore,
      [SELECT COUNT() FROM CronTrigger],
      'Denied submissions must not create schedules.'
    );
    RecordHealthCheckAccess.setRunPermissionForTest(null);
  }

  @IsTest
  static void shouldRecheckAuthorizationInEveryAsyncExecutionTransaction() {
    Id recordId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      1
    );
    RecordHealthCheckQueueable queueable = new RecordHealthCheckQueueable(
      VALID_CHECK_SET,
      new List<Id>{ recordId },
      RecordHealthCheckEventPublication.NONE
    );
    RecordHealthCheckBatch batch = new RecordHealthCheckBatch(
      VALID_CHECK_SET,
      new List<Id>{ recordId },
      RecordHealthCheckEventPublication.NONE
    );
    RecordHealthCheckScheduled scheduled = new RecordHealthCheckScheduled(
      VALID_CHECK_SET,
      new List<Id>{ recordId },
      RecordHealthCheckEventPublication.NONE
    );
    RecordHealthCheckAccess.setRunPermissionForTest(false);

    assertExecutionAuthorizationDenied(queueable, null, null);
    assertExecutionAuthorizationDenied(null, batch, null);
    assertExecutionAuthorizationDenied(null, null, scheduled);
    RecordHealthCheckAccess.setRunPermissionForTest(null);
  }

  private static List<Id> syntheticAccountIds(Integer count) {
    List<Id> result = new List<Id>();
    for (Integer index = 1; index <= count; index++) {
      result.add(
        RecordHealthCheckTestDataFactory.syntheticId(Account.SObjectType, index)
      );
    }
    return result;
  }

  private static String overlongIdentity() {
    String value = '';
    for (
      Integer index = 0;
      index <= RecordHealthCheckConstants.MAX_QUALIFIED_API_NAME_LENGTH;
      index++
    ) {
      value += 'x';
    }
    return value;
  }

  private static void assertQualifiedIdentityRejected(
    String adapter,
    String identity,
    Id recordId
  ) {
    try {
      if (adapter == 'QUEUEABLE') {
        RecordHealthCheckQueueable.validateScope(
          identity,
          new List<Id>{ recordId }
        );
      } else if (adapter == 'BATCH') {
        RecordHealthCheckBatch.validatePopulation(
          identity,
          new List<Id>{ recordId }
        );
      } else {
        RecordHealthCheckScheduled.validateSubmission(
          'RHC bounded identity',
          identity,
          new List<Id>{ recordId }
        );
      }
      Assert.fail(adapter + ' must reject an overlong identity.');
    } catch (IllegalArgumentException expected) {
      Assert.isTrue(
        expected.getMessage().contains('must not exceed 255 characters')
      );
    }
  }

  private static void assertQueueScopeRejected(List<Id> recordIds) {
    try {
      RecordHealthCheckQueueable.validateScope('Qualified_Set', recordIds);
      Assert.fail('One-over Queueable scope must be rejected.');
    } catch (IllegalArgumentException expected) {
      Assert.isTrue(expected.getMessage().contains('suppliedCount=201'));
    }
  }

  private static void assertBatchPopulationRejected(List<Id> recordIds) {
    try {
      RecordHealthCheckBatch.validatePopulation('Qualified_Set', recordIds);
      Assert.fail('One-over Batch population must be rejected.');
    } catch (IllegalArgumentException expected) {
      Assert.isTrue(expected.getMessage().contains('suppliedCount=2001'));
    }
  }

  private static void assertScheduledPopulationRejected(List<Id> recordIds) {
    try {
      RecordHealthCheckScheduled.validateSubmission(
        'RHC one over',
        'Qualified_Set',
        recordIds
      );
      Assert.fail('One-over Scheduled population must be rejected.');
    } catch (IllegalArgumentException expected) {
      Assert.isTrue(expected.getMessage().contains('suppliedCount=2001'));
    }
  }

  private static void assertAuthorizationDenied(String adapter, Id recordId) {
    try {
      if (adapter == 'QUEUEABLE') {
        RecordHealthCheckQueueable.enqueue(
          'Qualified_Set',
          new List<Id>{ recordId },
          RecordHealthCheckEventPublication.NONE
        );
      } else if (adapter == 'BATCH') {
        RecordHealthCheckBatch.run(
          'Qualified_Set',
          new List<Id>{ recordId },
          RecordHealthCheckEventPublication.NONE
        );
      } else {
        RecordHealthCheckScheduled.scheduleDaily(
          'RHC denied schedule',
          'Qualified_Set',
          new List<Id>{ recordId },
          RecordHealthCheckEventPublication.NONE
        );
      }
      Assert.fail(adapter + ' submission must be denied.');
    } catch (RecordHealthCheckAccess.AuthorizationException expected) {
      Assert.isTrue(expected.getMessage().contains('NOT_AUTHORIZED'));
    }
  }

  private static void assertIllegalArgument(String adapter, Id recordId) {
    try {
      if (adapter == 'QUEUEABLE') {
        RecordHealthCheckQueueable.validateScope(' ', new List<Id>{ recordId });
      } else if (adapter == 'BATCH') {
        RecordHealthCheckBatch.validatePopulation(
          ' ',
          new List<Id>{ recordId }
        );
      } else if (adapter == 'SCHEDULED_SET') {
        RecordHealthCheckScheduled.validateSubmission(
          'Valid name',
          ' ',
          new List<Id>{ recordId }
        );
      } else {
        RecordHealthCheckScheduled.validateSubmission(
          ' ',
          'Qualified_Set',
          new List<Id>{ recordId }
        );
      }
      Assert.fail(adapter + ' must reject the invalid submission.');
    } catch (IllegalArgumentException expected) {
      Assert.isNotNull(
        expected.getMessage(),
        adapter + ' must explain its rejection.'
      );
    }
  }

  private static void assertExecutionAuthorizationDenied(
    RecordHealthCheckQueueable queueable,
    RecordHealthCheckBatch batch,
    RecordHealthCheckScheduled scheduled
  ) {
    try {
      if (queueable != null) {
        queueable.execute((QueueableContext) null);
      } else if (batch != null) {
        batch.start((Database.BatchableContext) null);
      } else {
        scheduled.execute((SchedulableContext) null);
      }
      Assert.fail('Delayed execution must recheck authorization.');
    } catch (RecordHealthCheckAccess.AuthorizationException expected) {
      Assert.isTrue(expected.getMessage().contains('NOT_AUTHORIZED'));
    }
  }
}
