/** Integration assertions for Card Heading Display metadata transport. */
@IsTest
private class RHCCardHeadingTest {
  static {
    RecordHealthCheckAccess.setRunPermissionForTest(true);
  }

  @IsTest
  static void validShellsAndDefinitionsCarryExactHeadingModes() {
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
      'RHC_Heading_None' => 'HIDE',
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

  @IsTest
  static void headingModesPreserveIndependentPassAndFailOutcomes() {
    List<Account> records = new List<Account>{
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{
          'Name' => 'RHC Heading Healthy',
          'NumberOfEmployees' => 1
        }
      ),
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{
          'Name' => 'RHC Heading Needs Review',
          'NumberOfEmployees' => 0
        }
      )
    };
    RHCIntegrationTestDataFactory.createAccounts(records);
    Map<Id, String> expectedStatusByRecordId = new Map<Id, String>{
      records[0].Id => RecordHealthCheckStatus.PASS,
      records[1].Id => RecordHealthCheckStatus.FAIL
    };

    Test.startTest();
    for (
      String developerName : new List<String>{
        'RHC_Heading_Full',
        'RHC_Heading_Title',
        'RHC_Heading_None'
      }
    ) {
      RecordHealthCheckResponse response = RecordHealthCheck.evaluate(
        RecordHealthCheckRequest.forCheckSet(
            RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
              developerName
            ),
            new List<Id>{ records[0].Id, records[1].Id }
          )
          .withEventPublication(RecordHealthCheckEventPublication.NONE)
      );

      Assert.areEqual(
        2,
        response.results.size(),
        developerName + ' must return one result for each owned record.'
      );
      for (RecordHealthCheckResultItem item : response.results) {
        Assert.areEqual(
          expectedStatusByRecordId.get(item.evaluation.recordId),
          item.evaluation.status,
          developerName +
          ' must preserve the record outcome independently of heading presentation.'
        );
      }
      Assert.areEqual(
        1,
        response.summary.passed,
        developerName + ' must report exactly one PASS.'
      );
      Assert.areEqual(
        1,
        response.summary.failed,
        developerName + ' must report exactly one FAIL.'
      );
      Assert.areEqual(
        0,
        response.summary.skipped,
        developerName + ' must not turn either ordinary result into SKIPPED.'
      );
      Assert.areEqual(
        0,
        response.summary.unable + response.summary.systemError,
        developerName + ' must not hide a configuration or system failure.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void hiddenManualHeadingConfigurationsFailBeforeEvaluation() {
    Account accountRecord = RHCIntegrationTestDataFactory.createAccount(
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{
          'Name' => 'RHC Heading Invalid Configuration',
          'NumberOfEmployees' => 1
        }
      )
    );
    RecordHealthCheckConfigService service = new RecordHealthCheckConfigService();

    Test.startTest();
    for (
      String developerName : new List<String>{
        'RHC_Heading_Action',
        'RHC_Heading_NoneLabelManual',
        'RHC_Heading_NoneIconManual',
        'RHC_Heading_NoneManual'
      }
    ) {
      String qualifiedName = RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
        developerName
      );
      Map<String, String> shell = service.getCheckSetShellConfig(qualifiedName);
      Assert.areEqual(
        'HIDE',
        shell.get('cardHeadingDisplay'),
        developerName +
        ' shell transport must retain the authored heading mode.'
      );
      Assert.areEqual(
        'Manual',
        shell.get('runMode'),
        developerName + ' shell transport must retain the authored run mode.'
      );

      try {
        service.getDefinitionResponse(qualifiedName, accountRecord.Id);
        Assert.fail(
          developerName +
          ' must reject a hidden heading that leaves a manual run unreachable.'
        );
      } catch (RecordHealthCheckConfigService.ConfigException error) {
        Assert.areEqual(
          RecordHealthCheckConfigService.RC_INVALID_CONFIG,
          error.reasonCode,
          developerName + ' must use the stable invalid-configuration reason.'
        );
        Assert.areEqual(
          developerName == 'RHC_Heading_NoneManual'
            ? 'Run Button Display cannot be Hide when checks run only after a user clicks Run. Use a visible Run Button Display or run checks when the page opens.'
            : 'Card Heading Display cannot be Hide when checks run only after a user clicks Run. Show the heading or run checks when the page opens.',
          error.getMessage(),
          developerName +
          ' must retain first-failure precedence and explain the exact rejected combination.'
        );
      }
    }
    Test.stopTest();
  }
}
