/** Security regressions for record-field planning. */
@IsTest
private class RHCFieldPlannerSecurityTest {
  @IsTest
  static void marksRelationshipPathWhenIntermediateLookupIsDenied() {
    User minimumAccessUser = RecordHealthCheckPersonaTestDataFactory.createMinimumAccessUser(
      'relfls'
    );
    RecordHealthCheckFieldPlanner.FieldPlan plan;

    Test.startTest();
    System.runAs(minimumAccessUser) {
      plan = new RecordHealthCheckFieldPlanner()
        .planRecordFields(
          RecordHealthCheckTestDataFactory.check(
            new Map<String, Object>{
              'FailureMessage__c' => 'Parent: {!record.Parent.Name}'
            }
          ),
          Account.SObjectType
        );
    }
    Test.stopTest();

    Assert.isFalse(
      plan.selectedFields.contains('Parent.Name'),
      'A relationship path whose lookup is denied must not enter the user-mode query.'
    );
    Assert.isTrue(
      plan.inaccessibleFields.contains('Parent.Name'),
      'A denied intermediate lookup must mark the complete path inaccessible so evaluation returns an aligned field-access result.'
    );
  }

  @IsTest
  static void inaccessibleColonRelationshipKeepsAccessClassification() {
    User minimumAccessUser = RecordHealthCheckPersonaTestDataFactory.createMinimumAccessUser(
      'colonfls'
    );
    String relationshipName = Record_Health_Check_Readiness__c.Actor__c.getDescribe()
      .getRelationshipName();
    Assert.isNotNull(
      relationshipName,
      'The security fixture must use the actual Actor lookup relationship, including its namespace.'
    );
    System.runAs(minimumAccessUser) {
      Assert.isFalse(
        Record_Health_Check_Readiness__c.Actor__c.getDescribe().isAccessible(),
        'The fixture user must actually lack access to the intermediate Actor lookup.'
      );
      Test.startTest();
      RecordHealthCheckFormulaPlanService.FormulaPlan plan = RecordHealthCheckFormulaPlanService.plan(
        relationshipName + ':User.IsActive',
        Record_Health_Check_Readiness__c.SObjectType,
        'PassConditionFormula__c',
        'BOOLEAN'
      );
      Test.stopTest();

      Assert.areEqual(
        1,
        plan.findings.size(),
        'The denied colon relationship must produce one deterministic finding.'
      );
      Assert.areEqual(
        RecordHealthCheckReasonCodes.FIELD_NOT_ACCESSIBLE,
        plan.findings[0].code,
        'An existing relationship hidden by FLS must not be reported as unresolved.'
      );
    }
  }
}
