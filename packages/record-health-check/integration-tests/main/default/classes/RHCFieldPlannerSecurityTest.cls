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
}
