/** Package-safe diagnostics tests; persona creation lives in integration-tests. */
@IsTest
private class RecordHealthCheckAccessTest {
  @IsTest
  static void explicitDenyRejectsAnUnentitledTestUser() {
    User userRecord = RecordHealthCheckTestDataFactory.currentUser();
    RecordHealthCheckAccess.setRunPermissionForTest(false);
    System.runAs(userRecord) {
      Assert.isFalse(
        RecordHealthCheckAccess.canRunChecks(),
        'Apex test execution must not bypass the Run custom permission.'
      );
      try {
        RecordHealthCheckAccess.requireCanRunChecks();
        Assert.fail('The unentitled test user must be rejected.');
      } catch (RecordHealthCheckAccess.AuthorizationException expected) {
        Assert.isTrue(expected.getMessage().contains('NOT_AUTHORIZED'));
      }
    }
    RecordHealthCheckAccess.setRunPermissionForTest(null);
  }

  @IsTest
  static void explicitTestOverrideStillSupportsUnitIsolation() {
    RecordHealthCheckAccess.setRunPermissionForTest(true);
    Assert.isTrue(RecordHealthCheckAccess.canRunChecks());
    RecordHealthCheckAccess.setRunPermissionForTest(false);
    Assert.isFalse(RecordHealthCheckAccess.canRunChecks());
  }

  @IsTest
  static void explicitAdminCanViewDetails() {
    User viewer = RecordHealthCheckTestDataFactory.currentUser();
    RecordHealthCheckTestDataFactory.assignPermissionSet(
      viewer,
      'Record_Health_Check_Admin'
    );
    System.runAs(viewer) {
      Test.startTest();
      Assert.isTrue(
        RecordHealthCheckAccess.canViewDetails(),
        'Explicit Admin assignment grants detail.'
      );
      Test.stopTest();
    }
  }

  @IsTest
  static void repeatedAuthorizationUsesOneQuery() {
    User viewer = RecordHealthCheckTestDataFactory.currentUser();
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
