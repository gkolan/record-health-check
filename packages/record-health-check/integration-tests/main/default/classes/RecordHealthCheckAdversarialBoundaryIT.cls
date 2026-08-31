/** Adversarial tests for public and extension trust boundaries. */
@IsTest
private with sharing class RecordHealthCheckAdversarialBoundaryIT {
  static {
    RecordHealthCheckAccess.setRunPermissionForTest(true);
  }

  @TestSetup
  static void setupRecords() {
    RHCIntegrationTestDataFactory.createTestRecords();
  }

  @IsTest
  static void pluginScopeMutationIsRolledBackAndRemainsFatal() {
    Account accountRecord = RHCIntegrationTestDataFactory.getHealthyAccount();
    Integer accountCount = [SELECT COUNT() FROM Account];
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'Mutation_Attack',
        'MasterLabel' => 'Mutation Attack',
        'CheckTitle__c' => 'Mutation Attack',
        'ApexClass__c' => 'RecordHealthCheckEvaluationMutationCheck',
        'FailureSeverity__c' => 'ERROR',
        'UnableToEvaluateMessage__c' => 'Unable.'
      }
    );

    Test.startTest();
    try {
      new RecordHealthCheckApexEvaluator()
        .evaluateScope(
          check,
          new List<Id>{ accountRecord.Id },
          new Map<Id, SObject>{ accountRecord.Id => accountRecord },
          'Account',
          'Attack_Set',
          'mutation-attack'
        );
      Assert.fail('A mutating plugin must terminate the scope.');
    } catch (RecordHealthCheckPluginDispatch.SideEffectException error) {
      Assert.areEqual(
        'DML',
        error.effect,
        'The fence should identify the prohibited DML effect.'
      );
      Assert.isTrue(
        error.reversible,
        'Database mutations should be rolled back by the fence.'
      );
    }
    Test.stopTest();

    Assert.areEqual(
      accountCount,
      [SELECT COUNT() FROM Account],
      'The hostile plugin must leave no committed Account behind.'
    );
  }

  @IsTest
  static void pluginConstructorMutationIsFatalInScopeMode() {
    Account accountRecord = RHCIntegrationTestDataFactory.getHealthyAccount();
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'Constructor_Mutation_Attack',
        'MasterLabel' => 'Constructor Mutation Attack',
        'CheckTitle__c' => 'Constructor Mutation Attack',
        'ApexClass__c' => 'RHCConstructorMutationCheck',
        'FailureSeverity__c' => 'ERROR',
        'UnableToEvaluateMessage__c' => 'Unable.'
      }
    );

    Test.startTest();
    try {
      new RecordHealthCheckApexEvaluator()
        .evaluateScope(
          check,
          new List<Id>{ accountRecord.Id },
          new Map<Id, SObject>{ accountRecord.Id => accountRecord },
          'Account',
          'Attack_Set',
          'constructor-mutation-attack'
        );
      Assert.fail('Constructor DML must terminate scope evaluation.');
    } catch (RecordHealthCheckPluginDispatch.SideEffectException error) {
      Assert.areEqual(
        'DML',
        error.effect,
        'Constructor DML should be classified before invocation.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void unplannedCompareQueryFailsClosed() {
    RecordHealthCheckCompareQueriesEvaluator evaluator = new RecordHealthCheckCompareQueriesEvaluator();
    evaluator.scopeRowsByBoundSoql = new Map<String, List<SObject>>();
    evaluator.scopeExecutionActive = true;
    Account record = RHCIntegrationTestDataFactory.getHealthyAccount();
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'EvaluationType__c' => 'COMPARE_TWO_QUERIES',
        'SourceQuery__c' => 'SELECT Id FROM Account',
        'ComparisonQuery__c' => 'SELECT Id FROM Account',
        'SourceQueryField__c' => 'Id',
        'ComparisonQueryField__c' => 'Id',
        'ComparisonOperator__c' => 'EQUALS'
      }
    );

    Test.startTest();
    RecordHealthCheckInternalResult result = evaluator
      .withRunContext(new RecordHealthCheckRunContext('compare-attack', 'TEST'))
      .evaluate(check, record.Id, record);
    Test.stopTest();

    Assert.areEqual(
      'UNSUPPORTED_BULK_QUERY_SHAPE',
      result.reasonCode,
      'The rejection should use the stable bulk-shape reason.'
    );
  }

  @IsTest
  static void compareScopeUsesDefaultRowBudgetWhenUnconfigured() {
    Account accountRecord = RHCIntegrationTestDataFactory.getHealthyAccount();
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'Default_Row_Budget',
        'MasterLabel' => 'Default Row Budget',
        'CheckTitle__c' => 'Default Row Budget',
        'SourceQuery__c' => null,
        'ComparisonQuery__c' => null,
        'MaxQueryRows__c' => null,
        'FailureSeverity__c' => 'ERROR',
        'UnableToEvaluateMessage__c' => 'Unable.'
      }
    );

    RecordHealthCheckInternalResult result;
    Test.startTest();
    result = new RecordHealthCheckCompareQueriesEvaluator()
      .evaluateScope(
        check,
        new List<Id>{ accountRecord.Id },
        new Map<Id, SObject>{ accountRecord.Id => accountRecord }
      )
      .get(accountRecord.Id);
    Test.stopTest();

    Assert.areEqual(
      'INVALID_SOQL_TEMPLATE',
      result.reasonCode,
      'A blank query pair must fail closed with the template reason.'
    );
  }

  @IsTest
  static void descendingOrderedPickUsesMaximumAggregate() {
    Test.startTest();
    String rewritten = RecordHealthCheckBulkQueryRewriter.rewriteOrderedPickAggregate(
      'SELECT Amount FROM Opportunity WHERE AccountId = {!record.Id} ORDER BY Amount DESC LIMIT 1',
      'AccountId'
    );
    Test.stopTest();

    Assert.isTrue(
      rewritten.contains('MAX(Amount)'),
      'Descending ordered picks must use MAX, never MIN.'
    );
  }

  @IsTest
  static void correlationOnlyAggregateReturnsNoBusinessValue() {
    Account accountRecord = RHCIntegrationTestDataFactory.getHealthyAccount();
    RHCIntegrationTestDataFactory.createContact(
      RecordHealthCheckTestDataFactory.contact(
        new Map<String, Object>{
          'LastName' => 'Correlation only',
          'AccountId' => accountRecord.Id
        }
      )
    );
    AggregateResult row = [
      SELECT AccountId rhcCorrelation
      FROM Contact
      WHERE AccountId = :accountRecord.Id
      GROUP BY AccountId
      LIMIT 1
    ];

    Test.startTest();
    Object value = RecordHealthCheckValueResolver.singleValueFromRow(row, null);
    Test.stopTest();

    Assert.isNull(
      value,
      'A correlation alias must never be mistaken for the Check business value.'
    );
  }

  @IsTest
  static void comparisonEngineHandlesNullAndAbsentListValues() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'ComparisonOperator__c' => 'LIST_CONTAINS_ANY',
        'EmptyValueHandling__c' => 'AS_NO_MATCH'
      }
    );

    Test.startTest();
    Integer nullCount = RecordHealthCheckComparisonEngine.countFailingRows(
      check,
      null,
      'expected'
    );
    Boolean absent = RecordHealthCheckComparisonEngine.applyListComparison(
      'LIST_CONTAINS_ANY',
      'attacker-value',
      new List<Object>{ 'allowed-value' },
      check
    );
    Test.stopTest();

    Assert.areEqual(
      0,
      nullCount,
      'A missing primary collection should contain no failing rows.'
    );
    Assert.isFalse(
      absent,
      'An attacker-controlled value absent from the allow-list must not match.'
    );
  }

  @IsTest
  static void blankPluginIdentityIsRejectedBeforeReflection() {
    Test.startTest();
    Boolean valid = RecordHealthCheckConfigValidator.isValidApexPlugin(
      '\t\r\n'
    );
    Test.stopTest();

    Assert.isFalse(
      valid,
      'A whitespace-only plugin identity must never reach reflection.'
    );
  }

  @IsTest
  static void userInitiatedControllerEvaluationUsesQualifiedMembership() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures()) {
      return;
    }
    Account accountRecord = RHCIntegrationTestDataFactory.getHealthyAccount();

    Test.startTest();
    RecordHealthCheckResultItem result = RecordHealthCheckController.evaluateCheck(
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
        'Example_Account_Check_Builder_Guide'
      ),
      RecordHealthCheckTestDataFactory.qualifiedCheckName(
        'Example_Website_URL_Valid'
      ),
      accountRecord.Id,
      'user-controller-boundary',
      RecordHealthCheckLifecyclePublisher.SOURCE_USER_INITIATED
    );
    Test.stopTest();

    Assert.areNotEqual(
      RecordHealthCheckStatus.ERROR,
      result.evaluation.status,
      'A valid qualified membership must reach evaluation.'
    );
    Assert.areEqual(
      accountRecord.Id,
      result.evaluation.recordId,
      'The result must retain the requested identity.'
    );
  }

  @IsTest
  static void queryInjectionTextIsTreatedOnlyAsAnIdentity() {
    String hostileIdentity = 'Missing_Check\' OR DeveloperName != null';

    Test.startTest();
    try {
      RecordHealthCheck.evaluate(
        RecordHealthCheckRequest.forCheck(hostileIdentity, UserInfo.getUserId())
      );
      Assert.fail(
        'A fabricated Check identity must not select another metadata record.'
      );
    } catch (RecordHealthCheckScopePipeline.ScopePipelineException error) {
      Assert.isTrue(
        error.getMessage().contains('was not found'),
        'Bound identity text should produce a not-found result, not alter SOQL.'
      );
    }
    Test.stopTest();
  }
}
