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
