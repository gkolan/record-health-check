/** Focused coverage for cross-cutting validation and runtime boundaries. */
@IsTest
private with sharing class RHCCrossBoundaryCoverageTest {
  @IsTest
  static void rejectsNullQualifiedIdentity() {
    try {
      RecordHealthCheckQualifiedIdentity.normalize(null, 'Check');
      Assert.fail('A null identity must be rejected.');
    } catch (IllegalArgumentException error) {
      Assert.isTrue(
        error.getMessage().contains('QualifiedApiName is required')
      );
    }
  }

  @IsTest
  static void mapsMissingControllerIdentitiesToSafeError() {
    RecordHealthCheckAccess.setRunPermissionForTest(true);
    Account accountRecord = RecordHealthCheckTestDataFactory.accountFixture(
      'Missing controller identities'
    );
    Test.startTest();
    RecordHealthCheckResultItem result = RecordHealthCheckController.evaluateCheck(
      null,
      null,
      accountRecord.Id,
      'coverage-missing-identities',
      RecordHealthCheckLifecyclePublisher.SOURCE_USER_INITIATED
    );
    Test.stopTest();
    Assert.areEqual(RecordHealthCheckStatus.ERROR, result.evaluation.status);
  }

  @IsTest
  static void unloadedIndirectRelationshipReturnsNoRows() {
    Account accountRecord = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Id' => RecordHealthCheckTestDataFactory.syntheticId(
          Account.SObjectType,
          91
        ),
        'OwnerId' => UserInfo.getUserId()
      }
    );
    Test.startTest();
    RecordHealthCheckBulkQuerySupport.Result result = RecordHealthCheckBulkQuerySupport.execute(
      'SELECT Id FROM User WHERE Id = {!record.Owner.Id}',
      new Map<Id, SObject>{ accountRecord.Id => accountRecord },
      1
    );
    Test.stopTest();
    Assert.areEqual(0, result.rowsByRecordId.get(accountRecord.Id).size());
  }
}
