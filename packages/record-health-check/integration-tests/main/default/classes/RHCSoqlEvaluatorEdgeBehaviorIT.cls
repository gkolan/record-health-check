/**
 * Defensive evaluator edge-case tests.
 * SPDX-License-Identifier: Apache-2.0
 */
@IsTest
private class RHCSoqlEvaluatorEdgeBehaviorIT {
  @TestSetup
  static void setup() {
    RHCIntegrationTestDataFactory.createCoverageTestRecords();
  }

  @IsTest
  static void soqlEvaluatorCoversRemainingDefensiveBranches() {
    Account accountRecord = RHCIntegrationTestDataFactory.getHealthyAccount();
    RHCIntegrationTestDataFactory.createAccount('Second Query Account');
    RecordHealthCheckSoqlEvaluator soql = new RecordHealthCheckSoqlEvaluator();
    Record_Health_Check__mdt invalidListFormula = queryCheck(
      'Soql_Invalid_List_Formula'
    );
    invalidListFormula.ComparisonOperator__c = 'LIST_CONTAINS_ANY';
    invalidListFormula.QueryResultHandling__c = 'COMPARE_AS_LISTS';
    invalidListFormula.SourceQuery__c = null;
    invalidListFormula.FindInListFormula__c = 'Not A Formula(';
    invalidListFormula.ComparisonQuery__c = 'SELECT MailingCity FROM Contact';
    invalidListFormula.ComparisonQueryField__c = 'MailingCity';
    assertReason(
      soql.evaluate(invalidListFormula, accountRecord.Id, accountRecord),
      'INVALID_FORMULA'
    );
    Record_Health_Check__mdt query = queryCheck('Soql_Multiple_Primary_Rows');
    query.SourceQuery__c = 'SELECT Name FROM Account';
    query.SourceQueryField__c = 'Name';
    assertReason(
      soql.evaluate(query, accountRecord.Id, accountRecord),
      'MULTIPLE_ROWS_RETURNED'
    );

    query = queryCheck('Soql_Invalid_Comparison_Formula');
    query.ExpectedValueSource__c = 'RECORD_FORMULA';
    query.ExpectedRecordFormula__c = 'Not A Formula(';
    assertReason(
      soql.evaluate(query, accountRecord.Id, accountRecord),
      'INVALID_FORMULA'
    );
    query = queryCheck('Soql_Empty_Comparison_Query');
    query.ExpectedValueSource__c = 'COMPARISON_QUERY';
    query.ComparisonQuery__c = 'SELECT BillingCity FROM Account WHERE Name = \'does not exist\'';
    query.ComparisonQueryField__c = 'BillingCity';
    assertStatus(soql.evaluate(query, accountRecord.Id, accountRecord), 'FAIL');

    try {
      soql.runQueryForEvaluation('', 1);
      Assert.isTrue(false, 'Expected a template error.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.areEqual('INVALID_SOQL_TEMPLATE', ex.reasonCode);
    }
    try {
      soql.resolveFieldList(new List<SObject>{ accountRecord }, null);
      Assert.isTrue(false, 'Expected a missing field error.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.areEqual('INVALID_SOQL_TEMPLATE', ex.reasonCode);
    }
    try {
      RecordHealthCheckComparisonEngine.applySingleComparison(
        'Nope',
        'a',
        'b',
        query
      );
      Assert.isTrue(false, 'Expected an invalid operator.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.areEqual('INVALID_OPERATOR', ex.reasonCode);
    }
    query.EmptyValueHandling__c = 'AS_BLANK';
    RecordHealthCheckComparisonEngine.applyListComparison(
      'LIST_CONTAINS_ANY',
      null,
      new List<Object>{ '' },
      query
    );
    query.EmptyValueHandling__c = 'SKIP_RECORD';
    Assert.areEqual(
      null,
      RecordHealthCheckComparisonEngine.applyListComparison(
        'LIST_CONTAINS_ANY',
        null,
        new List<Object>{ 'a' },
        query
      )
    );
    Assert.areEqual(
      null,
      RecordHealthCheckComparisonEngine.resolveEmptyBehavior('SKIP')
    );
    Assert.areEqual(
      null,
      RecordHealthCheckComparisonEngine.resolveEmptyBehavior(null)
    );
    query.NoRowsResult__c = 'FAIL';
    query.FailureMessage__c = null;
    Assert.areEqual(
      'No matching records found.',
      soql.buildEmptyOrNullResult(
          query,
          new RecordHealthCheckInternalResult(),
          null
        )
        .message
    );
    Assert.areEqual(
      false,
      RecordHealthCheckSoqlBindValueResolver.isMultiSelectPicklist(
        accountRecord,
        'Bogus.Name'
      )
    );
    Account child = (Account) JSON.deserialize(
      '{"attributes":{"type":"Account"},"Parent":{"attributes":{"type":"Account"},"Name":"Parent"}}',
      Account.class
    );
    Assert.areEqual(
      'Parent',
      RecordHealthCheckSoqlBindValueResolver.resolveFieldPath(
        child,
        'Parent.Name'
      )
    );
    query.UnableToEvaluateMessage__c = null;
    Assert.areEqual(
      'This check could not be evaluated. Contact your administrator.',
      RecordHealthCheckQueryEvaluatorSupport.safeCannotEvaluateMessage(query)
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
    Record_Health_Check__mdt check = queryCheck('Invalid_Query');
    check.SourceQuery__c = 'SELECT DefinitelyMissing__c FROM Account';

    Test.startTest();
    RecordHealthCheckInternalResult result = new RecordHealthCheckSoqlEvaluator()
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
  static void multiRowIsBlankEvaluatesNullsWhenEmptyValuesSkip() {
    List<Account> accounts = new List<Account>{
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'Name' => 'Unary Blank Alpha' }
      ),
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'Name' => 'Unary Blank Beta' }
      )
    };
    RHCIntegrationTestDataFactory.createAccounts(accounts);
    Record_Health_Check__mdt check = queryCheck('Multi_Row_Is_Blank');
    check.SourceQuery__c = 'SELECT Description FROM Account WHERE Name LIKE \'Unary Blank %\'';
    check.SourceQueryField__c = 'Description';
    check.QueryResultHandling__c = 'ANY_ROW_PASSES';
    check.ComparisonOperator__c = 'IS_BLANK';
    check.ExpectedValueSource__c = null;
    check.EmptyValueHandling__c = 'SKIP_RECORD';

    Test.startTest();
    RecordHealthCheckInternalResult result = new RecordHealthCheckSoqlEvaluator()
      .evaluate(check, accounts[0].Id, accounts[0]);
    Integer failingRows = RecordHealthCheckComparisonEngine.countFailingRows(
      check,
      new List<Object>{ null, null },
      null
    );
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckStatus.PASS,
      result.status,
      'IS_BLANK must evaluate present null rows before Skip Record handling.'
    );
    Assert.areEqual(
      0,
      failingRows,
      'The multi-row summary must agree that both blank rows pass.'
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
