/**
 * Extend this class from a test and call verifyContract(). It supplies evidence
 * across several scope sizes; it does not claim runtime proof of query access mode.
 */
global abstract class RecordHealthCheckRuleContractTest {
  private static final List<Integer> SCOPE_SIZES = new List<Integer>{
    1,
    10,
    50,
    200
  };
  private static final Integer QUERY_GROWTH_TOLERANCE = 2;
  private static final Integer SAVEPOINT_LIFECYCLE_DML_STATEMENTS = 2;

  /** Returns a new plugin instance for each measured scope. */
  global abstract RecordHealthCheckRule newRule();

  /** Returns the author's scope and optional permission test-data provider. */
  global abstract RecordHealthCheckRuleContractTestData testData();

  /** Runs the complete bulk, coverage, forbidden-write, and permission evidence suite. */
  global void verifyContract() {
    List<Integer> queryDeltas = new List<Integer>();
    for (Integer size : SCOPE_SIZES) {
      RecordHealthCheckScope scope = testData().createScope(size);
      System.Assert.areEqual(
        size,
        scope.size(),
        'The fixture must build the requested scope size.'
      );

      Integer queriesBefore = Limits.getQueries();
      Integer dmlBefore = Limits.getDmlStatements();
      Integer dmlRowsBefore = Limits.getDmlRows();
      Integer calloutsBefore = Limits.getCallouts();
      Integer queueablesBefore = Limits.getQueueableJobs();
      Integer futuresBefore = Limits.getFutureCalls();
      Integer emailsBefore = Limits.getEmailInvocations();

      Map<Id, RecordHealthCheckOutcome> outcomes = RecordHealthCheckPluginDispatch.run(
        newRule(),
        scope
      );

      Integer queryDelta = Limits.getQueries() - queriesBefore;
      queryDeltas.add(queryDelta);
      System.Assert.isTrue(
        hasStableQueryGrowth(queryDeltas),
        'Query growth must stay approximately constant across scopes 1, 10, 50, and 200. Observed: ' +
        JSON.serialize(queryDeltas)
      );
      System.Assert.areEqual(
        new Set<Id>(scope.recordIds),
        outcomes.keySet(),
        'The plugin must return exactly one outcome for every requested Id.'
      );
      System.Assert.areEqual(
        SAVEPOINT_LIFECYCLE_DML_STATEMENTS,
        Limits.getDmlStatements() - dmlBefore,
        'Only the dispatcher savepoint creation and release may consume DML statements.'
      );
      System.Assert.areEqual(
        0,
        Limits.getDmlRows() - dmlRowsBefore,
        'A health check must not mutate rows.'
      );
      System.Assert.areEqual(
        calloutsBefore,
        Limits.getCallouts(),
        'A health check must not make callouts.'
      );
      System.Assert.areEqual(
        queueablesBefore,
        Limits.getQueueableJobs(),
        'A health check must not enqueue work.'
      );
      System.Assert.areEqual(
        futuresBefore,
        Limits.getFutureCalls(),
        'A health check must not call a future method.'
      );
      System.Assert.areEqual(
        emailsBefore,
        Limits.getEmailInvocations(),
        'A health check must not send email.'
      );
    }

    RecordHealthCheckRuleContractTestData.PermissionFixture fixture = testData()
      .permissionFixture();
    System.Assert.isTrue(
      fixture == null || hasPermissionEvidence(newRule(), fixture),
      'The controlled permission test setup must yield the expected status without leaking values.'
    );
  }

  /** Evaluates measured query deltas without throwing, for contract self-tests. */
  global static Boolean hasStableQueryGrowth(List<Integer> queryDeltas) {
    if (queryDeltas == null || queryDeltas.isEmpty()) {
      return false;
    }
    Integer smallest = queryDeltas[0];
    for (Integer delta : queryDeltas) {
      if (delta == null || delta > smallest + QUERY_GROWTH_TOLERANCE) {
        return false;
      }
    }
    return true;
  }

  /** Runs one controlled least-privilege test setup without claiming access-mode proof. */
  global static Boolean hasPermissionEvidence(
    RecordHealthCheckRule rule,
    RecordHealthCheckRuleContractTestData.PermissionFixture fixture
  ) {
    if (
      rule == null ||
      fixture == null ||
      fixture.leastPrivilegeUser == null ||
      fixture.scope == null ||
      fixture.assertedRecordId == null
    ) {
      return false;
    }
    Boolean matches = false;
    try {
      System.runAs(fixture.leastPrivilegeUser) {
        Map<Id, RecordHealthCheckOutcome> outcomes = RecordHealthCheckPluginDispatch.run(
          rule,
          fixture.scope
        );
        RecordHealthCheckOutcome outcome = outcomes.get(
          fixture.assertedRecordId
        );
        matches =
          outcome != null &&
          fixture.expectedStatus == outcome.status &&
          outcome.found == null &&
          outcome.expected == null;
      }
    } catch (Exception ex) {
      return false;
    }
    return matches;
  }
}
