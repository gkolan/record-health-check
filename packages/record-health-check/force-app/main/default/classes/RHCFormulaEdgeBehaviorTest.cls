/**
 * Defensive evaluator edge-case tests.
 * SPDX-License-Identifier: Apache-2.0
 */
@IsTest
private class RHCFormulaEdgeBehaviorTest {
  @TestSetup
  static void setup() {
    RecordHealthCheckTestDataFactory.createCoverageTestRecords();
  }

  @IsTest
  static void formulaEvaluatorCoversNullAndMergeFieldBranches() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    RecordHealthCheckFormulaEvaluator evaluator = new RecordHealthCheckFormulaEvaluator();
    String[] reasonCode = new List<String>{ null };

    Assert.areEqual(
      null,
      evaluator.evaluateApplicabilityFormula('NULL', accountRecord, reasonCode)
    );
    Assert.areEqual('INVALID_FORMULA', reasonCode[0]);

    Account nullTextAccount = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => null }
    );
    Assert.areEqual(
      'Name: ',
      evaluator.resolveMergeFields('Name: {!record.Name}', nullTextAccount)
    );
  }

  @IsTest
  static void formulaEvaluationMapsNullBudgetAndFieldAccessFailures() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    RecordHealthCheckFormulaEvaluator evaluator = new RecordHealthCheckFormulaEvaluator();
    Record_Health_Check__mdt nullCheck = baseCheck('Null_Formula', 'FORMULA');
    nullCheck.PassConditionFormula__c = 'NULL';
    nullCheck.UnableToEvaluateMessage__c = null;

    RecordHealthCheckInternalResult nullResult = evaluator.evaluate(
      nullCheck,
      accountRecord.Id,
      accountRecord
    );
    Assert.areEqual('UNABLE_TO_EVALUATE', nullResult.status);
    Assert.areEqual('INVALID_FORMULA', nullResult.reasonCode);
    Assert.isTrue(
      nullResult.detailMessage.contains('returned null'),
      'A null Boolean result must explain the likely relationship or access problem.'
    );

    Integer originalCount = RecordHealthCheckFormulaEvaluator.formulaEvalCallCount;
    try {
      RecordHealthCheckFormulaEvaluator.formulaEvalCallCount = RecordHealthCheckFormulaEvaluator.FORMULA_CALL_BUDGET;
      RecordHealthCheckInternalResult budgetResult = evaluator.evaluate(
        baseCheck('Budget_Formula', 'FORMULA'),
        accountRecord.Id,
        accountRecord
      );
      Assert.areEqual('FORMULA_EVAL_LIMIT', budgetResult.reasonCode);
    } finally {
      RecordHealthCheckFormulaEvaluator.formulaEvalCallCount = originalCount;
    }
  }

  @IsTest
  static void numericNullIsTreatedAsZeroRow26() {
    Account accountRecord = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Name' => 'Numeric null formula',
        'NumberOfEmployees' => null
      }
    );
    accountRecord.Id = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      26
    );
    Record_Health_Check__mdt check = baseCheck('Numeric_Null', 'FORMULA');
    check.PassConditionFormula__c = 'NumberOfEmployees = 0';

    RecordHealthCheckInternalResult result = new RecordHealthCheckFormulaEvaluator()
      .evaluate(check, accountRecord.Id, accountRecord);

    Assert.areEqual(
      RecordHealthCheckStatus.PASS,
      result.status,
      'FormulaEval numeric-null-as-zero is an intentional Formula Check contract.'
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
}
