/**
 * Verifies qualified selection, scope validation, ordering, and response modes.
 */
@IsTest
private with sharing class RecordHealthCheckScopeDisplayTest {
  private static final String FORMULA_CHECK = 'Example_Website_URL_Valid';

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
  static void displayFinalizationBuildsDefaultActionAndAdminDetail() {
    User diagnosticsUser = RecordHealthCheckTestDataFactory.currentUser();
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
    AggregateResult populatedAggregate = [
      SELECT COUNT(Id) total
      FROM User
      WHERE Id = :UserInfo.getUserId()
    ];
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>()
    );
    RecordHealthCheckScopeResultSupport resultSupport = new RecordHealthCheckScopeResultSupport();

    Test.startTest();
    Integer emptyCount = resultSupport.aggregateCount(emptyAggregate);
    Integer populatedCount = resultSupport.aggregateCount(populatedAggregate);
    String unsafeScheme = resultSupport.sanitizeActionUrl('http://example.com');
    RecordHealthCheckInternalResult skipped = resultSupport.skippedResult(
      check
    );
    Test.stopTest();

    Assert.areEqual(0, emptyCount);
    Assert.areEqual(1, populatedCount);
    Assert.isNull(
      unsafeScheme,
      'Only relative and HTTPS action URLs are allowed.'
    );
    Assert.isTrue(
      skipped.message.contains('count threshold'),
      'The default count-applicability message must explain the threshold.'
    );
  }

  @IsTest
  static void displayFinalizationResolvesFixAndExplicitActionLabel() {
    Account record = RecordHealthCheckTestDataFactory.accountFixture(
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'Name' => 'Acme' }
      )
    );
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'FixMessage__c' => 'Fix {!record.Name}',
        'ActionUrl__c' => '/lightning/r/Account/{!record.Id}/view',
        'ActionLabel__c' => 'Open {!record.Name}'
      }
    );
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.status = RecordHealthCheckStatus.FAIL;

    new RecordHealthCheckScopeResultSupport()
      .finalizeDisplay(check, record, result, false);

    Assert.areEqual('Fix Acme', result.fixInstructions);
    Assert.areEqual('Open Acme', result.actionLabel);
    Assert.isTrue(result.actionUrl.endsWith('/view'));
  }

  @IsTest
  static void itemConversionPrefersTypedEvidenceAndHidesRawFormulaCondition() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'QualifiedApiName' => 'Typed_Evidence',
        'EvaluationType__c' => 'FORMULA'
      }
    );
    RecordHealthCheckInternalResult internalResult = new RecordHealthCheckInternalResult();
    internalResult.status = RecordHealthCheckStatus.FAIL;
    internalResult.actualValue = 'raw found';
    internalResult.expectedValue = 'raw condition';
    internalResult.evaluationFound = RecordHealthCheckValue.ofString(
      'typed found'
    );
    internalResult.evaluationExpected = RecordHealthCheckValue.ofString(
      'typed expected'
    );
    internalResult.expectedValueLabel = RecordHealthCheckInternalResult.PASSES_WHEN_LABEL;

    RecordHealthCheckResultItem item = new RecordHealthCheckScopeResultSupport()
      .toItem(
        check,
        UserInfo.getUserId(),
        internalResult,
        RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY
      );

    Assert.areEqual('typed found', item.evaluation.found.storedValue);
    Assert.areEqual('typed expected', item.evaluation.expected.storedValue);
    if (RecordHealthCheckAccess.canViewDetails()) {
      Assert.areEqual('raw condition', item.display.expectedDisplayValue);
      Assert.areEqual(
        RecordHealthCheckInternalResult.PASSES_WHEN_LABEL,
        item.display.expectedValueLabel
      );
    } else {
      Assert.areEqual(null, item.display.expectedDisplayValue);
      Assert.areEqual(null, item.display.expectedValueLabel);
    }
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
