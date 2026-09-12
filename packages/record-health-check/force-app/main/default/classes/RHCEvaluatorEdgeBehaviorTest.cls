/**
 * Defensive evaluator edge-case tests.
 * SPDX-License-Identifier: Apache-2.0
 */
@IsTest
private class RHCEvaluatorEdgeBehaviorTest {
  @TestSetup
  static void setup() {
    RecordHealthCheckTestDataFactory.prepareCoverageFixtures();
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
    Assert.areEqual(
      'UNABLE_TO_EVALUATE',
      result.status,
      'An unable helper result must retain its terminal status.'
    );
    Assert.areEqual(
      reasonCode,
      result.reasonCode,
      'An unable helper result must retain its specific reason.'
    );
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

  @IsTest
  static void comparisonOperatorsCoverRemainingEdgeBranches() {
    Account accountRecord = RecordHealthCheckTestDataFactory.healthyAccountFixture();
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
      Assert.areEqual(
        'INVALID_SOQL_TEMPLATE',
        ex.reasonCode,
        'FOR UPDATE must retain the invalid-template rejection.'
      );
    }

    Assert.areEqual(
      1,
      soql
        .runQueryForEvaluation(
          'SELECT COUNT() FROM Contact WHERE AccountId = null',
          1
        )
        .size(),
      'A COUNT query must yield one aggregate row within the cap.'
    );
    try {
      soql.runQueryForEvaluation('SELECT COUNT() FROM Account', 0);
      Assert.isTrue(false, 'Expected row cap exception.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.areEqual(
        'ROW_LIMIT_EXCEEDED',
        ex.reasonCode,
        'A zero row cap must retain the row-limit reason.'
      );
    }
    try {
      soql.runQueryForEvaluation('SELECT NotAField__c FROM Account', 1);
      Assert.isTrue(false, 'Expected invalid query exception.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.areEqual(
        'FIELD_NOT_RESOLVED',
        ex.reasonCode,
        'An invalid selected field must retain the unresolved-field reason.'
      );
    }

    Assert.areEqual(
      accountRecord.BillingCity,
      soql.readQueryFieldValue(accountRecord, 'BillingCity'),
      'Reading BillingCity must return the selected field value.'
    );
    try {
      soql.readQueryFieldValue(accountRecord, null);
      Assert.isTrue(false, 'Expected missing field exception.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.areEqual(
        'INVALID_SOQL_TEMPLATE',
        ex.reasonCode,
        'Reading an unspecified query field must reject the template.'
      );
    }
    Assert.areEqual(
      1,
      soql.resolveFieldList(accountRows, 'BillingCity').size(),
      'A one-row field projection must return one value.'
    );

    assertScalarAndMultiRowBehavior(query, emptyRows);

    query.EmptyValueHandling__c = 'AS_NO_MATCH';
    Assert.areEqual(
      false,
      RecordHealthCheckComparisonEngine.applyListComparison(
        'LIST_CONTAINS_ANY',
        null,
        new List<Object>{ 'a' },
        query
      ),
      'A missing search value must not match LIST_CONTAINS_ANY under AS_NO_MATCH.'
    );
    Assert.areEqual(
      true,
      RecordHealthCheckComparisonEngine.applyListComparison(
        'LIST_CONTAINS_NONE',
        null,
        new List<Object>{ 'a' },
        query
      ),
      'A missing search value must satisfy LIST_CONTAINS_NONE under AS_NO_MATCH.'
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
      Assert.areEqual(
        'INVALID_OPERATOR',
        ex.reasonCode,
        'An unknown list operator must retain the invalid-operator reason.'
      );
    }
    Assert.areEqual(
      false,
      RecordHealthCheckComparisonEngine.applyEmptyValueHandling('AS_NO_MATCH'),
      'AS_NO_MATCH must resolve empty values as false.'
    );
    Assert.areEqual(
      null,
      RecordHealthCheckComparisonEngine.applyEmptyValueHandling('SKIP_RECORD'),
      'SKIP_RECORD must resolve empty values as indeterminate.'
    );
    Assert.areEqual(
      null,
      RecordHealthCheckComparisonEngine.applyEmptyValueHandling(null),
      'An absent empty-value mode must remain indeterminate.'
    );
    Assert.areEqual(
      false,
      RecordHealthCheckComparisonEngine.resolveEmptyBehavior('FAIL'),
      'An empty FAIL outcome must resolve as false.'
    );
    Assert.areEqual(
      null,
      RecordHealthCheckComparisonEngine.resolveEmptyBehavior(
        'UNABLE_TO_EVALUATE'
      ),
      'An empty UNABLE_TO_EVALUATE outcome must remain indeterminate.'
    );
    assertEmptyResultOutcomes(query, soql);

    Assert.areEqual(
      true,
      RecordHealthCheckValueResolver.isNumericObject(Decimal.valueOf('1.5')),
      'A Decimal must be recognized as numeric.'
    );
    Assert.areEqual(
      false,
      RecordHealthCheckValueResolver.isNumericObject('1.5'),
      'Numeric-looking text must not be treated as a numeric object.'
    );
  }
  private static void assertScalarAndMultiRowBehavior(
    Record_Health_Check__mdt query,
    List<SObject> emptyRows
  ) {
    Assert.areEqual(
      true,
      RecordHealthCheckComparisonEngine.applyUnaryComparison('IS_BLANK', ' '),
      'Whitespace must satisfy IS_BLANK.'
    );
    Assert.areEqual(
      false,
      RecordHealthCheckComparisonEngine.applyUnaryComparison(
        'IS_NOT_BLANK',
        null
      ),
      'A null value must not satisfy IS_NOT_BLANK.'
    );
    try {
      RecordHealthCheckComparisonEngine.applyUnaryComparison('Bogus', 'x');
      Assert.isTrue(false, 'Expected an invalid unary operator exception.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.areEqual(
        'INVALID_OPERATOR',
        ex.reasonCode,
        'An unknown unary operator must retain the invalid-operator reason.'
      );
    }
    Assert.areEqual(
      true,
      RecordHealthCheckComparisonEngine.applySingleComparison(
        'EQUALS',
        5,
        '5',
        query
      ),
      'A numeric value and its fixed text operand must compare equal.'
    );
    Assert.areEqual(
      true,
      RecordHealthCheckComparisonEngine.applySingleComparison(
        'GREATER_THAN_OR_EQUAL',
        5,
        5,
        query
      ),
      'Equal numeric operands must satisfy GREATER_THAN_OR_EQUAL.'
    );
    Assert.areEqual(
      true,
      RecordHealthCheckComparisonEngine.applySingleComparison(
        'LESS_THAN',
        Date.today(),
        Date.today().addDays(1),
        query
      ),
      'Today must compare less than tomorrow.'
    );
    Assert.areEqual(
      true,
      RecordHealthCheckComparisonEngine.applySingleComparison(
        'LESS_THAN_OR_EQUAL',
        Datetime.now(),
        Datetime.now().addSeconds(1),
        query
      ),
      'An earlier timestamp must satisfy LESS_THAN_OR_EQUAL.'
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
      ),
      'AS_NO_MATCH must reject a null operand as a match.'
    );
    query.EmptyValueHandling__c = 'AS_BLANK';
    Assert.areEqual(
      true,
      RecordHealthCheckComparisonEngine.applySingleComparisonNullSafe(
        'EQUALS',
        null,
        '',
        query
      ),
      'AS_BLANK must compare null and empty text as equal.'
    );
    query.EmptyValueHandling__c = 'SKIP_RECORD';
    Assert.areEqual(
      null,
      RecordHealthCheckComparisonEngine.applySingleComparisonNullSafe(
        'EQUALS',
        null,
        '',
        query
      ),
      'SKIP_RECORD must leave a null comparison indeterminate.'
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
      ),
      'An empty multirow query configured PASS must pass.'
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
      ),
      'ANY_ROW_PASSES with only skipped values must remain indeterminate.'
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
      ),
      'ALL_ROWS_PASS with only skipped values must remain indeterminate.'
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
      Assert.areEqual(
        'INVALID_OPERATOR',
        ex.reasonCode,
        'An unknown multirow mode must retain the invalid-operator reason.'
      );
    }
  }
  private static void assertEmptyResultOutcomes(
    Record_Health_Check__mdt query,
    RecordHealthCheckSoqlEvaluator soql
  ) {
    Assert.areEqual(
      'FAIL',
      soql.buildEmptyOrNullResult(
          query,
          new RecordHealthCheckInternalResult(),
          null
        )
        .status,
      'The empty-result builder must preserve configured FAIL.'
    );
    query.NoRowsResult__c = 'PASS';
    Assert.areEqual(
      'PASS',
      soql.buildEmptyOrNullResult(
          query,
          new RecordHealthCheckInternalResult(),
          null
        )
        .status,
      'The empty-result builder must preserve configured PASS.'
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
  }
}
