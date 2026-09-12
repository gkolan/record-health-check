/** Tests authorized Check configuration and resolution trace serialization. */
@IsTest
private class RecordHealthCheckDiagnosticTraceTest {
  @IsTest
  static void shouldSerializeConfigurationAndResolvedQuery() {
    Account record = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Id' => RecordHealthCheckTestDataFactory.syntheticId(
          Account.SObjectType,
          1
        )
      }
    );
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'EvaluationType__c' => 'QUERY',
        'SourceQuery__c' => 'SELECT Id FROM Account WHERE Id = {!record.Id}',
        'ComparisonOperator__c' => 'EQUALS'
      }
    );
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.status = RecordHealthCheckStatus.PASS;
    result.actualValue = '1';
    RecordHealthCheckAdminDetail detail = new RecordHealthCheckAdminDetail();

    Test.startTest();
    RecordHealthCheckDiagnosticTrace.populate(check, record, result, detail);
    Test.stopTest();

    Assert.isTrue(
      detail.configurationJson.contains('sourceQueryTemplate'),
      'Authorized configuration detail must include the original query template.'
    );
    Assert.isTrue(
      detail.resolutionJson.contains('sourceQueryAfterMerge'),
      'Authorized resolution detail must include the query after merging.'
    );
    Assert.isTrue(
      detail.resolutionJson.contains('WITH USER_MODE'),
      'The resolved diagnostic query must retain USER_MODE enforcement.'
    );
  }

  @IsTest
  static void shouldCaptureQueryResolutionFailure() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'EvaluationType__c' => 'QUERY',
        'SourceQuery__c' => 'SELECT Id FROM Account WHERE Name = {!record.Missing__c}'
      }
    );
    RecordHealthCheckAdminDetail detail = new RecordHealthCheckAdminDetail();

    Test.startTest();
    RecordHealthCheckDiagnosticTrace.populate(
      check,
      RecordHealthCheckTestDataFactory.account(new Map<String, Object>()),
      new RecordHealthCheckInternalResult(),
      detail
    );
    Test.stopTest();

    Assert.isTrue(
      detail.resolutionJson.contains('sourceQueryResolutionError'),
      'Trace generation must report resolution failures without changing evaluation.'
    );
  }

  @IsTest
  static void shouldShowTheSameProbeLimitUsedByQueryExecution() {
    Account record = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Id' => RecordHealthCheckTestDataFactory.syntheticId(
          Account.SObjectType,
          1
        )
      }
    );
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'EvaluationType__c' => 'QUERY',
        'SourceQuery__c' => 'SELECT Id FROM Account WHERE Id != null',
        'MaxQueryRows__c' => 100
      }
    );
    RecordHealthCheckAdminDetail detail = new RecordHealthCheckAdminDetail();

    Test.startTest();
    RecordHealthCheckDiagnosticTrace.populate(
      check,
      record,
      new RecordHealthCheckInternalResult(),
      detail
    );
    Test.stopTest();

    Map<String, Object> resolution = (Map<String, Object>) JSON.deserializeUntyped(
      detail.resolutionJson
    );
    Assert.isTrue(
      String.valueOf(resolution.get('sourceQueryPreparedPerRecordQuery'))
        .endsWith('LIMIT 101'),
      'The diagnostic query must show the cap-plus-one probe that execution actually runs.'
    );
  }

  @IsTest
  static void diagnosticVersionAndVisibilityRemainExplicit() {
    for (String version : new List<String>{ null, '', '2.0' }) {
      RecordHealthCheckDiagnosticRuntime.validateVersion(version);
    }
    try {
      RecordHealthCheckDiagnosticRuntime.validateVersion('unsupported');
      Assert.fail('Unsupported diagnostic versions must be rejected.');
    } catch (RecordHealthCheckScopePipeline.ScopePipelineException ex) {
      Assert.areEqual(
        'UNSUPPORTED_DIAGNOSTIC_VERSION',
        ex.getMessage(),
        'Version rejection must retain its machine reason.'
      );
    }
    List<RecordHealthCheckResultItem> items = new List<RecordHealthCheckResultItem>();
    RecordHealthCheckResponse response = new RecordHealthCheckResponse();
    RecordHealthCheckDiagnosticRuntime.attach(response, items, null, true);
    Assert.isNull(
      response.diagnosticItems,
      'Diagnostics must be absent without explicit version opt-in.'
    );
    RecordHealthCheckDiagnosticRuntime.attach(response, items, '2.0', false);
    Assert.isFalse(
      response.diagnosticProjectionAuthorized,
      'A disabled Check Set must not authorize diagnostic projection.'
    );
    Assert.isNull(
      response.diagnosticItems,
      'Disabled diagnostic projection must omit its payload.'
    );
    RecordHealthCheckDiagnosticRuntime.attach(response, items, '2.0', true);
    Boolean entitled = RecordHealthCheckAccess.canViewDetails();
    Assert.areEqual(
      entitled,
      response.diagnosticProjectionAuthorized,
      'A Check Set opt-in must still require the current user entitlement.'
    );
    Assert.areEqual(
      entitled ? items : null,
      response.diagnosticItems,
      'Only an entitled caller receives the requested diagnostic items.'
    );
  }
}
