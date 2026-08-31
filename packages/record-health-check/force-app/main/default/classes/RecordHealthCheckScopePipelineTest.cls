/**
 * Verifies qualified selection, scope validation, ordering, and response modes.
 */
@IsTest
private with sharing class RecordHealthCheckScopePipelineTest {
  private static final String FORMULA_CHECK = 'Example_Website_URL_Valid';
  static {
    RecordHealthCheckAccess.setRunPermissionForTest(true);
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
    RecordHealthCheckTestDataFactory.contactFixture(contact);
    try {
      RecordHealthCheck.evaluate(
        RecordHealthCheckRequest.forCheck(
          RecordHealthCheckTestDataFactory.qualifiedCheckName(FORMULA_CHECK),
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
    List<Id> oversizedScope = new List<Id>();
    for (
      Integer index = 0;
      index <= RecordHealthCheckConstants.MAX_RECORDS_PER_SCOPE;
      index++
    ) {
      oversizedScope.add(
        RecordHealthCheckTestDataFactory.syntheticId(
          Account.SObjectType,
          index + 1
        )
      );
    }

    Test.startTest();
    try {
      RecordHealthCheck.evaluate(
        RecordHealthCheckRequest.forCheck(
          RecordHealthCheckTestDataFactory.qualifiedCheckName(FORMULA_CHECK),
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
          .contains('uniqueCount=' + String.valueOf(oversizedScope.size())),
        'The error should distinguish the unique workload from the supplied count.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void callerRunIdIsPreservedForEmptyScope() {
    String callerRunId = 'caller-correlation-id';
    RecordHealthCheckRequest request = RecordHealthCheckRequest.forCheck(
        RecordHealthCheckTestDataFactory.qualifiedCheckName(FORMULA_CHECK),
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
