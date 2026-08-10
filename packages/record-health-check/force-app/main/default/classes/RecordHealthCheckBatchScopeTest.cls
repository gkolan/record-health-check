@IsTest
private with sharing class RecordHealthCheckBatchScopeTest {
  @TestSetup
  static void setupRunPermission() {
    RecordHealthCheckTestDataFactory.assignRunPermissionToCurrentUser();
  }

  @IsTest
  static void batchRunUsesCallerSelectedScopeSize() {
    Account accountRecord = RecordHealthCheckTestDataFactory.createAccount(
      'Framework Batch custom scope'
    );

    Test.startTest();
    Id jobId = RecordHealthCheckBatch.run(
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
        'Example_Account_Profile_Readiness'
      ),
      new List<Id>{ accountRecord.Id },
      RecordHealthCheckEventPublication.NONE,
      1
    );
    Test.stopTest();

    AsyncApexJob job = [
      SELECT Status, NumberOfErrors
      FROM AsyncApexJob
      WHERE Id = :jobId
    ];
    Assert.areEqual(
      'Completed',
      job.Status,
      'The Batch must accept a caller-selected scope size.'
    );
    Assert.areEqual(0, job.NumberOfErrors, 'The Batch must have no errors.');
  }

  @IsTest
  static void batchRunRejectsNullScopeSize() {
    assertBatchScopeSizeRejected(null);
  }

  @IsTest
  static void batchRunRejectsZeroScopeSize() {
    assertBatchScopeSizeRejected(0);
  }

  @IsTest
  static void batchRunRejectsScopeSizeAboveRecordHealthCheckLimit() {
    assertBatchScopeSizeRejected(
      RecordHealthCheckConstants.MAX_RECORDS_PER_SCOPE + 1
    );
  }

  private static void assertBatchScopeSizeRejected(Integer scopeSize) {
    Id recordId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      1
    );
    Test.startTest();
    try {
      RecordHealthCheckBatch.run(
        'Qualified_Set',
        new List<Id>{ recordId },
        RecordHealthCheckEventPublication.NONE,
        scopeSize
      );
      Assert.fail('An invalid Batch scope size must be rejected.');
    } catch (IllegalArgumentException expected) {
      Assert.isTrue(
        expected.getMessage()
          .contains('Batch scope size must be between 1 and 200'),
        'The error must explain the supported Batch scope sizes.'
      );
      Assert.isTrue(
        expected.getMessage().contains('suppliedScopeSize=' + scopeSize),
        'The error must report the rejected Batch scope size.'
      );
    }
    Test.stopTest();
  }
}
