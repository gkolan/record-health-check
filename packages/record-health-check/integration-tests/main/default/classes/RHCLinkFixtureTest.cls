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
    Assert.areEqual(
      'PASS',
      legacy.get(healthy.Id).status,
      'The healthy legacy fixture must pass.'
    );
    Assert.areEqual(
      'FAIL',
      legacy.get(review.Id).status,
      'The review legacy fixture must fail.'
    );
    Assert.areEqual(
      'Step 1 - Payment Term Approvals\nStep 2 - Finance Approval',
      legacy.get(review.Id).found.storedValue,
      'Legacy text keeps real LF and is never reparsed as structured content.'
    );
    Assert.areEqual(
      'UNABLE_TO_EVALUATE',
      legacy.get(missing.Id).status,
      'The missing-data legacy fixture must be unable to evaluate.'
    );

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
    Assert.areEqual(
      'PASS',
      outcomes.get(healthy.Id).status,
      'The healthy structured fixture must pass.'
    );
    Assert.areEqual(
      'FAIL',
      outcomes.get(review.Id).status,
      'The review structured fixture must fail.'
    );
    Assert.areEqual(
      'UNABLE_TO_EVALUATE',
      outcomes.get(missing.Id).status,
      'The missing-data structured fixture must be unable to evaluate.'
    );
    Assert.isTrue(
      displays.containsKey(healthy.Id),
      'The healthy result must have structured display.'
    );
    Assert.isTrue(
      displays.containsKey(review.Id),
      'The review result must have structured display.'
    );
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
      plain(displays.get(review.Id).message.copyNodes()),
      'The review message must identify the fixture account.'
    );
    Assert.areEqual(
      'Review the approval steps in order.',
      plain(displays.get(review.Id).fix.copyNodes()),
      'The review fix must explain the step order.'
    );
    Assert.areEqual(
      'Open approval account',
      displays.get(review.Id).action.label,
      'The review action must retain its label.'
    );
    Assert.areEqual(
      '/lightning/r/Account/' + review.Id + '/view',
      displays.get(review.Id).action.destination,
      'The review action must target the fixture account.'
    );
    Assert.areEqual(
      'Required state',
      displays.get(review.Id).expectedLabel,
      'The structured expected label must retain its text.'
    );
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
    Assert.areEqual(
      3,
      checks.size(),
      'The deployed Check Set must contain exactly three Checks.'
    );
    Assert.areEqual(
      'RHC_Link_Metadata',
      checks[0].DeveloperName,
      'The metadata Check must run first.'
    );
    Assert.areEqual(
      'QUERY',
      checks[0].EvaluationType__c,
      'The metadata Check must use QUERY evaluation.'
    );
    Assert.areEqual(
      'RHC_Link_Apex_Legacy',
      checks[1].DeveloperName,
      'The legacy Apex Check must run second.'
    );
    Assert.areEqual(
      'RHC_Link_Apex_Structured',
      checks[2].DeveloperName,
      'The structured Apex Check must run third.'
    );
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

  @IsTest
  static void numericHostFallbackPreservesFixtureVerdicts() {
    Account healthy = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Name' => 'RHC Link Healthy Numeric Host',
        'Site' => 'RHC_LINK_FIXTURE',
        'NumberOfEmployees' => 0,
        'Website' => 'https://2147483648.1.1.1/path'
      }
    );
    Account review = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Name' => 'RHC Link Numeric Host',
        'Site' => 'RHC_LINK_FIXTURE',
        'NumberOfEmployees' => 1,
        'Website' => 'https://2147483648.1.1.1/path'
      }
    );
    RHCIntegrationTestDataFactory.createAccounts(
      new List<Account>{ healthy, review }
    );
    RecordHealthCheckAccess.setRunPermissionForTest(true);
    RecordHealthCheckResponse response;
    try {
      Test.startTest();
      response = RecordHealthCheckSandboxRunner.runCheckSet(
        RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
          'RHC_Link_Conditions'
        ),
        new List<Id>{ healthy.Id, review.Id },
        'numeric-host-regression'
      );
      Test.stopTest();
    } finally {
      RecordHealthCheckAccess.setRunPermissionForTest(null);
    }
    Assert.areEqual(
      6,
      response.results.size(),
      'All three fixture Checks must return both records.'
    );
    Integer guides = 0;
    for (RecordHealthCheckResultItem item : response.results) {
      Assert.areEqual(
        item.evaluation.recordId == healthy.Id ? 'PASS' : 'FAIL',
        item.evaluation.status,
        'An invalid destination must preserve the business verdict.'
      );
      if (item.evaluation.checkQualifiedApiName.endsWith('RHC_Link_Metadata')) {
        Assert.isNotNull(
          item.display.displayContent,
          'Metadata display must retain its structured content.'
        );
        for (
          RecordHealthCheckDisplayNode node : item.display.displayContent.found
        ) {
          // Plain fallback may coalesce with the preceding separator text.
          if (node.text != null && node.text.contains('Approval guide')) {
            guides++;
            Assert.areEqual(
              'text',
              node.kind,
              'An overflowing host must downgrade the guide to plain text.'
            );
            Assert.isNull(
              node.href,
              'The fallback guide must not retain a destination.'
            );
          }
        }
      }
    }
    Assert.areEqual(
      2,
      guides,
      'Both PASS and FAIL metadata displays must retain the guide label.'
    );
  }
  @IsTest
  static void savedMissingBraceIsRejectedAndRecovers() {
    Record_Health_Check__mdt malformed = Record_Health_Check__mdt.getInstance(
      'RHC_Link_Grammar_Open'
    );
    Record_Health_Check__mdt valid = Record_Health_Check__mdt.getInstance(
      'RHC_Link_Grammar_Valid'
    );
    Assert.isNotNull(
      malformed,
      'The unclosed-link administrator fixture must exist.'
    );
    Assert.isNotNull(valid, 'The valid-link administrator fixture must exist.');
    RecordHealthCheckMetadataValidator validator = new RecordHealthCheckMetadataValidator();
    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = validator.validateCheck(
      malformed
    );
    Assert.areEqual(
      1,
      issues.size(),
      'The unclosed fixture must have one structural issue.'
    );
    Assert.areEqual(
      'INLINE_LINK_MALFORMED',
      issues[0].reasonCode,
      'Saved configuration must reject the missing final brace.'
    );
    Assert.isTrue(
      validator.validateCheck(valid).isEmpty(),
      'The paired closed-link fixture must validate.'
    );
    Record_Health_Check__mdt repaired = malformed.clone(
      false,
      true,
      false,
      false
    );
    repaired.FailureMessage__c += '}';
    Assert.isTrue(
      validator.validateCheck(repaired).isEmpty(),
      'Restoring exactly the final brace must recover validation.'
    );
  }
  @IsTest
  static void missingBraceStopsBothHealthyAndFailingRecords() {
    Account healthy = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Name' => 'RHC Link Grammar Healthy',
        'Site' => 'RHC_LINK_FIXTURE',
        'NumberOfEmployees' => 0,
        'Website' => 'https://example.com/approvals'
      }
    );
    Account review = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Name' => 'RHC Link Grammar Review',
        'Site' => 'RHC_LINK_FIXTURE',
        'NumberOfEmployees' => 1,
        'Website' => 'https://example.com/approvals'
      }
    );
    RHCIntegrationTestDataFactory.createAccounts(
      new List<Account>{ healthy, review }
    );
    RecordHealthCheckAccess.setRunPermissionForTest(true);
    RecordHealthCheckResponse response;
    try {
      Test.startTest();
      response = RecordHealthCheckSandboxRunner.runCheckSet(
        RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
          'RHC_Link_Grammar'
        ),
        new List<Id>{ healthy.Id, review.Id },
        'link-grammar-regression'
      );
      Test.stopTest();
    } finally {
      RecordHealthCheckAccess.setRunPermissionForTest(null);
    }
    Assert.areEqual(
      4,
      response.results.size(),
      'Both saved Checks must return both records.'
    );
    Integer malformedCount = 0;
    Integer validCount = 0;
    for (RecordHealthCheckResultItem item : response.results) {
      if (
        item.evaluation.checkQualifiedApiName.endsWith('RHC_Link_Grammar_Open')
      ) {
        malformedCount++;
        Assert.areEqual(
          'UNABLE_TO_EVALUATE',
          item.evaluation.status,
          'Malformed display configuration must stop evaluation for either business outcome.'
        );
        Assert.areEqual(
          'INVALID_CONFIG',
          item.evaluation.reasonCode,
          'Runtime must retain its configuration-error contract.'
        );
      } else {
        validCount++;
        Assert.isTrue(
          item.evaluation.checkQualifiedApiName.endsWith(
            'RHC_Link_Grammar_Valid'
          ),
          'Only the paired valid Check may supply business results.'
        );
        Assert.areEqual(
          item.evaluation.recordId == healthy.Id ? 'PASS' : 'FAIL',
          item.evaluation.status,
          'The closed-link partner must preserve the employee-count business verdict.'
        );
      }
    }
    Assert.areEqual(
      2,
      malformedCount,
      'Both records must exercise malformed configuration.'
    );
    Assert.areEqual(
      2,
      validCount,
      'Both records must exercise valid configuration.'
    );
  }
}
