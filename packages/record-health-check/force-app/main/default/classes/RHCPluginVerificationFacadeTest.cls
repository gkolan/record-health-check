/** Verifies raw plugin completeness, renderability, reuse and side-effect fences. */
@IsTest
private class RHCPluginVerificationFacadeTest {
  private static Integer pluginCalls = 0;
  private static Id foreignId;
  @IsTest
  static void rawMissingKeyFailsHelper() {
    RecordHealthCheckScope scope = scope(2);
    Boolean failed = false;
    try {
      RecordHealthCheckPluginTest.verify(new MissingKeyPlugin(), scope)
        .assertComplete();
    } catch (Exception error) {
      failed = true;
      Assert.isTrue(
        error.getMessage().contains('missing'),
        'Raw-map completeness failure must identify the missing record outcome.'
      );
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
    Assert.areEqual(
      1,
      pluginCalls,
      'Chained verification assertions must reuse one plugin evaluation.'
    );
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
        error.getMessage().contains('Expected'),
        'Renderability failure must identify the missing Expected operand.'
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
      Assert.isTrue(
        error.getMessage().contains(expectedFragment),
        'Raw completeness rejection must expose the expected missing-or-unknown-key detail.'
      );
    }
    Assert.isTrue(failed, 'Expected raw completeness failure.');
  }
}
