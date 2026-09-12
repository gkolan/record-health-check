@IsTest
private class RHCLinkFixtureTest {
  @IsTest
  static void legacyAndStructuredPluginsPreserveVerdictsAndPresentation() {
    Account healthy = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Name' => 'RHC Link Healthy',
        'Site' => 'RHC_LINK_FIXTURE',
        'NumberOfEmployees' => 0,
        'Website' => 'https://example.com/approvals'
      }
    );
    Account review = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Name' => 'RHC Link Needs Review',
        'Site' => 'RHC_LINK_FIXTURE',
        'NumberOfEmployees' => 1,
        'Website' => 'https://example.com/approvals'
      }
    );
    Account missing = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Name' => 'RHC Link Missing Data',
        'Site' => 'RHC_LINK_FIXTURE',
        'Website' => null
      }
    );
    RHCIntegrationTestDataFactory.createAccounts(
      new List<Account>{ healthy, review, missing }
    );
    List<Id> recordIds = new List<Id>{ healthy.Id, review.Id, missing.Id };

    RecordHealthCheckScope legacyScope = scopeFor(
      recordIds,
      'RHC_Link_Apex_Legacy'
    );
    Map<Id, RecordHealthCheckOutcome> legacy = new RHCLinkLegacyPlugin()
      .evaluate(legacyScope);
    Assert.areEqual('PASS', legacy.get(healthy.Id).status);
    Assert.areEqual('FAIL', legacy.get(review.Id).status);
    Assert.areEqual(
      'Step 1 - Payment Term Approvals\nStep 2 - Finance Approval',
      legacy.get(review.Id).found.storedValue,
      'Legacy text keeps real LF and is never reparsed as structured content.'
    );
    Assert.areEqual('UNABLE_TO_EVALUATE', legacy.get(missing.Id).status);

    RecordHealthCheckScope structuredScope = scopeFor(
      recordIds,
      'RHC_Link_Apex_Structured'
    );
    RHCLinkStructuredPlugin structured = new RHCLinkStructuredPlugin();
    Map<Id, RecordHealthCheckOutcome> outcomes = structured.evaluate(
      structuredScope
    );
    Integer queriesAfterEvaluation = Limits.getQueries();
    Map<Id, RecordHealthCheckDisplayOverride> displays = structured.getDisplay(
      structuredScope
    );
    Assert.areEqual(
      queriesAfterEvaluation,
      Limits.getQueries(),
      'The optional display callback must reuse evaluation data.'
    );
    Assert.areEqual('PASS', outcomes.get(healthy.Id).status);
    Assert.areEqual('FAIL', outcomes.get(review.Id).status);
    Assert.areEqual('UNABLE_TO_EVALUATE', outcomes.get(missing.Id).status);
    Assert.isTrue(displays.containsKey(healthy.Id));
    Assert.isTrue(displays.containsKey(review.Id));
    Assert.areEqual(
      'Step 1: ' +
        UserInfo.getName() +
        '\n' +
        'Step 2: ' +
        UserInfo.getName() +
        ', ' +
        UserInfo.getName() +
        '\n' +
        'Step 3: ' +
        UserInfo.getName() +
        ', ' +
        UserInfo.getName() +
        ', ' +
        UserInfo.getName(),
      plain(displays.get(review.Id).found.copyNodes()),
      'The live fixture must show one clickable Step per line and 1/2/3 comma-separated Users.'
    );
    Assert.areEqual(
      9,
      linkCount(displays.get(review.Id).found.copyNodes()),
      'Three Step links plus six User links must remain independently clickable.'
    );
    Assert.areEqual(
      'Approval state for RHC Link Needs Review',
      plain(displays.get(review.Id).message.copyNodes())
    );
    Assert.areEqual(
      'Review the approval steps in order.',
      plain(displays.get(review.Id).fix.copyNodes())
    );
    Assert.areEqual(
      'Open approval account',
      displays.get(review.Id).action.label
    );
    Assert.areEqual(
      '/lightning/r/Account/' + review.Id + '/view',
      displays.get(review.Id).action.destination
    );
    Assert.areEqual('Required state', displays.get(review.Id).expectedLabel);
    Assert.isFalse(
      displays.containsKey(missing.Id),
      'Missing data must not invent successfully-checked steps.'
    );
  }

  @IsTest
  static void deployedMetadataMatchesTheThreeCheckFixtureContract() {
    List<Record_Health_Check__mdt> checks = [
      SELECT DeveloperName, EvaluationOrder__c, EvaluationType__c
      FROM Record_Health_Check__mdt
      WHERE Record_Health_Check_Set__r.DeveloperName = 'RHC_Link_Conditions'
      ORDER BY EvaluationOrder__c
    ];
    Assert.areEqual(3, checks.size());
    Assert.areEqual('RHC_Link_Metadata', checks[0].DeveloperName);
    Assert.areEqual('QUERY', checks[0].EvaluationType__c);
    Assert.areEqual('RHC_Link_Apex_Legacy', checks[1].DeveloperName);
    Assert.areEqual('RHC_Link_Apex_Structured', checks[2].DeveloperName);
  }

  @IsTest
  static void metadataFixtureUsesVisibleSeparatorsBetweenAdjacentLinks() {
    Record_Health_Check__mdt check = [
      SELECT DisplayFoundText__c
      FROM Record_Health_Check__mdt
      WHERE DeveloperName = 'RHC_Link_Metadata'
      LIMIT 1
    ];

    Assert.isTrue(
      check.DisplayFoundText__c.contains(', {!link label='),
      'Text fields normalize newlines, so adjacent metadata links need an explicit visible separator.'
    );
  }

  private static RecordHealthCheckScope scopeFor(
    List<Id> recordIds,
    String checkName
  ) {
    return new RecordHealthCheckScope(
      'Account',
      recordIds,
      new Map<String, Object>(),
      checkName,
      'RHC_Link_Conditions',
      'url-story-test'
    );
  }

  private static String plain(List<RecordHealthCheckDisplayNode> nodes) {
    String result = '';
    for (RecordHealthCheckDisplayNode node : nodes) {
      result += node.kind == 'break' ? '\n' : node.text;
    }
    return result;
  }

  private static Integer linkCount(List<RecordHealthCheckDisplayNode> nodes) {
    Integer count = 0;
    for (RecordHealthCheckDisplayNode node : nodes) {
      count += node.kind == 'link' ? 1 : 0;
    }
    return count;
  }
}
