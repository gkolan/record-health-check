/** Verifies planner expansion against deployed formula-field describe metadata. */
@IsTest
private class RHCFormulaMetadataPlannerIntegrationTest {
  @IsTest
  static void plannerExpandsDeployedCalculatedFormulaMetadata() {
    String formulaFieldName;
    for (
      String fieldName : RecordHealthCheckDescribeCache.fieldMap(
          Lead.SObjectType
        )
        .keySet()
    ) {
      if (fieldName.toLowerCase().endsWith('rhc_owner_is_active__c')) {
        formulaFieldName = fieldName;
        break;
      }
    }
    Assert.isNotNull(
      formulaFieldName,
      'The integration formula-field fixture must be deployed.'
    );

    Test.startTest();
    Set<String> fields = new RecordHealthCheckFieldPlanner()
      .collectRecordFields(
        RecordHealthCheckTestDataFactory.check(
          new Map<String, Object>{
            'EvaluationType__c' => 'FORMULA',
            'PassConditionFormula__c' => formulaFieldName
          }
        ),
        Lead.SObjectType
      );
    Test.stopTest();

    Assert.isTrue(
      fields.contains(formulaFieldName),
      'The deployed calculated field must remain selected.'
    );
    Assert.isTrue(
      fields.contains('Owner.IsActive'),
      'The deployed formula metadata must expand to its Owner.IsActive dependency.'
    );
  }
}
