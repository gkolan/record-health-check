/** Regression test for deterministic formula-finding order. */
@IsTest
private class RHCFormulaFindingOrderTest {
  @IsTest
  static void metadataFindingsFollowConfigurationFieldOrder() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'Ordered_Formula_Findings',
        'EvaluationType__c' => 'FORMULA',
        'ApplicabilityMode__c' => 'WHEN_FORMULA_TRUE',
        'ApplicabilityFormula__c' => 'MissingApplicability__c',
        'DisplayExpectedFormula__c' => 'MissingExpected__c',
        'DisplayFoundFormula__c' => 'MissingFound__c',
        'PassConditionFormula__c' => 'MissingPass__c'
      }
    );

    Test.startTest();
    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = RecordHealthCheckFormulaMetadataAdapter.issues(
      check,
      Account.SObjectType
    );
    Test.stopTest();

    List<String> actualFields = new List<String>();
    for (RecordHealthCheckMetadataValidator.ValidationIssue issue : issues) {
      actualFields.add(issue.fieldName);
    }
    Assert.areEqual(
      new List<String>{
        'ApplicabilityFormula__c',
        'DisplayExpectedFormula__c',
        'DisplayFoundFormula__c',
        'PassConditionFormula__c'
      },
      actualFields,
      'Metadata findings must be deterministic by configuration-field API name.'
    );
  }
}
