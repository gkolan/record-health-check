/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Tests for AccountStrategicReadinessCheck — the Apex example that scores an
 * Account across four readiness criteria (25 points each) and passes when the
 * total meets a configurable threshold.
 */
@IsTest
private class AccountStrategicReadinessCheckTest {
  @IsTest
  static void bareAccountScoresZeroAndFails() {
    Account account = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'RHC Readiness Bare' }
    );
    RHCIntegrationTestDataFactory.createAccount(account);

    RecordHealthCheckInternalResult result = evaluate(account.Id, null);

    Assert.areEqual('FAIL', result.status);
    Assert.areEqual('0', result.actualValue);
    Assert.areEqual('80', result.expectedValue);
  }

  @IsTest
  static void singleCriterionPassesWhenThresholdIsLow() {
    Account account = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'RHC Readiness One Criterion' }
    );
    RHCIntegrationTestDataFactory.createAccount(account);
    RHCIntegrationTestDataFactory.createContact(
      new Map<String, Object>{
        'LastName' => 'Buyer',
        'AccountId' => account.Id
      }
    );

    // One criterion = 25 points; a threshold of 1 is comfortably met.
    RecordHealthCheckInternalResult result = evaluate(
      account.Id,
      new Map<String, Object>{ 'minScore' => 1 }
    );

    Assert.areEqual('PASS', result.status);
    // Values and value source are set on a PASS too so a
    // green row stays auditable through the disclosure.
    Assert.areEqual('25', result.actualValue);
  }

  @IsTest
  static void allCriteriaMetReachesFullScoreAndPasses() {
    Account account = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Name' => 'RHC Readiness Full',
        'BillingStreet' => '1 Market St',
        'BillingCity' => 'San Francisco',
        'BillingCountry' => 'USA'
      }
    );
    RHCIntegrationTestDataFactory.createAccount(account);

    RHCIntegrationTestDataFactory.createContact(
      new Map<String, Object>{
        'LastName' => 'Buyer',
        'AccountId' => account.Id
      }
    );
    RHCIntegrationTestDataFactory.createOpportunity(
      new Map<String, Object>{
        'AccountId' => account.Id,
        'Name' => 'Open pipeline',
        'StageName' => 'Prospecting',
        'Amount' => 50000,
        'CloseDate' => Date.today().addMonths(1)
      }
    );
    RHCIntegrationTestDataFactory.createTask(
      new Map<String, Object>{
        'WhatId' => account.Id,
        'Subject' => 'Recent QBR',
        'Status' => 'Completed',
        'ActivityDate' => Date.today()
      }
    );

    // All four criteria met = 100, clearing the default threshold of 80.
    RecordHealthCheckInternalResult result = evaluate(account.Id, null);

    Assert.areEqual('PASS', result.status);
    Assert.areEqual('100', result.actualValue);
    Assert.areEqual('80', result.expectedValue);
  }

  @IsTest
  static void invalidParametersFallBackToDefaults() {
    Account account = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'RHC Readiness Bad Params' }
    );
    RHCIntegrationTestDataFactory.createAccount(account);
    RHCIntegrationTestDataFactory.createContact(
      new Map<String, Object>{
        'LastName' => 'Buyer',
        'AccountId' => account.Id
      }
    );

    // Unparseable and out-of-range values fall back to defaults (minScore 80)
    // so a lone 25-point criterion still fails.
    Assert.areEqual(
      'FAIL',
      evaluate(
          account.Id,
          new Map<String, Object>{
            'minScore' => 'not-a-number',
            'activityDaysBack' => 999999
          }
        )
        .status
    );
  }

  @IsTest
  static void missingRecordAndEventCriterionCoverDefensivePaths() {
    Account eventAccount = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'RHC Readiness Event' }
    );
    Account deletedAccount = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'RHC Readiness Deleted' }
    );
    RHCIntegrationTestDataFactory.createAccounts(
      new List<Account>{ eventAccount, deletedAccount }
    );
    RHCIntegrationTestDataFactory.createEvent(
      new Map<String, Object>{
        'WhatId' => eventAccount.Id,
        'Subject' => 'Recent strategy session',
        'StartDateTime' => System.now(),
        'EndDateTime' => System.now().addHours(1)
      }
    );
    Id deletedId = deletedAccount.Id;
    delete deletedAccount;

    Test.startTest();
    RecordHealthCheckOutcome missing = new AccountStrategicReadinessCheck()
      .evaluate(
        new RecordHealthCheckScope(
          'Account',
          new List<Id>{ deletedId },
          new Map<String, Object>(),
          'Example_Strategic_Account_Is_Ready',
          null,
          null
        )
      )
      .get(deletedId);
    RecordHealthCheckOutcome eventOutcome = new AccountStrategicReadinessCheck()
      .evaluate(
        new RecordHealthCheckScope(
          'Account',
          new List<Id>{ eventAccount.Id },
          new Map<String, Object>{ 'minScore' => 1 },
          'Strategic_Account_Is_Ready',
          null,
          null
        )
      )
      .get(eventAccount.Id);
    Integer defaultScore = AccountStrategicReadinessCheck.resolveInt(
      null,
      'minScore',
      80,
      1,
      100
    );
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckStatus.UNABLE_TO_EVALUATE,
      missing.status,
      'A deleted Account must not leak as a failure.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.PASS,
      eventOutcome.status,
      'A recent Event should satisfy the activity criterion.'
    );
    Assert.areEqual(
      80,
      defaultScore,
      'Null parameters should retain the configured default.'
    );
  }

  /**
   * The check is bulk, so a single-record assertion is a scope of one. Mapped
   * back onto the internal result shape so the assertions stay readable.
   */
  private static RecordHealthCheckInternalResult evaluate(
    Id recordId,
    Map<String, Object> parameters
  ) {
    RecordHealthCheckOutcome outcome = new AccountStrategicReadinessCheck()
      .evaluate(
        new RecordHealthCheckScope(
          'Account',
          new List<Id>{ recordId },
          parameters,
          'Strategic_Account_Is_Ready',
          null,
          null
        )
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
}
