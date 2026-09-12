/** Integration assertions for Card Heading Display metadata transport. */
@IsTest
private class RHCCardHeadingTest {
  @IsTest
  static void shellAndDefinitionsCarryExactHeadingModes() {
    Account accountRecord = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Name' => 'RHC Heading Transport',
        'NumberOfEmployees' => 1
      }
    );
    RHCIntegrationTestDataFactory.createAccounts(
      new List<Account>{ accountRecord }
    );
    RecordHealthCheckConfigService service = new RecordHealthCheckConfigService();
    Map<String, String> expectedModes = new Map<String, String>{
      'RHC_Heading_Full' => 'TITLE_AND_SUBTITLE',
      'RHC_Heading_Title' => 'TITLE_ONLY',
      'RHC_Heading_Action' => 'HIDE',
      'RHC_Heading_Legacy' => 'TITLE_AND_SUBTITLE'
    };

    for (String developerName : expectedModes.keySet()) {
      String qualifiedName = RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
        developerName
      );
      Map<String, String> shell = service.getCheckSetShellConfig(qualifiedName);
      RecordHealthCheckDefinitionResponse definitions = service.getDefinitionResponse(
        qualifiedName,
        accountRecord.Id
      );

      Assert.areEqual(
        expectedModes.get(developerName),
        shell.get('cardHeadingDisplay'),
        developerName + ' shell mode must match metadata.'
      );
      Assert.areEqual(
        shell.get('cardHeadingDisplay'),
        definitions.cardHeadingDisplay,
        developerName + ' must use one mode in both transport paths.'
      );
      Assert.areEqual(
        shell.get('cardTitle'),
        definitions.displayTitle,
        'Heading configuration must not rewrite Card Title.'
      );
      Assert.areEqual(
        shell.get('cardDescription'),
        definitions.displayDescription,
        'Heading configuration must not rewrite Card Subtitle.'
      );
    }
  }
}
