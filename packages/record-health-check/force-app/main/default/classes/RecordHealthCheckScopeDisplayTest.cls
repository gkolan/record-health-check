/**
 * Verifies qualified selection, scope validation, ordering, and response modes.
 */
@IsTest
private with sharing class RecordHealthCheckScopeDisplayTest {
  private static final String PHONE_CHECK = 'Example_Profile_Phone_Available';

  @IsTest
  static void displayFinalizationHandlesActionTemplateFailure() {
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.status = RecordHealthCheckStatus.FAIL;
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'ActionUrl__c' => '/{!bad.value}' // rejected-token-fixture: intentional invalid namespace
      }
    );

    Test.startTest();
    new RecordHealthCheckScopeResultSupport()
      .finalizeDisplay(
        check,
        RecordHealthCheckTestDataFactory.account(
          new Map<String, Object>{ 'Name' => 'Action' }
        ),
        result,
        false
      );
    Test.stopTest();

    Assert.isNotNull(
      result.detailMessage,
      'An invalid action template must be retained as diagnostic detail.'
    );
  }

  @IsTest
  static void displayItemHidesRawFormulaConditionWithoutEntitlement() {
    User userWithoutPermission = RecordHealthCheckPersonaTestDataFactory.createMinimumAccessUser(
      'rhchide'
    );
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.status = RecordHealthCheckStatus.FAIL;
    result.expectedValue = 'Name = "Acme"';
    result.expectedValueLabel = RecordHealthCheckInternalResult.PASSES_WHEN_LABEL;
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{ 'QualifiedApiName' => 'Example.Check' }
    );

    Test.startTest();
    RecordHealthCheckResultItem item;
    System.runAs(userWithoutPermission) {
      item = new RecordHealthCheckScopeResultSupport()
        .toItem(
          check,
          userWithoutPermission.Id,
          result,
          RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY
        );
    }
    Test.stopTest();

    Assert.isNull(
      item.display.expectedDisplayValue,
      'Raw Formula conditions require the diagnostics entitlement.'
    );
    Assert.isNull(
      item.display.expectedValueLabel,
      'The semantic label must be hidden with its restricted Formula text.'
    );
  }

  @IsTest
  static void displayFinalizationBuildsDefaultActionAndAdminDetail() {
    User diagnosticsUser = RecordHealthCheckPersonaTestDataFactory.createMinimumAccessUser(
      'rhcdiag'
    );
    RecordHealthCheckTestDataFactory.assignPermissionSet(
      diagnosticsUser,
      'Record_Health_Check_Admin'
    );
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.status = RecordHealthCheckStatus.FAIL;
    result.reasonCode = 'TEST_REASON';
    result.detailMessage = 'Diagnostic detail';
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'ActionUrl__c' => '/lightning/page/home',
        'EvaluationType__c' => 'QUERY',
        'SourceQuery__c' => 'SELECT Id FROM Account WHERE Id = {!record.Id}'
      }
    );

    Test.startTest();
    System.runAs(diagnosticsUser) {
      new RecordHealthCheckScopeResultSupport()
        .finalizeDisplay(
          check,
          RecordHealthCheckTestDataFactory.account(
            new Map<String, Object>{ 'Name' => 'Action' }
          ),
          result,
          true
        );
    }
    Test.stopTest();

    Assert.areEqual('Fix this', result.actionLabel);
    Assert.areEqual('/lightning/page/home', result.actionUrl);
    Assert.areEqual('Diagnostic detail', result.adminDetail.message);
    Assert.isTrue(
      result.adminDetail.configurationJson.contains('sourceQueryTemplate'),
      'Authorized diagnostics must include the authored query template.'
    );
    Assert.isTrue(
      result.adminDetail.resolutionJson.contains('sourceQueryAfterMerge'),
      'Authorized diagnostics must include the query after token resolution.'
    );
  }

  @IsTest
  static void displayFinalizationIgnoresNullResult() {
    Integer queriesBefore = Limits.getQueries();
    Integer dmlBefore = Limits.getDmlStatements();
    Test.startTest();
    new RecordHealthCheckScopeResultSupport()
      .finalizeDisplay(
        RecordHealthCheckTestDataFactory.check(new Map<String, Object>()),
        null,
        null,
        false
      );
    Test.stopTest();

    Assert.areEqual(
      queriesBefore,
      Limits.getQueries(),
      'A null result must return before resolving display fields.'
    );
    Assert.areEqual(
      dmlBefore,
      Limits.getDmlStatements(),
      'Display finalization must never mutate data.'
    );
  }

  @IsTest
  static void displayFinalizationPreservesBracesInResolvedRecordData() {
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.status = RecordHealthCheckStatus.FAIL;
    result.message = 'Account {!record.Name} needs contacts';
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>()
    );

    Test.startTest();
    new RecordHealthCheckScopeResultSupport()
      .finalizeDisplay(
        check,
        RecordHealthCheckTestDataFactory.account(
          new Map<String, Object>{ 'Name' => 'Acme {Labs}' }
        ),
        result,
        false
      );
    Test.stopTest();

    Assert.areEqual(
      'Account Acme {Labs} needs contacts',
      result.message,
      'Record data braces must remain ordinary display text.'
    );
  }

  @IsTest
  static void displayFinalizationResolvesRunTokens() {
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.status = RecordHealthCheckStatus.FAIL;
    result.message = 'Run {!rhcRun.runId} from {!rhcRun.source}';
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>()
    );

    Test.startTest();
    new RecordHealthCheckScopeResultSupport()
      .withRunContext(
        new RecordHealthCheckRunContext('run-display-test', 'USER_INITIATED')
      )
      .finalizeDisplay(
        check,
        RecordHealthCheckTestDataFactory.account(
          new Map<String, Object>{ 'Name' => 'Run context' }
        ),
        result,
        false
      );
    Test.stopTest();

    Assert.areEqual(
      'Run run-display-test from USER_INITIATED',
      result.message,
      'Valid run tokens must resolve during final display rendering.'
    );
  }

  @IsTest
  static void itemConversionHandlesMissingEvaluatorResult() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{ 'QualifiedApiName' => 'Example.Check' }
    );

    Test.startTest();
    RecordHealthCheckResultItem item = new RecordHealthCheckScopeResultSupport()
      .toItem(
        check,
        UserInfo.getUserId(),
        null,
        RecordHealthCheckResultMode.EVALUATION
      );
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckStatus.UNABLE_TO_EVALUATE,
      item.evaluation.status,
      'A missing evaluator result must degrade to an unavailable item.'
    );
  }

  @IsTest
  static void helperDefaultsCoverEmptyAggregateAndUnsafeScheme() {
    AggregateResult emptyAggregate = (AggregateResult) JSON.deserialize(
      '{}',
      AggregateResult.class
    );
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>()
    );
    RecordHealthCheckScopeResultSupport resultSupport = new RecordHealthCheckScopeResultSupport();

    Test.startTest();
    Integer emptyCount = resultSupport.aggregateCount(emptyAggregate);
    String unsafeScheme = resultSupport.sanitizeActionUrl('http://example.com');
    RecordHealthCheckInternalResult skipped = resultSupport.skippedResult(
      check
    );
    Test.stopTest();

    Assert.areEqual(0, emptyCount);
    Assert.isNull(
      unsafeScheme,
      'Only relative and HTTPS action URLs are allowed.'
    );
    Assert.isTrue(
      skipped.message.contains('count threshold'),
      'The default count-applicability message must explain the threshold.'
    );
  }

  private static RecordHealthCheckScopePipeline.SelectionContext evaluationContext() {
    RecordHealthCheckScopePipeline.SelectionContext context = new RecordHealthCheckScopePipeline.SelectionContext();
    context.objectApiName = 'Account';
    context.checkSetDeveloperName = 'Synthetic_Set';
    context.showDiagnostics = false;
    return context;
  }

  private static Record_Health_Check__mdt queryCountCheck(
    String developerName,
    String failureMessage
  ) {
    return RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'QualifiedApiName' => developerName,
        'DeveloperName' => developerName,
        'CheckTitle__c' => developerName,
        'EvaluationOrder__c' => 1,
        'EvaluationType__c' => 'QUERY',
        'ApplicabilityMode__c' => 'ALL_RECORDS',
        'SourceQuery__c' => 'SELECT COUNT() total FROM Contact WHERE AccountId = {!record.Id}',
        'SourceQueryField__c' => 'total',
        'QueryResultHandling__c' => 'ONE_RESULT',
        'ExpectedValueSource__c' => 'FIXED_VALUE',
        'ExpectedFixedValue__c' => '0',
        'ComparisonOperator__c' => 'GREATER_THAN',
        'EmptyValueHandling__c' => 'AS_NO_MATCH',
        'NoRowsResult__c' => 'PASS',
        'FailureSeverity__c' => 'WARNING',
        'FailureMessage__c' => failureMessage,
        'UnableToEvaluateMessage__c' => 'Unable.',
        'MaxQueryRows__c' => 100
      }
    );
  }

  private static Record_Health_Check__mdt buildCheckWithPrerequisite(
    String prerequisiteName
  ) {
    return RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'Check_B',
        'QualifiedApiName' => 'namespace__Check_B',
        'PrerequisiteCheck__c' => prerequisiteName
      }
    );
  }

  private static RecordHealthCheckResultItem buildPrerequisiteResultItem(
    Id recordId,
    String qualifiedCheckName,
    String status
  ) {
    RecordHealthCheckResultItem item = new RecordHealthCheckResultItem();
    item.evaluation = new RecordHealthCheckEvaluationResult();
    item.evaluation.recordId = recordId;
    item.evaluation.checkQualifiedApiName = qualifiedCheckName;
    item.evaluation.status = status;
    return item;
  }
}
