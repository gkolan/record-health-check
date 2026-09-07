@IsTest
private class RecordHealthCheckAccessTest {
  @IsTest
  static void explicitDenyRejectsAnUnentitledTestUser() {
    User userRecord = RecordHealthCheckTestDataFactory.createMinimumAccessUser(
      'rhcdeny'
    );

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

  @IsTest
  static void derivesPackageIdentityForInstalledAndUnpackagedMetadata() {
    Assert.isNull(
      RecordHealthCheckAccess.packageNamespaceForTypeName(
        'Record_Health_Check__mdt'
      ),
      'Unpackaged metadata has no namespace.'
    );
    Assert.areEqual(
      'rhc',
      RecordHealthCheckAccess.packageNamespaceForTypeName(
        'rhc__Record_Health_Check__mdt'
      ),
      'Packaged metadata must authorize only this package namespace.'
    );
  }

  @IsTest
  static void inabilityToReadAssignmentsFailsClosed() {
    RecordHealthCheckAccess.diagnosticsQueryExceptionForTest = true;
    try {
      Assert.isFalse(
        RecordHealthCheckAccess.canViewDetails(),
        'A Setup metadata query failure must never reveal diagnostics.'
      );
    } finally {
      RecordHealthCheckAccess.diagnosticsQueryExceptionForTest = null;
    }
  }
}
