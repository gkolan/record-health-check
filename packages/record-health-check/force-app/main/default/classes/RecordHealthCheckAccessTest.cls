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
}
