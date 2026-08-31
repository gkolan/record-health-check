/** Verifies defensive scope integrity and governor side-effect classification. */
@IsTest
private class RHCPluginScopeIntegrityTest {
  /** Tries to keep the scope and mutate it later. */
  private class ScopeHoardingCheck implements RecordHealthCheckPlugin {
    public RecordHealthCheckScope captured;
    public Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      captured = scope;
      scope.recordIds.clear();
      scope.parameters.put('injected', 'yes');
      Map<Id, RecordHealthCheckOutcome> out = new Map<Id, RecordHealthCheckOutcome>();
      for (Id recordId : scope.recordIds) {
        out.put(recordId, RecordHealthCheckOutcome.pass('OK'));
      }
      return out;
    }
  }

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

  // ─── Scope integrity ───────────────────────────────────────────────────────

  /** A check cannot reach engine state through the scope it was handed. */
  @IsTest
  static void mutatingTheScopeDoesNotAffectTheEngine() {
    List<Account> accounts = makeAccounts(3);
    RecordHealthCheckScope scope = scopeFor(accounts);
    ScopeHoardingCheck check = new ScopeHoardingCheck();

    Test.startTest();
    // The check clears the list and injects a parameter, but both act on copies,
    // so its own loop still sees all three records and it returns a complete
    // result. That it succeeds is the point: the tampering had no effect at all.
    Map<Id, RecordHealthCheckOutcome> outcomes = RecordHealthCheckPluginDispatch.run(
      check,
      scope
    );
    Test.stopTest();

    Assert.areEqual(3, outcomes.size(), 'All three records still answered.');
    Assert.areEqual(3, scope.recordIds.size(), 'The scope is unchanged.');
    Assert.areEqual(
      false,
      scope.parameters.containsKey('injected'),
      'Parameters cannot be injected into engine state.'
    );
  }

  /** Nested parameter maps and lists cannot expose engine-owned state. */
  @IsTest
  static void nestedParametersAreDeeplyDetached() {
    Map<String, Object> nested = new Map<String, Object>{
      'checks' => new List<Object>{
        new Map<String, Object>{ 'threshold' => 3 }
      }
    };
    RecordHealthCheckScope scope = new RecordHealthCheckScope(
      'Account',
      null,
      nested,
      'Test_Check',
      'Test_Set',
      'run-test'
    );

    ((Map<String, Object>) ((List<Object>) nested.get('checks'))[0])
      .put('threshold', 9);
    Map<String, Object> returned = scope.parameters;
    ((Map<String, Object>) ((List<Object>) returned.get('checks'))[0])
      .put('threshold', 12);

    Map<String, Object> storedCheck = (Map<String, Object>) ((List<Object>) scope
      .parameters.get('checks'))[0];
    Assert.areEqual(
      3,
      storedCheck.get('threshold'),
      'Neither constructor input nor returned nested values may mutate scope state.'
    );
  }

  /** A Check is authored against one object, so a mixed scope is rejected before dispatch. */
  @IsTest
  static void mixedObjectTypesAreRejectedAtScopeConstruction() {
    Account account = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Mixed' }
    );
    RecordHealthCheckTestDataFactory.accountFixture(account);
    Contact contact = RecordHealthCheckTestDataFactory.contact(
      new Map<String, Object>{ 'LastName' => 'Mixed' }
    );
    RecordHealthCheckTestDataFactory.contactFixture(contact);

    Test.startTest();
    Boolean threw = false;
    try {
      new RecordHealthCheckScope(
        'Account',
        new List<Id>{ account.Id, contact.Id },
        null,
        'Test_Check',
        null,
        null
      );
    } catch (RecordHealthCheckScope.RecordHealthCheckScopeException ex) {
      threw = true;
    }
    Test.stopTest();

    Assert.areEqual(true, threw, 'A scope must not mix object types.');
  }

  /** Duplicates collapse, first occurrence wins, and order is preserved. */
  @IsTest
  static void duplicateIdsAreDeduplicatedPreservingOrder() {
    List<Account> accounts = makeAccounts(3);
    List<Id> ids = new List<Id>(new Map<Id, Account>(accounts).keySet());

    RecordHealthCheckScope scope = new RecordHealthCheckScope(
      'Account',
      new List<Id>{ ids[2], ids[0], ids[2], ids[1], ids[0] },
      null,
      'Test_Check',
      null,
      null
    );

    Assert.areEqual(3, scope.size());
    Assert.areEqual(ids[2], scope.recordIds[0]);
    Assert.areEqual(ids[0], scope.recordIds[1]);
    Assert.areEqual(ids[1], scope.recordIds[2]);
  }

  @IsTest
  static void nullIdsAreIgnoredRatherThanProducingAPhantomResult() {
    List<Account> accounts = makeAccounts(1);
    RecordHealthCheckScope scope = new RecordHealthCheckScope(
      'Account',
      new List<Id>{ accounts[0].Id, null, null },
      null,
      'Test_Check',
      null,
      null
    );
    Assert.areEqual(1, scope.size());
  }

  @IsTest
  static void detectorClassifiesEveryGovernorSideEffect() {
    Integer dml = Limits.getDmlStatements();
    Integer rows = Limits.getDmlRows();
    Integer callouts = Limits.getCallouts();
    Integer queueables = Limits.getQueueableJobs();
    Integer futures = Limits.getFutureCalls();
    Integer emails = Limits.getEmailInvocations();

    Test.startTest();
    RecordHealthCheckPluginDispatch.SideEffectException callout = RecordHealthCheckPluginDispatch.detect(
      dml,
      rows,
      callouts - 1,
      queueables,
      futures,
      emails
    );
    RecordHealthCheckPluginDispatch.SideEffectException queueable = RecordHealthCheckPluginDispatch.detect(
      dml,
      rows,
      callouts,
      queueables - 1,
      futures,
      emails
    );
    RecordHealthCheckPluginDispatch.SideEffectException futureCall = RecordHealthCheckPluginDispatch.detect(
      dml,
      rows,
      callouts,
      queueables,
      futures - 1,
      emails
    );
    RecordHealthCheckPluginDispatch.SideEffectException email = RecordHealthCheckPluginDispatch.detect(
      dml,
      rows,
      callouts,
      queueables,
      futures,
      emails - 1
    );
    Test.stopTest();

    Assert.areEqual('CALLOUT', callout.effect);
    Assert.isFalse(callout.reversible, 'A sent callout cannot be rolled back.');
    Assert.areEqual('QUEUEABLE', queueable.effect);
    Assert.isTrue(
      queueable.reversible,
      'An enqueued job rolls back with the transaction.'
    );
    Assert.areEqual('FUTURE', futureCall.effect);
    Assert.isTrue(
      futureCall.reversible,
      'A future call rolls back with the transaction.'
    );
    Assert.areEqual('EMAIL', email.effect);
    Assert.isFalse(email.reversible, 'A sent email cannot be undone.');
  }
}
