/** Focused tests for check dependency metadata validation. */
@IsTest
private class RHCMetadataDependencyValidatorTest {
  @IsTest
  static void reportsMissingPrerequisite() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'Dependent_Check',
        'PrerequisiteCheck__c' => 'Missing_Check'
      }
    );

    Test.startTest();
    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = RHCMetadataDependencyValidator.validate(
      'Set',
      new List<Record_Health_Check__mdt>{ check },
      new Map<String, Record_Health_Check__mdt>()
    );
    Test.stopTest();

    Assert.areEqual(
      1,
      issues.size(),
      'The missing dependency should be reported.'
    );
    Assert.areEqual(
      'INVALID_DEPENDENCY',
      issues[0].reasonCode,
      'The dependency reason code must remain stable.'
    );
  }

  @IsTest
  static void acceptsAcyclicOrderedDependency() {
    Id checkSetId = RecordHealthCheckTestDataFactory.syntheticId(
      Record_Health_Check_Set__mdt.SObjectType,
      1
    );
    Record_Health_Check__mdt prerequisite = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'Prerequisite_Check',
        'Record_Health_Check_Set__c' => checkSetId,
        'EvaluationOrder__c' => 10
      }
    );
    Record_Health_Check__mdt dependent = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'Dependent_Check',
        'Record_Health_Check_Set__c' => checkSetId,
        'EvaluationOrder__c' => 20,
        'PrerequisiteCheck__c' => 'Prerequisite_Check'
      }
    );

    Test.startTest();
    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = RHCMetadataDependencyValidator.validate(
      'Set',
      new List<Record_Health_Check__mdt>{ prerequisite, dependent },
      new Map<String, Record_Health_Check__mdt>{
        prerequisite.DeveloperName => prerequisite,
        dependent.DeveloperName => dependent
      }
    );
    Test.stopTest();

    Assert.areEqual(
      0,
      issues.size(),
      'A dependency on an earlier Check in the same Check Set should be valid.'
    );
  }
}
