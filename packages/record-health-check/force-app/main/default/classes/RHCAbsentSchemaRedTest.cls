/**
 * Red evidence for framework-contract step 16.
 *
 * These tests assert the intended first-class absence contract. They fail against
 * the step-15 baseline because unresolved paths are dropped without a reason.
 */
@IsTest
private class RHCAbsentSchemaRedTest {
  private static final String ABSENT_FIELD = 'RHC_Does_Not_Exist__c';
  private static final String ABSENT_RELATIONSHIP = 'RHC_Missing__r.Name';
  private static final String ABSENT_NAMESPACE_FIELD = 'fake_ns__Field__c';

  @IsTest
  static void shouldClassifyAbsentTerminalField() {
    assertUnresolvedReason(
      formulaCheck(ABSENT_FIELD + ' = 1'),
      ABSENT_FIELD,
      'FIELD_NOT_RESOLVED'
    );
  }

  @IsTest
  static void shouldClassifyAbsentRelationshipSegment() {
    assertUnresolvedReason(
      formulaCheck(ABSENT_RELATIONSHIP + ' = \'value\''),
      ABSENT_RELATIONSHIP,
      'RELATIONSHIP_NOT_RESOLVED'
    );
  }

  @IsTest
  static void shouldClassifyAbsentNamespaceField() {
    assertUnresolvedReason(
      formulaCheck(ABSENT_NAMESPACE_FIELD + ' = 1'),
      ABSENT_NAMESPACE_FIELD,
      'FIELD_NOT_RESOLVED'
    );
  }

  @IsTest
  static void shouldNotCollapseAbsentFieldIntoAccessFailure() {
    RecordHealthCheckFieldPlanner.FieldPlan plan = planFor(
      formulaCheck(ABSENT_FIELD + ' = 1')
    );

    Assert.isFalse(
      plan.inaccessibleFields.contains(ABSENT_FIELD),
      'Schema absence must remain distinct from running-user field access.'
    );
  }

  private static void assertUnresolvedReason(
    Record_Health_Check__mdt check,
    String fieldPath,
    String expectedReasonCode
  ) {
    Test.startTest();
    RecordHealthCheckFieldPlanner.FieldPlan plan = planFor(check);
    Test.stopTest();

    Map<String, Object> serializedPlan = (Map<String, Object>) JSON.deserializeUntyped(
      JSON.serialize(plan)
    );
    Map<String, Object> reasonsByField = (Map<String, Object>) serializedPlan.get(
      'unresolvedReasonCodesByField'
    );
    String actualReasonCode = reasonsByField == null
      ? null
      : String.valueOf(reasonsByField.get(fieldPath));
    Assert.areEqual(
      expectedReasonCode,
      actualReasonCode,
      'An unresolved configured path must carry a deterministic absence reason.'
    );
    Assert.isFalse(
      plan.selectedFields.contains(fieldPath),
      'An unresolved path must never enter the user-mode SELECT.'
    );
  }

  private static RecordHealthCheckFieldPlanner.FieldPlan planFor(
    Record_Health_Check__mdt check
  ) {
    return new RecordHealthCheckFieldPlanner()
      .planRecordFields(check, Account.SObjectType);
  }

  private static Record_Health_Check__mdt formulaCheck(String formula) {
    return RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'EvaluationType__c' => 'FORMULA',
        'PassConditionFormula__c' => formula
      }
    );
  }
}
