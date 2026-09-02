@IsTest
private with sharing class RecordHealthCheckAutomationAsyncTest {
  static {
    RecordHealthCheckAccess.setRunPermissionForTest(true);
  }

  @IsTest
  static void directConstructorsRejectInvalidState() {
    assertConstructorRejected('QUEUEABLE');
    assertConstructorRejected('BATCH');
    assertConstructorRejected('SCHEDULED');
    try {
      new RecordHealthCheckBatch(
        'Qualified_Set',
        syntheticAccountIds(RecordHealthCheckConstants.MAX_ASYNC_RECORDS + 1),
        null
      );
      Assert.fail(
        'The direct Batch constructor must enforce its population cap.'
      );
    } catch (IllegalArgumentException expected) {
      Assert.isTrue(
        expected.getMessage().contains('suppliedCount=2001'),
        'The failure must report the normalized population.'
      );
    }
  }

  @IsTest
  static void sharedAsyncSupportNormalizesIdsWithoutChangingOrder() {
    Id firstId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      1
    );
    Id secondId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      2
    );

    Test.startTest();
    List<Id> normalized = RecordHealthCheckAsyncSupport.normalizeIds(
      new List<Id>{ firstId, null, secondId, firstId }
    );
    List<Id> empty = RecordHealthCheckAsyncSupport.normalizeIds(null);
    Test.stopTest();

    Assert.areEqual(
      new List<Id>{ firstId, secondId },
      normalized,
      'Normalization must remove nulls and duplicates without reordering IDs.'
    );
    Assert.isTrue(
      empty.isEmpty(),
      'A null population must normalize to empty.'
    );
  }

  @IsTest
  static void asyncRequestsDropIdsForOtherObjects() {
    Id accountId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      1
    );
    Id contactId = RecordHealthCheckTestDataFactory.syntheticId(
      Contact.SObjectType,
      1
    );
    String checkSetName = RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
      'Example_Account_Check_Builder_Guide'
    );

    try {
      RecordHealthCheckAsyncSupport.requestState(
        checkSetName,
        new List<Id>{ accountId, contactId },
        RecordHealthCheckConstants.MAX_RECORDS_PER_SCOPE,
        'Test population'
      );
      Assert.fail('A mixed-object async population must be rejected in full.');
    } catch (IllegalArgumentException expected) {
      Assert.isTrue(
        expected.getMessage().contains('no records were submitted')
      );
    }
  }

  @IsTest
  static void asyncRequestsFailClosedWhenCheckSetIsMissing() {
    Id accountId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      1
    );

    try {
      RecordHealthCheckAsyncSupport.requestState(
        'Missing_Check_Set',
        new List<Id>{ accountId },
        RecordHealthCheckConstants.MAX_RECORDS_PER_SCOPE,
        'Test population'
      );
      Assert.fail('A missing Check Set must not bypass object filtering.');
    } catch (IllegalArgumentException expected) {
      Assert.isTrue(
        expected.getMessage().contains('was not found'),
        'The caller should receive the missing Check Set diagnosis.'
      );
    }
  }

  @IsTest
  static void duplicateQueueableIsRejectedButDifferentPublicationIsAccepted() {
    Account accountRecord = RHCIntegrationTestDataFactory.createAccount(
      'Duplicate Queueable defense'
    );
    String checkSetName = RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
      'Example_Account_Check_Builder_Guide'
    );

    Test.startTest();
    RecordHealthCheckQueueable.enqueue(
      checkSetName,
      new List<Id>{ accountRecord.Id },
      RecordHealthCheckEventPublication.NONE
    );
    try {
      RecordHealthCheckQueueable.enqueue(
        ' ' + checkSetName.toUpperCase() + ' ',
        new List<Id>{ accountRecord.Id, accountRecord.Id, null },
        null
      );
      Assert.fail('An equivalent queued request must be deduplicated.');
    } catch (DuplicateMessageException expected) {
      Assert.isNotNull(
        expected.getMessage(),
        'The platform must explain the duplicate rejection.'
      );
    }
    Id distinctJob = RecordHealthCheckQueueable.enqueue(
      checkSetName,
      new List<Id>{ accountRecord.Id },
      RecordHealthCheckEventPublication.ACTIONABLE
    );
    Test.stopTest();

    Assert.isNotNull(
      distinctJob,
      'A different publication contract must receive a distinct signature.'
    );
  }

  @IsTest
  static void queueableAcceptsAllPublicationAsDistinctContract() {
    Account accountRecord = RHCIntegrationTestDataFactory.createAccount(
      'Queueable all publication'
    );
    String checkSetName = RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
      'Example_Account_Check_Builder_Guide'
    );

    Test.startTest();
    Id jobId = RecordHealthCheckQueueable.enqueue(
      checkSetName,
      new List<Id>{ accountRecord.Id },
      RecordHealthCheckEventPublication.ALL
    );
    Test.stopTest();

    Assert.isNotNull(
      jobId,
      'ALL publication must produce a valid queued request.'
    );
  }

  @IsTest
  static void queueableExecutesEveryEvaluationType() {
    assertAsyncAdapterExecutesEveryEvaluationType('QUEUEABLE');
  }

  @IsTest
  static void batchExecutesEveryEvaluationType() {
    assertAsyncAdapterExecutesEveryEvaluationType('BATCH');
  }

  @IsTest
  static void scheduledExecutesEveryEvaluationType() {
    assertAsyncAdapterExecutesEveryEvaluationType('SCHEDULED');
  }

  @IsTest
  static void equivalentQueueableRequestsAreScopedPerSubmittingUser() {
    User otherUser = RecordHealthCheckPersonaTestDataFactory.createUserWithLocale(
      'en_US',
      'rhcqdif'
    );
    RecordHealthCheckTestDataFactory.assignPermissionSet(
      otherUser,
      RecordHealthCheckSchemaTestDataFactory.runnerPermissionSetName()
    );
    Id accountId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      42
    );
    String checkSetName = RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
      'Example_Account_Check_Builder_Guide'
    );

    Test.startTest();
    Id firstJob = RecordHealthCheckQueueable.enqueue(
      checkSetName,
      new List<Id>{ accountId },
      RecordHealthCheckEventPublication.NONE
    );
    Id secondJob;
    System.runAs(otherUser) {
      secondJob = RecordHealthCheckQueueable.enqueue(
        checkSetName,
        new List<Id>{ accountId },
        RecordHealthCheckEventPublication.NONE
      );
    }
    Test.stopTest();

    Assert.areNotEqual(
      firstJob,
      secondJob,
      'Equivalent requests from different submitting users must not share an org-wide duplicate signature.'
    );
  }

  @IsTest
  static void duplicateScheduleNameDoesNotConsumeAnotherSlot() {
    Id recordId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      1
    );
    String jobName = 'RHC duplicate schedule test';
    String checkSetName = RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
      'Example_Account_Check_Builder_Guide'
    );
    Test.startTest();
    String firstJobId = RecordHealthCheckScheduled.scheduleDaily(
      jobName,
      checkSetName,
      new List<Id>{ recordId },
      RecordHealthCheckEventPublication.NONE
    );
    try {
      RecordHealthCheckScheduled.scheduleDaily(
        jobName,
        checkSetName,
        new List<Id>{ recordId },
        RecordHealthCheckEventPublication.NONE
      );
      Assert.fail('A duplicate schedule name must be rejected.');
    } catch (Exception expected) {
      Assert.isTrue(
        expected.getMessage().toLowerCase().contains('already scheduled'),
        'The rejection must identify the existing schedule.'
      );
    }
    Assert.areEqual(
      1,
      [SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name = :jobName],
      'A rejected duplicate must not consume another scheduled-job slot.'
    );
    System.abortJob(firstJobId);
    Test.stopTest();
  }

  @IsTest
  static void batchAndSchedulePreserveTwoThousandRecordBoundary() {
    List<Id> boundary = syntheticAccountIds(
      RecordHealthCheckConstants.MAX_ASYNC_RECORDS
    );
    String checkSetName = RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
      'Example_Account_Check_Builder_Guide'
    );
    RecordHealthCheckBatch batch = new RecordHealthCheckBatch(
      checkSetName,
      boundary,
      RecordHealthCheckEventPublication.NONE
    );
    new RecordHealthCheckScheduled(
      checkSetName,
      boundary,
      RecordHealthCheckEventPublication.NONE
    );

    Test.startTest();
    Integer iterated = 0;
    for (Id recordId : batch.start(null)) {
      Assert.isNotNull(
        recordId,
        'Normalized populations must not retain null IDs.'
      );
      iterated++;
    }
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckConstants.MAX_ASYNC_RECORDS,
      iterated,
      'The exact asynchronous population boundary must remain usable.'
    );
  }

  @IsTest
  static void scheduledExecutionDelegatesToBatch() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures()) {
      return;
    }
    Account accountRecord = RHCIntegrationTestDataFactory.createAccount(
      'Scheduled delegation'
    );
    RecordHealthCheckScheduled scheduled = new RecordHealthCheckScheduled(
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
        'Example_Account_Check_Builder_Guide'
      ),
      new List<Id>{ accountRecord.Id },
      RecordHealthCheckEventPublication.NONE
    );

    Test.startTest();
    scheduled.execute(null);
    Test.stopTest();

    Assert.areEqual(
      1,
      [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'BatchApex'],
      'Scheduled execution must create exactly one Batch job.'
    );
  }

  @IsTest
  static void scheduledValidationRejectsNullPopulation() {
    Test.startTest();
    try {
      RecordHealthCheckScheduled.validateSubmission(
        'Null population',
        'Qualified_Set',
        null
      );
      Assert.fail('A null scheduled population must be rejected.');
    } catch (IllegalArgumentException error) {
      Assert.isTrue(
        error.getMessage().contains('suppliedCount=0'),
        'The rejection must report the normalized empty population.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void scheduledValidationRejectsBlankJobName() {
    Test.startTest();
    try {
      RecordHealthCheckScheduled.validateSubmission(
        ' ',
        'Qualified_Set',
        new List<Id>{
          RecordHealthCheckTestDataFactory.syntheticId(Account.SObjectType, 1)
        }
      );
      Assert.fail('A blank scheduled-job name must be rejected.');
    } catch (IllegalArgumentException error) {
      Assert.isTrue(
        error.getMessage().contains('1–80 characters'),
        'The rejection must state the supported job-name length.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void missingCheckSetIsRejectedBeforeBatchSubmission() {
    Id recordId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      1
    );

    try {
      new RecordHealthCheckBatch(
        'Missing_Check_Set',
        new List<Id>{ recordId },
        RecordHealthCheckEventPublication.NONE
      );
      Assert.fail('A missing Check Set must fail before Batch submission.');
    } catch (IllegalArgumentException error) {
      Assert.isTrue(
        error.getMessage().contains('was not found'),
        'The Batch rejection must identify the missing Check Set.'
      );
    }
  }

  private static void assertConstructorRejected(String adapter) {
    try {
      if (adapter == 'QUEUEABLE') {
        new RecordHealthCheckQueueable('Qualified_Set', new List<Id>(), null);
      } else if (adapter == 'BATCH') {
        new RecordHealthCheckBatch('Qualified_Set', null, null);
      } else {
        new RecordHealthCheckScheduled(' ', new List<Id>(), null);
      }
      Assert.fail(adapter + ' direct construction must reject invalid state.');
    } catch (IllegalArgumentException expected) {
      Assert.isNotNull(
        expected.getMessage(),
        adapter + ' must explain the invalid state.'
      );
    }
  }

  private static void assertAsyncAdapterExecutesEveryEvaluationType(
    String adapter
  ) {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures()) {
      Assert.fail(
        'The release-matrix async test requires integration fixtures and must never skip.'
      );
    }
    Account accountRecord = RHCIntegrationTestDataFactory.createAccount(
      adapter + ' four-type matrix'
    );
    String checkSetName = RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
      'Example_Account_Check_Builder_Guide'
    );
    RHCIntegrationEventReceipt.reset();

    Test.startTest();
    Id jobId;
    if (adapter == 'QUEUEABLE') {
      jobId = RecordHealthCheckQueueable.enqueue(
        checkSetName,
        new List<Id>{ accountRecord.Id },
        RecordHealthCheckEventPublication.ALL
      );
    } else if (adapter == 'BATCH') {
      jobId = RecordHealthCheckBatch.run(
        checkSetName,
        new List<Id>{ accountRecord.Id },
        RecordHealthCheckEventPublication.ALL
      );
    } else {
      new RecordHealthCheckScheduled(
          checkSetName,
          new List<Id>{ accountRecord.Id },
          RecordHealthCheckEventPublication.ALL
        )
        .execute(null);
    }
    Test.stopTest();
    Test.getEventBus().deliver();

    if (jobId != null) {
      AsyncApexJob job = [
        SELECT Status, NumberOfErrors
        FROM AsyncApexJob
        WHERE Id = :jobId
      ];
      Assert.areEqual('Completed', job.Status, adapter + ' must complete.');
      Assert.areEqual(0, job.NumberOfErrors, adapter + ' must have no errors.');
    }
    Set<String> uniqueCheckNames = new Set<String>(
      RHCIntegrationEventReceipt.checkQualifiedNames
    );
    Assert.areEqual(
      25,
      uniqueCheckNames.size(),
      adapter + ' must publish one result for every Check in the matrix set.'
    );
    Assert.areEqual(
      new Set<String>{ 'APEX', 'COMPARE_TWO_QUERIES', 'FORMULA', 'QUERY' },
      RHCIntegrationEventReceipt.receivedEvaluationTypes(),
      adapter + ' must execute every evaluator type.'
    );
    Assert.areEqual(
      new Set<String>{ adapter },
      new Set<String>(RHCIntegrationEventReceipt.checkSources),
      adapter + ' result events must retain their execution origin.'
    );
    Assert.areEqual(
      2,
      RHCIntegrationEventReceipt.setRunCount,
      adapter + ' must publish the record and terminal async envelopes.'
    );
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
}
