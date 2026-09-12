/** Verifies the packaged recent-activity definition and evidence contract. */
@IsTest
private class RHCRecentActivityContractTest {
  @IsTest
  static void definitionDeclaresTypedParametersAndBulkCapacity() {
    RecordHealthCheckPluginDefinition definition = new AccountHasRecentActivityCheck()
      .getDefinition();

    Assert.areEqual(
      new List<String>{ 'daysBack', 'minimumActivities' },
      definition.parameterKeys(),
      'The shipped JSON example must be backed by an ordered, typed definition.'
    );
    RecordHealthCheckPluginDefinition.ParameterDefinition daysBack = definition.parameter(
      'daysBack'
    );
    Assert.areEqual(
      'INTEGER',
      daysBack.typeName,
      'The activity window must be declared as a typed integer parameter.'
    );
    Assert.areEqual(
      30,
      daysBack.defaultValue,
      'The example must default to a thirty-day activity window.'
    );
    Assert.areEqual(
      1,
      daysBack.minValue,
      'The activity window must exclude zero-day configurations.'
    );
    Assert.areEqual(
      3650,
      daysBack.maxValue,
      'The declared activity window must retain its documented upper bound.'
    );
    Assert.areEqual(
      200,
      definition.maxScopeSize(),
      'The example must declare support for a two-hundred-record scope.'
    );
    Assert.areEqual(
      true,
      definition.bulkSafe(),
      'The example definition must advertise bulk-safe execution.'
    );
    Assert.areEqual(
      'LOW',
      definition.estimatedCost(),
      'The example definition must retain its low-cost declaration.'
    );
  }

  @IsTest
  static void positiveAndNegativeOutcomesIncludeTypedEvidence() {
    Account account = RecordHealthCheckTestDataFactory.accountFixture(
      'RHC 2.0.10 Evidence'
    );
    RecordHealthCheckOutcome passing = AccountHasRecentActivityCheck.outcomeFor(
      2,
      2,
      60,
      account.Id
    );
    RecordHealthCheckOutcome failing = AccountHasRecentActivityCheck.outcomeFor(
      0,
      2,
      60,
      account.Id
    );

    Assert.areEqual(
      RecordHealthCheckStatus.PASS,
      passing.status,
      'Meeting the activity threshold must produce a passing outcome.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.FAIL,
      failing.status,
      'Missing the activity threshold must produce a failing outcome.'
    );
    Assert.areEqual(
      4,
      passing.evidence.columns.size(),
      'The evidence schema must retain all four explanatory columns.'
    );
    Assert.areEqual(
      1,
      passing.evidence.rows.size(),
      'A positive outcome must retain its summary evidence row.'
    );
    Assert.areEqual(
      '2',
      passing.evidence.rows[0][1].typedValue.storedValue,
      'Evidence must carry the observed completed-activity count.'
    );
    Assert.areEqual(
      '0',
      failing.evidence.rows[0][1].typedValue.storedValue,
      'The negative example must retain zero as evidence, not treat it as missing.'
    );
    Assert.areEqual(
      'windowDays',
      passing.evidence.stepGroupKey,
      'Evidence step grouping must use the activity-window column.'
    );
    Assert.areEqual(
      'accountId',
      passing.evidence.ruleGroupKey,
      'Evidence rule grouping must use the Account identity column.'
    );
  }
}
