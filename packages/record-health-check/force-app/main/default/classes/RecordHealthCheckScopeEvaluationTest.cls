/**
 * Verifies qualified selection, scope validation, ordering, and response modes.
 */
@IsTest
private with sharing class RecordHealthCheckScopeEvaluationTest {
  private static final String PHONE_CHECK = 'Example_Profile_Phone_Available';

  @TestSetup
  static void setupRunPermission() {
    RecordHealthCheckTestDataFactory.assignRunPermissionToCurrentUser();
  }
  @IsTest
  static void unmigratedEvaluatorProducesAlignedUnableResult() {
    Account accountRecord = RecordHealthCheckTestDataFactory.createAccount(
      'Unmigrated evaluator'
    );
    RecordHealthCheckScopePipeline pipeline = new RecordHealthCheckScopePipeline();
    RecordHealthCheckScopePipeline.SelectionContext context = new RecordHealthCheckScopePipeline.SelectionContext();
    context.objectApiName = 'Account';
    context.showDiagnostics = false;
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'Unmigrated',
        'QualifiedApiName' => 'Unmigrated',
        'MasterLabel' => 'Unmigrated',
        'CheckTitle__c' => 'Unmigrated',
        'EvaluationOrder__c' => 1,
        'EvaluationType__c' => 'FUTURE_TYPE',
        'FailureSeverity__c' => 'WARNING',
        'FailureMessage__c' => 'Failed.',
        'UnableToEvaluateMessage__c' => 'Unable.'
      }
    );
    Map<String, RecordHealthCheckResultItem> items = new Map<String, RecordHealthCheckResultItem>();

    Test.startTest();
    pipeline.evaluateCheck(
      check,
      context,
      new List<Id>{ accountRecord.Id },
      new Map<Id, SObject>{ accountRecord.Id => accountRecord },
      false,
      RecordHealthCheckResultMode.EVALUATION,
      'unmigrated-run',
      items
    );
    Test.stopTest();
    Assert.areEqual(
      1,
      items.size(),
      'The evaluator must return one aligned item.'
    );
    RecordHealthCheckResultItem item = items.values()[0];
    Assert.areEqual(
      'INVALID_CHECK_TYPE',
      item.evaluation.reasonCode,
      'Unknown future evaluators must fail validation with a stable reason.'
    );
  }

  @IsTest
  static void queryCheckUsesOneScopeQueryAndPreservesPerRecordVerdicts() {
    Account passing = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Passing Contacts' }
    );
    Account failing = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Failing Contacts' }
    );
    RecordHealthCheckTestDataFactory.createAccounts(
      new List<Account>{ passing, failing }
    );
    RecordHealthCheckTestDataFactory.createContacts(
      new List<Contact>{
        RecordHealthCheckTestDataFactory.contact(
          new Map<String, Object>{
            'LastName' => 'Reachable',
            'Email' => 'reachable@example.com',
            'AccountId' => passing.Id
          }
        ),
        RecordHealthCheckTestDataFactory.contact(
          new Map<String, Object>{
            'LastName' => 'Unreachable',
            'AccountId' => failing.Id
          }
        )
      }
    );
    RecordHealthCheckRequest request = RecordHealthCheckRequest.forCheck(
      RecordHealthCheckTestDataFactory.qualifiedCheckName(
        'Example_Contacts_Have_Email'
      ),
      new List<Id>{ failing.Id, passing.Id }
    );

    Test.startTest();
    Integer beforeQueries = Limits.getQueries();
    RecordHealthCheckResponse response = RecordHealthCheck.evaluate(request);
    Integer queryDelta = Limits.getQueries() - beforeQueries;
    Test.stopTest();
    Assert.areEqual(
      3,
      queryDelta,
      'The request should use one metadata query, one record load, and one scope query.'
    );
    Assert.areEqual(
      failing.Id,
      response.results[0].evaluation.recordId,
      'Query results should retain input order.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.FAIL,
      response.results[0].evaluation.status,
      'A blank Contact email should fail its Account.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.PASS,
      response.results[1].evaluation.status,
      'A populated Contact email should pass its Account.'
    );
  }

  @IsTest
  static void apexPluginIsInvokedOnceForTheNarrowedScope() {
    Account active = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Recent Activity' }
    );
    Account inactive = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'No Activity' }
    );
    RecordHealthCheckTestDataFactory.createAccounts(
      new List<Account>{ active, inactive }
    );
    RecordHealthCheckTestDataFactory.createTask(
      RecordHealthCheckTestDataFactory.task(
        new Map<String, Object>{
          'Subject' => 'Recent customer call',
          'Status' => 'Completed',
          'ActivityDate' => Date.today(),
          'WhatId' => active.Id
        }
      )
    );
    RecordHealthCheckRequest request = RecordHealthCheckRequest.forCheck(
      RecordHealthCheckTestDataFactory.qualifiedCheckName(
        'Example_Customer_Engagement_Current'
      ),
      new List<Id>{ inactive.Id, active.Id }
    );

    Test.startTest();
    Integer beforeQueries = Limits.getQueries();
    RecordHealthCheckResponse response = RecordHealthCheck.evaluate(request);
    Integer queryDelta = Limits.getQueries() - beforeQueries;
    Test.stopTest();
    Assert.areEqual(
      4,
      queryDelta,
      'The request should use metadata, record load, and the plugin\'s two scope queries.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.FAIL,
      response.results[0].evaluation.status,
      'The inactive Account should fail first in input order.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.PASS,
      response.results[1].evaluation.status,
      'The Account with a recent Task should pass.'
    );
  }

  @IsTest
  static void unsupportedEvaluatorReturnsAlignedUnavailableItem() {
    Account account = RecordHealthCheckTestDataFactory.createAccount(
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'Name' => 'Unsupported evaluator' }
      )
    );
    RecordHealthCheckScopePipeline.SelectionContext context = new RecordHealthCheckScopePipeline.SelectionContext();
    context.objectApiName = 'Account';
    context.checkSetDeveloperName = 'Synthetic_Set';
    context.showDiagnostics = false;
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'QualifiedApiName' => 'Synthetic.Unsupported',
        'DeveloperName' => 'Unsupported',
        'CheckTitle__c' => 'Unsupported',
        'EvaluationOrder__c' => 1,
        'EvaluationType__c' => 'UNKNOWN',
        'ApplicabilityMode__c' => 'ALL_RECORDS',
        'FailureSeverity__c' => 'WARNING',
        'FailureMessage__c' => 'Unsupported.'
      }
    );
    Map<String, RecordHealthCheckResultItem> items = new Map<String, RecordHealthCheckResultItem>();

    Test.startTest();
    new RecordHealthCheckScopePipeline()
      .evaluateCheck(
        check,
        context,
        new List<Id>{ account.Id },
        new Map<Id, SObject>{ account.Id => account },
        false,
        RecordHealthCheckResultMode.EVALUATION,
        'run',
        items
      );
    Test.stopTest();

    Assert.areEqual(
      'INVALID_CHECK_TYPE',
      items.values()[0].evaluation.reasonCode
    );
  }

  @IsTest
  static void absentRecordReturnsAlignedUnavailableItem() {
    Account deletedAccount = RecordHealthCheckTestDataFactory.createDeletedAccount(
      'Absent scope record'
    );
    RecordHealthCheckScopePipeline.SelectionContext context = new RecordHealthCheckScopePipeline.SelectionContext();
    context.objectApiName = 'Account';
    context.checkSetDeveloperName = 'Synthetic_Set';
    context.showDiagnostics = false;
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'QualifiedApiName' => 'Synthetic.Absent',
        'DeveloperName' => 'Absent',
        'CheckTitle__c' => 'Absent',
        'EvaluationOrder__c' => 1,
        'EvaluationType__c' => 'FORMULA',
        'ApplicabilityMode__c' => 'ALL_RECORDS',
        'PassConditionFormula__c' => 'TRUE',
        'ComparisonOperator__c' => 'EQUALS',
        'ExpectedFixedValue__c' => 'true',
        'FailureSeverity__c' => 'WARNING',
        'FailureMessage__c' => 'Absent.'
      }
    );
    Map<String, RecordHealthCheckResultItem> items = new Map<String, RecordHealthCheckResultItem>();

    Test.startTest();
    new RecordHealthCheckScopePipeline()
      .evaluateCheck(
        check,
        context,
        new List<Id>{ deletedAccount.Id },
        new Map<Id, SObject>(),
        false,
        RecordHealthCheckResultMode.EVALUATION,
        'run',
        items
      );
    Test.stopTest();

    Assert.areEqual(
      'RECORD_NOT_VISIBLE',
      items.values()[0].evaluation.reasonCode
    );
  }

  @IsTest
  static void inaccessibleFieldReturnsAlignedResultForVisibleRecord() {
    Account account = RecordHealthCheckTestDataFactory.createAccount(
      'Visible record with inaccessible field'
    );
    Map<String, RecordHealthCheckResultItem> items = new Map<String, RecordHealthCheckResultItem>();

    Test.startTest();
    new RecordHealthCheckScopePipeline()
      .evaluateCheck(
        queryCountCheck('Inaccessible_Field', 'Unable to read field.'),
        evaluationContext(),
        new List<Id>{ account.Id },
        new Map<Id, SObject>{ account.Id => account },
        true,
        RecordHealthCheckResultMode.EVALUATION,
        'field-access-denied',
        items
      );
    Test.stopTest();

    Assert.areEqual(
      1,
      items.size(),
      'The visible record must retain one result.'
    );
    Assert.areEqual(
      RecordHealthCheckReasonCodes.CANNOT_EVALUATE,
      items.values()[0].evaluation.reasonCode,
      'A field-access failure should be redacted from callers without diagnostic-detail access.'
    );
  }

  @IsTest
  static void inaccessibleFieldPreservesMissingRecordReason() {
    Account deletedAccount = RecordHealthCheckTestDataFactory.createDeletedAccount(
      'Missing record with inaccessible field'
    );
    Map<String, RecordHealthCheckResultItem> items = new Map<String, RecordHealthCheckResultItem>();

    Test.startTest();
    new RecordHealthCheckScopePipeline()
      .evaluateCheck(
        queryCountCheck('Missing_Inaccessible_Field', 'Unable to read record.'),
        evaluationContext(),
        new List<Id>{ deletedAccount.Id },
        new Map<Id, SObject>(),
        true,
        RecordHealthCheckResultMode.EVALUATION,
        'missing-field-access-denied',
        items
      );
    Test.stopTest();

    Assert.areEqual(
      1,
      items.size(),
      'The missing record must retain one result.'
    );
    Assert.areEqual(
      'RECORD_NOT_VISIBLE',
      items.values()[0].evaluation.reasonCode,
      'Record visibility should remain the reason when no record was loaded.'
    );
  }

  @IsTest
  static void failedPrerequisiteSkipsEvaluationAndBuildsDisplay() {
    Account account = RecordHealthCheckTestDataFactory.createAccount(
      'Blocked dependent check'
    );
    Record_Health_Check__mdt check = queryCountCheck(
      'Dependent_Check',
      'Dependent check failed.'
    );
    check.QualifiedApiName = 'namespace__Dependent_Check';
    check.PrerequisiteCheck__c = 'Prerequisite_Check';
    RecordHealthCheckScopePipeline.SelectionContext context = evaluationContext();
    context.showDiagnostics = true;
    Map<String, RecordHealthCheckResultItem> items = new Map<String, RecordHealthCheckResultItem>{
      String.valueOf(account.Id) +
      '|namespace__Prerequisite_Check' => buildPrerequisiteResultItem(
        account.Id,
        'namespace__Prerequisite_Check',
        RecordHealthCheckStatus.FAIL
      )
    };

    Test.startTest();
    new RecordHealthCheckScopePipeline()
      .evaluateCheck(
        check,
        context,
        new List<Id>{ account.Id },
        new Map<Id, SObject>{ account.Id => account },
        false,
        RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY,
        'blocked-prerequisite',
        items
      );
    Test.stopTest();

    RecordHealthCheckResultItem dependent = items.get(
      String.valueOf(account.Id) + '|namespace__Dependent_Check'
    );
    Assert.isNotNull(
      dependent,
      'The dependent Check must retain an aligned item.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.SKIPPED,
      dependent.evaluation.status,
      'A failed prerequisite must skip the dependent Check.'
    );
    Assert.areEqual(
      RecordHealthCheckReasonCodes.PREREQUISITE_NOT_MET,
      dependent.evaluation.reasonCode,
      'The dependent result should preserve the prerequisite reason.'
    );
    Assert.isNotNull(
      dependent.display,
      'Display mode should still return display content for a skipped Check.'
    );
  }

  @IsTest
  static void runtimeValidationRejectsHalfConfiguredChecksBeforeEvaluation() {
    Account first = RecordHealthCheckTestDataFactory.createAccount(
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'Name' => 'Half configured one' }
      )
    );
    Account second = RecordHealthCheckTestDataFactory.createAccount(
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'Name' => 'Half configured two' }
      )
    );
    Record_Health_Check__mdt check = queryCountCheck(
      'Half_Configured',
      'Invalid configuration.'
    );
    check.ComparisonOperator__c = 'DROP_TABLE';
    Map<String, RecordHealthCheckResultItem> items = new Map<String, RecordHealthCheckResultItem>();
    RecordHealthCheckScopePipeline.SelectionContext context = evaluationContext();

    Test.startTest();
    new RecordHealthCheckScopePipeline()
      .evaluateCheck(
        check,
        context,
        new List<Id>{ first.Id, second.Id },
        new Map<Id, SObject>{ first.Id => first, second.Id => second },
        false,
        RecordHealthCheckResultMode.EVALUATION,
        'run-invalid',
        items
      );
    Test.stopTest();

    Assert.areEqual(
      2,
      items.size(),
      'Every scoped record needs an aligned result.'
    );
    for (RecordHealthCheckResultItem item : items.values()) {
      Assert.areEqual(
        'INVALID_OPERATOR',
        item.evaluation.reasonCode,
        'Hostile operator text must be rejected before evaluator execution.'
      );
    }
  }

  @IsTest
  static void queryFailureMessageResolvesBraceDataExactlyOnce() {
    Account account = RecordHealthCheckTestDataFactory.createAccount(
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'Name' => 'Acme {Labs}' }
      )
    );
    Record_Health_Check__mdt check = queryCountCheck(
      'Brace_Query',
      'Account {!record.Name} needs contacts'
    );
    Map<String, RecordHealthCheckResultItem> items = new Map<String, RecordHealthCheckResultItem>();

    Test.startTest();
    new RecordHealthCheckScopePipeline()
      .evaluateCheck(
        check,
        evaluationContext(),
        new List<Id>{ account.Id },
        new Map<Id, SObject>{ account.Id => account },
        false,
        RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY,
        'run-braces',
        items
      );
    Test.stopTest();

    RecordHealthCheckResultItem item = items.values()[0];
    Assert.areEqual(
      RecordHealthCheckStatus.FAIL,
      item.evaluation.status,
      'An Account with no Contacts must fail the positive-count Check.'
    );
    Assert.areEqual(
      'Account Acme {Labs} needs contacts',
      item.display.renderedMessage,
      'Braces originating in record data must remain literal after one resolution pass.'
    );
  }

  @IsTest
  static void unsupportedBulkShapeMapsToAlignedEvaluatorReason() {
    Account account = RecordHealthCheckTestDataFactory.createAccount(
      'Unsupported bulk shape'
    );
    Record_Health_Check__mdt check = queryCountCheck(
      'Unsupported_Bulk_Shape',
      'Unsupported.'
    );
    check.SourceQuery__c = 'SELECT Industry FROM Account WHERE Id != {!record.Id}';
    check.SourceQueryField__c = 'Industry';
    Map<String, RecordHealthCheckResultItem> items = new Map<String, RecordHealthCheckResultItem>();

    Test.startTest();
    new RecordHealthCheckScopePipeline()
      .evaluateCheck(
        check,
        evaluationContext(),
        new List<Id>{ account.Id },
        new Map<Id, SObject>{ account.Id => account },
        false,
        RecordHealthCheckResultMode.EVALUATION,
        'unsupported-bulk',
        items
      );
    Test.stopTest();

    Assert.areEqual(1, items.size(), 'The scope must retain one aligned item.');
    Assert.areEqual(
      'UNSUPPORTED_BULK_QUERY_SHAPE',
      items.values()[0].evaluation.reasonCode,
      'The evaluator exception must retain its stable bulk-shape reason.'
    );
  }

  @IsTest
  static void compareFailureMessageResolvesBraceDataExactlyOnce() {
    Account account = RecordHealthCheckTestDataFactory.createAccount(
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'Name' => 'Compare {Brace}' }
      )
    );
    Record_Health_Check__mdt check = queryCountCheck(
      'Brace_Compare',
      'Account {!record.Name} has mismatched coverage'
    );
    check.EvaluationType__c = 'COMPARE_TWO_QUERIES';
    check.ComparisonQuery__c = 'SELECT COUNT() total FROM Opportunity WHERE AccountId = {!record.Id}';
    check.ComparisonQueryField__c = 'total';
    check.ComparisonOperator__c = 'NOT_EQUALS';
    check.ExpectedValueSource__c = null;
    check.ExpectedFixedValue__c = null;
    Map<String, RecordHealthCheckResultItem> items = new Map<String, RecordHealthCheckResultItem>();

    Test.startTest();
    new RecordHealthCheckScopePipeline()
      .evaluateCheck(
        check,
        evaluationContext(),
        new List<Id>{ account.Id },
        new Map<Id, SObject>{ account.Id => account },
        false,
        RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY,
        'run-compare-braces',
        items
      );
    Test.stopTest();

    RecordHealthCheckResultItem item = items.values()[0];
    Assert.areEqual(
      RecordHealthCheckStatus.FAIL,
      item.evaluation.status,
      'Equal zero counts must fail a NOT_EQUALS comparison.'
    );
    Assert.areEqual(
      'Account Compare {Brace} has mismatched coverage',
      item.display.renderedMessage,
      'Compare-query record data must not be parsed as template syntax twice.'
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
