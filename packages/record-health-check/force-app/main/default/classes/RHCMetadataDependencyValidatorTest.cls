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
      new List<Record_Health_Check__mdt>{ prerequisite, dependent }
    );
    Test.stopTest();

    Assert.areEqual(
      0,
      issues.size(),
      'A dependency on an earlier Check in the same Check Set should be valid.'
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
  static void rejectsDependencyWithMissingEvaluationOrder() {
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

    Assert.areEqual(1, issues.size());
    Assert.isTrue(
      issues[0].message.contains('must have an Evaluation Order'),
      'Validation must explain why nullable dependency ordering is unsafe.'
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
