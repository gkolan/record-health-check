/** Guards formula sizing and plugin-fence admission at their pure planning boundary. */
@IsTest
private with sharing class RHCArchitectureBudgetTest {
  @IsTest
  static void caseB01ReturnsZeroForEmptyInputs() {
    Assert.areEqual(0, RecordHealthCheckResourcePlan.formulaCalls(null, 100));
    Assert.areEqual(
      0,
      RecordHealthCheckResourcePlan.formulaCalls(
        new List<Record_Health_Check__mdt>(),
        0
      )
    );
  }

  @IsTest
  static void caseB02ReservesCallsForOneFormula() {
    Assert.areEqual(
      95,
      RecordHealthCheckResourcePlan.defaultAsyncScope(
        new List<Record_Health_Check__mdt>{ formulaCheck(null, null) },
        100
      )
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
      )
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
      )
    );
  }

  @IsTest
  static void caseB05IncludesQueryValueFormulaCalls() {
    Assert.areEqual(
      40,
      RecordHealthCheckResourcePlan.defaultAsyncScope(
        new List<Record_Health_Check__mdt>{ queryCheck() },
        100
      )
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
        Assert.isNotNull(expected.getMessage());
      }
    }
  }

  @IsTest
  static void caseB08RejectsNegativeRecordCount() {
    try {
      RecordHealthCheckResourcePlan.formulaCalls(null, -1);
      Assert.fail('Negative record count must be rejected.');
    } catch (IllegalArgumentException expected) {
      Assert.isNotNull(expected.getMessage());
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
