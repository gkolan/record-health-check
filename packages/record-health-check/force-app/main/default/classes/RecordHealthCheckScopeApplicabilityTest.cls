/**
 * Verifies qualified selection, scope validation, ordering, and response modes.
 */
@IsTest
private with sharing class RecordHealthCheckScopeApplicabilityTest {
  private static final String FORMULA_CHECK = 'Example_Website_URL_Valid';
  static {
    RecordHealthCheckAccess.setRunPermissionForTest(true);
  }

  @IsTest
  static void helperBranchesCoverEmptyScopeApplicabilityAndComparisons() {
    RecordHealthCheckScopeResultSupport resultSupport = new RecordHealthCheckScopeResultSupport();
    Account record = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Applicability' }
    );
    Record_Health_Check__mdt falseCheck = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'ApplicabilityMode__c' => 'WHEN_FORMULA_TRUE',
        'ApplicabilityFormula__c' => 'FALSE',
        'ApplicabilityNotMetMessage__c' => 'Not applicable',
        'UnableToEvaluateMessage__c' => 'Unable'
      }
    );
    Record_Health_Check__mdt invalidCheck = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'ApplicabilityMode__c' => 'WHEN_FORMULA_TRUE',
        'ApplicabilityFormula__c' => 'NOT_VALID(',
        'ApplicabilityNotMetMessage__c' => 'Not applicable',
        'UnableToEvaluateMessage__c' => 'Unable'
      }
    );

    Test.startTest();
    RecordHealthCheckResponse emptyResponse = RecordHealthCheck.evaluate(
      RecordHealthCheckRequest.forCheck(
        RecordHealthCheckTestDataFactory.qualifiedCheckName(FORMULA_CHECK),
        new List<Id>()
      )
    );
    RecordHealthCheckInternalResult skipped = resultSupport.applicabilityResult(
      falseCheck,
      record
    );
    RecordHealthCheckInternalResult unable = resultSupport.applicabilityResult(
      invalidCheck,
      record
    );
    RecordHealthCheckInternalResult applicable = resultSupport.applicabilityResult(
      RecordHealthCheckTestDataFactory.check(
        new Map<String, Object>{
          'ApplicabilityMode__c' => 'WHEN_FORMULA_TRUE',
          'ApplicabilityFormula__c' => 'TRUE'
        }
      ),
      record
    );
    List<Boolean> comparisons = new List<Boolean>{
      resultSupport.compareCount('EQUALS', 2, 2),
      resultSupport.compareCount('NOT_EQUALS', 1, 2),
      resultSupport.compareCount('GREATER_THAN', 2, 1),
      resultSupport.compareCount('GREATER_THAN_OR_EQUAL', 2, 2),
      resultSupport.compareCount('LESS_THAN', 1, 2),
      resultSupport.compareCount('LESS_THAN_OR_EQUAL', 2, 2)
    };
    Test.stopTest();

    Assert.areEqual(
      0,
      emptyResponse.results.size(),
      'An empty scope returns no items.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.SKIPPED,
      skipped.status,
      'False applicability skips.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.UNABLE_TO_EVALUATE,
      unable.status,
      'Invalid applicability is unable.'
    );
    Assert.isNull(
      applicable,
      'A true applicability formula continues evaluation.'
    );
    Assert.areEqual(
      6,
      comparisons.size(),
      'Every comparison operator should execute.'
    );
  }

  @IsTest
  static void countApplicabilityQueriesOnceAndSkipsBeforeEvaluation() {
    Account applicable = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Applicable', 'AnnualRevenue' => 100 }
    );
    Account skipped = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Skipped', 'AnnualRevenue' => 100 }
    );
    RecordHealthCheckTestDataFactory.createAccounts(
      new List<Account>{ applicable, skipped }
    );
    Opportunity openOpportunity = RecordHealthCheckTestDataFactory.createOpportunity(
      RecordHealthCheckTestDataFactory.opportunity(
        new Map<String, Object>{
          'Name' => 'Open Pipeline',
          'AccountId' => applicable.Id,
          'StageName' => 'Prospecting',
          'CloseDate' => Date.today().addDays(30),
          'Amount' => 100
        }
      )
    );
    Contact contactRecord = RecordHealthCheckTestDataFactory.createContact(
      new Map<String, Object>{
        'LastName' => 'Contacted',
        'AccountId' => applicable.Id
      }
    );
    RecordHealthCheckTestDataFactory.createRecords(
      new List<SObject>{
        new OpportunityContactRole(
          OpportunityId = openOpportunity.Id,
          ContactId = contactRecord.Id,
          IsPrimary = true
        )
      }
    );
    RecordHealthCheckRequest request = RecordHealthCheckRequest.forCheck(
      RecordHealthCheckTestDataFactory.qualifiedCheckName(
        'Example_Open_Deals_Have_Contacts'
      ),
      new List<Id>{ skipped.Id, applicable.Id }
    );

    RecordHealthCheckDisplayCurrencyResolver.corporateCurrency();
    Test.startTest();
    Integer beforeQueries = Limits.getQueries();
    RecordHealthCheckResponse response = RecordHealthCheck.evaluate(request);
    Integer queryDelta = Limits.getQueries() - beforeQueries;
    Test.stopTest();

    Assert.areEqual(
      5,
      queryDelta,
      'The request should use metadata, one record load, one applicability query, and two comparison queries.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.SKIPPED,
      response.results[0].evaluation.status,
      'A record below the count threshold should be skipped in place.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.PASS,
      response.results[1].evaluation.status,
      'Only the applicable record should reach the query evaluator.'
    );
  }

  @IsTest
  static void defensiveHelpersPreserveStableResults() {
    RecordHealthCheckScopeResultSupport resultSupport = new RecordHealthCheckScopeResultSupport();
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'ApplicabilityMode__c' => 'WHEN_COUNT_QUERY_MATCHES',
        'ApplicabilityNotMetMessage__c' => 'Not applicable.',
        'UnableToEvaluateMessage__c' => 'Unable.'
      }
    );

    Test.startTest();
    RecordHealthCheckInternalResult notMigrated = resultSupport.applicabilityResult(
      check,
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'Name' => 'Applicability' }
      )
    );
    RecordHealthCheckInternalResult skipped = resultSupport.skippedResult(
      check
    );
    Boolean invalidComparison = resultSupport.compareCount('UNKNOWN', 1, 1);
    String blankUrl = resultSupport.sanitizeActionUrl(' ');
    String unsafeUrl = resultSupport.sanitizeActionUrl('//example.com');
    String safeUrl = resultSupport.sanitizeActionUrl('/lightning/page/home');
    Test.stopTest();

    Assert.areEqual('APPLICABILITY_NOT_MIGRATED', notMigrated.reasonCode);
    Assert.areEqual('Not applicable.', skipped.message);
    Assert.isNull(invalidComparison, 'An unknown count operator is invalid.');
    Assert.isNull(blankUrl, 'A blank action URL must be omitted.');
    Assert.isNull(
      unsafeUrl,
      'A protocol-relative action URL must be rejected.'
    );
    Assert.areEqual('/lightning/page/home', safeUrl);
  }

  @IsTest
  static void malformedCountApplicabilityReturnsStableUnavailableResult() {
    Account account = RecordHealthCheckTestDataFactory.createAccount(
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'Name' => 'Count applicability' }
      )
    );
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'ApplicabilityMode__c' => 'WHEN_COUNT_QUERY_MATCHES',
        'ApplicabilityCountQuery__c' => 'SELECT Id FROM Contact',
        'ApplicabilityCountThreshold__c' => 1,
        'UnableToEvaluateMessage__c' => 'Unable.'
      }
    );

    Test.startTest();
    Map<Id, RecordHealthCheckInternalResult> results = new RecordHealthCheckScopeResultSupport()
      .applicabilityResults(
        check,
        new List<Id>{ account.Id },
        new Map<Id, SObject>{ account.Id => account }
      );
    Test.stopTest();

    Assert.areEqual(
      'INVALID_SOQL_TEMPLATE',
      results.get(account.Id).reasonCode
    );
  }

  @IsTest
  static void unknownCountApplicabilityOperatorReturnsUnavailable() {
    Account account = RecordHealthCheckTestDataFactory.createAccount(
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'Name' => 'Unknown count operator' }
      )
    );
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'EvaluationType__c' => 'FORMULA',
        'ApplicabilityMode__c' => 'WHEN_COUNT_QUERY_MATCHES',
        'ApplicabilityCountQuery__c' => 'SELECT COUNT(Id) total FROM Contact WHERE AccountId = {!record.Id}',
        'ApplicabilityCountOperator__c' => 'UNKNOWN',
        'ApplicabilityCountThreshold__c' => 0,
        'UnableToEvaluateMessage__c' => 'Unable.'
      }
    );

    Test.startTest();
    Map<Id, RecordHealthCheckInternalResult> results = new RecordHealthCheckScopeResultSupport()
      .applicabilityResults(
        check,
        new List<Id>{ account.Id },
        new Map<Id, SObject>{ account.Id => account }
      );
    Test.stopTest();

    Assert.areEqual('INVALID_OPERATOR', results.get(account.Id).reasonCode);
  }

  @IsTest
  static void formulaApplicabilityCollectsSkippedRecordsByIdentity() {
    Account account = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Formula applicability false' }
    );
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'ApplicabilityMode__c' => 'WHEN_FORMULA_TRUE',
        'ApplicabilityFormula__c' => 'FALSE',
        'ApplicabilityNotMetMessage__c' => 'Formula did not apply.'
      }
    );

    Test.startTest();
    Map<Id, RecordHealthCheckInternalResult> results = new RecordHealthCheckScopeResultSupport()
      .applicabilityResults(
        check,
        new List<Id>{ account.Id },
        new Map<Id, SObject>{ account.Id => account }
      );
    Test.stopTest();

    Assert.areEqual(
      1,
      results.size(),
      'A false formula should produce one applicability result for its record.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.SKIPPED,
      results.get(account.Id).status,
      'A false applicability formula should skip the matching record.'
    );
  }

  @IsTest
  static void countApplicabilityIgnoresRecordsNotLoadedIntoScope() {
    Id missingId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      73
    );
    Record_Health_Check__mdt check = countApplicabilityCheck(
      'FORMULA',
      'GREATER_THAN',
      0
    );

    Test.startTest();
    Map<Id, RecordHealthCheckInternalResult> results = new RecordHealthCheckScopeResultSupport()
      .applicabilityResults(
        check,
        new List<Id>{ missingId },
        new Map<Id, SObject>()
      );
    Test.stopTest();

    Assert.areEqual(
      0,
      results.size(),
      'A record absent from the loaded scope should not receive an applicability verdict.'
    );
  }

  @IsTest
  static void compareCheckSkipsWhenCountThresholdIsNotMet() {
    Account account = RecordHealthCheckTestDataFactory.createAccount(
      'Compare applicability below threshold'
    );
    Record_Health_Check__mdt check = countApplicabilityCheck(
      'COMPARE_TWO_QUERIES',
      'GREATER_THAN',
      0
    );
    check.NoRowsResult__c = 'FAIL';
    check.FailureSeverity__c = 'WARNING';
    check.FailureMessage__c = 'No applicable rows.';

    Test.startTest();
    Map<Id, RecordHealthCheckInternalResult> results = new RecordHealthCheckScopeResultSupport()
      .applicabilityResults(
        check,
        new List<Id>{ account.Id },
        new Map<Id, SObject>{ account.Id => account }
      );
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckStatus.SKIPPED,
      results.get(account.Id).status,
      'A compare Check should skip when its applicability threshold is not met.'
    );
    Assert.areEqual(
      RecordHealthCheckReasonCodes.NOT_APPLICABLE_BY_COUNT,
      results.get(account.Id).reasonCode,
      'Count applicability should use the documented not-applicable reason.'
    );
  }

  @IsTest
  static void countApplicabilityPreservesBulkQueryFailureReason() {
    System.runAs(RecordHealthCheckTestDataFactory.currentUser()) {
      Account account = RecordHealthCheckTestDataFactory.createAccount(
        'Unsupported applicability query'
      );
      Record_Health_Check__mdt check = countApplicabilityCheck(
        'FORMULA',
        'GREATER_THAN',
        0
      );
      check.ApplicabilityCountQuery__c = 'SELECT COUNT(Id) FROM Contact WHERE AccountId = {!record.Id} AND LastName = {!record.Name}';

      Test.startTest();
      Map<Id, RecordHealthCheckInternalResult> results = new RecordHealthCheckScopeResultSupport()
        .applicabilityResults(
          check,
          new List<Id>{ account.Id },
          new Map<Id, SObject>{ account.Id => account }
        );
      Test.stopTest();

      Assert.areEqual(
        'UNSUPPORTED_BULK_QUERY_SHAPE',
        results.get(account.Id).reasonCode,
        'The bulk-query failure reason should remain actionable for every scoped record.'
      );
    }
  }

  @IsTest
  static void countApplicabilityMapsUnexpectedScopeFailure() {
    System.runAs(RecordHealthCheckTestDataFactory.currentUser()) {
      Id accountId = RecordHealthCheckTestDataFactory.syntheticId(
        Account.SObjectType,
        74
      );
      Record_Health_Check__mdt check = countApplicabilityCheck(
        'FORMULA',
        'GREATER_THAN',
        0
      );

      Test.startTest();
      Map<Id, RecordHealthCheckInternalResult> results = new RecordHealthCheckScopeResultSupport()
        .applicabilityResults(check, new List<Id>{ accountId }, null);
      Test.stopTest();

      Assert.areEqual(
        'UNABLE_TO_EVALUATE',
        results.get(accountId).reasonCode,
        'An unexpected scope failure should produce the stable defensive reason.'
      );
    }
  }

  private static Record_Health_Check__mdt countApplicabilityCheck(
    String evaluationType,
    String countOperator,
    Integer threshold
  ) {
    return RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'EvaluationType__c' => evaluationType,
        'ApplicabilityMode__c' => 'WHEN_COUNT_QUERY_MATCHES',
        'ApplicabilityCountQuery__c' => 'SELECT COUNT(Id) total FROM Contact WHERE AccountId = {!record.Id}',
        'ApplicabilityCountOperator__c' => countOperator,
        'ApplicabilityCountThreshold__c' => threshold,
        'ApplicabilityNotMetMessage__c' => 'Count threshold not met.',
        'UnableToEvaluateMessage__c' => 'Unable.'
      }
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
