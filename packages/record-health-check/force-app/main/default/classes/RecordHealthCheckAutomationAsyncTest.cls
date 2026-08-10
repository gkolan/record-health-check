@IsTest
private with sharing class RecordHealthCheckAutomationAsyncTest {
  @TestSetup
  static void setupRunPermission() {
    RecordHealthCheckTestDataFactory.assignRunPermissionToCurrentUser();
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
  static void duplicateQueueableIsRejectedButDifferentPublicationIsAccepted() {
    Account accountRecord = RecordHealthCheckTestDataFactory.createAccount(
      'Duplicate Queueable defense'
    );
    String checkSetName = RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
      'Example_Account_Profile_Readiness'
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
    Account accountRecord = RecordHealthCheckTestDataFactory.createAccount(
      'Queueable all publication'
    );
    String checkSetName = RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
      'Example_Account_Profile_Readiness'
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
  static void duplicateScheduleNameDoesNotConsumeAnotherSlot() {
    Id recordId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      1
    );
    String jobName = 'RHC duplicate schedule test';
    Test.startTest();
    String firstJobId = RecordHealthCheckScheduled.scheduleDaily(
      jobName,
      'Qualified_Set',
      new List<Id>{ recordId },
      RecordHealthCheckEventPublication.NONE
    );
    try {
      RecordHealthCheckScheduled.scheduleDaily(
        jobName,
        'Qualified_Set',
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
    RecordHealthCheckBatch batch = new RecordHealthCheckBatch(
      'Qualified_Set',
      boundary,
      RecordHealthCheckEventPublication.NONE
    );
    new RecordHealthCheckScheduled(
      'Qualified_Set',
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
    Account accountRecord = RecordHealthCheckTestDataFactory.createAccount(
      'Scheduled delegation'
    );
    RecordHealthCheckScheduled scheduled = new RecordHealthCheckScheduled(
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
        'Example_Account_Profile_Readiness'
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
  static void batchScopeFailureIsLoggedAndRethrown() {
    Id recordId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      1
    );

    Test.startTest();
    Database.executeBatch(
      new RecordHealthCheckBatch(
        'Missing_Check_Set',
        new List<Id>{ recordId },
        RecordHealthCheckEventPublication.NONE
      ),
      1
    );
    try {
      Test.stopTest();
      Assert.fail('A missing Check Set must fail the Batch scope.');
    } catch (Exception error) {
      Assert.isNotNull(
        error.getMessage(),
        'The Batch failure must retain an explanation.'
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
