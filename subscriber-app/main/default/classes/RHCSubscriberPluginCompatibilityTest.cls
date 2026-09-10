/** Focused installed-package contract for subscriber-owned plugin dispatch. */
@IsTest
private class RHCSubscriberPluginCompatibilityTest {
  @IsTest
  static void subscriberPluginPreservesControlledOutcomeMatrix() {
    List<Account> accounts = new List<Account>{
      RHCSubscriberTestDataFactory.createAccount(
        'Subscriber Plugin Compatibility Healthy'
      ),
      RHCSubscriberTestDataFactory.createAccount(
        'Subscriber Plugin Compatibility [FAIL] Needs Review'
      ),
      RHCSubscriberTestDataFactory.createAccount(
        'Subscriber Plugin Compatibility [SKIP] Not Applicable'
      ),
      RHCSubscriberTestDataFactory.createAccount(
        'Subscriber Plugin Compatibility [UNABLE] Missing Data'
      )
    };
    RHCSubscriberPlugin.constructorCount = 0;
    RHCSubscriberPlugin.evaluateCount = 0;

    rhc.RecordHealthCheckResponse response = rhc.RecordHealthCheck.evaluate(
      rhc.RecordHealthCheckRequest.forCheckSet(
          RHCSubscriberTestDataFactory.qualifiedCheckSetName(
            'Subscriber_Smoke_Extension'
          ),
          new List<Id>{
            accounts[0].Id,
            accounts[1].Id,
            accounts[2].Id,
            accounts[3].Id
          }
        )
        .withRunId('subscriber-plugin-outcome-matrix')
    );

    Map<Id, rhc.RecordHealthCheckEvaluationResult> byRecord = new Map<Id, rhc.RecordHealthCheckEvaluationResult>();
    for (rhc.RecordHealthCheckResultItem item : response.results) {
      byRecord.put(item.evaluation.recordId, item.evaluation);
    }
    assertPluginOutcome(
      byRecord.get(accounts[0].Id),
      'PASS',
      'SUBSCRIBER_PLUGIN_PASS'
    );
    assertPluginOutcome(
      byRecord.get(accounts[1].Id),
      'FAIL',
      'SUBSCRIBER_PLUGIN_NEEDS_REVIEW'
    );
    assertPluginOutcome(
      byRecord.get(accounts[2].Id),
      'SKIPPED',
      'SUBSCRIBER_PLUGIN_NOT_APPLICABLE'
    );
    assertPluginOutcome(
      byRecord.get(accounts[3].Id),
      'UNABLE_TO_EVALUATE',
      'SUBSCRIBER_PLUGIN_DATA_UNAVAILABLE'
    );
    System.assertEquals(
      1,
      RHCSubscriberPlugin.constructorCount,
      'Validation and execution must share one subscriber plugin instance.'
    );
    System.assertEquals(
      1,
      RHCSubscriberPlugin.evaluateCount,
      'The subscriber plugin must evaluate the full scope once.'
    );
  }

  private static void assertPluginOutcome(
    rhc.RecordHealthCheckEvaluationResult result,
    String expectedStatus,
    String expectedReason
  ) {
    System.assertNotEquals(null, result);
    System.assertEquals(expectedStatus, result.status);
    System.assertEquals(expectedReason, result.reasonCode);
  }
}
