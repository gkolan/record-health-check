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

    Assert.isTrue(detail.configurationJson.contains('sourceQueryTemplate'));
    Assert.isTrue(detail.resolutionJson.contains('sourceQueryAfterMerge'));
    Assert.isTrue(detail.resolutionJson.contains('WITH USER_MODE'));
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
}
