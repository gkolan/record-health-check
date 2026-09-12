/** Org-backed contract for the valid RHC_Plugin_Compatibility fixture. */
@IsTest
private class RHCPluginCompatibilityTest {
  static {
    RecordHealthCheckAccess.setRunPermissionForTest(true);
  }

  @IsTest
  static void publicApexSetPreservesEveryPluginOutcome() {
    List<Account> accounts = new List<Account>{
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'Name' => 'RHC Plugin Compatibility Healthy' }
      ),
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{
          'Name' => 'RHC Plugin Compatibility [FAIL] Needs Review'
        }
      ),
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{
          'Name' => 'RHC Plugin Compatibility [SKIP] Not Applicable'
        }
      ),
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{
          'Name' => 'RHC Plugin Compatibility [UNABLE] Missing Data'
        }
      )
    };
    RHCIntegrationTestDataFactory.createAccounts(accounts);
    RHCPluginCompatibilityFixture.constructorCount = 0;
    RHCPluginCompatibilityFixture.evaluateCount = 0;

    RecordHealthCheckResponse response = RecordHealthCheck.evaluate(
      RecordHealthCheckRequest.forCheckSet(
          RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
            'RHC_Plugin_Compatibility'
          ),
          new List<Id>{
            accounts[0].Id,
            accounts[1].Id,
            accounts[2].Id,
            accounts[3].Id
          }
        )
        .withRunId('plugin-compatibility-matrix')
    );

    Assert.areEqual(
      4,
      response.results.size(),
      'The compatibility matrix must return all four results.'
    );
    Map<Id, RecordHealthCheckEvaluationResult> byRecord = new Map<Id, RecordHealthCheckEvaluationResult>();
    for (RecordHealthCheckResultItem item : response.results) {
      byRecord.put(item.evaluation.recordId, item.evaluation);
    }
    assertOutcome(
      byRecord.get(accounts[0].Id),
      'PASS',
      'PLUGIN_COMPATIBILITY_PASS'
    );
    assertOutcome(
      byRecord.get(accounts[1].Id),
      'FAIL',
      'PLUGIN_COMPATIBILITY_NEEDS_REVIEW'
    );
    assertOutcome(
      byRecord.get(accounts[2].Id),
      'SKIPPED',
      'PLUGIN_COMPATIBILITY_NOT_APPLICABLE'
    );
    assertOutcome(
      byRecord.get(accounts[3].Id),
      'UNABLE_TO_EVALUATE',
      'PLUGIN_COMPATIBILITY_DATA_UNAVAILABLE'
    );
    Assert.areEqual(
      1,
      RHCPluginCompatibilityFixture.constructorCount,
      'Validation and execution must hand off one constructed plugin instance.'
    );
    Assert.areEqual(
      1,
      RHCPluginCompatibilityFixture.evaluateCount,
      'The plugin must evaluate the complete record scope exactly once.'
    );
  }

  private static void assertOutcome(
    RecordHealthCheckEvaluationResult result,
    String expectedStatus,
    String expectedReason
  ) {
    Assert.isNotNull(result, 'Every requested Account must return a result.');
    Assert.areEqual(
      expectedStatus,
      result.status,
      'The plugin must preserve the expected compatibility status.'
    );
    Assert.areEqual(
      expectedReason,
      result.reasonCode,
      'The plugin must preserve the expected compatibility reason.'
    );
    Assert.isTrue(
      result.checkQualifiedApiName.endsWith('RHC_Plugin_Compatibility_Matrix'),
      'The result must retain the compatibility Check identity.'
    );
  }
}
