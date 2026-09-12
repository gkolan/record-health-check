/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Tests for AccountOpenOpportunityHealthCheck — the Apex example that fails when
 * any open Opportunity is simultaneously stale, missing Next Step, and not
 * closing this quarter.
 */
@IsTest
private class AccountOpenOpportunityHealthCheckTest {
  @IsTest
  static void noOpenOpportunitiesPasses() {
    Account account = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'RHC Opp Health None' }
    );
    RHCIntegrationTestDataFactory.createAccount(account);

    RecordHealthCheckInternalResult result = evaluate(account.Id, null);

    Assert.areEqual(
      'PASS',
      result.status,
      'An Account without open opportunities must pass.'
    );
    Assert.areEqual(
      '0',
      result.actualValue,
      'An Account without open opportunities must report zero unhealthy deals.'
    );
    Assert.areEqual(
      '0',
      result.expectedValue,
      'The required unhealthy deal count must be zero.'
    );
  }

  @IsTest
  static void healthyOpenOpportunityPasses() {
    Account account = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'RHC Opp Health Healthy' }
    );
    RHCIntegrationTestDataFactory.createAccount(account);

    Date inQuarter = AccountOpenOpportunityHealthCheck.getQuarterStart(
      Date.today()
    );
    RHCIntegrationTestDataFactory.createOpportunity(
      new Map<String, Object>{
        'AccountId' => account.Id,
        'Name' => 'Healthy deal',
        'StageName' => 'Prospecting',
        'NextStep' => 'Schedule demo',
        'CloseDate' => inQuarter
      }
    );

    RecordHealthCheckInternalResult result = evaluate(account.Id, null);

    Assert.areEqual(
      'PASS',
      result.status,
      'A deal with a Next Step closing this quarter is healthy.'
    );
    Assert.areEqual(
      '0',
      result.actualValue,
      'A healthy open opportunity must not count as unhealthy.'
    );
    Assert.areEqual(
      '0',
      result.expectedValue,
      'A healthy deal result must retain the zero unhealthy-deal target.'
    );
  }

  @IsTest
  static void unhealthyOpenOpportunityFails() {
    Account account = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'RHC Opp Health Unhealthy' }
    );
    RHCIntegrationTestDataFactory.createAccount(account);

    // No Next Step, closing far in the future, and (by default) no activity
    // stale, so the deal is unhealthy.
    RHCIntegrationTestDataFactory.createOpportunity(
      new Map<String, Object>{
        'AccountId' => account.Id,
        'Name' => 'Neglected deal',
        'StageName' => 'Prospecting',
        'CloseDate' => Date.today().addYears(2)
      }
    );

    RecordHealthCheckInternalResult result = evaluate(account.Id, null);

    Assert.areEqual(
      'FAIL',
      result.status,
      'An unhealthy open opportunity must fail.'
    );
    Assert.areEqual(
      '1',
      result.actualValue,
      'The unhealthy opportunity must count exactly once.'
    );
    Assert.areEqual(
      '0',
      result.expectedValue,
      'The failed result must retain the zero unhealthy-deal target.'
    );
  }

  @IsTest
  static void staleDaysParametersFallBackSafely() {
    Account account = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'RHC Opp Health Parameters' }
    );
    RHCIntegrationTestDataFactory.createAccount(account);

    for (
      Map<String, Object> parameters : new List<Map<String, Object>>{
        new Map<String, Object>(),
        new Map<String, Object>{ 'staleDays' => null },
        new Map<String, Object>{ 'staleDays' => 0 },
        new Map<String, Object>{ 'staleDays' => 3651 },
        new Map<String, Object>{ 'staleDays' => 'not-a-number' },
        new Map<String, Object>{ 'staleDays' => 1 }
      }
    ) {
      Assert.areEqual(
        'PASS',
        evaluate(account.Id, parameters).status,
        'Parameter parsing should never prevent evaluation.'
      );
    }
  }

  @IsTest
  static void nullParametersUseDefaultStaleWindow() {
    Test.startTest();
    Integer days = new AccountOpenOpportunityHealthCheck()
      .resolveStaleDays(null);
    Test.stopTest();

    Assert.areEqual(
      30,
      days,
      'Null parameters should use the documented 30-day default.'
    );
  }

  @IsTest
  static void isUnhealthyEvaluatesEachCriterion() {
    Date staleCutoff = Date.today().addDays(-30);
    Date quarterStart = AccountOpenOpportunityHealthCheck.getQuarterStart(
      Date.today()
    );
    Date quarterEnd = quarterStart.addMonths(3).addDays(-1);

    // LastActivityDate is a read-only system field and cannot be assigned in
    // Apex; a freshly constructed Opportunity already has it null, which counts
    // as stale.
    Opportunity unhealthy = RecordHealthCheckTestDataFactory.opportunity(
      new Map<String, Object>{
        'NextStep' => null,
        'CloseDate' => quarterStart.addMonths(6)
      }
    );
    Assert.areEqual(
      true,
      AccountOpenOpportunityHealthCheck.isUnhealthy(
        unhealthy,
        staleCutoff,
        quarterStart,
        quarterEnd
      ),
      'Missing activity and next step outside the quarter must be unhealthy.'
    );

    // A Next Step alone is enough to make it healthy (AND logic).
    Opportunity hasNextStep = RecordHealthCheckTestDataFactory.opportunity(
      new Map<String, Object>{
        'NextStep' => 'Follow up',
        'CloseDate' => quarterStart.addMonths(6)
      }
    );
    Assert.areEqual(
      false,
      AccountOpenOpportunityHealthCheck.isUnhealthy(
        hasNextStep,
        staleCutoff,
        quarterStart,
        quarterEnd
      ),
      'A next step alone must break the conjunction of unhealthy criteria.'
    );

    Opportunity explicitlyStale = (Opportunity) JSON.deserialize(
      '{"attributes":{"type":"Opportunity"},"LastActivityDate":"' +
        String.valueOf(staleCutoff.addDays(-1)) +
        '","CloseDate":"' +
        String.valueOf(quarterEnd.addDays(1)) +
        '"}',
      Opportunity.class
    );
    Assert.areEqual(
      true,
      AccountOpenOpportunityHealthCheck.isUnhealthy(
        explicitlyStale,
        staleCutoff,
        quarterStart,
        quarterEnd
      ),
      'An activity date before the stale cutoff should count as stale.'
    );
  }

  @IsTest
  static void getQuarterStartReturnsFirstDayOfQuarter() {
    Assert.areEqual(
      Date.newInstance(2026, 1, 1),
      AccountOpenOpportunityHealthCheck.getQuarterStart(
        Date.newInstance(2026, 2, 14)
      ),
      'A February date must resolve to the first-quarter start.'
    );
    Assert.areEqual(
      Date.newInstance(2026, 10, 1),
      AccountOpenOpportunityHealthCheck.getQuarterStart(
        Date.newInstance(2026, 12, 31)
      ),
      'The last day of December must resolve to the fourth-quarter start.'
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
    RecordHealthCheckOutcome outcome = new AccountOpenOpportunityHealthCheck()
      .evaluate(
        new RecordHealthCheckScope(
          'Account',
          new List<Id>{ recordId },
          parameters,
          'Example_Open_Opportunities_Are_Healthy',
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
