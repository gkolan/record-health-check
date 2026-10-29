/** Tests explicit diagnostics assignment without a diagnostics custom permission. */
@IsTest
private class RHCExplicitDiagnosticsTest {
  @IsTest
  static void runnerAloneCannotViewDetails() {
    User runner = RecordHealthCheckTestDataFactory.createMinimumAccessUser(
      'runonly'
    );
    RecordHealthCheckTestDataFactory.assignPermissionSet(
      runner,
      'Record_Health_Check_User'
    );
    System.runAs(runner) {
      Test.startTest();
      Assert.isTrue(
        RecordHealthCheckAccess.canRunChecks(),
        'Run remains authorized.'
      );
      Assert.isFalse(
        RecordHealthCheckAccess.canViewDetails(),
        'Run must not grant diagnostics.'
      );
      Test.stopTest();
    }
  }

  @IsTest
  static void explicitViewerCanViewDetails() {
    User viewer = RecordHealthCheckTestDataFactory.createMinimumAccessUser(
      'diagview'
    );
    RecordHealthCheckTestDataFactory.assignPermissionSet(
      viewer,
      'Record_Health_Check_Diagnostics_Viewer'
    );
    System.runAs(viewer) {
      Test.startTest();
      Assert.isTrue(
        RecordHealthCheckAccess.canViewDetails(),
        'Explicit Viewer assignment grants detail.'
      );
      Assert.isFalse(
        RecordHealthCheckAccess.canRunChecks(),
        'Viewer must not independently grant Run.'
      );
      Test.stopTest();
    }
  }

  @IsTest
  static void explicitAdminCanViewDetails() {
    User admin = RecordHealthCheckTestDataFactory.createMinimumAccessUser(
      'rhcadmin'
    );
    RecordHealthCheckTestDataFactory.assignPermissionSet(
      admin,
      'Record_Health_Check_Admin'
    );
    System.runAs(admin) {
      Test.startTest();
      Assert.isTrue(
        RecordHealthCheckAccess.canViewDetails(),
        'Explicit Admin assignment grants detail.'
      );
      Test.stopTest();
    }
  }

  /**
   * An authorized viewer reads the specific access code in diagnostics, and
   * the message still shows the public code.
   *
   * The message is the same text every viewer receives. Before this was fixed
   * the message resolved {!rhcResult.reasonCode} before diagnostics replaced
   * the code, so even this viewer's message carried FIELD_NOT_ACCESSIBLE.
   */
  @IsTest
  static void explicitViewerReadsRestrictedReasonOnlyInDiagnostics() {
    User viewer = RecordHealthCheckTestDataFactory.createMinimumAccessUser(
      'diagcode'
    );
    RecordHealthCheckTestDataFactory.assignPermissionSet(
      viewer,
      'Record_Health_Check_Diagnostics_Viewer'
    );
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.status = RecordHealthCheckStatus.UNABLE_TO_EVALUATE;
    result.reasonCode = RecordHealthCheckReasonCodes.FIELD_NOT_ACCESSIBLE;
    result.message = 'Reason {!rhcResult.reasonCode}';
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{ 'EvaluationType__c' => 'FORMULA' }
    );
    System.runAs(viewer) {
      Test.startTest();
      new RecordHealthCheckScopeResultSupport()
        .finalizeDisplay(
          check,
          RecordHealthCheckTestDataFactory.account(
            new Map<String, Object>{ 'Name' => 'Diagnostics reason' }
          ),
          result,
          true
        );
      Test.stopTest();
    }

    Assert.isNotNull(result.adminDetail, 'The viewer receives diagnostics.');
    Assert.areEqual(
      RecordHealthCheckReasonCodes.FIELD_NOT_ACCESSIBLE,
      result.adminDetail.reasonCode,
      'Authorized diagnostics keep the specific access code.'
    );
    Assert.isTrue(
      result.adminDetail.containsRestrictedDetail,
      'Diagnostics mark the code as restricted detail.'
    );
    Assert.areEqual(
      'Reason CANNOT_EVALUATE',
      result.message,
      'The message is public text, even for an authorized viewer.'
    );
    Assert.areEqual(
      RecordHealthCheckReasonCodes.CANNOT_EVALUATE,
      result.reasonCode,
      'The public result code stays neutral.'
    );
  }

  @IsTest
  static void adminProfileAloneCannotViewDetails() {
    User admin = RecordHealthCheckPersonaTestDataFactory.createProfileOnlyAdmin();
    System.runAs(admin) {
      Test.startTest();
      Assert.isFalse(
        RecordHealthCheckAccess.canViewDetails(),
        'System Administrator profile must not grant diagnostics.'
      );
      Test.stopTest();
    }
  }

  @IsTest
  static void repeatedAuthorizationUsesOneQuery() {
    User viewer = RecordHealthCheckTestDataFactory.createMinimumAccessUser(
      'diagbulk'
    );
    RecordHealthCheckTestDataFactory.assignPermissionSet(
      viewer,
      'Record_Health_Check_Diagnostics_Viewer'
    );
    System.runAs(viewer) {
      Test.startTest();
      for (Integer i = 0; i < 251; i++) {
        Assert.isTrue(
          RecordHealthCheckAccess.canViewDetails(),
          'Every repeated authorization remains valid.'
        );
      }
      Assert.areEqual(
        1,
        Limits.getQueries(),
        'One assignment query per user per transaction.'
      );
      Test.stopTest();
    }
  }
}
