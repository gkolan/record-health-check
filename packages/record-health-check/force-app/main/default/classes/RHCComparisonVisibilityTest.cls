@IsTest
private class RHCComparisonVisibilityTest {
  @TestSetup
  static void setup() {
    RecordHealthCheckTestDataFactory.prepareCoverageFixtures();
  }

  /**
   * Scenario N14. The setting decides what the card renders and nothing else,
   * so two Checks that differ only in comparison visibility must evaluate
   * identically. This is the assertion that fails if the setting ever reaches
   * the evaluation path.
   */
  @IsTest
  static void hiddenComparisonLeavesTheEvaluationResultUntouched() {
    Account accountRecord = RecordHealthCheckTestDataFactory.healthyAccountFixture();
    RecordHealthCheckFormulaEvaluator evaluator = new RecordHealthCheckFormulaEvaluator();

    Record_Health_Check__mdt automatic = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'EvaluationType__c' => 'FORMULA',
        'PassConditionFormula__c' => 'ISBLANK(BillingCity)',
        'FormulaResultType__c' => 'TEXT',
        'FailureMessage__c' => 'Billing City is set.',
        'ComparisonDisplayMode__c' => 'AUTOMATIC'
      }
    );
    Record_Health_Check__mdt hidden = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'EvaluationType__c' => 'FORMULA',
        'PassConditionFormula__c' => 'ISBLANK(BillingCity)',
        'FormulaResultType__c' => 'TEXT',
        'FailureMessage__c' => 'Billing City is set.',
        'ComparisonDisplayMode__c' => 'HIDDEN'
      }
    );

    RecordHealthCheckInternalResult shown = evaluator.evaluate(
      automatic,
      accountRecord.Id,
      accountRecord
    );
    RecordHealthCheckInternalResult concealed = evaluator.evaluate(
      hidden,
      accountRecord.Id,
      accountRecord
    );

    Assert.areEqual(
      shown.status,
      concealed.status,
      'Comparison visibility must not change the verdict.'
    );
    Assert.areEqual(
      shown.actualValue,
      concealed.actualValue,
      'Hidden must not erase the Found value from the evaluation result.'
    );
    Assert.areEqual(
      shown.expectedValue,
      concealed.expectedValue,
      'Hidden must not erase the Expected value from the evaluation result.'
    );
    Assert.areEqual(
      shown.message,
      concealed.message,
      'Hidden must not change the failure message.'
    );
  }
  @IsTest
  static void blankAndUnknownValuesResolveToAutomatic() {
    Assert.areEqual(
      RecordHealthCheckComparisonVisibility.AUTOMATIC,
      RecordHealthCheckComparisonVisibility.normalize(null),
      'Blank metadata must keep existing card behavior.'
    );
    Assert.areEqual(
      RecordHealthCheckComparisonVisibility.AUTOMATIC,
      RecordHealthCheckComparisonVisibility.normalize('   '),
      'Whitespace must be treated as blank.'
    );
    Assert.areEqual(
      RecordHealthCheckComparisonVisibility.AUTOMATIC,
      RecordHealthCheckComparisonVisibility.normalize('NOT_A_MODE'),
      'An unrecognized value must degrade to Automatic, never hide evidence.'
    );
  }

  @IsTest
  static void normalizesSupportedValues() {
    Assert.areEqual(
      RecordHealthCheckComparisonVisibility.HIDDEN,
      RecordHealthCheckComparisonVisibility.normalize(' hidden '),
      'Values are compared case-insensitively after trimming.'
    );
    Assert.areEqual(
      RecordHealthCheckComparisonVisibility.FOUND_ONLY,
      RecordHealthCheckComparisonVisibility.normalize('found_only'),
      'Found only must survive normalization.'
    );
    Assert.areEqual(
      RecordHealthCheckComparisonVisibility.EXPECTED_ONLY,
      RecordHealthCheckComparisonVisibility.normalize('EXPECTED_ONLY'),
      'Expected only must survive normalization.'
    );
    Assert.areEqual(
      4,
      RecordHealthCheckComparisonVisibility.supportedModes().size(),
      'Exactly four comparison display modes are supported.'
    );
  }

  @IsTest
  static void reportsUnsupportedValuesOnly() {
    Assert.isFalse(
      RecordHealthCheckComparisonVisibility.isUnsupported(null),
      'Blank is a supported configuration, not an error.'
    );
    Assert.isFalse(
      RecordHealthCheckComparisonVisibility.isUnsupported('AUTOMATIC'),
      'A supported value is not an error.'
    );
    Assert.isTrue(
      RecordHealthCheckComparisonVisibility.isUnsupported('SOMETHING_ELSE'),
      'An unsupported value must be reported to metadata validation.'
    );
  }

  @IsTest
  static void warnsOnlyWhenHiddenLeavesNoExplanation() {
    Record_Health_Check__mdt bare = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'ComparisonDisplayMode__c' => 'HIDDEN',
        'FailureMessage__c' => null,
        'FixMessage__c' => null,
        'ActionUrl__c' => null
      }
    );
    Assert.isTrue(
      RecordHealthCheckComparisonVisibility.hidesEvidenceWithoutGuidance(bare),
      'Hidden with no message, fix, or action leaves a bare failure.'
    );

    Record_Health_Check__mdt explained = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'ComparisonDisplayMode__c' => 'HIDDEN',
        'FailureMessage__c' => 'Add the missing detail record.',
        'FixMessage__c' => null,
        'ActionUrl__c' => null
      }
    );
    Assert.isFalse(
      RecordHealthCheckComparisonVisibility.hidesEvidenceWithoutGuidance(
        explained
      ),
      'A failure message is enough explanation.'
    );

    Record_Health_Check__mdt automatic = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'ComparisonDisplayMode__c' => 'AUTOMATIC',
        'FailureMessage__c' => null,
        'FixMessage__c' => null,
        'ActionUrl__c' => null
      }
    );
    Assert.isFalse(
      RecordHealthCheckComparisonVisibility.hidesEvidenceWithoutGuidance(
        automatic
      ),
      'The warning applies only to Hidden.'
    );
  }

  @IsTest
  static void rejectsHostileAndNearMissValues() {
    for (
      String hostile : new List<String>{
        'HIDDEN; DROP TABLE',
        'HIDDEN,FOUND_ONLY',
        '<script>HIDDEN</script>',
        'HIDDE N',
        'AUTO',
        'FOUND',
        'TRUE'
      }
    ) {
      Assert.isTrue(
        RecordHealthCheckComparisonVisibility.isUnsupported(hostile),
        'A near-miss or hostile value must be reported, not guessed: ' + hostile
      );
      Assert.areEqual(
        RecordHealthCheckComparisonVisibility.AUTOMATIC,
        RecordHealthCheckComparisonVisibility.normalize(hostile),
        'An unsupported value must never resolve to a hiding mode: ' + hostile
      );
    }
  }

  @IsTest
  static void treatsPaddedAndMixedCaseValuesAsConfigured() {
    Assert.areEqual(
      RecordHealthCheckComparisonVisibility.HIDDEN,
      RecordHealthCheckComparisonVisibility.normalize('\n Hidden \t'),
      'Leading and trailing whitespace must not defeat a configured value.'
    );
    Assert.areEqual(
      RecordHealthCheckComparisonVisibility.EXPECTED_ONLY,
      RecordHealthCheckComparisonVisibility.normalize('Expected_Only'),
      'Mixed case must resolve to the configured value.'
    );
  }

  @IsTest
  static void acceptsAnyOneFormOfGuidanceWithHidden() {
    Map<String, Object> onlyFix = new Map<String, Object>{
      'ComparisonDisplayMode__c' => 'HIDDEN',
      'FailureMessage__c' => null,
      'FixMessage__c' => 'Open the run detail and re-run the process.',
      'ActionUrl__c' => null
    };
    Map<String, Object> onlyAction = new Map<String, Object>{
      'ComparisonDisplayMode__c' => 'HIDDEN',
      'FailureMessage__c' => null,
      'FixMessage__c' => null,
      'ActionUrl__c' => '/lightning/o/Account/list'
    };
    for (
      Map<String, Object> overrides : new List<Map<String, Object>>{
        onlyFix,
        onlyAction
      }
    ) {
      Assert.isFalse(
        RecordHealthCheckComparisonVisibility.hidesEvidenceWithoutGuidance(
          RecordHealthCheckTestDataFactory.check(overrides)
        ),
        'One form of guidance is enough to explain a hidden failure.'
      );
    }
  }

  @IsTest
  static void warnsWhenGuidanceIsOnlyWhitespace() {
    Assert.isTrue(
      RecordHealthCheckComparisonVisibility.hidesEvidenceWithoutGuidance(
        RecordHealthCheckTestDataFactory.check(
          new Map<String, Object>{
            'ComparisonDisplayMode__c' => 'HIDDEN',
            'FailureMessage__c' => '   ',
            'FixMessage__c' => '',
            'ActionUrl__c' => null
          }
        )
      ),
      'Whitespace is not an explanation the user can read.'
    );
  }

  @IsTest
  static void supportedModesAreImmutableToCallers() {
    Set<String> modes = RecordHealthCheckComparisonVisibility.supportedModes();
    modes.add('SOMETHING_ELSE');
    Assert.areEqual(
      4,
      RecordHealthCheckComparisonVisibility.supportedModes().size(),
      'A caller must not be able to widen the supported modes.'
    );
  }

  /**
   * Scenarios P5 and P6. Found only and Expected only are card instructions,
   * not evaluation instructions: the machine result keeps the side the card
   * declines to render, so integrations and dependencies are unaffected.
   */
  @IsTest
  static void singleSidedModesLeaveTheEvaluationResultUntouched() {
    Account accountRecord = RecordHealthCheckTestDataFactory.healthyAccountFixture();
    RecordHealthCheckFormulaEvaluator evaluator = new RecordHealthCheckFormulaEvaluator();
    RecordHealthCheckInternalResult baseline = evaluator.evaluate(
      formulaCheck('AUTOMATIC', null),
      accountRecord.Id,
      accountRecord
    );

    for (String mode : new List<String>{ 'FOUND_ONLY', 'EXPECTED_ONLY' }) {
      RecordHealthCheckInternalResult sided = evaluator.evaluate(
        formulaCheck(mode, null),
        accountRecord.Id,
        accountRecord
      );
      Assert.areEqual(
        baseline.status,
        sided.status,
        mode + ' must not change the verdict.'
      );
      Assert.areEqual(
        baseline.actualValue,
        sided.actualValue,
        mode + ' must preserve the Found value in the machine result.'
      );
      Assert.areEqual(
        baseline.expectedValue,
        sided.expectedValue,
        mode + ' must preserve the Expected value in the machine result.'
      );
    }
  }

  /**
   * Scenario E12. Display: Found Text keeps resolving under Expected only, so
   * switching the mode back to Automatic restores the authored phrase without
   * the administrator having to retype it.
   */
  @IsTest
  static void displayTextStillResolvesUnderASingleSidedMode() {
    Account accountRecord = RecordHealthCheckTestDataFactory.healthyAccountFixture();
    RecordHealthCheckFormulaEvaluator evaluator = new RecordHealthCheckFormulaEvaluator();

    RecordHealthCheckInternalResult concealed = evaluator.evaluate(
      formulaCheck('EXPECTED_ONLY', '{!record.Name} was reviewed'),
      accountRecord.Id,
      accountRecord
    );
    RecordHealthCheckInternalResult shown = evaluator.evaluate(
      formulaCheck('AUTOMATIC', '{!record.Name} was reviewed'),
      accountRecord.Id,
      accountRecord
    );

    Assert.areEqual(
      shown.actualValue,
      concealed.actualValue,
      'Display: Found Text must resolve identically whatever the card shows.'
    );
    Assert.isTrue(
      String.isNotBlank(concealed.actualValue),
      'The authored Found phrase must survive Expected only.'
    );
  }

  /**
   * Scenario W14. Hidden is presentation, not concealment: an entitled
   * administrator reading diagnostics still sees both values.
   */
  @IsTest
  static void hiddenComparisonStillReachesEntitledDiagnostics() {
    Account accountRecord = RecordHealthCheckTestDataFactory.healthyAccountFixture();
    Record_Health_Check__mdt check = formulaCheck('HIDDEN', null);
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.status = 'FAIL';
    result.actualValue = 'found-value';
    result.expectedValue = 'expected-value';
    RecordHealthCheckAdminDetail detail = new RecordHealthCheckAdminDetail();

    Test.startTest();
    RecordHealthCheckDiagnosticTrace.populate(
      check,
      accountRecord,
      result,
      detail
    );
    Test.stopTest();

    Assert.isTrue(
      detail.resolutionJson.contains('found-value'),
      'Authorized diagnostics must still report the Found value.'
    );
    Assert.isTrue(
      detail.resolutionJson.contains('expected-value'),
      'Authorized diagnostics must still report the Expected value.'
    );
  }

  private static Record_Health_Check__mdt formulaCheck(
    String mode,
    String displayFoundText
  ) {
    return RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'EvaluationType__c' => 'FORMULA',
        'PassConditionFormula__c' => 'ISBLANK(BillingCity)',
        'FormulaResultType__c' => 'TEXT',
        'FailureMessage__c' => 'Billing City is set.',
        'DisplayFoundText__c' => displayFoundText,
        'ComparisonDisplayMode__c' => mode
      }
    );
  }
}
