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
private class RecordHealthCheckPluginDispatchTest {
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

  /** Supplies optional display without repeating evaluation or querying. */
  private class DisplayCheck implements RecordHealthCheckPlugin, RecordHealthCheckDisplayPlugin {
    public Integer evaluationCalls = 0;
    public Integer displayCalls = 0;
    public Id extraKey;
    public Boolean queryDuringDisplay = false;

    public Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      evaluationCalls++;
      Map<Id, RecordHealthCheckOutcome> values = new Map<Id, RecordHealthCheckOutcome>();
      for (Id recordId : scope.recordIds) {
        values.put(recordId, RecordHealthCheckOutcome.pass('OK'));
      }
      return values;
    }

    public Map<Id, RecordHealthCheckDisplayOverride> getDisplay(
      RecordHealthCheckScope scope
    ) {
      displayCalls++;
      if (queryDuringDisplay) {
        List<Account> queriedAccounts = [
          SELECT Id
          FROM Account
          WITH USER_MODE
          LIMIT 1
        ];
        queriedAccounts.clear();
      }
      Map<Id, RecordHealthCheckDisplayOverride> values = new Map<Id, RecordHealthCheckDisplayOverride>();
      for (Id recordId : scope.recordIds) {
        values.put(
          recordId,
          new RecordHealthCheckDisplayOverride()
            .withFound(
              new RecordHealthCheckDisplayText()
                .text('Step ')
                .link('one', '/one')
            )
            .withMessage(new RecordHealthCheckDisplayText().text('Message'))
            .withFix(new RecordHealthCheckDisplayText().text('Fix'))
            .withAction(new RecordHealthCheckDisplayAction('Open', '/open'))
            .withExpectedLabel('Target')
            .withFoundFormat('CURRENCY', 'USD')
            .withExpectedFormat('NUMBER', null)
        );
      }
      if (extraKey != null) {
        values.put(extraKey, new RecordHealthCheckDisplayOverride());
      }
      return values;
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
    RecordHealthCheckTestDataFactory.accountsFixture(accounts);
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

  /**
   * The precedence case, and the reason the fence lives in a `finally`.
   *
   * If the exception were handled first, it would be converted into ordinary
   * ERROR results, those results would be returned normally, and the DML the
   * check performed on its way out would commit with them.
   */
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
  static void optionalDisplayRunsOnceOnSameInstanceAndReturnsCopies() {
    List<Account> accounts = makeAccounts(2);
    DisplayCheck plugin = new DisplayCheck();
    RecordHealthCheckScope scope = scopeFor(accounts);

    RecordHealthCheckPluginDispatch.run(plugin, scope);
    Map<Id, RecordHealthCheckDisplayOverride> display = RecordHealthCheckPluginDisplayDispatch.run(
      plugin,
      scope
    );

    Assert.areEqual(1, plugin.evaluationCalls);
    Assert.areEqual(1, plugin.displayCalls);
    Assert.areEqual(2, display.size());
    Assert.areEqual(
      'link',
      display.get(accounts[0].Id).found.copyNodes()[1].kind
    );
    RecordHealthCheckDisplayOverride first = display.get(accounts[0].Id);
    Assert.areEqual('Message', first.message.copyNodes()[0].text);
    Assert.areEqual('Fix', first.fix.copyNodes()[0].text);
    Assert.areEqual('Open', first.action.label);
    Assert.areEqual('/open', first.action.destination);
    Assert.areEqual('Target', first.expectedLabel);
    Assert.areEqual('CURRENCY', first.foundFormat);
    Assert.areEqual('USD', first.foundCurrencyIsoCode);
    Assert.areEqual('NUMBER', first.expectedFormat);
  }

  @IsTest
  static void optionalDisplayRejectsQueriesAndUnknownRecordKeys() {
    List<Account> accounts = makeAccounts(2);
    DisplayCheck querying = new DisplayCheck();
    querying.queryDuringDisplay = true;
    String queryReason;
    try {
      RecordHealthCheckPluginDisplayDispatch.run(querying, scopeFor(accounts));
    } catch (RecordHealthCheckPluginDisplayDispatch.DisplayException ex) {
      queryReason = ex.reasonCode;
    }
    Assert.areEqual('PLUGIN_DISPLAY_QUERIED', queryReason);

    Account foreign = makeAccounts(1)[0];
    DisplayCheck extra = new DisplayCheck();
    extra.extraKey = foreign.Id;
    String keyReason;
    try {
      RecordHealthCheckPluginDisplayDispatch.run(extra, scopeFor(accounts));
    } catch (RecordHealthCheckPluginDisplayDispatch.DisplayException ex) {
      keyReason = ex.reasonCode;
    }
    Assert.areEqual('PLUGIN_DISPLAY_UNKNOWN_KEY', keyReason);
  }

  @IsTest
  static void optionalDisplayFailurePreservesCompletedEvaluation() {
    Account record = RecordHealthCheckTestDataFactory.accountFixture(
      'Display failure'
    );
    RecordHealthCheckDiagModeTestPlugin.mode = 'DISPLAY_THROW_SECRET';

    try {
      Test.startTest();
      RecordHealthCheckInternalResult result = new RecordHealthCheckApexEvaluator()
        .withCardPresentation(true)
        .evaluate(
          RecordHealthCheckTestDataFactory.check(
            new Map<String, Object>{
              'DeveloperName' => 'Display_Failure',
              'QualifiedApiName' => 'Display_Failure',
              'EvaluationType__c' => 'APEX',
              'ApexClass__c' => 'RecordHealthCheckDiagModeTestPlugin',
              'ApexParametersJson__c' => '{}'
            }
          ),
          record.Id,
          record
        );
      Test.stopTest();

      Assert.areEqual(
        RecordHealthCheckStatus.PASS,
        result.status,
        'Optional presentation failure must not replace a completed verdict.'
      );
      Assert.areEqual('DISPLAY_EVALUATION_PRESERVED', result.reasonCode);
      Assert.areEqual('Evaluated found', result.actualValue);
      Assert.areEqual('Evaluated found', result.expectedValue);
      Assert.areEqual(
        'PLUGIN_DISPLAY_THREW',
        result.detailMessage,
        'Only the bounded framework reason may describe display failure.'
      );
      Assert.isFalse(
        result.detailMessage.contains('display-secret'),
        'Subscriber exception text must not leak into the result.'
      );
      Assert.isNull(
        result.displayContent,
        'Rejected display content must fall back to the original value.'
      );
    } finally {
      RecordHealthCheckDiagModeTestPlugin.mode = null;
    }
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
