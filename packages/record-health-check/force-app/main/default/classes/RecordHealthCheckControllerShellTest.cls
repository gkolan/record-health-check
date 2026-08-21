/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

@IsTest
private class RecordHealthCheckControllerShellTest {
  @TestSetup
  static void setup() {
    RecordHealthCheckTestDataFactory.assignRunPermissionToCurrentUser();
  }

  @IsTest
  static void getCheckSetShellConfigReturnsMetadataValues() {
    Record_Health_Check_Set__mdt expectedCheckSet = [
      SELECT
        CardTitle__c,
        CardSubtitle__c,
        RunButtonDisplay__c,
        RunButtonLabel__c,
        RerunButtonLabel__c,
        RunButtonIcon__c
      FROM Record_Health_Check_Set__mdt
      WHERE DeveloperName = 'Example_Account_Relationship_Risk'
      LIMIT 1
    ];

    Test.startTest();
    Map<String, String> shellConfig = RecordHealthCheckController.getCheckSetShellConfig(
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
        'Example_Account_Relationship_Risk'
      )
    );
    Test.stopTest();

    Assert.areEqual(
      'Manual',
      shellConfig.get('runMode'),
      'The shell should expose the metadata-owned run mode.'
    );
    Assert.areEqual(
      expectedCheckSet.CardTitle__c,
      shellConfig.get('cardTitle'),
      'The shell should expose the configured title.'
    );
    Assert.areEqual(
      expectedCheckSet.CardSubtitle__c,
      shellConfig.get('cardDescription'),
      'The shell should expose the configured subtitle.'
    );
    Assert.isTrue(
      Integer.valueOf(shellConfig.get('activeCheckCount')) > 0,
      'The shell should expose the active Check count.'
    );
    Assert.areEqual(
      RecordHealthCheckConstants.normalizedRunButtonDisplay(
        expectedCheckSet.RunButtonDisplay__c
      ),
      shellConfig.get('runButtonDisplay'),
      'The shell should expose the normalized button display.'
    );
    Assert.areEqual(
      expectedCheckSet.RunButtonLabel__c,
      shellConfig.get('runButtonLabel'),
      'The shell should expose the Run label.'
    );
    Assert.areEqual(
      expectedCheckSet.RerunButtonLabel__c,
      shellConfig.get('rerunButtonLabel'),
      'The shell should expose the Rerun label.'
    );
    Assert.areEqual(
      expectedCheckSet.RunButtonIcon__c,
      shellConfig.get('runButtonIcon'),
      'The shell should expose the Run icon.'
    );
  }

  @IsTest
  static void getCheckSetShellConfigMapsUnexpectedFailureToLoadFailed() {
    RecordHealthCheckConfigService original = RecordHealthCheckController.configService;
    RecordHealthCheckController.configService = null;

    Test.startTest();
    try {
      RecordHealthCheckController.getCheckSetShellConfig('Any_Set');
      Assert.fail('An unexpected shell failure must become an Aura error.');
    } catch (AuraHandledException error) {
      Assert.isTrue(
        error.getMessage().contains('LOAD_FAILED'),
        'Unexpected shell failures should use LOAD_FAILED.'
      );
      Assert.isFalse(
        error.getMessage().contains('NullPointerException'),
        'The Aura response must not expose internal exception details.'
      );
    } finally {
      RecordHealthCheckController.configService = original;
    }
    Test.stopTest();
  }
}
