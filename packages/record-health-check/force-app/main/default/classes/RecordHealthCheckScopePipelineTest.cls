/**
 * Verifies qualified selection, scope validation, ordering, and response modes.
 */
@IsTest
private with sharing class RecordHealthCheckScopePipelineTest {
  private static final String PHONE_CHECK = 'Example_Profile_Phone_Available';

  @TestSetup
  static void setupRunPermission() {
    RecordHealthCheckTestDataFactory.assignRunPermissionToCurrentUser();
  }

  @IsTest
  static void qualifiedCheckEvaluatesDeduplicatedScopeInInputOrder() {
    Account first = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'First', 'Phone' => '312-555-0100' }
    );
    Account second = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Second', 'Phone' => '312-555-0200' }
    );
    RecordHealthCheckTestDataFactory.createAccounts(
      new List<Account>{ first, second }
    );

    RecordHealthCheckRequest request = RecordHealthCheckRequest.forCheck(
      RecordHealthCheckTestDataFactory.qualifiedCheckName(PHONE_CHECK),
      new List<Id>{ second.Id, first.Id, second.Id }
    );

    Test.startTest();
    RecordHealthCheckResponse response = RecordHealthCheck.evaluate(request);
    Test.stopTest();

    Assert.areEqual(
      new List<Id>{ second.Id, first.Id },
      response.recordIds,
      'The response should preserve first-seen input order and remove duplicates.'
    );
    Assert.areEqual(
      2,
      response.results.size(),
      'One Check should return one item per record.'
    );
    Assert.areEqual(
      second.Id,
      response.results[0].evaluation.recordId,
      'The first item should match input order.'
    );
    Assert.areEqual(
      first.Id,
      response.results[1].evaluation.recordId,
      'The second item should match input order.'
    );
    Assert.areEqual(
      2,
      response.summary.passed,
      'Both populated phone records should pass.'
    );
    Assert.isNull(
      response.results[0].display,
      'Evaluation mode should omit display content.'
    );
  }

  @IsTest
  static void displayModeAddsDisplayWithoutChangingEnvelope() {
    Account account = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Missing Phone' }
    );
    RecordHealthCheckTestDataFactory.createAccount(account);
    RecordHealthCheckRequest request = RecordHealthCheckRequest.forCheck(
        RecordHealthCheckTestDataFactory.qualifiedCheckName(PHONE_CHECK),
        account.Id
      )
      .withResultMode(RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY);

    RecordHealthCheckResponse response = RecordHealthCheck.evaluate(request);

    Assert.areEqual(
      1,
      response.results.size(),
      'The Check should return one result item.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.FAIL,
      response.results[0].evaluation.status,
      'A blank phone should fail.'
    );
    Assert.isNotNull(
      response.results[0].display,
      'Display mode should attach display content.'
    );
    Assert.isNotNull(
      response.results[0].display.renderedMessage,
      'A failure should render its configured message.'
    );
  }

  @IsTest
  static void summaryModeOmitsPassingItemsButRetainsCounts() {
    Account account = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Name' => 'Passing Phone',
        'Phone' => '312-555-0300'
      }
    );
    RecordHealthCheckTestDataFactory.createAccount(account);
    RecordHealthCheckRequest request = RecordHealthCheckRequest.forCheck(
        RecordHealthCheckTestDataFactory.qualifiedCheckName(PHONE_CHECK),
        account.Id
      )
      .withResultMode(RecordHealthCheckResultMode.SUMMARY);

    RecordHealthCheckResponse response = RecordHealthCheck.evaluate(request);

    Assert.areEqual(
      1,
      response.summary.passed,
      'The summary should count a passing Check.'
    );
    Assert.areEqual(
      0,
      response.results.size(),
      'Summary mode should omit non-actionable items.'
    );
  }

  @IsTest
  static void publicationOptionsAreCallerDrivenAndFilterBeforeMetadata() {
    Account account = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Name' => 'Silent Default',
        'Phone' => '312-555-0400'
      }
    );
    RecordHealthCheckTestDataFactory.createAccount(account);
    Integer beforeDefault = Limits.getDmlStatements();
    RecordHealthCheck.evaluate(
      RecordHealthCheckRequest.forCheck(
        RecordHealthCheckTestDataFactory.qualifiedCheckName(PHONE_CHECK),
        account.Id
      )
    );
    Assert.areEqual(
      0,
      Limits.getDmlStatements() - beforeDefault,
      'The default programmatic request must publish nothing.'
    );

    Integer beforeActionable = Limits.getDmlStatements();
    RecordHealthCheck.evaluate(
      RecordHealthCheckRequest.forCheck(
          RecordHealthCheckTestDataFactory.qualifiedCheckName(PHONE_CHECK),
          account.Id
        )
        .withEventPublication(RecordHealthCheckEventPublication.ACTIONABLE)
    );
    Assert.areEqual(
      0,
      Limits.getDmlStatements() - beforeActionable,
      'ACTIONABLE should publish nothing for an all-pass response.'
    );

    Integer beforeAll = Limits.getDmlStatements();
    RecordHealthCheck.evaluate(
      RecordHealthCheckRequest.forCheck(
          RecordHealthCheckTestDataFactory.qualifiedCheckName(PHONE_CHECK),
          account.Id
        )
        .withEventPublication(RecordHealthCheckEventPublication.ALL)
    );
    Assert.isTrue(
      Limits.getDmlStatements() > beforeAll,
      'ALL should publish lifecycle events for a passing response.'
    );
  }

  @IsTest
  static void rejectsUnknownIdentityAndWrongRecordType() {
    try {
      RecordHealthCheck.evaluate(
        RecordHealthCheckRequest.forCheck(
          'Definitely_Missing_Check',
          new List<Id>()
        )
      );
      Assert.fail('An unknown qualified Check identity should be rejected.');
    } catch (RecordHealthCheckScopePipeline.ScopePipelineException error) {
      Assert.isTrue(
        error.getMessage().contains('was not found'),
        'The error should identify the missing Check.'
      );
    }

    Contact contact = RecordHealthCheckTestDataFactory.contact(
      new Map<String, Object>{ 'LastName' => 'Wrong Type' }
    );
    RecordHealthCheckTestDataFactory.createContact(contact);
    try {
      RecordHealthCheck.evaluate(
        RecordHealthCheckRequest.forCheck(
          RecordHealthCheckTestDataFactory.qualifiedCheckName(PHONE_CHECK),
          contact.Id
        )
      );
      Assert.fail('A Contact should not run through an Account Check.');
    } catch (RecordHealthCheckScopePipeline.ScopePipelineException error) {
      Assert.isTrue(
        error.getMessage().contains('not Contact'),
        'The error should name the mismatched object type.'
      );
    }
  }

  @IsTest
  static void rejectsNullRequest() {
    try {
      RecordHealthCheck.evaluate(null);
      Assert.fail('A null request should be rejected.');
    } catch (RecordHealthCheckScopePipeline.ScopePipelineException error) {
      Assert.isTrue(
        error.getMessage().contains('request is required'),
        'The error should identify the missing request.'
      );
    }
  }

  @IsTest
  static void rejectsScopeLargerThanFrameworkCeilingBeforeEvaluation() {
    Id accountId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      1
    );
    List<Id> oversizedScope = new List<Id>();
    for (
      Integer index = 0;
      index <= RecordHealthCheckConstants.MAX_RECORDS_PER_SCOPE;
      index++
    ) {
      oversizedScope.add(accountId);
    }

    Test.startTest();
    try {
      RecordHealthCheck.evaluate(
        RecordHealthCheckRequest.forCheck(
          RecordHealthCheckTestDataFactory.qualifiedCheckName(PHONE_CHECK),
          oversizedScope
        )
      );
      Assert.fail('A scope above the documented ceiling must be rejected.');
    } catch (RecordHealthCheckScopePipeline.ScopePipelineException error) {
      Assert.isTrue(
        error.getMessage().contains('MAX_RECORDS_PER_SCOPE_EXCEEDED'),
        'The error should expose the stable scope-ceiling reason.'
      );
      Assert.isTrue(
        error.getMessage()
          .contains('suppliedCount=' + String.valueOf(oversizedScope.size())),
        'The error should report the exact supplied record count.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void callerRunIdIsPreservedForEmptyScope() {
    String callerRunId = 'caller-correlation-id';
    RecordHealthCheckRequest request = RecordHealthCheckRequest.forCheck(
        RecordHealthCheckTestDataFactory.qualifiedCheckName(PHONE_CHECK),
        new List<Id>()
      )
      .withRunId(callerRunId);

    Test.startTest();
    RecordHealthCheckResponse response = RecordHealthCheck.evaluate(request);
    Test.stopTest();

    Assert.areEqual(
      callerRunId,
      response.runId,
      'A caller-supplied correlation identifier must be retained unchanged.'
    );
    Assert.areEqual(
      0,
      response.results.size(),
      'An empty scope should return no evaluation items.'
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
