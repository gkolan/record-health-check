/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

@IsTest
private class RecordHealthCheckApiIT {
  static {
    RecordHealthCheckAccess.setRunPermissionForTest(true);
  }

  private class EnabledLogSettingsProvider extends RecordHealthCheckSettingsProvider {
    public override Boolean isErrorEventPublicationEnabled(
      String checkSetQualifiedApiName
    ) {
      return true;
    }
  }

  @TestSetup
  static void setup() {
    RHCIntegrationTestDataFactory.createTestRecords();
  }

  @IsTest
  static void evaluateCheckReturnsStableEnvelope() {
    Account accountRecord = RHCIntegrationTestDataFactory.getHealthyAccount();
    RecordHealthCheckResponse response = RecordHealthCheck.evaluate(
      RecordHealthCheckRequest.forCheck(
        RecordHealthCheckTestDataFactory.qualifiedCheckName(
          'Example_Website_URL_Valid'
        ),
        accountRecord.Id
      )
    );
    Assert.areEqual(
      1,
      response.results.size(),
      'A single Check request must return exactly one aligned result.'
    );
    Assert.areEqual(
      RecordHealthCheckTestDataFactory.qualifiedCheckName(
        'Example_Website_URL_Valid'
      ),
      response.results[0].evaluation.checkQualifiedApiName,
      'The result must preserve the requested qualified Check identity.'
    );
    Assert.areNotEqual(
      null,
      response.results[0].evaluation.status,
      'The public evaluation envelope must include a terminal status.'
    );
  }

  @IsTest
  static void explicitRunIdIsPreserved() {
    Account accountRecord = RHCIntegrationTestDataFactory.getHealthyAccount();
    RecordHealthCheckResponse response = RecordHealthCheck.evaluate(
      RecordHealthCheckRequest.forCheck(
          RecordHealthCheckTestDataFactory.qualifiedCheckName(
            'Example_Website_URL_Valid'
          ),
          accountRecord.Id
        )
        .withRunId('ticket-12345')
    );
    Assert.areEqual(
      'ticket-12345',
      response.runId,
      'An explicit caller run identifier must survive single-Check evaluation.'
    );
  }

  @IsTest
  static void publicFacadeFlushesHeldDiagnosticsOnFailure() {
    RecordHealthCheckLogger.settingsProvider = new EnabledLogSettingsProvider();
    RecordHealthCheckLogger.log(
      RecordHealthCheckLogger.Level.ERROR,
      'facade-flush-run',
      null,
      null,
      null,
      'SYNTHETIC_HELD_ERROR',
      null,
      null
    );
    Assert.areEqual(
      1,
      RecordHealthCheckLogger.pendingEventCount(),
      'The test must begin with one held diagnostic event.'
    );

    Test.startTest();
    try {
      RecordHealthCheck.evaluate(null);
      Assert.fail(
        'A null request must fail after the facade flushes diagnostics.'
      );
    } catch (RecordHealthCheckScopePipeline.ScopePipelineException error) {
      Assert.isTrue(
        error.getMessage().contains('request is required'),
        'The original request exception must survive the flush boundary.'
      );
    }
    Test.stopTest();

    Assert.areEqual(
      0,
      RecordHealthCheckLogger.pendingEventCount(),
      'The public facade must clear held diagnostics even when evaluation throws.'
    );
  }

  @IsTest
  static void unknownQualifiedIdentityThrows() {
    Account accountRecord = RHCIntegrationTestDataFactory.getHealthyAccount();
    try {
      RecordHealthCheck.evaluate(
        RecordHealthCheckRequest.forCheck('No_Such_Check', accountRecord.Id)
      );
      Assert.isTrue(false, 'Expected unknown identity to fail.');
    } catch (RecordHealthCheckScopePipeline.ScopePipelineException expected) {
      Assert.isTrue(
        expected.getMessage().contains('was not found'),
        'An unknown qualified identity must report that the Check was not found.'
      );
    }
  }

  @IsTest
  static void evaluateSetReturnsCountsAndResults() {
    Account accountRecord = RHCIntegrationTestDataFactory.getHealthyAccount();
    RecordHealthCheckResponse response = RecordHealthCheck.evaluate(
      RecordHealthCheckRequest.forCheckSet(
          RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
            'Example_Account_Check_Builder_Guide'
          ),
          accountRecord.Id
        )
        .withRunId('set-test-run')
    );
    Assert.areEqual(
      'set-test-run',
      response.runId,
      'An explicit caller run identifier must survive Check Set evaluation.'
    );
    Assert.areEqual(
      25,
      response.results.size(),
      'The Apex API must return every Check in the four-evaluator release set.'
    );
    Assert.areEqual(
      new Set<String>{ 'APEX', 'COMPARE_TWO_QUERIES', 'FORMULA', 'QUERY' },
      evaluationTypes(response),
      'The Apex API response must contain results from every evaluator type.'
    );
    Assert.areEqual(
      response.results.size(),
      response.summary.passed +
        response.summary.failed +
        response.summary.skipped +
        response.summary.unable +
        response.summary.systemError,
      'Summary status counts must account for every returned Check result.'
    );
  }

  @IsTest
  static void scopePreservesInputOrder() {
    Account first = RHCIntegrationTestDataFactory.getHealthyAccount();
    Account second = RHCIntegrationTestDataFactory.createAccount(
      'Second account'
    );
    RecordHealthCheckResponse response = RecordHealthCheck.evaluate(
      RecordHealthCheckRequest.forCheck(
        RecordHealthCheckTestDataFactory.qualifiedCheckName(
          'Example_Website_URL_Valid'
        ),
        new List<Id>{ first.Id, second.Id }
      )
    );
    Assert.areEqual(
      first.Id,
      response.results[0].evaluation.recordId,
      'The first result must correspond to the first supplied record.'
    );
    Assert.areEqual(
      second.Id,
      response.results[1].evaluation.recordId,
      'The second result must correspond to the second supplied record.'
    );
  }

  @IsTest
  static void scopeLimitNamesCeilingAndSuppliedCount() {
    List<Id> ids = new List<Id>();
    for (
      Integer index = 0;
      index <= RecordHealthCheckConstants.MAX_RECORDS_PER_SCOPE;
      index++
    ) {
      ids.add(
        RecordHealthCheckTestDataFactory.syntheticId(
          Account.SObjectType,
          index + 1
        )
      );
    }
    try {
      RecordHealthCheck.evaluate(
        RecordHealthCheckRequest.forCheck(
          RecordHealthCheckTestDataFactory.qualifiedCheckName(
            'Example_Website_URL_Valid'
          ),
          ids
        )
      );
      Assert.isTrue(false, 'Expected record scope limit.');
    } catch (RecordHealthCheckScopePipeline.ScopePipelineException expected) {
      Assert.isTrue(
        expected.getMessage().contains('uniqueCount=201'),
        'Scope-limit diagnostics must identify the supplied unique record count.'
      );
      Assert.isTrue(
        expected.getMessage().contains('ceiling=200'),
        'Scope-limit diagnostics must identify the supported two-hundred-record ceiling.'
      );
    }
  }

  private static Set<String> evaluationTypes(
    RecordHealthCheckResponse response
  ) {
    Set<String> checkNames = new Set<String>();
    for (RecordHealthCheckResultItem item : response.results) {
      checkNames.add(item.evaluation.checkQualifiedApiName);
    }
    Map<String, Record_Health_Check__mdt> checksByQualifiedName = new Map<String, Record_Health_Check__mdt>();
    for (Record_Health_Check__mdt configuredCheck : [
      SELECT QualifiedApiName, EvaluationType__c
      FROM Record_Health_Check__mdt
      WHERE QualifiedApiName IN :checkNames
    ]) {
      checksByQualifiedName.put(
        configuredCheck.QualifiedApiName,
        configuredCheck
      );
    }
    Set<String> types = new Set<String>();
    for (String checkName : checkNames) {
      Record_Health_Check__mdt configuredCheck = checksByQualifiedName.get(
        checkName
      );
      Assert.isNotNull(
        configuredCheck,
        'Every Apex API result identity must resolve to Custom Metadata.'
      );
      types.add(configuredCheck.EvaluationType__c);
    }
    return types;
  }
}
