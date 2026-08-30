/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Adversarial tests for the extension boundary.
 *
 * A custom Check is third-party code running inside the framework's transaction.
 * These tests assume it is hostile rather than merely careless, because the
 * guarantee the product sells is that a health check never changes anything,
 * and a guarantee that only holds for well-behaved code is not a guarantee.
 *
 * The cases below are the ways a check could break that promise and have the
 * damage stick.
 */
@IsTest
private class RecordHealthCheckPluginDispatchIT {
  // ─── Test doubles ──────────────────────────────────────────────────────────

  /** Behaves. The control case. */
  private class WellBehavedCheck implements RecordHealthCheckPlugin {
    public Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      Map<Id, RecordHealthCheckOutcome> out = new Map<Id, RecordHealthCheckOutcome>();
      for (Id recordId : scope.recordIds) {
        out.put(recordId, RecordHealthCheckOutcome.pass('OK'));
      }
      return out;
    }
  }

  /** Mutates a record, which is the one thing the framework promises never happens. */
  private class MutatingCheck implements RecordHealthCheckPlugin {
    public Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      update RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'Id' => scope.recordIds[0], 'Rating' => 'Hot' }
      );
      Map<Id, RecordHealthCheckOutcome> out = new Map<Id, RecordHealthCheckOutcome>();
      for (Id recordId : scope.recordIds) {
        out.put(recordId, RecordHealthCheckOutcome.pass('OK'));
      }
      return out;
    }
  }

  /**
   * The dangerous one. Mutates, then throws, so an engine that converts
   * exceptions into results before checking for side effects would commit the
   * mutation and report a tidy ERROR row alongside it.
   */
  private class MutateThenThrowCheck implements RecordHealthCheckPlugin {
    public Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      update RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'Id' => scope.recordIds[0], 'Rating' => 'Hot' }
      );
      throw new IllegalArgumentException('Nothing to see here.');
    }
  }

  /** Throws, but changes nothing. Attributable to the check, so it may become results. */
  private class ThrowingCheck implements RecordHealthCheckPlugin {
    public Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      throw new IllegalArgumentException('Boom.');
    }
  }

  /** Answers about a record it was never asked about. */
  private class ExtraKeyCheck implements RecordHealthCheckPlugin {
    public Id foreignId;
    public Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      Map<Id, RecordHealthCheckOutcome> out = new Map<Id, RecordHealthCheckOutcome>();
      for (Id recordId : scope.recordIds) {
        out.put(recordId, RecordHealthCheckOutcome.pass('OK'));
      }
      out.put(foreignId, RecordHealthCheckOutcome.fail('SMUGGLED'));
      return out;
    }
  }

  /** Silently drops a record, which without validation would simply vanish from the report. */
  private class SkippingCheck implements RecordHealthCheckPlugin {
    public Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      Map<Id, RecordHealthCheckOutcome> out = new Map<Id, RecordHealthCheckOutcome>();
      List<Id> ids = scope.recordIds;
      for (Integer i = 1; i < ids.size(); i++) {
        out.put(ids[i], RecordHealthCheckOutcome.pass('OK'));
      }
      return out;
    }
  }

  /** Returns nothing at all. */
  private class NullCheck implements RecordHealthCheckPlugin {
    public Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      return null;
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  private static List<Account> makeAccounts(Integer count) {
    List<Account> accounts = new List<Account>();
    for (Integer i = 0; i < count; i++) {
      accounts.add(
        RecordHealthCheckTestDataFactory.account(
          new Map<String, Object>{ 'Name' => 'Dispatch ' + i }
        )
      );
    }
    RHCIntegrationTestDataFactory.createAccounts(accounts);
    return accounts;
  }

  private static RecordHealthCheckScope scopeFor(List<Account> accounts) {
    return new RecordHealthCheckScope(
      'Account',
      new List<Id>(new Map<Id, Account>(accounts).keySet()),
      null,
      'Test_Check',
      'Test_Set',
      'run-test'
    );
  }

  // ─── Side effects ──────────────────────────────────────────────────────────

  @IsTest
  static void pluginConstructorDmlIsStoppedAndRolledBack() {
    Integer accountsBefore = [SELECT COUNT() FROM Account];

    Test.startTest();
    try {
      RecordHealthCheckPluginDispatch.instantiate(
        Type.forName(RHCConstructorMutationCheck.class.getName())
      );
      Assert.fail('Constructor DML must be detected as a plugin side effect.');
    } catch (RecordHealthCheckPluginDispatch.SideEffectException error) {
      Assert.areEqual(
        RecordHealthCheckReasonCodes.PLUGIN_SIDE_EFFECT_DETECTED,
        error.reasonCode,
        'Constructor DML must use the stable side-effect reason code.'
      );
      Assert.areEqual(
        'DML',
        error.effect,
        'Constructor DML must be classified as DML.'
      );
    }
    Test.stopTest();

    Assert.areEqual(
      accountsBefore,
      [SELECT COUNT() FROM Account],
      'Constructor DML must be rolled back before control returns.'
    );
  }

  @IsTest
  static void pluginInstantiationRejectsNullAndNonContractTypes() {
    Test.startTest();
    RecordHealthCheckPlugin nullType = RecordHealthCheckPluginDispatch.instantiate(
      null
    );
    RecordHealthCheckPlugin wrongType = RecordHealthCheckPluginDispatch.instantiate(
      Type.forName('RecordHealthCheckConstants')
    );
    Test.stopTest();

    Assert.isNull(nullType, 'A null Type must not produce a plugin.');
    Assert.isNull(
      wrongType,
      'A class outside the plugin contract must not be accepted.'
    );
  }

  @IsTest
  static void sequentialPluginConstructionDoesNotExhaustSavepoints() {
    Type pluginType = Type.forName('AccountHasRecentActivityCheck');
    Integer constructed = 0;

    Test.startTest();
    for (Integer i = 0; i < 10; i++) {
      RecordHealthCheckPlugin plugin = RecordHealthCheckPluginDispatch.instantiate(
        pluginType
      );
      if (plugin != null) {
        constructed++;
      }
    }
    Test.stopTest();

    Assert.areEqual(
      10,
      constructed,
      'Released constructor fences must allow more than five sequential plugins.'
    );
  }

  @IsTest
  static void mutatingCheckIsStoppedAndTheChangeIsRolledBack() {
    List<Account> accounts = makeAccounts(1);
    Id accountId = accounts[0].Id;

    Test.startTest();
    Boolean threw = false;
    String reasonCode;
    try {
      RecordHealthCheckPluginDispatch.run(
        new MutatingCheck(),
        scopeFor(accounts)
      );
    } catch (RecordHealthCheckPluginDispatch.SideEffectException ex) {
      threw = true;
      reasonCode = ex.reasonCode;
      Assert.areEqual('DML', ex.effect);
      Assert.areEqual(true, ex.reversible);
    }
    Test.stopTest();

    Assert.areEqual(true, threw, 'A check that performs DML must fail.');
    Assert.areEqual(
      RecordHealthCheckReasonCodes.PLUGIN_SIDE_EFFECT_DETECTED,
      reasonCode
    );
    // The dispatcher throws rather than returning, which is what lets the
    // caller abandon the transaction. Verified here by the rollback the test
    // framework performs around the assertion above.
    Assert.areEqual(
      null,
      [SELECT Rating FROM Account WHERE Id = :accountId].Rating,
      'The mutation must not survive.'
    );
  }

  /**
   * The precedence case, and the reason the fence lives in a `finally`.
   *
   * If the exception were handled first, it would be converted into ordinary
   * ERROR results, those results would be returned normally, and the DML the
   * check performed on its way out would commit with them.
   */
  @IsTest
  static void mutateThenThrowReportsTheSideEffectNotTheException() {
    List<Account> accounts = makeAccounts(1);

    Test.startTest();
    String reasonCode;
    try {
      RecordHealthCheckPluginDispatch.run(
        new MutateThenThrowCheck(),
        scopeFor(accounts)
      );
      Assert.isTrue(false, 'Expected the run to fail.');
    } catch (RecordHealthCheckPluginDispatch.SideEffectException ex) {
      reasonCode = ex.reasonCode;
    } catch (RecordHealthCheckPluginDispatch.ContractException ex) {
      Assert.isTrue(
        false,
        'The exception must not outrank the side effect it hid behind.'
      );
    }
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckReasonCodes.PLUGIN_SIDE_EFFECT_DETECTED,
      reasonCode,
      'A side effect outranks an exception thrown after it.'
    );
  }

  @IsTest
  static void throwingWithoutSideEffectsBecomesAnAttributableFailure() {
    List<Account> accounts = makeAccounts(1);

    Test.startTest();
    String reasonCode;
    try {
      RecordHealthCheckPluginDispatch.run(
        new ThrowingCheck(),
        scopeFor(accounts)
      );
    } catch (RecordHealthCheckPluginDispatch.ContractException ex) {
      reasonCode = ex.reasonCode;
    }
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckReasonCodes.PLUGIN_THREW,
      reasonCode,
      'No prohibited effect, so the throw is safe to report as a result.'
    );
  }

  @IsTest
  static void wellBehavedCheckIsNotFlaggedAsASideEffect() {
    List<Account> accounts = makeAccounts(25);

    Test.startTest();
    Map<Id, RecordHealthCheckOutcome> outcomes = RecordHealthCheckPluginDispatch.run(
      new WellBehavedCheck(),
      scopeFor(accounts)
    );
    Test.stopTest();

    Assert.areEqual(
      25,
      outcomes.size(),
      'The fence must not fire on a check that behaves.'
    );
  }

  @IsTest
  static void sequentialPluginRunsDoNotExhaustSavepoints() {
    List<Account> accounts = makeAccounts(1);
    RecordHealthCheckScope scope = scopeFor(accounts);
    Integer completed = 0;

    Test.startTest();
    for (Integer i = 0; i < 10; i++) {
      Map<Id, RecordHealthCheckOutcome> outcomes = RecordHealthCheckPluginDispatch.run(
        new WellBehavedCheck(),
        scope
      );
      if (outcomes.size() == 1) {
        completed++;
      }
    }
    Test.stopTest();

    Assert.areEqual(
      10,
      completed,
      'Released evaluation fences must allow more than five sequential plugins.'
    );
  }

  // ─── Completeness ──────────────────────────────────────────────────────────

  /**
   * Fail-closed on purpose. A check confused about which records it was handed
   * is not one whose other answers should be believed, so one stray key
   * invalidates the whole scope rather than being quietly dropped.
   */
  @IsTest
  static void answeringAboutAnUnrequestedRecordFailsTheWholeScope() {
    List<Account> inScope = makeAccounts(3);
    List<Account> outOfScope = makeAccounts(1);

    ExtraKeyCheck check = new ExtraKeyCheck();
    check.foreignId = outOfScope[0].Id;

    Test.startTest();
    String reasonCode;
    try {
      RecordHealthCheckPluginDispatch.run(check, scopeFor(inScope));
    } catch (RecordHealthCheckPluginDispatch.ContractException ex) {
      reasonCode = ex.reasonCode;
    }
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckReasonCodes.PLUGIN_RESULT_UNKNOWN_KEY,
      reasonCode
    );
  }

  /** A dropped record becomes a visible ERROR rather than silently disappearing. */
  @IsTest
  static void aDroppedRecordBecomesAnErrorForThatRecordOnly() {
    List<Account> accounts = makeAccounts(4);
    RecordHealthCheckScope scope = scopeFor(accounts);
    Id dropped = scope.recordIds[0];

    Test.startTest();
    Map<Id, RecordHealthCheckOutcome> outcomes = RecordHealthCheckPluginDispatch.run(
      new SkippingCheck(),
      scope
    );
    Test.stopTest();

    Assert.areEqual(4, outcomes.size(), 'Every requested Id is answered.');
    Assert.areEqual(
      RecordHealthCheckStatus.ERROR,
      outcomes.get(dropped).status
    );
    Assert.areEqual(
      RecordHealthCheckReasonCodes.PLUGIN_RESULT_MISSING,
      outcomes.get(dropped).reasonCode
    );
    for (Integer i = 1; i < scope.recordIds.size(); i++) {
      Assert.areEqual(
        RecordHealthCheckStatus.PASS,
        outcomes.get(scope.recordIds[i]).status,
        'One bad record must not cost the others their verdicts.'
      );
    }
  }

  @IsTest
  static void returningNothingIsAContractViolation() {
    List<Account> accounts = makeAccounts(2);

    Test.startTest();
    String reasonCode;
    try {
      RecordHealthCheckPluginDispatch.run(new NullCheck(), scopeFor(accounts));
    } catch (RecordHealthCheckPluginDispatch.ContractException ex) {
      reasonCode = ex.reasonCode;
    }
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckReasonCodes.PLUGIN_RESULT_MISSING,
      reasonCode
    );
  }
}
