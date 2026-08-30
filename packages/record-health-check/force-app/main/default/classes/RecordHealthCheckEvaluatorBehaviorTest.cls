/**
 * Focused evaluator behavior and regression tests.
 * SPDX-License-Identifier: Apache-2.0
 */
@IsTest
private class RecordHealthCheckEvaluatorBehaviorTest {
  @TestSetup
  static void setup() {
    RecordHealthCheckTestDataFactory.createCoverageTestRecords();
  }

  @IsTest
  static void formulaEvaluatorCoversPassFailUnableAndMergeFields() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    RecordHealthCheckFormulaEvaluator evaluator = new RecordHealthCheckFormulaEvaluator();

    Record_Health_Check__mdt passCheck = baseCheck('F_Pass', 'FORMULA');
    passCheck.PassConditionFormula__c = 'NOT(ISBLANK(BillingCity))';
    assertStatus(
      evaluator.evaluate(passCheck, accountRecord.Id, accountRecord),
      'PASS'
    );

    Record_Health_Check__mdt failCheck = baseCheck('F_Fail', 'FORMULA');
    failCheck.PassConditionFormula__c = 'ISBLANK(BillingCity)';
    failCheck.FailureMessage__c = '{!record.Name} city is {!record.BillingCity}.';
    RecordHealthCheckInternalResult failResult = evaluator.evaluate(
      failCheck,
      accountRecord.Id,
      accountRecord
    );
    assertStatus(failResult, 'FAIL');
    Assert.isTrue(failResult.message.contains(accountRecord.Name));
    // Formula checks surface the expression as the pass/fail condition, unquoted
    // and under its own "Passes when" key rather than framed as an expected value.
    Assert.areEqual(
      'ISBLANK(BillingCity)',
      failResult.expectedValue,
      'Formula FAIL should expose the formula as the pass/fail condition'
    );
    Assert.areEqual(
      'Passes when',
      failResult.expectedValueLabel,
      'Formula FAIL condition carries the "Passes when" key'
    );

    Record_Health_Check__mdt nonBoolean = baseCheck('F_Non_Boolean', 'FORMULA');
    nonBoolean.PassConditionFormula__c = 'BillingCity';
    assertReason(
      evaluator.evaluate(nonBoolean, accountRecord.Id, accountRecord),
      'INVALID_FORMULA'
    );

    String[] reasonOut = new List<String>{ '' };
    Assert.areEqual(
      true,
      evaluator.evaluateApplicabilityFormula(
        'NOT(ISBLANK(BillingCity))',
        accountRecord,
        reasonOut
      )
    );
    Assert.areEqual(
      null,
      evaluator.evaluateApplicabilityFormula(
        'BillingCity',
        accountRecord,
        reasonOut
      )
    );
    Assert.areEqual('INVALID_FORMULA', reasonOut[0]);

    Assert.areEqual(
      accountRecord.BillingCity,
      evaluator.resolveFormulaSingleValue('BillingCity', accountRecord)
    );
    Assert.areEqual(
      accountRecord.AnnualRevenue,
      evaluator.resolveFormulaSingleValue('AnnualRevenue', accountRecord)
    );
    Assert.areNotEqual(
      null,
      evaluator.resolveFormulaSingleValue('TODAY()', accountRecord)
    );
    Assert.areNotEqual(
      null,
      evaluator.resolveFormulaSingleValue('NOW()', accountRecord)
    );
    Assert.areEqual(null, evaluator.resolveMergeFields(null, accountRecord));

    try {
      evaluator.resolveFormulaSingleValue(
        'Definitely_Not_A_Field__c',
        accountRecord
      );
      Assert.isTrue(false, 'Expected invalid formula exception.');
    } catch (RecordHealthCheckFormulaEvaluator.FormulaEvaluationException ex) {
      Assert.areEqual('FIELD_NOT_ACCESSIBLE', ex.reasonCode);
    }

    RecordHealthCheckFormulaEvaluator.formulaEvalCallCount = 95;
    try {
      evaluator.resolveFormulaSingleValue('BillingCity', accountRecord);
      Assert.isTrue(false, 'Expected FormulaEval limit guard.');
    } catch (RecordHealthCheckFormulaEvaluator.FormulaEvaluationException ex) {
      Assert.areEqual('FORMULA_EVAL_LIMIT', ex.reasonCode);
    } finally {
      RecordHealthCheckFormulaEvaluator.formulaEvalCallCount = 0;
    }
  }

  @IsTest
  static void formulaEvaluatorHonorsDeclaredReturnType() {
    // a declared single-value return type (FormulaResultType__c) resolves
    // the formula in a single FormulaEval call instead of trying up to eight types.
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    RecordHealthCheckFormulaEvaluator evaluator = new RecordHealthCheckFormulaEvaluator();

    // Each picklist value maps to its FormulaReturnType; only Auto enables
    // deliberate type discovery. Missing or unknown values are invalid config.
    Assert.areEqual(
      formulaeval.FormulaReturnType.STRING,
      evaluator.mapDeclaredReturnType('TEXT')
    );
    Assert.areEqual(
      formulaeval.FormulaReturnType.DECIMAL,
      evaluator.mapDeclaredReturnType('NUMBER')
    );
    Assert.areEqual(
      formulaeval.FormulaReturnType.BOOLEAN,
      evaluator.mapDeclaredReturnType('BOOLEAN')
    );
    Assert.areEqual(
      formulaeval.FormulaReturnType.DATE,
      evaluator.mapDeclaredReturnType('DATE')
    );
    Assert.areEqual(
      formulaeval.FormulaReturnType.DATETIME,
      evaluator.mapDeclaredReturnType('DATETIME')
    );
    Assert.areEqual(null, evaluator.mapDeclaredReturnType('AUTO'));
    assertInvalidFormulaReturnType(evaluator, null);
    assertInvalidFormulaReturnType(evaluator, 'Bogus');

    // Correct declaration ('TEXT' for a text field) → exactly one FormulaEval call.
    RecordHealthCheckFormulaEvaluator.formulaEvalCallCount = 0;
    RecordHealthCheckFormulaEvaluator.resolvedReturnTypeByFormula.clear();
    Assert.areEqual(
      accountRecord.BillingCity,
      evaluator.resolveFormulaSingleValue('BillingCity', accountRecord, 'TEXT')
    );
    Assert.areEqual(
      1,
      RecordHealthCheckFormulaEvaluator.formulaEvalCallCount,
      'Declared Text type should resolve a string formula in one FormulaEval call.'
    );

    // AUTO tries multiple types but resolves the same value.
    RecordHealthCheckFormulaEvaluator.formulaEvalCallCount = 0;
    RecordHealthCheckFormulaEvaluator.resolvedReturnTypeByFormula.clear();
    Assert.areEqual(
      accountRecord.BillingCity,
      evaluator.resolveFormulaSingleValue('BillingCity', accountRecord, 'AUTO')
    );
    Assert.isTrue(
      RecordHealthCheckFormulaEvaluator.formulaEvalCallCount > 1,
      'Auto (no declared type) should probe multiple return types.'
    );

    // A mis-declared type is rejected instead of being silently reinterpreted.
    RecordHealthCheckFormulaEvaluator.formulaEvalCallCount = 0;
    RecordHealthCheckFormulaEvaluator.resolvedReturnTypeByFormula.clear();
    try {
      evaluator.resolveFormulaSingleValue(
        'BillingCity',
        accountRecord,
        'NUMBER'
      );
      Assert.fail('A mismatched explicit Formula Result Type must fail.');
    } catch (RecordHealthCheckFormulaEvaluator.FormulaEvaluationException error) {
      Assert.areEqual(
        1,
        RecordHealthCheckFormulaEvaluator.formulaEvalCallCount
      );
    }
  }

  @IsTest
  static void formulaEvaluatorFallsBackWhenDisplayFormulaInvalid() {
    RecordHealthCheckFormulaEvaluator evaluator = new RecordHealthCheckFormulaEvaluator();
    Record_Health_Check__mdt check = baseCheck('Invalid_Display', 'FORMULA');
    check.DisplayFoundFormula__c = 'Not A Formula(';
    Account accountRecord = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Fallback' }
    );

    Test.startTest();
    RecordHealthCheckInternalResult result = evaluator.evaluate(
      check,
      RecordHealthCheckTestDataFactory.syntheticId(Account.SObjectType, 1),
      accountRecord
    );
    Test.stopTest();

    Assert.areEqual(
      'PASS',
      result.status,
      'A display-only formula failure must not change evaluation status.'
    );
    Assert.isNull(
      result.actualValue,
      'An invalid display formula should omit the Found value.'
    );
  }

  @IsTest
  static void formulaEvaluatorPreservesBudgetReasonForApplicability() {
    RecordHealthCheckFormulaEvaluator evaluator = new RecordHealthCheckFormulaEvaluator();
    RecordHealthCheckFormulaEvaluator.formulaEvalCallCount = RecordHealthCheckFormulaEvaluator.FORMULA_CALL_BUDGET;
    String[] reasonCode = new List<String>{ null };

    Test.startTest();
    Boolean applicable = evaluator.evaluateApplicabilityFormula(
      'TRUE',
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'Name' => 'Budget' }
      ),
      reasonCode
    );
    Test.stopTest();

    Assert.isNull(
      applicable,
      'An exhausted formula budget cannot determine applicability.'
    );
    Assert.areEqual(
      'FORMULA_EVAL_LIMIT',
      reasonCode[0],
      'The typed budget reason must be preserved.'
    );
  }

  @IsTest
  static void formulaEvaluatorCachesUnresolvableAutoFormula() {
    RecordHealthCheckFormulaEvaluator evaluator = new RecordHealthCheckFormulaEvaluator();
    List<Account> accounts = new List<Account>();
    for (Integer index = 0; index < 12; index++) {
      accounts.add(
        RecordHealthCheckTestDataFactory.account(
          new Map<String, Object>{ 'Name' => 'Unresolvable ' + index }
        )
      );
    }
    RecordHealthCheckFormulaEvaluator.formulaEvalCallCount = 0;
    RecordHealthCheckFormulaEvaluator.resolvedReturnTypeByFormula.clear();

    Test.startTest();
    for (Account accountRecord : accounts) {
      try {
        evaluator.resolveFormulaSingleValue(
          'Definitely_Not_A_Field__c',
          accountRecord,
          'AUTO'
        );
        Assert.fail('An inaccessible AUTO formula must not resolve.');
      } catch (RecordHealthCheckFormulaEvaluator.FormulaEvaluationException error) {
        Assert.areEqual(
          'FIELD_NOT_ACCESSIBLE',
          error.reasonCode,
          'Every record must retain the original classified failure.'
        );
      }
    }
    Test.stopTest();

    Assert.areEqual(
      8,
      RecordHealthCheckFormulaEvaluator.formulaEvalCallCount,
      'Only the first record may perform the eight-type AUTO probe.'
    );
  }

  @IsTest
  static void formulaBudgetFailureKeepsResolvedAutoType() {
    RecordHealthCheckFormulaEvaluator evaluator = new RecordHealthCheckFormulaEvaluator();
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    String cacheKey = String.valueOf(Account.SObjectType) + '|BillingCity';
    RecordHealthCheckFormulaEvaluator.resolvedReturnTypeByFormula.clear();
    RecordHealthCheckFormulaEvaluator.resolvedReturnTypeByFormula.put(
      cacheKey,
      formulaeval.FormulaReturnType.STRING
    );
    RecordHealthCheckFormulaEvaluator.formulaEvalCallCount = RecordHealthCheckFormulaEvaluator.FORMULA_CALL_BUDGET;

    Test.startTest();
    try {
      evaluator.resolveFormulaSingleValue('BillingCity', accountRecord, 'AUTO');
      Assert.fail('An exhausted FormulaEval budget must stop immediately.');
    } catch (RecordHealthCheckFormulaEvaluator.FormulaEvaluationException error) {
      Assert.areEqual(
        'FORMULA_EVAL_LIMIT',
        error.reasonCode,
        'The budget guard must remain the reported failure.'
      );
    }
    Test.stopTest();

    Assert.areEqual(
      formulaeval.FormulaReturnType.STRING,
      RecordHealthCheckFormulaEvaluator.resolvedReturnTypeByFormula.get(
        cacheKey
      ),
      'A budget failure is not evidence that the cached return type is wrong.'
    );
  }

  @IsTest
  static void formulaEvaluatorResolvesUrlWithRunContext() {
    RecordHealthCheckFormulaEvaluator evaluator = new RecordHealthCheckFormulaEvaluator()
      .withRunContext(new RecordHealthCheckRunContext('url-run', 'TEST'));
    Id recordId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      1
    );

    Test.startTest();
    String resolved = evaluator.resolveUrlMergeFields(
      '/lightning/r/Account/{!record.Id}/view',
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'Id' => recordId }
      )
    );
    Test.stopTest();

    Assert.isTrue(
      resolved.contains(String.valueOf(recordId)),
      'The URL resolver should substitute the record identity.'
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

  private static void assertInvalidFormulaReturnType(
    RecordHealthCheckFormulaEvaluator evaluator,
    String declaredReturnType
  ) {
    try {
      evaluator.mapDeclaredReturnType(declaredReturnType);
      Assert.fail('A missing or unknown Formula Result Type must be rejected.');
    } catch (RecordHealthCheckFormulaEvaluator.FormulaEvaluationException error) {
      Assert.areEqual('INVALID_CONFIG', error.reasonCode);
    }
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
