/** Guards formula sizing and plugin-fence admission at their pure planning boundary. */
@IsTest
private with sharing class RHCArchitectureBudgetTest {
  @IsTest
  static void caseB01ReturnsZeroForEmptyInputs() {
    Assert.areEqual(
      0,
      RecordHealthCheckResourcePlan.formulaCalls(null, 100),
      'An absent Check list must reserve zero formula calls.'
    );
    Assert.areEqual(
      0,
      RecordHealthCheckResourcePlan.formulaCalls(
        new List<Record_Health_Check__mdt>(),
        0
      ),
      'An empty Check list and scope must reserve zero formula calls.'
    );
  }

  @IsTest
  static void caseB02ReservesCallsForOneFormula() {
    Assert.areEqual(
      95,
      RecordHealthCheckResourcePlan.defaultAsyncScope(
        new List<Record_Health_Check__mdt>{ formulaCheck(null, null) },
        100
      ),
      'One formula must retain the reserved-capacity scope of 95.'
    );
  }

  @IsTest
  static void caseB03DividesBudgetAcrossTwoFormulas() {
    Assert.areEqual(
      47,
      RecordHealthCheckResourcePlan.defaultAsyncScope(
        new List<Record_Health_Check__mdt>{
          formulaCheck(null, null),
          formulaCheck(null, null)
        },
        100
      ),
      'Two formulas must share the budget with a scope of 47.'
    );
  }

  @IsTest
  static void caseB04IncludesDisplayFormulaCalls() {
    Assert.areEqual(
      44,
      RecordHealthCheckResourcePlan.defaultAsyncScope(
        new List<Record_Health_Check__mdt>{
          formulaCheck('NumberOfEmployees', null)
        },
        100
      ),
      'Display formula calls must reduce the admitted scope to 44.'
    );
  }

  @IsTest
  static void caseB05IncludesQueryValueFormulaCalls() {
    Assert.areEqual(
      40,
      RecordHealthCheckResourcePlan.defaultAsyncScope(
        new List<Record_Health_Check__mdt>{ queryCheck() },
        100
      ),
      'Query value formulas must reduce the admitted scope to 40.'
    );
  }

  @IsTest
  static void caseB06AcceptsAvailableFenceCapacity() {
    Test.startTest();
    RecordHealthCheckResourcePlan.requireFenceCapacity(0);
    Test.stopTest();
    Assert.areEqual(0, Limits.getDmlRows(), 'Planning must not write rows.');
  }

  @IsTest
  static void caseB07RejectsInvalidPreferredScope() {
    for (Integer invalid : new List<Integer>{ 0, 201 }) {
      try {
        RecordHealthCheckResourcePlan.defaultAsyncScope(null, invalid);
        Assert.fail('Invalid preferred size must be rejected.');
      } catch (IllegalArgumentException expected) {
        Assert.isNotNull(
          expected.getMessage(),
          'An invalid preferred scope must explain its rejection.'
        );
      }
    }
  }

  @IsTest
  static void caseB08RejectsNegativeRecordCount() {
    try {
      RecordHealthCheckResourcePlan.formulaCalls(null, -1);
      Assert.fail('Negative record count must be rejected.');
    } catch (IllegalArgumentException expected) {
      Assert.isNotNull(
        expected.getMessage(),
        'A negative record count must explain its rejection.'
      );
    }
  }

  private static Record_Health_Check__mdt formulaCheck(
    String foundFormula,
    String expectedFormula
  ) {
    return new Record_Health_Check__mdt(
      EvaluationType__c = 'FORMULA',
      DisplayFoundFormula__c = foundFormula,
      DisplayExpectedFormula__c = expectedFormula
    );
  }

  private static Record_Health_Check__mdt queryCheck() {
    return new Record_Health_Check__mdt(
      EvaluationType__c = 'QUERY',
      FormulaResultType__c = 'AUTO',
      FindInListFormula__c = 'Name',
      ExpectedRecordFormula__c = 'Name'
    );
  }
}
