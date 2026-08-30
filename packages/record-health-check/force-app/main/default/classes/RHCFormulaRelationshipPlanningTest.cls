/** Regression coverage for relationship references discovered in formulas. */
@IsTest
private with sharing class RHCFormulaRelationshipPlanningTest {
  @IsTest
  static void scannerReturnsCompletePathsWithoutRelationshipFragments() {
    Test.startTest();
    List<RecordHealthCheckFormulaFieldScanner.FieldReference> references = RecordHealthCheckFormulaFieldScanner.scan(
      'TEXT(Industry) = TEXT(Parent.Industry)',
      Account.SObjectType
    );
    Test.stopTest();

    Set<String> paths = new Set<String>();
    for (
      RecordHealthCheckFormulaFieldScanner.FieldReference reference : references
    ) {
      paths.add(reference.path);
    }
    Assert.areEqual(
      new Set<String>{ 'Industry', 'Parent.Industry' },
      paths,
      'A relationship operand must remain one complete path; its relationship and terminal segments are not root fields.'
    );
  }

  @IsTest
  static void plannerKeepsRelationshipFormulaRunnable() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'EvaluationType__c' => 'FORMULA',
        'PassConditionFormula__c' => 'TEXT(Industry) = TEXT(Parent.Industry)'
      }
    );

    Test.startTest();
    RecordHealthCheckFieldPlanner.FieldPlan plan = new RecordHealthCheckFieldPlanner()
      .planRecordFields(check, Account.SObjectType);
    Test.stopTest();

    Assert.isTrue(
      plan.selectedFields.contains('Industry'),
      'The root operand must be hydrated.'
    );
    Assert.isTrue(
      plan.selectedFields.contains('Parent.Industry'),
      'The complete relationship operand must be hydrated.'
    );
    Assert.areEqual(
      new Map<String, String>(),
      plan.unresolvedReasonCodesByField,
      'Valid relationship syntax must not create bogus unresolved root fields that suppress evaluation.'
    );
  }
}
