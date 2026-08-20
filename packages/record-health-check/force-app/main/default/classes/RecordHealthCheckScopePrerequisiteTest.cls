/**
 * Verifies qualified selection, scope validation, ordering, and response modes.
 */
@IsTest
private with sharing class RecordHealthCheckScopePrerequisiteTest {
  private static final String PHONE_CHECK = 'Example_Profile_Phone_Available';

  @IsTest
  static void missingPrerequisiteDoesNotBlockSingleCheckSelection() {
    Account account = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Missing Prerequisite' }
    );
    RecordHealthCheckTestDataFactory.createAccount(account);
    Record_Health_Check__mdt checkWithPrerequisite = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'Check_B',
        'PrerequisiteCheck__c' => 'Check_A'
      }
    );

    Test.startTest();
    RecordHealthCheckInternalResult result = new RecordHealthCheckScopeResultSupport()
      .findPrerequisiteBlock(
        checkWithPrerequisite,
        account.Id,
        new Map<String, RecordHealthCheckResultItem>()
      );
    Test.stopTest();

    Assert.isNull(
      result,
      'A qualified single-Check request has no prerequisite history and must not invent a failed dependency.'
    );
  }

  @IsTest
  static void passingPrerequisiteAllowsDependentCheck() {
    Account account = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Passing Prerequisite' }
    );
    RecordHealthCheckTestDataFactory.createAccount(account);
    RecordHealthCheckResultItem prerequisiteResult = buildPrerequisiteResultItem(
      account.Id,
      'Check_A',
      RecordHealthCheckStatus.PASS
    );

    Test.startTest();
    RecordHealthCheckInternalResult result = new RecordHealthCheckScopeResultSupport()
      .findPrerequisiteBlock(
        buildCheckWithPrerequisite('Check_A'),
        account.Id,
        new Map<String, RecordHealthCheckResultItem>{
          String.valueOf(account.Id) + '|Check_A' => prerequisiteResult
        }
      );
    Test.stopTest();

    Assert.isNull(
      result,
      'Only a PASS result from the Prerequisite Check may allow the Check to run.'
    );
  }

  @IsTest
  static void missingPrerequisiteBlocksFullCheckSetSelection() {
    Account account = RecordHealthCheckTestDataFactory.createAccount(
      'Missing prerequisite in full set'
    );

    Test.startTest();
    RecordHealthCheckInternalResult result = new RecordHealthCheckScopeResultSupport()
      .findPrerequisiteBlock(
        buildCheckWithPrerequisite('Typo_Check'),
        account.Id,
        new Map<String, RecordHealthCheckResultItem>(),
        true
      );
    Test.stopTest();

    Assert.areEqual(RecordHealthCheckStatus.SKIPPED, result.status);
    Assert.areEqual(
      RecordHealthCheckReasonCodes.DEPENDENCY_NOT_IN_RUN,
      result.reasonCode,
      'A typo must fail closed during a full Check Set run.'
    );
  }

  @IsTest
  static void everyNonPassingPrerequisiteStatusSkipsDependentCheck() {
    Account account = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Non-Passing Prerequisite' }
    );
    RecordHealthCheckTestDataFactory.createAccount(account);
    List<String> terminalStatuses = new List<String>{
      RecordHealthCheckStatus.FAIL,
      RecordHealthCheckStatus.SKIPPED,
      RecordHealthCheckStatus.UNABLE_TO_EVALUATE,
      RecordHealthCheckStatus.ERROR
    };

    Test.startTest();
    for (String status : terminalStatuses) {
      RecordHealthCheckResultItem prerequisiteResult = buildPrerequisiteResultItem(
        account.Id,
        'namespace__Check_A',
        status
      );
      RecordHealthCheckInternalResult result = new RecordHealthCheckScopeResultSupport()
        .findPrerequisiteBlock(
          buildCheckWithPrerequisite('Check_A'),
          account.Id,
          new Map<String, RecordHealthCheckResultItem>{
            String.valueOf(account.Id) +
            '|namespace__Check_A' => prerequisiteResult
          }
        );
      Assert.areEqual(
        RecordHealthCheckStatus.SKIPPED,
        result.status,
        status + ' must block the Check that requires the Prerequisite Check.'
      );
      Assert.areEqual(
        RecordHealthCheckReasonCodes.PREREQUISITE_NOT_MET,
        result.reasonCode,
        status + ' means the Prerequisite Check ran but did not pass.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void prerequisiteOutcomeIsScopedToTheSameRecord() {
    Account first = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'First Scope Record' }
    );
    Account second = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Second Scope Record' }
    );
    RecordHealthCheckTestDataFactory.createAccounts(
      new List<Account>{ first, second }
    );
    Map<String, RecordHealthCheckResultItem> priorItems = new Map<String, RecordHealthCheckResultItem>{
      String.valueOf(first.Id) + '|Check_A' => buildPrerequisiteResultItem(
        first.Id,
        'Check_A',
        RecordHealthCheckStatus.PASS
      ),
      String.valueOf(second.Id) + '|Check_A' => buildPrerequisiteResultItem(
        second.Id,
        'Check_A',
        RecordHealthCheckStatus.FAIL
      )
    };

    Test.startTest();
    RecordHealthCheckScopeResultSupport resultSupport = new RecordHealthCheckScopeResultSupport();
    RecordHealthCheckInternalResult firstResult = resultSupport.findPrerequisiteBlock(
      buildCheckWithPrerequisite('Check_A'),
      first.Id,
      priorItems
    );
    RecordHealthCheckInternalResult secondResult = resultSupport.findPrerequisiteBlock(
      buildCheckWithPrerequisite('Check_A'),
      second.Id,
      priorItems
    );
    Test.stopTest();

    Assert.isNull(
      firstResult,
      'The record whose Prerequisite Check passed may proceed.'
    );
    Assert.areEqual(
      RecordHealthCheckReasonCodes.PREREQUISITE_NOT_MET,
      secondResult.reasonCode,
      'A different record\'s PASS must not unblock this record.'
    );
  }

  @IsTest
  static void prerequisiteLookupIgnoresSpoofedMapIdentity() {
    Account account = RecordHealthCheckTestDataFactory.createAccount(
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'Name' => 'Spoofed prerequisite identity' }
      )
    );
    RecordHealthCheckResultItem spoofed = buildPrerequisiteResultItem(
      account.Id,
      'Check_A',
      RecordHealthCheckStatus.PASS
    );

    Test.startTest();
    RecordHealthCheckInternalResult result = new RecordHealthCheckScopeResultSupport()
      .findPrerequisiteBlock(
        buildCheckWithPrerequisite('Check_A'),
        account.Id,
        new Map<String, RecordHealthCheckResultItem>{
          'attacker-controlled-key' => spoofed
        }
      );
    Test.stopTest();

    Assert.isNull(
      result,
      'A value under the wrong identity key is ignored and absent history remains unknown.'
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
