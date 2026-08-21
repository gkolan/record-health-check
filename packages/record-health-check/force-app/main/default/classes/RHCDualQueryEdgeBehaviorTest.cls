/**
 * Defensive evaluator edge-case tests.
 * SPDX-License-Identifier: Apache-2.0
 */
@IsTest
private class RHCDualQueryEdgeBehaviorTest {
  @TestSetup
  static void setup() {
    RecordHealthCheckTestDataFactory.createCoverageTestRecords();
  }

  @IsTest
  static void dualQueryCoversRemainingEdgeBranches() {
    List<SObject> emptyRows = new List<SObject>();
    List<SObject> accountRows = new List<SObject>();
    accountRows.add(
      [
        SELECT Id, BillingCity, BillingState
        FROM Account
        LIMIT 1
      ]
    );
    List<SObject> duplicateRows = new List<SObject>{
      accountRows[0],
      accountRows[0]
    };
    Record_Health_Check__mdt dualCheck = validDualCheck('Helper_Dual');
    dualCheck.NoRowsResult__c = 'FAIL';
    dualCheck.SourceQueryField__c = 'BillingCity';
    dualCheck.ComparisonQueryField__c = 'BillingCity';
    dualCheck.EmptyValueHandling__c = 'AS_NO_MATCH';

    Assert.areEqual(
      false,
      RecordHealthCheckCompareQuerySupport.evaluateSingleVsSingle(
        dualCheck,
        emptyRows,
        accountRows
      )
    );
    dualCheck.EmptyValueHandling__c = 'AS_BLANK';
    Assert.areEqual(
      true,
      RecordHealthCheckCompareQuerySupport.evaluateSingleVsSingle(
        dualCheck,
        emptyRows,
        emptyRows
      )
    );
    dualCheck.EmptyValueHandling__c = null;
    Assert.areEqual(
      null,
      RecordHealthCheckCompareQuerySupport.evaluateSingleVsSingle(
        dualCheck,
        emptyRows,
        accountRows
      )
    );
    try {
      RecordHealthCheckCompareQuerySupport.resolveSingleValue(
        duplicateRows,
        'Id',
        'primary'
      );
      Assert.isTrue(false, 'Expected multiple row exception.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.areEqual('MULTIPLE_ROWS_RETURNED', ex.reasonCode);
    }
    try {
      RecordHealthCheckCompareQuerySupport.resolveSingleValue(
        accountRows,
        null,
        'primary'
      );
      Assert.isTrue(false, 'Expected missing field exception.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.areEqual('INVALID_SOQL_TEMPLATE', ex.reasonCode);
    }

    Record_Health_Check__mdt dualList = validDualCheck('Helper_Dual_List');
    dualList.QueryResultHandling__c = 'COMPARE_AS_LISTS';
    dualList.SourceQueryField__c = 'BillingCity';
    dualList.ComparisonQueryField__c = 'BillingState';
    dualList.ComparisonOperator__c = 'LISTS_OVERLAP';
    Assert.areEqual(
      false,
      RecordHealthCheckCompareQuerySupport.evaluateListVsList(
        dualList,
        accountRows,
        accountRows
      )
    );
    dualList.ComparisonOperator__c = 'LISTS_CONTAIN_ALL';
    dualList.ComparisonQueryField__c = 'BillingCity';
    Assert.areEqual(
      true,
      RecordHealthCheckCompareQuerySupport.evaluateListVsList(
        dualList,
        accountRows,
        accountRows
      )
    );
    dualList.ComparisonOperator__c = 'LISTS_MATCH_EXACTLY';
    Assert.areEqual(
      true,
      RecordHealthCheckCompareQuerySupport.evaluateListVsList(
        dualList,
        accountRows,
        accountRows
      )
    );
    dualList.ComparisonOperator__c = 'BadList';
    try {
      RecordHealthCheckCompareQuerySupport.evaluateListVsList(
        dualList,
        accountRows,
        accountRows
      );
      Assert.isTrue(false, 'Expected invalid compare-queries list operator.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.areEqual('INVALID_OPERATOR', ex.reasonCode);
    }
    try {
      RecordHealthCheckCompareQuerySupport.toStringList(
        accountRows,
        null,
        'primary',
        'AS_BLANK'
      );
      Assert.isTrue(false, 'Expected missing list field exception.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.areEqual('INVALID_SOQL_TEMPLATE', ex.reasonCode);
    }
    try {
      RecordHealthCheckCompareQuerySupport.toStringList(
        accountRows,
        'Missing__c',
        'primary',
        'AS_BLANK'
      );
      Assert.isTrue(false, 'Expected invalid list field exception.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.areEqual('INVALID_SOQL_TEMPLATE', ex.reasonCode);
    }

    Assert.areEqual(
      true,
      RecordHealthCheckComparisonEngine.applySingleValueComparison(
        'NOT_EQUALS',
        'a',
        'b'
      )
    );
    Assert.areEqual(
      true,
      RecordHealthCheckComparisonEngine.applySingleValueComparison(
        'CONTAINS',
        'abc',
        'b'
      )
    );
    Assert.areEqual(
      true,
      RecordHealthCheckComparisonEngine.applySingleValueComparison(
        'DOES_NOT_CONTAIN',
        'abc',
        'z'
      )
    );
    try {
      RecordHealthCheckComparisonEngine.applySingleValueComparison(
        'CONTAINS',
        2100,
        '100'
      );
      Assert.fail('Numeric values must not be compared as substrings.');
    } catch (RecordHealthCheckEvaluatorException expected) {
      Assert.areEqual('INCOMPATIBLE_COMPARISON_TYPES', expected.reasonCode);
    }
    Assert.areEqual(
      true,
      RecordHealthCheckComparisonEngine.applySingleValueComparison(
        'GREATER_THAN_OR_EQUAL',
        2,
        2
      )
    );
    Assert.areEqual(
      true,
      RecordHealthCheckComparisonEngine.applySingleValueComparison(
        'LESS_THAN_OR_EQUAL',
        Datetime.now(),
        Datetime.now().addSeconds(1)
      )
    );
    Assert.areEqual(
      true,
      RecordHealthCheckComparisonEngine.applySingleValueComparison(
        'LESS_THAN',
        Date.today(),
        Date.today().addDays(1)
      )
    );
    try {
      RecordHealthCheckComparisonEngine.applySingleValueComparison(
        'Nope',
        'a',
        'b'
      );
      Assert.isTrue(false, 'Expected invalid single-value operator.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.areEqual('INVALID_OPERATOR', ex.reasonCode);
    }
    try {
      RecordHealthCheckComparisonEngine.applySingleValueComparison(
        'GREATER_THAN',
        'a',
        'b'
      );
      Assert.isTrue(false, 'Expected incompatible single-value operator.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.areEqual('INCOMPATIBLE_COMPARISON_TYPES', ex.reasonCode);
    }

    Assert.areEqual(
      false,
      RecordHealthCheckCompareQuerySupport.frequencyMapsEqual(
        RecordHealthCheckCompareQuerySupport.toFrequencyMap(
          new List<String>{ 'a' }
        ),
        RecordHealthCheckCompareQuerySupport.toFrequencyMap(
          new List<String>{ 'a', 'a' }
        )
      )
    );
    try {
      RecordHealthCheckComparisonEngine.valuesEqual(
        Date.today(),
        String.valueOf(Date.today())
      );
      Assert.isTrue(false, 'Expected Date coercion incompatibility.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.isTrue(
        ex.reasonCode == 'INCOMPATIBLE_COMPARISON_TYPES',
        'Expected a typed comparison error.'
      );
    }
    Assert.areEqual(
      true,
      RecordHealthCheckValueResolver.isNumericObject(Decimal.valueOf('1'))
    );
    Assert.areEqual(false, RecordHealthCheckValueResolver.isNumericObject('1'));
    try {
      RecordHealthCheckQueryEvaluatorSupport.runQuery(
        'SELECT Id FROM Account',
        0
      );
      Assert.isTrue(false, 'Expected compare-queries row cap exception.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.areEqual('ROW_LIMIT_EXCEEDED', ex.reasonCode);
    }
    try {
      RecordHealthCheckQueryEvaluatorSupport.runQuery(
        'SELECT Missing__c FROM Account',
        1
      );
      Assert.isTrue(false, 'Expected compare-queries invalid query exception.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.areEqual('FIELD_NOT_RESOLVED', ex.reasonCode);
    }
    Assert.areEqual(
      false,
      RecordHealthCheckComparisonEngine.resolveEmptyBehavior('FAIL')
    );
    Assert.areEqual(
      null,
      RecordHealthCheckComparisonEngine.resolveEmptyBehavior('SKIP')
    );
    Assert.areEqual(
      'FAIL',
      RecordHealthCheckQueryEvaluatorSupport.buildEmptyResult(
          dualCheck,
          new RecordHealthCheckInternalResult(),
          null
        )
        .status
    );
    dualCheck.NoRowsResult__c = 'UNABLE_TO_EVALUATE';
    assertReason(
      RecordHealthCheckQueryEvaluatorSupport.buildEmptyResult(
        dualCheck,
        new RecordHealthCheckInternalResult(),
        null
      ),
      'NO_ROWS_RETURNED'
    );
  }

  private static Record_Health_Check__mdt baseCheck(
    String developerName,
    String checkType
  ) {
    return RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => developerName,
        'MasterLabel' => developerName,
        'CheckTitle__c' => developerName,
        'EvaluationType__c' => checkType,
        'FailureSeverity__c' => 'WARNING',
        'PassConditionFormula__c' => checkType == 'FORMULA' ? 'TRUE' : null,
        'FailureMessage__c' => 'Apex failure for {!record.Name}',
        'UnableToEvaluateMessage__c' => 'Cannot evaluate test check.',
        'FormulaResultType__c' => 'AUTO',
        'EvaluationOrder__c' => 10,
        'ApplicabilityMode__c' => 'ALL_RECORDS',
        'NoRowsResult__c' => 'FAIL',
        'EmptyValueHandling__c' => 'SKIP_RECORD'
      }
    );
  }

  @IsTest
  static void evaluatorMapsPlatformQueryFailuresToStableConfigurationResult() {
    Account accountRecord = [SELECT Id, Name FROM Account LIMIT 1];
    Record_Health_Check__mdt check = validDualCheck('Invalid_Query');
    check.SourceQuery__c = 'SELECT DefinitelyMissing__c FROM Account';

    Test.startTest();
    RecordHealthCheckInternalResult result = new RecordHealthCheckCompareQueriesEvaluator()
      .evaluate(check, accountRecord.Id, accountRecord);
    Test.stopTest();

    Assert.areEqual('UNABLE_TO_EVALUATE', result.status);
    Assert.areEqual(
      'FIELD_NOT_RESOLVED',
      result.reasonCode,
      'A supported flat selected field must be describe-validated before execution.'
    );
  }

  @IsTest
  static void scopeEvaluatorMapsBlankAndUnexpectedCachedQueryFailures() {
    Account accountRecord = [SELECT Id, Name FROM Account LIMIT 1];

    Record_Health_Check__mdt blankCheck = validDualCheck('Blank_Scope_Query');
    blankCheck.SourceQuery__c = ' ';
    blankCheck.ComparisonQuery__c = ' ';
    RecordHealthCheckCompareQueriesEvaluator blankEvaluator = new RecordHealthCheckCompareQueriesEvaluator();
    blankEvaluator.scopeRowsByBoundSoql = new Map<String, List<SObject>>();
    blankEvaluator.scopeZeroCountSoql = new Set<String>();
    blankEvaluator.scopeExecutionActive = true;

    RecordHealthCheckInternalResult blankResult = blankEvaluator.evaluate(
      blankCheck,
      accountRecord.Id,
      accountRecord
    );
    Assert.areEqual('UNABLE_TO_EVALUATE', blankResult.status);
    Assert.areEqual('INVALID_SOQL_TEMPLATE', blankResult.reasonCode);

    Record_Health_Check__mdt cachedCheck = validDualCheck(
      'Unexpected_Cached_Query'
    );
    String boundQuery = new RecordHealthCheckSoqlEvaluator()
      .bindTokens(cachedCheck.SourceQuery__c, accountRecord);
    RecordHealthCheckCompareQueriesEvaluator cachedEvaluator = new RecordHealthCheckCompareQueriesEvaluator();
    cachedEvaluator.scopeRowsByBoundSoql = new Map<String, List<SObject>>{
      boundQuery => null
    };
    cachedEvaluator.scopeZeroCountSoql = new Set<String>();
    cachedEvaluator.scopeExecutionActive = true;

    RecordHealthCheckInternalResult cachedResult = cachedEvaluator.evaluate(
      cachedCheck,
      accountRecord.Id,
      accountRecord
    );
    Assert.areEqual('ERROR', cachedResult.status);
    Assert.areEqual('APEX_EVALUATOR_ERROR', cachedResult.reasonCode);
  }

  private static Record_Health_Check__mdt dualCheck(String developerName) {
    return baseCheck(developerName, 'COMPARE_TWO_QUERIES');
  }

  private static Record_Health_Check__mdt validDualCheck(String developerName) {
    Record_Health_Check__mdt check = dualCheck(developerName);
    check.SourceQuery__c = 'SELECT COUNT(Id) totalCount FROM Contact WHERE AccountId = {!record.Id}';
    check.SourceQueryField__c = 'totalCount';
    check.ComparisonQuery__c = 'SELECT COUNT(Id) totalCount FROM Contact WHERE AccountId = {!record.Id}';
    check.ComparisonQueryField__c = 'totalCount';
    check.QueryResultHandling__c = 'ONE_RESULT';
    check.ComparisonOperator__c = 'EQUALS';
    return check;
  }

  private static void assertUnable(
    RecordHealthCheckInternalResult result,
    String reasonCode
  ) {
    Assert.areNotEqual(null, result, 'Expected an unable result.');
    Assert.areEqual('UNABLE_TO_EVALUATE', result.status);
    Assert.areEqual(reasonCode, result.reasonCode);
  }

  private static void assertStatus(
    RecordHealthCheckInternalResult result,
    String status
  ) {
    Assert.areNotEqual(null, result, 'Expected a result.');
    Assert.areEqual(
      status,
      result.status,
      'Unexpected detail: ' + result.detailMessage
    );
  }

  private static void assertReason(
    RecordHealthCheckInternalResult result,
    String reasonCode
  ) {
    Assert.areNotEqual(null, result, 'Expected a result.');
    Assert.areEqual(
      reasonCode,
      result.reasonCode,
      'Unexpected status/detail: ' + result.status + ' ' + result.detailMessage
    );
  }
}
