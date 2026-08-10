/** Proves the integration persona fixtures exercise real Salesforce sharing and FLS. */
@IsTest
private with sharing class RecordHealthCheckPersonaFixtureTest {
  @IsTest
  static void shouldEnforceSharingAndFieldAccessWhenRunningAsPersona() {
    User runner = RecordHealthCheckTestDataFactory.createMinimumAccessUser(
      'rhcpfix'
    );
    RecordHealthCheckTestDataFactory.assignPermissionSet(
      runner,
      'Record_Health_Check_User'
    );
    RecordHealthCheckTestDataFactory.assignPermissionSet(
      runner,
      'Record_Health_Check_Persona_Record_Access'
    );
    RHC_Persona_Record__c visibleRecord = RHCIntegrationTestDataFactory.personaRecord(
      'VISIBLE_SENTINEL',
      'RESTRICTED_SENTINEL'
    );
    RHC_Persona_Record__c hiddenRecord = RHCIntegrationTestDataFactory.personaRecord(
      'HIDDEN_SENTINEL',
      'HIDDEN_RESTRICTED_SENTINEL'
    );
    RHCIntegrationTestDataFactory.sharePersonaRecord(
      visibleRecord.Id,
      runner.Id
    );

    System.runAs(runner) {
      Test.startTest();
      List<RHC_Persona_Record__c> visibleRows = [
        SELECT Id, Accessible_Value__c
        FROM RHC_Persona_Record__c
        WHERE Id IN :new Set<Id>{ visibleRecord.Id, hiddenRecord.Id }
        WITH USER_MODE
      ];
      Test.stopTest();

      Assert.areEqual(
        1,
        visibleRows.size(),
        'Private sharing must expose only the manually shared record.'
      );
      Assert.areEqual(
        visibleRecord.Id,
        visibleRows[0].Id,
        'The shared record must be the only visible identity.'
      );
      try {
        Database.query(
          'SELECT Restricted_Value__c FROM RHC_Persona_Record__c WHERE Id = :visibleRecord.Id WITH USER_MODE'
        );
        Assert.fail('The deliberately withheld field must be inaccessible.');
      } catch (QueryException expected) {
        Assert.isTrue(
          String.isNotBlank(expected.getMessage()),
          'Salesforce must report a real user-mode access failure.'
        );
      }
    }
  }
}
