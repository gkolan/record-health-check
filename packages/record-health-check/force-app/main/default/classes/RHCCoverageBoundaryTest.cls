/** Focused tests for defensive branches that span public framework boundaries. */
@IsTest
private with sharing class RHCCoverageBoundaryTest {
  @TestSetup
  static void setup() {
    RecordHealthCheckTestDataFactory.assignRunPermissionToCurrentUser();
  }

  @IsTest
  static void flowExecutorClassifiesAuthorizationFailure() {
    String groupKey = RecordHealthCheckFlowGroupExecutor.key(
      'Missing.Check',
      'NONE'
    );
    RecordHealthCheckAccess.setRunPermissionForTest(false);

    Test.startTest();
    try {
      RecordHealthCheckFlowGroupExecutor.Result result = RecordHealthCheckFlowGroupExecutor.evaluate(
        groupKey,
        new List<Id>{
          RecordHealthCheckTestDataFactory.syntheticId(Account.SObjectType, 1)
        },
        RecordHealthCheckFlowGroupExecutor.SelectionKind.CHECK
      );
      Assert.areEqual('AUTHORIZATION', result.errorType);
      Assert.isTrue(result.errorMessage.contains('permission'));
    } finally {
      RecordHealthCheckAccess.setRunPermissionForTest(null);
    }
    Test.stopTest();
  }

  @IsTest
  static void flowExecutorUsesSelectionSpecificSafeMessages() {
    Test.startTest();
    RecordHealthCheckFlowGroupExecutor.Result checkResult = RecordHealthCheckFlowGroupExecutor.evaluate(
      'not-json',
      new List<Id>(),
      RecordHealthCheckFlowGroupExecutor.SelectionKind.CHECK
    );
    RecordHealthCheckFlowGroupExecutor.Result setResult = RecordHealthCheckFlowGroupExecutor.evaluate(
      'not-json',
      new List<Id>(),
      RecordHealthCheckFlowGroupExecutor.SelectionKind.CHECK_SET
    );
    Test.stopTest();

    Assert.areEqual('EXECUTION', checkResult.errorType);
    Assert.areEqual(
      'The Check request could not be evaluated.',
      checkResult.errorMessage
    );
    Assert.areEqual('EXECUTION', setResult.errorType);
    Assert.areEqual(
      'The Check Set request could not be evaluated.',
      setResult.errorMessage
    );
  }

  @IsTest
  static void multiCurrencyRewritePreservesNonCurrencySelection() {
    Account account = RecordHealthCheckTestDataFactory.createAccount(
      'Non-currency selection'
    );
    Map<Id, SObject> records = new Map<Id, SObject>{
      account.Id => [SELECT Id FROM Account WHERE Id = :account.Id]
    };
    RecordHealthCheckDisplayCurrencyResolver.multiCurrency = true;

    Test.startTest();
    try {
      RecordHealthCheckBulkQuerySupport.Result result = RecordHealthCheckBulkQuerySupport.execute(
        'SELECT Name FROM Account WHERE Id = {!record.Id}',
        records,
        10
      );
      Assert.areEqual(1, result.rowsByRecordId.get(account.Id).size());
    } finally {
      RecordHealthCheckDisplayCurrencyResolver.multiCurrency = null;
    }
    Test.stopTest();
  }

  @IsTest
  static void controllerRethrowsFatalPluginSideEffect() {
    Account account = RecordHealthCheckTestDataFactory.createAccount(
      'Controller side effect'
    );
    RecordHealthCheckScopePipeline.evaluatorFailureOverride = 'SIDE_EFFECT';

    Test.startTest();
    try {
      RecordHealthCheckController.evaluateCheck(
        RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
          'Example_Account_Profile_Readiness'
        ),
        RecordHealthCheckTestDataFactory.qualifiedCheckName(
          'Example_Profile_Phone_Available'
        ),
        account.Id,
        'controller-side-effect',
        RecordHealthCheckLifecyclePublisher.SOURCE_RUN_ON_LOAD
      );
      Assert.fail(
        'A fatal plugin side effect must cross the controller boundary.'
      );
    } catch (RecordHealthCheckPluginDispatch.SideEffectException expected) {
      Assert.areEqual(
        RecordHealthCheckReasonCodes.PLUGIN_SIDE_EFFECT_DETECTED,
        expected.reasonCode
      );
    } finally {
      RecordHealthCheckScopePipeline.evaluatorFailureOverride = null;
    }
    Test.stopTest();
  }

  @IsTest
  static void formulaOverrideAcceptsUnqualifiedFieldKey() {
    RecordHealthCheckFieldPlanner planner = new RecordHealthCheckFieldPlanner();
    planner.calculatedFormulaOverrideByField = new Map<String, String>{
      'SyntheticFormula__c' => 'Owner.IsActive'
    };

    Test.startTest();
    Set<String> fields = planner.collectRecordFields(
      RecordHealthCheckTestDataFactory.check(
        new Map<String, Object>{
          'EvaluationType__c' => 'FORMULA',
          'PassConditionFormula__c' => 'Parent.SyntheticFormula__c'
        }
      ),
      Account.SObjectType
    );
    Test.stopTest();

    Assert.isFalse(fields.isEmpty());
  }

  @IsTest
  static void validatorRejectsUnsupportedCorrelatedQueryShapes() {
    Record_Health_Check__mdt applicability = baseCheck('FORMULA');
    applicability.ApplicabilityMode__c = 'WHEN_COUNT_QUERY_MATCHES';
    applicability.ApplicabilityCountQuery__c = 'SELECT COUNT() FROM Account WHERE Id != {!record.Id}';
    applicability.ApplicabilityCountOperator__c = 'GREATER_THAN';
    applicability.ApplicabilityCountThreshold__c = 0;

    Record_Health_Check__mdt query = queryCheck();
    query.ExpectedValueSource__c = 'COMPARISON_QUERY';
    query.ComparisonQuery__c = 'SELECT Industry FROM Account WHERE Id != {!record.Id}';
    query.ComparisonQueryField__c = 'Industry';

    Record_Health_Check__mdt dual = dualCheck();
    dual.SourceQuery__c = 'SELECT Industry FROM Account WHERE Id != {!record.Id}';
    dual.ComparisonQuery__c = 'SELECT Industry FROM Account WHERE Id != {!record.Id}';

    Test.startTest();
    List<RecordHealthCheckValidator.Finding> applicabilityFindings = RecordHealthCheckValidator.applicabilityFindings(
      applicability
    );
    List<RecordHealthCheckValidator.Finding> queryFindings = RecordHealthCheckValidator.queryFindings(
      query
    );
    List<RecordHealthCheckValidator.Finding> dualFindings = RecordHealthCheckValidator.compareQueriesFindings(
      dual
    );
    Test.stopTest();

    Assert.isFalse(applicabilityFindings.isEmpty());
    Assert.isFalse(queryFindings.isEmpty());
    Assert.isTrue(dualFindings.size() >= 2);
  }

  @IsTest
  static void validatorChecksBothTextOperatorSelections() {
    Record_Health_Check__mdt dual = dualCheck();
    dual.ComparisonOperator__c = 'CONTAINS';
    dual.SourceQuery__c = 'SELECT AnnualRevenue FROM Account';
    dual.SourceQueryField__c = 'AnnualRevenue';
    dual.ComparisonQuery__c = 'SELECT NumberOfEmployees FROM Account';
    dual.ComparisonQueryField__c = 'NumberOfEmployees';

    Test.startTest();
    List<RecordHealthCheckValidator.Finding> findings = RecordHealthCheckValidator.compareQueriesFindings(
      dual
    );
    Test.stopTest();

    Assert.isFalse(findings.isEmpty());
  }

  @IsTest
  static void aggregateCurrencyRowsRetainUnitEvidence() {
    RecordHealthCheckDisplayCurrencyResolver.multiCurrency = true;
    List<SObject> rows = new List<SObject>{
      [SELECT COUNT(Id) CurrencyIsoCode FROM Account]
    };

    Test.startTest();
    RecordHealthCheckCurrencySupport.requireCompatibleQueryUnits(
      'SELECT SUM(AnnualRevenue), CurrencyIsoCode FROM Account GROUP BY CurrencyIsoCode',
      'expr0',
      rows,
      null,
      null,
      new List<SObject>(),
      null
    );
    Test.stopTest();

    Assert.areEqual(1, rows.size());
  }

  @IsTest
  static void aggregateCurrencyRowsRejectMixedUnits() {
    RecordHealthCheckDisplayCurrencyResolver.multiCurrency = true;
    RecordHealthCheckTestDataFactory.createAccount('Currency coverage');
    List<SObject> primaryRows = new List<SObject>{
      [SELECT COUNT(Id) CurrencyIsoCode FROM Account]
    };
    List<SObject> comparisonRows = new List<SObject>{
      [SELECT COUNT(Id) CurrencyIsoCode FROM Contact]
    };

    Test.startTest();
    try {
      RecordHealthCheckCurrencySupport.requireCompatibleQueryUnits(
        'SELECT SUM(AnnualRevenue), CurrencyIsoCode FROM Account GROUP BY CurrencyIsoCode',
        'expr0',
        primaryRows,
        'SELECT SUM(Amount), CurrencyIsoCode FROM Opportunity GROUP BY CurrencyIsoCode',
        'expr0',
        comparisonRows,
        null
      );
      Assert.fail('Different aggregate unit evidence must be rejected.');
    } catch (RecordHealthCheckEvaluatorException expected) {
      Assert.areEqual(
        RecordHealthCheckReasonCodes.MIXED_CURRENCY,
        expected.reasonCode
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void aggregateCurrencyRowsRejectMissingUnits() {
    RecordHealthCheckDisplayCurrencyResolver.multiCurrency = true;
    List<SObject> rows = new List<SObject>{
      [SELECT MAX(ParentId) CurrencyIsoCode FROM Account]
    };

    Test.startTest();
    try {
      RecordHealthCheckCurrencySupport.requireCompatibleQueryUnits(
        'SELECT SUM(AnnualRevenue), CurrencyIsoCode FROM Account GROUP BY CurrencyIsoCode',
        'expr0',
        rows,
        null,
        null,
        new List<SObject>(),
        null
      );
      Assert.fail('Missing aggregate unit evidence must be rejected.');
    } catch (RecordHealthCheckEvaluatorException expected) {
      Assert.areEqual('CURRENCY_UNIT_UNKNOWN', expected.reasonCode);
    }
    Test.stopTest();
  }

  @IsTest
  static void currencySelectionHelpersRejectNonCurrencyInputs() {
    RecordHealthCheckDisplayCurrencyResolver.multiCurrency = true;

    Test.startTest();
    Boolean blankAggregate = RecordHealthCheckCurrencySupport.isCurrencyAggregateSelection(
      null
    );
    Boolean numericAggregate = RecordHealthCheckCurrencySupport.isCurrencyAggregateSelection(
      'SELECT MAX(NumberOfEmployees) FROM Account'
    );
    String isoPath = RecordHealthCheckCurrencySupport.currencyIsoFieldPath(
      'SELECT Name FROM Account',
      'Name'
    );
    Test.stopTest();

    Assert.isFalse(blankAggregate);
    Assert.isFalse(numericAggregate);
    Assert.isNull(isoPath);
  }

  private static Record_Health_Check__mdt baseCheck(String evaluationType) {
    return RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'Coverage_Boundary',
        'CheckTitle__c' => 'Coverage boundary',
        'EvaluationType__c' => evaluationType,
        'PassConditionFormula__c' => evaluationType == 'FORMULA'
          ? 'TRUE'
          : null,
        'FailureSeverity__c' => 'WARNING',
        'FailureMessage__c' => 'Failed.',
        'UnableToEvaluateMessage__c' => 'Unable.',
        'ApplicabilityMode__c' => 'ALL_RECORDS',
        'NoRowsResult__c' => 'FAIL',
        'EmptyValueHandling__c' => 'SKIP_RECORD'
      }
    );
  }

  private static Record_Health_Check__mdt queryCheck() {
    Record_Health_Check__mdt check = baseCheck('QUERY');
    check.SourceQuery__c = 'SELECT Industry FROM Account';
    check.SourceQueryField__c = 'Industry';
    check.QueryResultHandling__c = 'ONE_RESULT';
    check.ComparisonOperator__c = 'EQUALS';
    check.ExpectedValueSource__c = 'FIXED_VALUE';
    check.ExpectedFixedValue__c = 'Technology';
    return check;
  }

  private static Record_Health_Check__mdt dualCheck() {
    Record_Health_Check__mdt check = baseCheck('COMPARE_TWO_QUERIES');
    check.SourceQuery__c = 'SELECT Industry FROM Account';
    check.SourceQueryField__c = 'Industry';
    check.ComparisonQuery__c = 'SELECT Industry FROM Account';
    check.ComparisonQueryField__c = 'Industry';
    check.QueryResultHandling__c = 'ONE_RESULT';
    check.ComparisonOperator__c = 'EQUALS';
    return check;
  }
}
