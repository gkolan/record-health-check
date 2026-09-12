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
      new List<Record_Health_Check__mdt>{ check }
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
        'EvaluationOrder__c' => 30
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
      new List<Record_Health_Check__mdt>{ prerequisite, dependent }
    );
    Test.stopTest();

    Assert.areEqual(
      0,
      issues.size(),
      'A dependency on a later displayed Check should be valid.'
    );
  }

  @IsTest
  static void validatesPrerequisiteInDependentNamespace() {
    Id checkSetId = RecordHealthCheckTestDataFactory.syntheticId(
      Record_Health_Check_Set__mdt.SObjectType,
      2
    );
    Record_Health_Check__mdt subscriber = check(
      checkSetId,
      'Shared_Name',
      'Shared_Name',
      30,
      null
    );
    Record_Health_Check__mdt managed = check(
      checkSetId,
      'Shared_Name',
      'rhc__Shared_Name',
      10,
      null
    );
    Record_Health_Check__mdt dependent = check(
      checkSetId,
      'Dependent',
      'rhc__Dependent',
      20,
      'Shared_Name'
    );

    Test.startTest();
    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = RHCMetadataDependencyValidator.validate(
      'Set',
      new List<Record_Health_Check__mdt>{ subscriber, managed, dependent }
    );
    Test.stopTest();

    Assert.areEqual(
      0,
      issues.size(),
      'Validation must use the earlier managed prerequisite, not the later subscriber collision.'
    );
  }

  @IsTest
  static void acceptsDependencyWithoutUsingDisplayOrder() {
    Id checkSetId = RecordHealthCheckTestDataFactory.syntheticId(
      Record_Health_Check_Set__mdt.SObjectType,
      3
    );
    Record_Health_Check__mdt prerequisite = check(
      checkSetId,
      'Prerequisite',
      'Prerequisite',
      null,
      null
    );
    Record_Health_Check__mdt dependent = check(
      checkSetId,
      'Dependent',
      'Dependent',
      20,
      'Prerequisite'
    );

    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = RHCMetadataDependencyValidator.validate(
      'Set',
      new List<Record_Health_Check__mdt>{ prerequisite, dependent }
    );

    Assert.areEqual(
      0,
      issues.size(),
      'Dependency validity must not be coupled to presentation order.'
    );
  }

  @IsTest
  static void rejectsDependencyCycle() {
    Id checkSetId = RecordHealthCheckTestDataFactory.syntheticId(
      Record_Health_Check_Set__mdt.SObjectType,
      4
    );
    Record_Health_Check__mdt first = check(
      checkSetId,
      'First',
      'First',
      10,
      'Second'
    );
    Record_Health_Check__mdt second = check(
      checkSetId,
      'Second',
      'Second',
      20,
      'First'
    );

    Test.startTest();
    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = RHCMetadataDependencyValidator.validate(
      'Set',
      new List<Record_Health_Check__mdt>{ first, second }
    );
    Test.stopTest();

    Assert.areEqual(2, issues.size(), 'Every cycle member must be identified.');
    Assert.areEqual(
      'INVALID_DEPENDENCY',
      issues[0].reasonCode,
      'The first cycle member must report INVALID_DEPENDENCY.'
    );
    Assert.areEqual(
      'INVALID_DEPENDENCY',
      issues[1].reasonCode,
      'The second cycle member must report INVALID_DEPENDENCY.'
    );
  }

  private static Record_Health_Check__mdt check(
    Id checkSetId,
    String developerName,
    String qualifiedApiName,
    Decimal evaluationOrder,
    String prerequisite
  ) {
    return RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => developerName,
        'QualifiedApiName' => qualifiedApiName,
        'Record_Health_Check_Set__c' => checkSetId,
        'EvaluationOrder__c' => evaluationOrder,
        'PrerequisiteCheck__c' => prerequisite
      }
    );
  }
}
