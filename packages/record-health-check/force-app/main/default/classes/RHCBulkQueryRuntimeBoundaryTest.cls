/** Tests runtime mapping, fallback and governor boundaries for bulk queries. */
@IsTest
private with sharing class RHCBulkQueryRuntimeBoundaryTest {
  @IsTest
  static void mapsLiveSetupRowsWithoutBusinessObjectDml() {
    RecordHealthCheckTestDataFactory.assignRunPermissionToCurrentUser();
    User current = RecordHealthCheckTestDataFactory.currentUser();
    Map<Id, SObject> users = new Map<Id, SObject>{ current.Id => current };

    RecordHealthCheckBulkQuerySupport.Result selfResult = RecordHealthCheckBulkQuerySupport.execute(
      'SELECT Id FROM User WHERE Id = {!record.Id}',
      users,
      null
    );
    Assert.areEqual(
      1,
      selfResult.rowsByRecordId.get(current.Id).size(),
      'Self correlation must return the current user once.'
    );

    Account owned = RecordHealthCheckTestDataFactory.accountFixture(
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{
          'Name' => 'Indirect setup query',
          'OwnerId' => current.Id
        }
      )
    );
    Map<Id, SObject> accounts = new Map<Id, SObject>{ owned.Id => owned };
    RecordHealthCheckBulkQuerySupport.Result indirect = RecordHealthCheckBulkQuerySupport.execute(
      'SELECT Id FROM User WHERE Id = {!record.OwnerId} LIMIT 1',
      accounts,
      20
    );
    Assert.areEqual(
      1,
      indirect.rowsByRecordId.get(owned.Id).size(),
      'Indirect owner correlation must return the owner once.'
    );

    RecordHealthCheckBulkQuerySupport.Result children = RecordHealthCheckBulkQuerySupport.execute(
      'SELECT Id FROM PermissionSetAssignment WHERE AssigneeId = {!record.Id}',
      users,
      20
    );
    Assert.isTrue(
      children.rowsByRecordId.get(current.Id).size() > 0,
      'The current user must have the permission assignment created by the fixture.'
    );

    RecordHealthCheckBulkQuerySupport.Result ordered = RecordHealthCheckBulkQuerySupport.execute(
      'SELECT PermissionSetId FROM PermissionSetAssignment WHERE AssigneeId = {!record.Id} ORDER BY SystemModstamp ASC LIMIT 1',
      users,
      20
    );
    Assert.areEqual(
      1,
      ordered.rowsByRecordId.get(current.Id).size(),
      'An ordered assignment query must retain one row.'
    );

    RecordHealthCheckBulkQuerySupport.Result aggregatePick = RecordHealthCheckBulkQuerySupport.execute(
      'SELECT SystemModstamp FROM PermissionSetAssignment WHERE AssigneeId = {!record.Id} ORDER BY SystemModstamp ASC LIMIT 1',
      users,
      20
    );
    Assert.areEqual(
      1,
      aggregatePick.rowsByRecordId.get(current.Id).size(),
      'Selecting the sort field must still retain one ordered row.'
    );
  }

  @IsTest
  static void indirectFallbackAndNonIdCorrelationAreDeterministic() {
    Account account = RecordHealthCheckTestDataFactory.accountFixture(
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'Name' => 'Not an Id' }
      )
    );
    Map<Id, SObject> records = new Map<Id, SObject>{ account.Id => account };
    Id currentUserId = UserInfo.getUserId();
    RecordHealthCheckBulkQuerySupport.Result fallback = RecordHealthCheckBulkQuerySupport.execute(
      'SELECT Id FROM User WHERE Id = {!record.OwnerId fallback="' +
        currentUserId +
        '"}',
      records,
      20
    );
    Assert.areEqual(
      1,
      fallback.rowsByRecordId.get(account.Id).size(),
      'The fallback owner ID must map one user to the Account.'
    );

    try {
      RecordHealthCheckBulkQuerySupport.execute(
        'SELECT Id FROM User WHERE Id = {!record.Name}',
        records,
        20
      );
      Assert.fail('A text-valued indirect correlation must be rejected.');
    } catch (RecordHealthCheckEvaluatorException error) {
      Assert.areEqual(
        'UNSUPPORTED_BULK_QUERY_SHAPE',
        error.reasonCode,
        'A text value cannot be used as an indirect Salesforce ID.'
      );
    }
  }

  @IsTest
  static void capacityRuntimeAndRowCapsFailWithStableReasons() {
    Account account = RecordHealthCheckTestDataFactory.accountFixture(
      'Bulk failure boundaries'
    );
    Map<Id, SObject> records = new Map<Id, SObject>{ account.Id => account };
    RecordHealthCheckBulkQuerySupport.remainingQueryRowsOverride = 0;
    try {
      RecordHealthCheckBulkQuerySupport.execute(
        'SELECT Id FROM Account WHERE Name != null',
        records,
        10
      );
      Assert.fail('Insufficient query capacity must fail.');
    } catch (RecordHealthCheckEvaluatorException error) {
      Assert.areEqual(
        RecordHealthCheckReasonCodes.GOVERNOR_LIMIT_RISK,
        error.reasonCode,
        'An exhausted query budget must fail before execution.'
      );
    } finally {
      RecordHealthCheckBulkQuerySupport.remainingQueryRowsOverride = null;
    }

    try {
      RecordHealthCheckBulkQuerySupport.execute(
        'SELECT Id FROM Account WHERE Id = :rhcMissingBind',
        records,
        10
      );
      Assert.fail('An unresolved runtime bind must fail.');
    } catch (RecordHealthCheckEvaluatorException error) {
      Assert.isNotNull(
        error.reasonCode,
        'An unresolved runtime bind must expose a failure reason.'
      );
    }

    RecordHealthCheckTestDataFactory.assignRunPermissionToCurrentUser();
    RecordHealthCheckTestDataFactory.assignPermissionSet(
      RecordHealthCheckTestDataFactory.currentUser(),
      'Record_Health_Check_User'
    );
    try {
      RecordHealthCheckBulkQuerySupport.execute(
        'SELECT Id FROM PermissionSetAssignment WHERE AssigneeId = \'' +
          UserInfo.getUserId() +
          '\'',
        records,
        1
      );
      Assert.fail('A scope-wide result above its row cap must fail.');
    } catch (RecordHealthCheckEvaluatorException error) {
      Assert.areEqual(
        RecordHealthCheckReasonCodes.SCOPE_ROW_CAP_EXCEEDED,
        error.reasonCode,
        'A scope result over its row cap must expose the stable cap reason.'
      );
    }
  }
}
