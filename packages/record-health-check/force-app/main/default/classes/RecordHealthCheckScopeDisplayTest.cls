/**
 * Verifies display finalization, typed evidence, and authorized diagnostic projection.
 */
@IsTest
private with sharing class RecordHealthCheckScopeDisplayTest {
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

    Assert.areEqual(
      'Fix this',
      result.actionLabel,
      'An action without a label must use the default label.'
    );
    Assert.areEqual(
      '/lightning/page/home',
      result.actionUrl,
      'The safe action destination must be retained.'
    );
    Assert.areEqual(
      'Diagnostic detail',
      result.adminDetail.message,
      'Authorized admin detail must retain its diagnostic message.'
    );
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

    Assert.areEqual(0, emptyCount, 'An empty aggregate must count as zero.');
    Assert.areEqual(
      1,
      populatedCount,
      'A populated aggregate must retain its count.'
    );
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

    Assert.areEqual(
      'Fix Acme',
      result.fixInstructions,
      'The fix template must resolve the record name.'
    );
    Assert.areEqual(
      'Open Acme',
      result.actionLabel,
      'The action label must resolve the record name.'
    );
    Assert.isTrue(
      result.actionUrl.endsWith('/view'),
      'The action destination must retain its view suffix.'
    );
  }

  @IsTest
  static void structuredFixInstructionsRemainFailOnly() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'QualifiedApiName' => 'Structured_Fix_Status',
        'FixMessage__c' => 'Review {!link label="the record" href="/lightning/page/home"}'
      }
    );
    Account record = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Structured fix' }
    );
    for (String status : new List<String>{ 'PASS', 'SKIPPED' }) {
      RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
      result.status = status;
      new RecordHealthCheckStructuredDisplay(
          new RecordHealthCheckFormulaEvaluator()
        )
        .attach(check, record, result, 'Complete.');
      Assert.isNull(
        result.displayContent.fix,
        status + ' must not expose remediation instructions.'
      );
    }
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
    internalResult.displayContent = new RecordHealthCheckDisplayContent();
    internalResult.displayContent.expected = new RecordHealthCheckDisplayText()
      .text('raw condition')
      .copyNodes();

    RecordHealthCheckResultItem item = new RecordHealthCheckScopeResultSupport()
      .toItem(
        check,
        UserInfo.getUserId(),
        internalResult,
        RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY
      );

    Assert.areEqual(
      'typed found',
      item.evaluation.found.storedValue,
      'Typed found evidence must take precedence over raw text.'
    );
    Assert.areEqual(
      'typed expected',
      item.evaluation.expected.storedValue,
      'Typed expected evidence must take precedence over raw text.'
    );
    if (RecordHealthCheckAccess.canViewDetails()) {
      Assert.areEqual(
        'raw condition',
        item.display.expectedDisplayValue,
        'An authorized viewer must retain the raw condition display.'
      );
      Assert.areEqual(
        RecordHealthCheckInternalResult.PASSES_WHEN_LABEL,
        item.display.expectedValueLabel,
        'An authorized viewer must retain the condition label.'
      );
    } else {
      Assert.areEqual(
        null,
        item.display.expectedDisplayValue,
        'A restricted viewer must not receive the condition display.'
      );
      Assert.areEqual(
        null,
        item.display.expectedValueLabel,
        'A restricted viewer must not receive the condition label.'
      );
      Assert.isNull(
        item.display.displayContent.expected,
        'Restricted Formula conditions must be removed from structured content too.'
      );
    }
  }

  @IsTest
  static void queryDisplayFinalizationDoesNotReformatSettledValues() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'QualifiedApiName' => 'Query_Display_Isolation',
        'EvaluationType__c' => 'QUERY',
        'DisplayValueFormat__c' => 'NUMBER'
      }
    );
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.status = RecordHealthCheckStatus.FAIL;
    result.actualValue = 'Authored 7';
    result.evaluationFound = RecordHealthCheckValue.ofNumber(7);
    result.operandsRecorded = true;

    Test.startTest();
    new RecordHealthCheckScopeResultSupport()
      .finalizeDisplay(
        check,
        RecordHealthCheckTestDataFactory.account(
          new Map<String, Object>{ 'Name' => 'Display isolation' }
        ),
        result,
        false,
        true
      );
    Test.stopTest();

    Assert.areEqual(
      'Authored 7',
      result.actualValue,
      'The Apex plugin presentation resolver must not rewrite Query display output.'
    );
  }
}
