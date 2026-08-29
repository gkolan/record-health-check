/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Tests for AccountHasRecentActivityCheck — the Apex example that passes when an
 * Account has a completed Task or logged Event inside a tunable window.
 */
@IsTest
private class AccountHasRecentActivityCheckTest {
  @IsTest
  static void completedTaskInsideWindowPasses() {
    Account account = RecordHealthCheckTestDataFactory.createAccount(
      'RHC Recent Activity Pass'
    );

    RecordHealthCheckTestDataFactory.createTask(
      RecordHealthCheckTestDataFactory.task(
        new Map<String, Object>{
          'WhatId' => account.Id,
          'Subject' => 'Recent call',
          'Status' => 'Completed',
          'ActivityDate' => Date.today()
        }
      )
    );

    RecordHealthCheckInternalResult result = evaluate(account.Id, null);

    Assert.areEqual('PASS', result.status);
    Assert.areEqual('1', result.actualValue);
    Assert.areEqual('1', result.expectedValue);
  }

  @IsTest
  static void noActivityFails() {
    Account account = RecordHealthCheckTestDataFactory.createAccount(
      'RHC Recent Activity Fail'
    );

    RecordHealthCheckInternalResult result = evaluate(account.Id, null);

    Assert.areEqual('FAIL', result.status);
    Assert.areEqual('0', result.actualValue);
    Assert.areEqual('1', result.expectedValue);
  }

  @IsTest
  static void configuredMinimumPassesWhenEnoughEngagementsExist() {
    Account account = RecordHealthCheckTestDataFactory.createAccount(
      'RHC Engagement Volume Pass'
    );
    RecordHealthCheckTestDataFactory.createTask(
      RecordHealthCheckTestDataFactory.task(
        new Map<String, Object>{
          'WhatId' => account.Id,
          'Subject' => 'Executive review',
          'Status' => 'Completed',
          'ActivityDate' => Date.today()
        }
      )
    );
    RecordHealthCheckTestDataFactory.createEvent(
      RecordHealthCheckTestDataFactory.event(
        new Map<String, Object>{
          'WhatId' => account.Id,
          'Subject' => 'Operating review',
          'ActivityDate' => Date.today(),
          'StartDateTime' => Datetime.now(),
          'EndDateTime' => Datetime.now().addHours(1)
        }
      )
    );

    Test.startTest();
    RecordHealthCheckInternalResult result = evaluate(
      account.Id,
      new Map<String, Object>{ 'daysBack' => 60, 'minimumActivities' => 2 }
    );
    Test.stopTest();

    Assert.areEqual('PASS', result.status, 'Two engagements should pass.');
    Assert.areEqual('2', result.actualValue, 'Both activities should count.');
    Assert.areEqual(
      '2',
      result.expectedValue,
      'The configured minimum should display.'
    );
  }

  @IsTest
  static void configuredMinimumFailsWhenVolumeIsTooLow() {
    Account account = RecordHealthCheckTestDataFactory.createAccount(
      'RHC Engagement Volume Fail'
    );
    RecordHealthCheckTestDataFactory.createTask(
      RecordHealthCheckTestDataFactory.task(
        new Map<String, Object>{
          'WhatId' => account.Id,
          'Subject' => 'Only engagement',
          'Status' => 'Completed',
          'ActivityDate' => Date.today()
        }
      )
    );

    Test.startTest();
    RecordHealthCheckInternalResult result = evaluate(
      account.Id,
      new Map<String, Object>{ 'minimumActivities' => 2 }
    );
    Test.stopTest();

    Assert.areEqual(
      'FAIL',
      result.status,
      'One engagement should miss a minimum of two.'
    );
    Assert.areEqual(
      '1',
      result.actualValue,
      'The observed volume should display.'
    );
    Assert.areEqual(
      '2',
      result.expectedValue,
      'The configured minimum should display.'
    );
  }

  @IsTest
  static void whoOnlyContactTaskIsExplicitlyOutsideWhatIdContractRow22() {
    Account account = RecordHealthCheckTestDataFactory.createAccount(
      'RHC Who-only activity'
    );
    Contact contact = RecordHealthCheckTestDataFactory.contact(
      new Map<String, Object>{
        'LastName' => 'Who only',
        'AccountId' => account.Id
      }
    );
    RecordHealthCheckTestDataFactory.createContacts(
      new List<Contact>{ contact }
    );
    RecordHealthCheckTestDataFactory.createTask(
      RecordHealthCheckTestDataFactory.task(
        new Map<String, Object>{
          'WhoId' => contact.Id,
          'Subject' => 'Contact-only call',
          'Status' => 'Completed',
          'ActivityDate' => Date.today()
        }
      )
    );

    RecordHealthCheckInternalResult result = evaluate(account.Id, null);

    Assert.areEqual(
      RecordHealthCheckStatus.FAIL,
      result.status,
      'The packaged example is intentionally WhatId-only; documentation supplies the WhoId recipe.'
    );
    Assert.areEqual('0', result.actualValue);
  }

  @IsTest
  static void activityOutsideWindowFails() {
    Account account = RecordHealthCheckTestDataFactory.createAccount(
      'RHC Recent Activity Stale'
    );

    RecordHealthCheckTestDataFactory.createTask(
      RecordHealthCheckTestDataFactory.task(
        new Map<String, Object>{
          'WhatId' => account.Id,
          'Subject' => 'Old call',
          'Status' => 'Completed',
          'ActivityDate' => Date.today().addDays(-400)
        }
      )
    );

    // A 90-day window excludes the 400-day-old task.
    RecordHealthCheckInternalResult result = evaluate(
      account.Id,
      new Map<String, Object>{ 'daysBack' => 90 }
    );

    Assert.areEqual('FAIL', result.status);
    Assert.areEqual('0', result.actualValue);
    Assert.areEqual('1', result.expectedValue);
  }

  @IsTest
  static void invalidDaysBackIsRejected() {
    Account account = RecordHealthCheckTestDataFactory.createAccount(
      'RHC Recent Activity Default'
    );

    RecordHealthCheckTestDataFactory.createTask(
      RecordHealthCheckTestDataFactory.task(
        new Map<String, Object>{
          'WhatId' => account.Id,
          'Subject' => 'Recent call',
          'Status' => 'Completed',
          'ActivityDate' => Date.today()
        }
      )
    );

    // Invalid configuration must be visible instead of silently changing the
    // administrator's requested window.
    Assert.areEqual(
      'UNABLE_TO_EVALUATE',
      evaluate(account.Id, new Map<String, Object>{ 'daysBack' => 999999 })
        .status
    );
    Assert.areEqual(
      'INVALID_CONFIG',
      evaluate(account.Id, new Map<String, Object>{ 'daysBack' => 999999 })
        .reasonCode
    );
    Assert.areEqual(
      'UNABLE_TO_EVALUATE',
      evaluate(account.Id, new Map<String, Object>{ 'daysBack' => 'abc' })
        .status
    );
    Assert.areEqual(
      'INVALID_CONFIG',
      evaluate(account.Id, new Map<String, Object>{ 'minimumActivities' => 0 })
        .reasonCode,
      'A zero engagement requirement is not a useful health policy.'
    );
    Assert.areEqual(
      'UNABLE_TO_EVALUATE',
      evaluate(
          account.Id,
          new Map<String, Object>{ 'minimumActivities' => true }
        )
        .status,
      'Unsupported minimum types must be rejected.'
    );
  }

  @IsTest
  static void recentEventPassesAndUnsupportedParameterTypeIsRejected() {
    Account account = RecordHealthCheckTestDataFactory.createAccount(
      'RHC Recent Event'
    );
    RecordHealthCheckTestDataFactory.createEvent(
      RecordHealthCheckTestDataFactory.event(
        new Map<String, Object>{
          'WhatId' => account.Id,
          'Subject' => 'Recent meeting',
          'ActivityDate' => Date.today(),
          'StartDateTime' => Datetime.now(),
          'EndDateTime' => Datetime.now().addHours(1)
        }
      )
    );

    Test.startTest();
    RecordHealthCheckInternalResult decimalResult = evaluate(
      account.Id,
      new Map<String, Object>{ 'daysBack' => Decimal.valueOf('30') }
    );
    RecordHealthCheckInternalResult unsupportedResult = evaluate(
      account.Id,
      new Map<String, Object>{ 'daysBack' => true }
    );
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckStatus.PASS,
      decimalResult.status,
      'A recent Event must satisfy the Check with a Decimal window.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.UNABLE_TO_EVALUATE,
      unsupportedResult.status,
      'An unsupported parameter type must be rejected.'
    );
    Assert.areEqual(
      'INVALID_CONFIG',
      unsupportedResult.reasonCode,
      'The result must explain the invalid configuration.'
    );
  }

  /**
   * The check is bulk, so a single-record assertion is a scope of one. This
   * helper returns the internal result shape so the assertions stay readable.
   */
  private static RecordHealthCheckInternalResult evaluate(
    Id recordId,
    Map<String, Object> parameters
  ) {
    RecordHealthCheckOutcome outcome = evaluateScope(
        new List<Id>{ recordId },
        parameters
      )
      .get(recordId);
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.status = outcome.status;
    result.reasonCode = outcome.reasonCode;
    result.actualValue = outcome.found == null
      ? null
      : outcome.found.storedValue;
    result.expectedValue = outcome.expected == null
      ? null
      : outcome.expected.storedValue;
    return result;
  }

  private static Map<Id, RecordHealthCheckOutcome> evaluateScope(
    List<Id> recordIds,
    Map<String, Object> parameters
  ) {
    return new AccountHasRecentActivityCheck()
      .evaluate(
        new RecordHealthCheckScope(
          'Account',
          recordIds,
          parameters,
          'Account_Has_Recent_Activity',
          null,
          null
        )
      );
  }

  /**
   * The property the bulk contract exists for: query count must not move with
   * scope size. Two queries serve one record and they serve two hundred.
   */
  @IsTest
  static void queryCountDoesNotGrowWithScopeSize() {
    List<Account> accounts = new List<Account>();
    for (Integer i = 0; i < 200; i++) {
      accounts.add(
        RecordHealthCheckTestDataFactory.account(
          new Map<String, Object>{ 'Name' => 'Bulk Scope ' + i }
        )
      );
    }
    RecordHealthCheckTestDataFactory.createAccounts(accounts);
    List<Id> accountIds = new List<Id>(new Map<Id, Account>(accounts).keySet());

    Test.startTest();
    Integer before = Limits.getQueries();
    Map<Id, RecordHealthCheckOutcome> single = evaluateScope(
      new List<Id>{ accountIds[0] },
      null
    );
    Integer afterSingle = Limits.getQueries() - before;

    before = Limits.getQueries();
    Map<Id, RecordHealthCheckOutcome> all = evaluateScope(accountIds, null);
    Integer afterAll = Limits.getQueries() - before;
    Test.stopTest();

    Assert.areEqual(
      afterSingle,
      afterAll,
      'A scope of 200 must cost the same queries as a scope of 1.'
    );
    Assert.areEqual(2, afterAll, 'One query for Task, one for Event.');
    Assert.areEqual(1, single.size());
    Assert.areEqual(
      200,
      all.size(),
      'Every record in scope must receive an outcome.'
    );
  }

  /**
   * Zero is a real answer. An aggregate returns no row for an Account with no
   * activity, so seeding matters: without it these records would be missing
   * from the map entirely, and they are exactly the ones the check should flag.
   */
  @IsTest
  static void accountsWithNoActivityStillReceiveAnOutcome() {
    List<Account> accounts = new List<Account>{
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'Name' => 'No Activity A' }
      ),
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'Name' => 'No Activity B' }
      )
    };
    RecordHealthCheckTestDataFactory.createAccounts(accounts);
    List<Id> accountIds = new List<Id>(new Map<Id, Account>(accounts).keySet());

    Test.startTest();
    Map<Id, RecordHealthCheckOutcome> outcomes = evaluateScope(
      accountIds,
      null
    );
    Test.stopTest();

    Assert.areEqual(2, outcomes.size());
    for (Id accountId : accountIds) {
      RecordHealthCheckOutcome outcome = outcomes.get(accountId);
      Assert.areNotEqual(null, outcome, 'Missing key for ' + accountId);
      Assert.areEqual(RecordHealthCheckStatus.FAIL, outcome.status);
      Assert.areEqual('0', outcome.found.storedValue, 'Zero, not absent.');
    }
  }

  /** An empty scope must not query at all, and must not throw. */
  @IsTest
  static void emptyScopeDoesNoWork() {
    Test.startTest();
    Integer before = Limits.getQueries();
    Map<Id, RecordHealthCheckOutcome> outcomes = evaluateScope(
      new List<Id>(),
      null
    );
    Integer used = Limits.getQueries() - before;
    Test.stopTest();

    Assert.areEqual(0, outcomes.size());
    Assert.areEqual(0, used, 'An empty scope must not issue activity queries.');
  }
}
