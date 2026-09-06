/**
 * Display formulas are typed independently of the pass condition.
 *
 * `FormulaResultType__c` declares what the pass condition returns, and a pass
 * condition must return a Boolean. Display: Found Formula and Display: Expected
 * Formula return whatever the author wants to show, usually text. One picklist
 * used to govern both, so declaring the correct type for the pass condition
 * silently blanked the display value: the failure was logged at WARN, swallowed,
 * and the Check reported PASS with an empty Found chip.
 */
@IsTest
private with sharing class RHCFormulaDisplayTypeIT {
  static {
    RecordHealthCheckAccess.setRunPermissionForTest(true);
  }

  private static Account industryAccount() {
    Account record = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Name' => 'Formula Display Type',
        'Industry' => 'Technology'
      }
    );
    RHCIntegrationTestDataFactory.createAccounts(new List<Account>{ record });
    return [SELECT Id, Name, Industry FROM Account WHERE Id = :record.Id];
  }

  private static Record_Health_Check__mdt checkWithDeclaredType(
    String declaredType
  ) {
    return new Record_Health_Check__mdt(
      DeveloperName = 'FormulaDisplayType',
      EvaluationType__c = 'FORMULA',
      PassConditionFormula__c = 'NOT(ISBLANK(TEXT(Industry)))',
      FormulaResultType__c = declaredType,
      DisplayFoundFormula__c = 'Industry',
      FailureSeverity__c = 'WARNING',
      FailureMessage__c = 'No industry.'
    );
  }

  @IsTest
  static void aTextDisplayFormulaSurvivesABooleanPassCondition() {
    Account record = industryAccount();

    Test.startTest();
    RecordHealthCheckInternalResult declared = new RecordHealthCheckFormulaEvaluator()
      .evaluate(checkWithDeclaredType('BOOLEAN'), record.Id, record);
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckStatus.PASS,
      declared.status,
      'The pass condition is a Boolean and evaluates normally.'
    );
    Assert.areEqual(
      'Technology',
      declared.actualValue,
      'And the display formula still shows its text, because the declared ' +
        'type belongs to the pass condition rather than to everything typed ' +
        'near it.'
    );
  }

  @IsTest
  static void everyDeclaredTypeGivesTheSameDisplayValue() {
    Account record = industryAccount();
    Map<String, String> found = new Map<String, String>();

    Test.startTest();
    for (String declaredType : new List<String>{ 'AUTO', 'BOOLEAN', 'TEXT' }) {
      found.put(
        declaredType,
        new RecordHealthCheckFormulaEvaluator()
          .evaluate(checkWithDeclaredType(declaredType), record.Id, record)
          .actualValue
      );
    }
    Test.stopTest();

    Assert.areEqual(
      'Technology',
      found.get('AUTO'),
      'Auto probes the type and reads the text.'
    );
    Assert.areEqual(
      found.get('AUTO'),
      found.get('BOOLEAN'),
      'Declaring the pass condition Boolean must not change what is displayed.'
    );
    Assert.areEqual(
      found.get('AUTO'),
      found.get('TEXT'),
      'Nor must declaring it Text.'
    );
  }

  /**
   * Comparison visibility is presentation, and only presentation.
   *
   * The setting decides what the card may render. Every other reader - the
   * evaluation result an automation receives, the merge tokens, the API - keeps
   * both values. Three deployed Checks with the same formula and different
   * settings are the only way to prove that against configuration Salesforce
   * actually stored, rather than against a metadata row built in memory.
   */
  @IsTest
  static void everyComparisonVisibilityModeReachesTheCardAndChangesNothingElse() {
    Account record = industryAccount();
    Map<String, String> expectedMode = new Map<String, String>{
      'Account_FormulaType_FoundOnly' => 'FOUND_ONLY',
      'Account_FormulaType_ExpectedOnly' => 'EXPECTED_ONLY',
      'Account_FormulaType_Hidden' => 'HIDDEN',
      'Account_FormulaType_BooleanDeclared' => 'AUTOMATIC'
    };
    String checkSetName = RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
      'Account_Formula_Display_Types'
    );

    Test.startTest();
    RecordHealthCheckDefinitionResponse definitions = RecordHealthCheckController.getCheckDefinitions(
      checkSetName,
      record.Id,
      'visibility-run'
    );
    RecordHealthCheckResponse evaluated = RecordHealthCheck.evaluate(
      RecordHealthCheckRequest.forCheckSet(
          checkSetName,
          new List<Id>{ record.Id }
        )
        .withResultMode(RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY)
    );
    Test.stopTest();

    Map<String, String> actualMode = new Map<String, String>();
    for (RecordHealthCheckDefinition definition : definitions.checks) {
      actualMode.put(
        definition.developerName,
        definition.comparisonDisplayMode
      );
    }
    for (String developerName : expectedMode.keySet()) {
      Assert.areEqual(
        expectedMode.get(developerName),
        actualMode.get(developerName),
        developerName +
          ' carries its configured setting to the card, unchanged by the ' +
          'settings on its neighbours.'
      );
    }

    // The three visibility Checks share one formula, so anything that differs
    // between their results came from the setting - which is exactly what the
    // setting is not allowed to do.
    Map<String, RecordHealthCheckResultItem> byCheck = new Map<String, RecordHealthCheckResultItem>();
    for (RecordHealthCheckResultItem item : evaluated.results) {
      for (String developerName : expectedMode.keySet()) {
        if (
          item.evaluation.checkQualifiedApiName?.endsWith(developerName) == true
        ) {
          byCheck.put(developerName, item);
        }
      }
    }
    RecordHealthCheckResultItem shown = byCheck.get(
      'Account_FormulaType_FoundOnly'
    );
    for (
      String developerName : new List<String>{
        'Account_FormulaType_ExpectedOnly',
        'Account_FormulaType_Hidden'
      }
    ) {
      RecordHealthCheckResultItem other = byCheck.get(developerName);
      Assert.areEqual(
        shown.evaluation.status,
        other.evaluation.status,
        developerName + ' reaches the same verdict.'
      );
      Assert.areEqual(
        shown.evaluation.found?.storedValue,
        other.evaluation.found?.storedValue,
        developerName + ' still reports what it found to every caller.'
      );
      Assert.areEqual(
        shown.evaluation.expected?.storedValue,
        other.evaluation.expected?.storedValue,
        developerName + ' still reports what it expected to every caller.'
      );
      Assert.areEqual(
        shown.display?.renderedMessage,
        other.display?.renderedMessage,
        developerName + ' still says the same thing to the reader.'
      );
    }
  }
}
