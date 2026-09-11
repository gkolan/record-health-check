/** Regression-first acceptance tests for the typed plugin value contract. */
@IsTest
private class RHCSubscriberValueSpecTest {
  private static Integer pluginCalls = 0;
  private static Id foreignId;
  @IsTest
  static void emptyListIsPresent() {
    RecordHealthCheckInternalResult result = evaluate('EMPTY_LIST');

    Assert.areEqual(
      RecordHealthCheckStatus.PASS,
      result.status,
      'An empty LIST is a present typed value, not missing plugin output.'
    );
    Assert.areEqual('LIST', result.evaluationFound.dataType);
    Assert.areEqual(0, result.evaluationFound.storedValues.size());
    Assert.areEqual('LIST', result.evaluationExpected.dataType);
    Assert.areEqual(0, result.evaluationExpected.storedValues.size());
    Assert.areEqual('0 items', result.actualValue);
    Assert.areEqual('0 items', result.expectedValue);
  }

  @IsTest
  static void falseAndZeroArePresent() {
    RecordHealthCheckInternalResult falseResult = evaluate('FALSE');
    RecordHealthCheckInternalResult zeroResult = evaluate('ZERO');

    Assert.areEqual(RecordHealthCheckStatus.PASS, falseResult.status);
    Assert.areEqual('false', falseResult.actualValue);
    Assert.areEqual('false', falseResult.expectedValue);
    Assert.areEqual(RecordHealthCheckStatus.PASS, zeroResult.status);
    Assert.areEqual('0', zeroResult.actualValue);
    Assert.areEqual('0', zeroResult.expectedValue);
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

    Assert.areEqual(2, statusViolations.size());
    Assert.areEqual(
      RecordHealthCheckReasonCodes.PLUGIN_STATUS_INVALID,
      statusViolations[0].reasonCode
    );
    Assert.areEqual(
      RecordHealthCheckReasonCodes.PLUGIN_REASON_CODE_INVALID,
      statusViolations[1].reasonCode
    );

    RecordHealthCheckOutcome missing = (RecordHealthCheckOutcome) JSON.deserialize(
      '{"status":"PASS","reasonCode":"' + longReason + '"}',
      RecordHealthCheckOutcome.class
    );
    List<RecordHealthCheckOutcomeValidator.Violation> valueViolations = RecordHealthCheckOutcomeValidator.validate(
      missing
    );
    Assert.areEqual(3, valueViolations.size());
    Assert.areEqual(
      RecordHealthCheckReasonCodes.PLUGIN_REASON_CODE_INVALID,
      valueViolations[0].reasonCode
    );
    Assert.areEqual('Found', valueViolations[1].side);
    Assert.areEqual('Expected', valueViolations[2].side);
  }

  @IsTest
  static void rawMissingKeyFailsHelper() {
    RecordHealthCheckScope scope = scope(2);
    Boolean failed = false;
    try {
      RecordHealthCheckPluginTest.verify(new MissingKeyPlugin(), scope)
        .assertComplete();
    } catch (Exception error) {
      failed = true;
      Assert.isTrue(error.getMessage().contains('missing'));
    }
    Assert.isTrue(
      failed,
      'The helper must inspect the raw map before dispatcher completion adds an ERROR outcome.'
    );

    assertCompletenessFailure(new NullMapPlugin(), scope, 'MISSING');
    foreignId = RecordHealthCheckTestDataFactory.accountFixture(
        'SP-V-Foreign-Key'
      )
      .Id;
    assertCompletenessFailure(new UnknownKeyPlugin(), scope, 'UNKNOWN_KEY');
  }

  @IsTest
  static void helperEvaluatesOnce() {
    pluginCalls = 0;
    RecordHealthCheckPluginVerification verification = RecordHealthCheckPluginTest.verify(
      new CountingValidPlugin(),
      scope(2)
    );
    verification
      .assertComplete()
      .assertNoSideEffects()
      .assertRenderable()
      .assertRenderable();
    Assert.areEqual(1, pluginCalls);
  }

  @IsTest
  static void helperRejectsMissingValueButAcceptsTypedControls() {
    Boolean failed = false;
    try {
      RecordHealthCheckPluginTest.verify(new MissingExpectedPlugin(), scope(1))
        .assertRenderable();
    } catch (Exception error) {
      failed = true;
      Assert.isTrue(
        error.getMessage().contains('PLUGIN_VALUES_MISSING') ||
        error.getMessage().contains('Expected')
      );
    }
    Assert.isTrue(failed, 'A PASS without Expected must fail renderability.');

    RecordHealthCheckPluginTest.verify(new EmptyListPlugin(), scope(1))
      .assertComplete()
      .assertRenderable();
    RecordHealthCheckPluginTest.verify(new FalsePlugin(), scope(1))
      .assertComplete()
      .assertRenderable();
  }

  @IsTest
  static void helperDetectsSideEffects() {
    Boolean fatalEscaped = false;
    try {
      RecordHealthCheckPluginTest.verify(new DmlThenThrowPlugin(), scope(1));
    } catch (RecordHealthCheckPluginDispatch.SideEffectException expected) {
      fatalEscaped = true;
    }
    Assert.isTrue(
      fatalEscaped,
      'A fatal side-effect violation must escape facade verification.'
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
    Assert.areEqual(RecordHealthCheckStatus.PASS, passing.status);
    Assert.areEqual('EQUALS', passing.comparisonOperator);
    Assert.areEqual(RecordHealthCheckStatus.FAIL, failing.status);
    Assert.areEqual('EQUALS', failing.comparisonOperator);

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

    Assert.areEqual(RecordHealthCheckStatus.PASS, none.status);
    Assert.areEqual(0, none.found.storedValues.size());
    Assert.areEqual(0, none.expected.storedValues.size());
    Assert.areEqual(RecordHealthCheckStatus.FAIL, some.status);
    Assert.areEqual(new List<String>{ 'website' }, some.found.storedValues);
    Assert.areEqual(RecordHealthCheckStatus.PASS, noneAgain.status);
  }

  @IsTest
  static void builderCopiesInput() {
    List<String> input = new List<String>{ 'A' };
    RecordHealthCheckOutcome outcome = RecordHealthCheckOutcome.itemsFound(
      'APEX_FAIL',
      input
    );
    input[0] = 'B';

    Assert.areEqual(new List<String>{ 'A' }, outcome.found.storedValues);
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
    Assert.areEqual(RecordHealthCheckStatus.ERROR, result.status);
    Assert.areEqual(
      RecordHealthCheckReasonCodes.PLUGIN_VALUES_MISSING,
      result.reasonCode
    );
    Assert.areEqual(expectedMessage, result.detailMessage);
    Assert.isTrue(result.detailMessage.contains(side));
    Assert.areEqual(side, result.diagnosticIncident.valueSide);
    Assert.isNull(result.diagnosticIncident.valueDeclaredType);
    Assert.isNull(result.diagnosticIncident.valueMemberCount);
    Assert.areEqual(true, result.diagnosticIncident.valueRenderedBlank);
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

  private static RecordHealthCheckScope scope(Integer size) {
    List<Account> accounts = new List<Account>();
    for (Integer index = 0; index < size; index++) {
      accounts.add(
        RecordHealthCheckTestDataFactory.account(
          new Map<String, Object>{ 'Name' => 'SP-V-Helper-' + index }
        )
      );
    }
    RecordHealthCheckTestDataFactory.accountsFixture(accounts);
    List<Id> recordIds = new List<Id>();
    for (Account accountRecord : accounts) {
      recordIds.add(accountRecord.Id);
    }
    return new RecordHealthCheckScope(
      'Account',
      recordIds,
      new Map<String, Object>(),
      'RHC_SP_Value_Helper',
      'RHC_SP_Values',
      'sp-v-helper'
    );
  }

  private class MissingKeyPlugin implements RecordHealthCheckPlugin {
    public Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      return new Map<Id, RecordHealthCheckOutcome>{
        scope.recordIds[0] => validOutcome()
      };
    }
  }

  private class NullMapPlugin implements RecordHealthCheckPlugin {
    public Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      return null;
    }
  }

  private class UnknownKeyPlugin implements RecordHealthCheckPlugin {
    public Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      Map<Id, RecordHealthCheckOutcome> outcomes = new Map<Id, RecordHealthCheckOutcome>();
      for (Id recordId : scope.recordIds) {
        outcomes.put(recordId, validOutcome());
      }
      outcomes.put(foreignId, validOutcome());
      return outcomes;
    }
  }

  private class CountingValidPlugin implements RecordHealthCheckPlugin {
    public Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      pluginCalls++;
      Map<Id, RecordHealthCheckOutcome> outcomes = new Map<Id, RecordHealthCheckOutcome>();
      for (Id recordId : scope.recordIds) {
        outcomes.put(recordId, validOutcome());
      }
      return outcomes;
    }
  }

  private class MissingExpectedPlugin implements RecordHealthCheckPlugin {
    public Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      return new Map<Id, RecordHealthCheckOutcome>{
        scope.recordIds[0] => RecordHealthCheckOutcome.pass('MISSING_EXPECTED')
          .withFound(RecordHealthCheckValue.ofString('Found'))
      };
    }
  }

  private class EmptyListPlugin implements RecordHealthCheckPlugin {
    public Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      return new Map<Id, RecordHealthCheckOutcome>{
        scope.recordIds[0] => RecordHealthCheckOutcome.pass('EMPTY_LIST')
          .withFound(RecordHealthCheckValue.ofList(null))
          .withExpected(RecordHealthCheckValue.ofList(null))
      };
    }
  }

  private class FalsePlugin implements RecordHealthCheckPlugin {
    public Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      return new Map<Id, RecordHealthCheckOutcome>{
        scope.recordIds[0] => RecordHealthCheckOutcome.pass('FALSE')
          .withFound(RecordHealthCheckValue.ofBoolean(false))
          .withExpected(RecordHealthCheckValue.ofBoolean(false))
      };
    }
  }

  private class DmlThenThrowPlugin implements RecordHealthCheckPlugin {
    public Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      update RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{
          'Id' => scope.recordIds[0],
          'Name' => 'Forbidden mutation'
        }
      );
      throw new DeliberateFailureException();
    }
  }

  private class DeliberateFailureException extends Exception {
  }

  private static RecordHealthCheckOutcome validOutcome() {
    return RecordHealthCheckOutcome.pass('VALID')
      .withFound(RecordHealthCheckValue.ofCount(0))
      .withExpected(RecordHealthCheckValue.ofCount(0));
  }

  private static void assertCompletenessFailure(
    RecordHealthCheckPlugin plugin,
    RecordHealthCheckScope scope,
    String expectedFragment
  ) {
    Boolean failed = false;
    try {
      RecordHealthCheckPluginTest.verify(plugin, scope).assertComplete();
    } catch (Exception error) {
      failed = true;
      Assert.isTrue(error.getMessage().contains(expectedFragment));
    }
    Assert.isTrue(failed, 'Expected raw completeness failure.');
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
      Assert.areEqual(expectedCode, error.getMessage());
    }
    Assert.isTrue(failed, 'Expected builder rejection for ' + mode + '.');
  }
}
