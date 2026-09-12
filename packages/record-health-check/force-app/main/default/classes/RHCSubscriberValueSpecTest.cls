/** Regression-first acceptance tests for the typed plugin value contract. */
@IsTest
private class RHCSubscriberValueSpecTest {
  @IsTest
  static void emptyListIsPresent() {
    RecordHealthCheckInternalResult result = evaluate('EMPTY_LIST');

    Assert.areEqual(
      RecordHealthCheckStatus.PASS,
      result.status,
      'An empty LIST is a present typed value, not missing plugin output.'
    );
    Assert.areEqual(
      'LIST',
      result.evaluationFound.dataType,
      'Empty Found values must retain their declared LIST type.'
    );
    Assert.areEqual(
      0,
      result.evaluationFound.storedValues.size(),
      'An empty Found list must remain present with zero members.'
    );
    Assert.areEqual(
      'LIST',
      result.evaluationExpected.dataType,
      'Empty Expected values must retain their declared LIST type.'
    );
    Assert.areEqual(
      0,
      result.evaluationExpected.storedValues.size(),
      'An empty Expected list must remain present with zero members.'
    );
    Assert.areEqual(
      '0 items',
      result.actualValue,
      'An empty Found list must render its meaningful zero-item fallback.'
    );
    Assert.areEqual(
      '0 items',
      result.expectedValue,
      'An empty Expected list must render its meaningful zero-item fallback.'
    );
  }

  @IsTest
  static void falseAndZeroArePresent() {
    RecordHealthCheckInternalResult falseResult = evaluate('FALSE');
    RecordHealthCheckInternalResult zeroResult = evaluate('ZERO');

    Assert.areEqual(
      RecordHealthCheckStatus.PASS,
      falseResult.status,
      'Boolean false must count as a present operand and remain evaluable.'
    );
    Assert.areEqual(
      'false',
      falseResult.actualValue,
      'Found false must render explicitly rather than disappear as empty.'
    );
    Assert.areEqual(
      'false',
      falseResult.expectedValue,
      'Expected false must render explicitly rather than disappear as empty.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.PASS,
      zeroResult.status,
      'Numeric zero must count as a present operand and remain evaluable.'
    );
    Assert.areEqual(
      '0',
      zeroResult.actualValue,
      'Found zero must render explicitly rather than disappear as empty.'
    );
    Assert.areEqual(
      '0',
      zeroResult.expectedValue,
      'Expected zero must render explicitly rather than disappear as empty.'
    );
  }

  @IsTest
  static void missingSidesAreDistinct() {
    RecordHealthCheckInternalResult missingFound = evaluate('MISSING_FOUND');
    RecordHealthCheckInternalResult missingExpected = evaluate(
      'MISSING_EXPECTED'
    );

    assertMissing(
      missingFound,
      'Found',
      'A PASS outcome must include a nonblank Found value.'
    );
    assertMissing(
      missingExpected,
      'Expected',
      'A PASS outcome must include a nonblank Expected value.'
    );
  }

  @IsTest
  static void validatorUsesStablePrecedence() {
    String longReason = '';
    while (longReason.length() < 81) {
      longReason += 'R';
    }
    RecordHealthCheckOutcome invalid = (RecordHealthCheckOutcome) JSON.deserialize(
      '{"status":"NOT_REAL","reasonCode":"' + longReason + '"}',
      RecordHealthCheckOutcome.class
    );

    List<RecordHealthCheckOutcomeValidator.Violation> statusViolations = RecordHealthCheckOutcomeValidator.validate(
      invalid
    );

    Assert.areEqual(
      2,
      statusViolations.size(),
      'Invalid status and reason must produce both ordered validation findings.'
    );
    Assert.areEqual(
      RecordHealthCheckReasonCodes.PLUGIN_STATUS_INVALID,
      statusViolations[0].reasonCode,
      'Status validation must take precedence over reason validation.'
    );
    Assert.areEqual(
      RecordHealthCheckReasonCodes.PLUGIN_REASON_CODE_INVALID,
      statusViolations[1].reasonCode,
      'Invalid reason must follow the invalid-status finding.'
    );

    RecordHealthCheckOutcome missing = (RecordHealthCheckOutcome) JSON.deserialize(
      '{"status":"PASS","reasonCode":"' + longReason + '"}',
      RecordHealthCheckOutcome.class
    );
    List<RecordHealthCheckOutcomeValidator.Violation> valueViolations = RecordHealthCheckOutcomeValidator.validate(
      missing
    );
    Assert.areEqual(
      3,
      valueViolations.size(),
      'A long reason and both missing operands must produce three findings.'
    );
    Assert.areEqual(
      RecordHealthCheckReasonCodes.PLUGIN_REASON_CODE_INVALID,
      valueViolations[0].reasonCode,
      'Reason validation must precede missing-operand findings.'
    );
    Assert.areEqual(
      'Found',
      valueViolations[1].side,
      'Missing Found must precede missing Expected in the validation order.'
    );
    Assert.areEqual(
      'Expected',
      valueViolations[2].side,
      'Missing Expected must follow missing Found in the validation order.'
    );
  }

  @IsTest
  static void equalityBuildersRejectContradiction() {
    RecordHealthCheckOutcome passing = RecordHealthCheckOutcome.passEquals(
      'APEX_PASS',
      RecordHealthCheckValue.ofNumber(1),
      RecordHealthCheckValue.ofNumber(1)
    );
    RecordHealthCheckOutcome failing = RecordHealthCheckOutcome.failEquals(
      'APEX_FAIL',
      RecordHealthCheckValue.ofNumber(1),
      RecordHealthCheckValue.ofNumber(2)
    );
    Assert.areEqual(
      RecordHealthCheckStatus.PASS,
      passing.status,
      'Equal typed operands must support a passing equality outcome.'
    );
    Assert.areEqual(
      'EQUALS',
      passing.comparisonOperator,
      'The passing equality builder must retain its comparison operator.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.FAIL,
      failing.status,
      'Unequal typed operands must support a failing equality outcome.'
    );
    Assert.areEqual(
      'EQUALS',
      failing.comparisonOperator,
      'The failing equality builder must retain its comparison operator.'
    );

    assertBuilderFailure('PASS_MISMATCH', 'BUILDER_VERDICT_MISMATCH');
    assertBuilderFailure('FAIL_MATCH', 'BUILDER_VERDICT_MISMATCH');
    assertBuilderFailure('TYPE_MISMATCH', 'INVALID_BUILDER_VALUES');
    assertBuilderFailure('NULL_OPERAND', 'INVALID_BUILDER_VALUES');
    assertBuilderFailure('BLANK_REASON', 'INVALID_BUILDER_REASON');
  }

  @IsTest
  static void itemsAndNoneTransition() {
    RecordHealthCheckOutcome none = RecordHealthCheckOutcome.noneFound(
      'APEX_PASS'
    );
    RecordHealthCheckOutcome some = RecordHealthCheckOutcome.itemsFound(
      'APEX_FAIL',
      new List<String>{ 'website' }
    );
    RecordHealthCheckOutcome noneAgain = RecordHealthCheckOutcome.noneFound(
      'APEX_PASS'
    );

    Assert.areEqual(
      RecordHealthCheckStatus.PASS,
      none.status,
      'No found items must produce a passing outcome.'
    );
    Assert.areEqual(
      0,
      none.found.storedValues.size(),
      'The no-items outcome must retain an empty Found list.'
    );
    Assert.areEqual(
      0,
      none.expected.storedValues.size(),
      'The no-items outcome must retain an empty Expected list.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.FAIL,
      some.status,
      'A found item must transition the outcome to failing.'
    );
    Assert.areEqual(
      new List<String>{ 'website' },
      some.found.storedValues,
      'The failing item outcome must preserve the supplied item identity.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.PASS,
      noneAgain.status,
      'A later no-items outcome must return to passing without stale state.'
    );
  }

  @IsTest
  static void builderCopiesInput() {
    List<String> input = new List<String>{ 'A' };
    RecordHealthCheckOutcome outcome = RecordHealthCheckOutcome.itemsFound(
      'APEX_FAIL',
      input
    );
    input[0] = 'B';

    Assert.areEqual(
      new List<String>{ 'A' },
      outcome.found.storedValues,
      'Mutating the caller list must not change the outcome snapshot.'
    );
    assertBuilderFailure('NULL_ITEMS', 'INVALID_BUILDER_VALUES');
    assertBuilderFailure('EMPTY_ITEMS', 'INVALID_BUILDER_VALUES');
  }

  private static RecordHealthCheckInternalResult evaluate(String mode) {
    RecordHealthCheckDiagModeTestPlugin.mode = mode;
    Account record = RecordHealthCheckTestDataFactory.accountFixture(
      'SP-V-' + mode
    );
    return new RecordHealthCheckApexEvaluator()
      .evaluate(check(), record.Id, record);
  }

  private static void assertMissing(
    RecordHealthCheckInternalResult result,
    String side,
    String expectedMessage
  ) {
    Assert.areEqual(
      RecordHealthCheckStatus.ERROR,
      result.status,
      'Missing required operands must become a plugin contract error.'
    );
    Assert.areEqual(
      RecordHealthCheckReasonCodes.PLUGIN_VALUES_MISSING,
      result.reasonCode,
      'Missing operands must expose the stable plugin-values-missing reason.'
    );
    Assert.areEqual(
      expectedMessage,
      result.detailMessage,
      'The missing-value explanation must distinguish Found from Expected.'
    );
    Assert.isTrue(
      result.detailMessage.contains(side),
      'The explanation must name the specific missing operand side.'
    );
    Assert.areEqual(
      side,
      result.diagnosticIncident.valueSide,
      'The diagnostic incident must identify the missing operand side.'
    );
    Assert.isNull(
      result.diagnosticIncident.valueDeclaredType,
      'An absent operand must not invent a declared type in diagnostics.'
    );
    Assert.isNull(
      result.diagnosticIncident.valueMemberCount,
      'An absent operand must not invent a member count in diagnostics.'
    );
    Assert.areEqual(
      true,
      result.diagnosticIncident.valueRenderedBlank,
      'An absent operand must be diagnosed as rendering blank.'
    );
  }

  private static Record_Health_Check__mdt check() {
    return RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'RHC_SP_Value_Items',
        'QualifiedApiName' => 'RHC_SP_Value_Items',
        'CheckTitle__c' => 'Typed plugin values',
        'EvaluationType__c' => 'APEX',
        'ApexClass__c' => 'RecordHealthCheckDiagModeTestPlugin',
        'ApexParametersJson__c' => '{}',
        'UnableToEvaluateMessage__c' => 'This check could not be evaluated.'
      }
    );
  }

  private static void assertBuilderFailure(String mode, String expectedCode) {
    Boolean failed = false;
    try {
      if (mode == 'PASS_MISMATCH') {
        RecordHealthCheckOutcome.passEquals(
          'R',
          RecordHealthCheckValue.ofString('A'),
          RecordHealthCheckValue.ofString('B')
        );
      } else if (mode == 'FAIL_MATCH') {
        RecordHealthCheckOutcome.failEquals(
          'R',
          RecordHealthCheckValue.ofString('A'),
          RecordHealthCheckValue.ofString('A')
        );
      } else if (mode == 'TYPE_MISMATCH') {
        RecordHealthCheckOutcome.passEquals(
          'R',
          RecordHealthCheckValue.ofString('1'),
          RecordHealthCheckValue.ofNumber(1)
        );
      } else if (mode == 'NULL_OPERAND') {
        RecordHealthCheckOutcome.passEquals(
          'R',
          null,
          RecordHealthCheckValue.ofString('A')
        );
      } else if (mode == 'BLANK_REASON') {
        RecordHealthCheckOutcome.passEquals(
          ' ',
          RecordHealthCheckValue.ofString('A'),
          RecordHealthCheckValue.ofString('A')
        );
      } else if (mode == 'NULL_ITEMS') {
        RecordHealthCheckOutcome.itemsFound('R', null);
      } else if (mode == 'EMPTY_ITEMS') {
        RecordHealthCheckOutcome.itemsFound('R', new List<String>());
      }
    } catch (RecordHealthCheckOutcomeBuilderException error) {
      failed = true;
      Assert.areEqual(
        expectedCode,
        error.getMessage(),
        'Invalid builder input must produce its specific stable contract error.'
      );
    }
    Assert.isTrue(failed, 'Expected builder rejection for ' + mode + '.');
  }
}
