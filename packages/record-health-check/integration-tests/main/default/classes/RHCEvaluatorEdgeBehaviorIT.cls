/**
 * Defensive evaluator edge-case tests.
 * SPDX-License-Identifier: Apache-2.0
 */
@IsTest
private class RHCEvaluatorEdgeBehaviorIT {
  @TestSetup
  static void setup() {
    RHCIntegrationTestDataFactory.createCoverageTestRecords();
  }

  @IsTest
  static void comparisonOperatorsCoverRemainingEdgeBranches() {
    Account accountRecord = [
      SELECT Id, Name, BillingCity, BillingState, Description, AnnualRevenue
      FROM Account
      WHERE Id = :RHCIntegrationTestDataFactory.getHealthyAccount().Id
    ];
    List<SObject> accountRows = new List<SObject>{ accountRecord };
    List<SObject> emptyRows = new List<SObject>();

    RecordHealthCheckSoqlEvaluator soql = new RecordHealthCheckSoqlEvaluator();
    Record_Health_Check__mdt query = queryCheck('Helper_Query');
    query.NoRowsResult__c = 'FAIL';

    RecordHealthCheckSoqlTokenBinder.validateNoDisallowedKeywords(
      'SELECT Last_Update__c FROM Account WHERE IsDeleted = false'
    );
    try {
      RecordHealthCheckSoqlTokenBinder.validateNoDisallowedKeywords(
        'SELECT Id FROM Account FOR UPDATE'
      );
      Assert.isTrue(false, 'Expected disallowed phrase.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.areEqual('INVALID_SOQL_TEMPLATE', ex.reasonCode);
    }

    Assert.areEqual(
      1,
      soql
        .runQueryForEvaluation(
          'SELECT COUNT() FROM Contact WHERE AccountId = null',
          1
        )
        .size()
    );
    try {
      soql.runQueryForEvaluation('SELECT Id FROM Account', 0);
      Assert.isTrue(false, 'Expected row cap exception.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.areEqual('ROW_LIMIT_EXCEEDED', ex.reasonCode);
    }
    try {
      soql.runQueryForEvaluation('SELECT NotAField__c FROM Account', 1);
      Assert.isTrue(false, 'Expected invalid query exception.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.areEqual('FIELD_NOT_RESOLVED', ex.reasonCode);
    }

    Assert.areEqual(
      accountRecord.BillingCity,
      soql.readQueryFieldValue(accountRecord, 'BillingCity')
    );
    try {
      soql.readQueryFieldValue(accountRecord, null);
      Assert.isTrue(false, 'Expected missing field exception.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.areEqual('INVALID_SOQL_TEMPLATE', ex.reasonCode);
    }
    Assert.areEqual(
      1,
      soql.resolveFieldList(accountRows, 'BillingCity').size()
    );

    Assert.areEqual(
      true,
      RecordHealthCheckComparisonEngine.applyUnaryComparison('IS_BLANK', ' ')
    );
    Assert.areEqual(
      false,
      RecordHealthCheckComparisonEngine.applyUnaryComparison(
        'IS_NOT_BLANK',
        null
      )
    );
    try {
      RecordHealthCheckComparisonEngine.applyUnaryComparison('Bogus', 'x');
      Assert.isTrue(false, 'Expected an invalid unary operator exception.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.areEqual('INVALID_OPERATOR', ex.reasonCode);
    }
    Assert.areEqual(
      true,
      RecordHealthCheckComparisonEngine.applySingleComparison(
        'EQUALS',
        5,
        '5',
        query
      )
    );
    Assert.areEqual(
      true,
      RecordHealthCheckComparisonEngine.applySingleComparison(
        'GREATER_THAN_OR_EQUAL',
        5,
        5,
        query
      )
    );
    Assert.areEqual(
      true,
      RecordHealthCheckComparisonEngine.applySingleComparison(
        'LESS_THAN',
        Date.today(),
        Date.today().addDays(1),
        query
      )
    );
    Assert.areEqual(
      true,
      RecordHealthCheckComparisonEngine.applySingleComparison(
        'LESS_THAN_OR_EQUAL',
        Datetime.now(),
        Datetime.now().addSeconds(1),
        query
      )
    );
    Record_Health_Check__mdt missingMeansNoMatch = query.clone();
    missingMeansNoMatch.EmptyValueHandling__c = 'AS_NO_MATCH';
    Assert.areEqual(
      false,
      RecordHealthCheckComparisonEngine.applySingleComparisonNullSafe(
        'EQUALS',
        null,
        'x',
        missingMeansNoMatch
      )
    );
    query.EmptyValueHandling__c = 'AS_BLANK';
    Assert.areEqual(
      true,
      RecordHealthCheckComparisonEngine.applySingleComparisonNullSafe(
        'EQUALS',
        null,
        '',
        query
      )
    );
    query.EmptyValueHandling__c = 'SKIP_RECORD';
    Assert.areEqual(
      null,
      RecordHealthCheckComparisonEngine.applySingleComparisonNullSafe(
        'EQUALS',
        null,
        '',
        query
      )
    );

    Record_Health_Check__mdt emptyPassCheck = queryCheck('Helper_Empty_Pass');
    emptyPassCheck.NoRowsResult__c = 'PASS';
    Assert.areEqual(
      true,
      RecordHealthCheckComparisonEngine.applyMultiRecordComparison(
        emptyPassCheck,
        emptyRows,
        'x',
        null
      )
    );
    Record_Health_Check__mdt anySkipped = queryCheck('Helper_Any_Skipped');
    anySkipped.QueryResultHandling__c = 'ANY_ROW_PASSES';
    anySkipped.EmptyValueHandling__c = 'SKIP_RECORD';
    Assert.areEqual(
      null,
      RecordHealthCheckComparisonEngine.applyMultiRecordComparison(
        anySkipped,
        new List<Object>{ null },
        'x',
        null
      )
    );
    Record_Health_Check__mdt allSkipped = anySkipped.clone();
    allSkipped.DeveloperName = 'Helper_All_Skipped';
    allSkipped.QueryResultHandling__c = 'ALL_ROWS_PASS';
    Assert.areEqual(
      null,
      RecordHealthCheckComparisonEngine.applyMultiRecordComparison(
        allSkipped,
        new List<Object>{ null },
        'x',
        null
      )
    );
    Record_Health_Check__mdt badMode = anySkipped.clone();
    badMode.DeveloperName = 'Helper_Bad_Mode';
    badMode.QueryResultHandling__c = 'Nope';
    try {
      RecordHealthCheckComparisonEngine.applyMultiRecordComparison(
        badMode,
        new List<Object>{ 'x' },
        'x',
        null
      );
      Assert.isTrue(false, 'Expected invalid mode.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.areEqual('INVALID_OPERATOR', ex.reasonCode);
    }

    query.EmptyValueHandling__c = 'AS_NO_MATCH';
    Assert.areEqual(
      false,
      RecordHealthCheckComparisonEngine.applyListComparison(
        'LIST_CONTAINS_ANY',
        null,
        new List<Object>{ 'a' },
        query
      )
    );
    Assert.areEqual(
      true,
      RecordHealthCheckComparisonEngine.applyListComparison(
        'LIST_CONTAINS_NONE',
        null,
        new List<Object>{ 'a' },
        query
      )
    );
    try {
      RecordHealthCheckComparisonEngine.applyListComparison(
        'BadList',
        'a',
        new List<Object>{ 'a' },
        query
      );
      Assert.isTrue(false, 'Expected invalid list operator.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.areEqual('INVALID_OPERATOR', ex.reasonCode);
    }
    Assert.areEqual(
      false,
      RecordHealthCheckComparisonEngine.applyEmptyValueHandling('AS_NO_MATCH')
    );
    Assert.areEqual(
      null,
      RecordHealthCheckComparisonEngine.applyEmptyValueHandling('SKIP_RECORD')
    );
    Assert.areEqual(
      null,
      RecordHealthCheckComparisonEngine.applyEmptyValueHandling(null)
    );
    Assert.areEqual(
      false,
      RecordHealthCheckComparisonEngine.resolveEmptyBehavior('FAIL')
    );
    Assert.areEqual(
      null,
      RecordHealthCheckComparisonEngine.resolveEmptyBehavior(
        'UNABLE_TO_EVALUATE'
      )
    );
    Assert.areEqual(
      'FAIL',
      soql.buildEmptyOrNullResult(
          query,
          new RecordHealthCheckInternalResult(),
          null
        )
        .status
    );
    query.NoRowsResult__c = 'PASS';
    Assert.areEqual(
      'PASS',
      soql.buildEmptyOrNullResult(
          query,
          new RecordHealthCheckInternalResult(),
          null
        )
        .status
    );
    query.NoRowsResult__c = 'UNABLE_TO_EVALUATE';
    assertReason(
      soql.buildEmptyOrNullResult(
        query,
        new RecordHealthCheckInternalResult(),
        null
      ),
      'NO_ROWS_RETURNED'
    );
    Assert.areEqual(
      true,
      RecordHealthCheckValueResolver.isNumericObject(Decimal.valueOf('1.5'))
    );
    Assert.areEqual(
      false,
      RecordHealthCheckValueResolver.isNumericObject('1.5')
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

  private static Record_Health_Check__mdt queryCheck(String developerName) {
    Record_Health_Check__mdt check = baseCheck(developerName, 'QUERY');
    check.SourceQuery__c = 'SELECT BillingCity FROM Account WHERE Id = {!record.Id}';
    check.SourceQueryField__c = 'BillingCity';
    check.QueryResultHandling__c = 'ONE_RESULT';
    check.ComparisonOperator__c = 'EQUALS';
    check.ExpectedValueSource__c = 'FIXED_VALUE';
    check.ExpectedFixedValue__c = 'Chicago';
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
