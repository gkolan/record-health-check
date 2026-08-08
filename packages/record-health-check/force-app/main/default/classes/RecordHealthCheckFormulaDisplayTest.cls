@IsTest
private class RecordHealthCheckFormulaDisplayTest {
  @IsTest
  static void preservesVerdictWhenDisplayFormulaIsInvalid() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'PassConditionFormula__c' => 'AnnualRevenue > 0',
        'DisplayFoundFormula__c' => 'Missing_Field__c',
        'FormulaResultType__c' => 'TEXT'
      }
    );
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.status = 'PASS';

    Test.startTest();
    RecordHealthCheckFormulaDisplay.apply(
      check,
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'AnnualRevenue' => 100 }
      ),
      result,
      new RecordHealthCheckFormulaEvaluator(),
      new RecordHealthCheckRunContext('formula-display-test', 'TEST')
    );
    Test.stopTest();

    Assert.areEqual(
      'PASS',
      result.status,
      'Display-only failures must not change the business verdict.'
    );
    Assert.isNull(
      result.actualValue,
      'An invalid Found formula must not produce a misleading value.'
    );
    Assert.areEqual(
      'AnnualRevenue > 0',
      result.expectedValue,
      'The pass condition should remain the Expected fallback.'
    );
  }

  @IsTest
  static void usesPassConditionWhenDisplayFormulasAreBlank() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'PassConditionFormula__c' => 'TRUE',
        'DisplayFoundFormula__c' => null,
        'DisplayExpectedFormula__c' => null
      }
    );
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();

    Test.startTest();
    RecordHealthCheckFormulaDisplay.apply(
      check,
      RecordHealthCheckTestDataFactory.account(null),
      result,
      new RecordHealthCheckFormulaEvaluator(),
      null
    );
    Test.stopTest();

    Assert.areEqual(
      'TRUE',
      result.expectedValue,
      'A Formula check without display formulas should expose its condition.'
    );
    Assert.areEqual(
      RecordHealthCheckInternalResult.PASSES_WHEN_LABEL,
      result.expectedValueLabel,
      'The fallback must be labelled as a condition rather than a value.'
    );
  }

  @IsTest
  static void resolvesFoundAndExpectedDisplayFormulas() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'PassConditionFormula__c' => 'TRUE',
        'DisplayFoundFormula__c' => 'Name',
        'DisplayExpectedFormula__c' => 'BillingCity',
        'FormulaResultType__c' => 'TEXT'
      }
    );
    Account accountRecord = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Name' => 'Formula display account',
        'BillingCity' => 'Chicago'
      }
    );
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();

    Test.startTest();
    RecordHealthCheckFormulaDisplay.apply(
      check,
      accountRecord,
      result,
      new RecordHealthCheckFormulaEvaluator(),
      new RecordHealthCheckRunContext('formula-display-values', 'TEST')
    );
    Test.stopTest();

    Assert.areEqual(
      'Formula display account',
      result.actualValue,
      'The Found formula should resolve against the evaluated record.'
    );
    Assert.areEqual(
      'Chicago',
      result.expectedValue,
      'The Expected formula should replace the pass-condition fallback.'
    );
    Assert.isNotNull(
      result.actualValueSource,
      'A resolved Found formula should retain value provenance.'
    );
    Assert.isNotNull(
      result.expectedValueSource,
      'A resolved Expected formula should retain value provenance.'
    );
  }

  @IsTest
  static void preservesFallbackWhenExpectedDisplayFormulaIsInvalid() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'PassConditionFormula__c' => 'AnnualRevenue > 0',
        'DisplayExpectedFormula__c' => 'Missing_Field__c',
        'FormulaResultType__c' => 'TEXT'
      }
    );
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();

    Test.startTest();
    RecordHealthCheckFormulaDisplay.apply(
      check,
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'AnnualRevenue' => 100 }
      ),
      result,
      new RecordHealthCheckFormulaEvaluator(),
      null
    );
    Test.stopTest();

    Assert.areEqual(
      'AnnualRevenue > 0',
      result.expectedValue,
      'An invalid Expected display formula should preserve the condition fallback.'
    );
    Assert.areEqual(
      RecordHealthCheckInternalResult.PASSES_WHEN_LABEL,
      result.expectedValueLabel,
      'The fallback should remain clearly labelled as the pass condition.'
    );
  }
}
