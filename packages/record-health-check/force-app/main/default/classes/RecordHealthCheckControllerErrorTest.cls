/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */
@IsTest
private class RecordHealthCheckControllerErrorTest {
  static {
    RecordHealthCheckAccess.setRunPermissionForTest(true);
  }

  @IsTest
  static void getCheckDefinitionsWrapsConfigErrorsForAura() {
    RecordHealthCheckAccess.diagnosticsQueryExceptionForTest = true;
    try {
      try {
        RecordHealthCheckController.getCheckDefinitions(
          'Missing_Config',
          UserInfo.getUserId(),
          'regular-config-error'
        );
        Assert.fail('A missing Check Set must return a configuration error.');
      } catch (AuraHandledException error) {
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
          error.getMessage()
        );
        Assert.areEqual(
          'CONFIG_NOT_FOUND',
          payload.get('reasonCode'),
          'The Aura payload must retain the exact reason code.'
        );
        Assert.areEqual(
          'The selected Check Set configuration could not be loaded.',
          payload.get('message'),
          'An ordinary Aura payload must replace exact configuration detail with a generic message.'
        );
        Assert.isFalse(
          error.getMessage().contains('Missing_Config'),
          'An ordinary Aura payload must not disclose the rejected configuration identity.'
        );
        Assert.areEqual(
          false,
          payload.get('canViewDetails'),
          'An unverified diagnostics entitlement must fail closed.'
        );
      }
    } finally {
      RecordHealthCheckAccess.diagnosticsQueryExceptionForTest = null;
    }
  }

  @IsTest
  static void getCheckDefinitionsCarriesVerifiedAdministratorEntitlement() {
    User viewer = RecordHealthCheckTestDataFactory.currentUser();
    RecordHealthCheckTestDataFactory.assignPermissionSet(
      viewer,
      'Record_Health_Check_Admin'
    );

    System.runAs(viewer) {
      Test.startTest();
      try {
        RecordHealthCheckController.getCheckDefinitions(
          'Missing_Config',
          UserInfo.getUserId(),
          'admin-config-error'
        );
        Assert.fail('A missing Check Set must return a configuration error.');
      } catch (AuraHandledException error) {
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
          error.getMessage()
        );
        Assert.areEqual(
          true,
          payload.get('canViewDetails'),
          'A directly assigned administrator must receive verified detail entitlement.'
        );
        Assert.areEqual(
          'Check Set "Missing_Config" was not found.',
          payload.get('message'),
          'A verified administrator must retain the exact bounded configuration message.'
        );
      }
      Test.stopTest();
    }
  }
}
