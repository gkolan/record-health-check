/** Focused tests for Check Set metadata validation. */
@IsTest
private class RHCMetadataSetValidatorTest {
  @IsTest
  static void reportsMissingRequiredFields() {
    Record_Health_Check_Set__mdt checkSet = RecordHealthCheckTestDataFactory.checkSet(
      new Map<String, Object>{
        'DeveloperName' => 'Invalid_Set',
        'ObjectApiName__c' => null,
        'CardTitle__c' => null,
        'CardRunMode__c' => 'RUN_ON_LOAD',
        'CardRevealMode__c' => 'ALL_AT_ONCE',
        'PassedChecksDisplay__c' => 'SHOW_EACH_CHECK',
        'SkippedChecksDisplay__c' => 'SHOW_EACH_CHECK'
      }
    );

    Test.startTest();
    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = RecordHealthCheckMetadataSetValidator.validate(
      checkSet
    );
    Test.stopTest();

    Assert.areEqual(
      2,
      issues.size(),
      'Both required fields should be reported.'
    );
  }

  @IsTest
  static void rejectsUnknownRunButtonDisplay() {
    Record_Health_Check_Set__mdt checkSet = validCheckSet();
    checkSet.RunButtonDisplay__c = 'UNKNOWN';

    Test.startTest();
    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = RecordHealthCheckMetadataSetValidator.validate(
      checkSet
    );
    Test.stopTest();

    Assert.areEqual(1, issues.size(), 'The invalid display must be reported.');
    Assert.areEqual(
      'RunButtonDisplay__c',
      issues[0].fieldName,
      'The issue must point to Run Button Display.'
    );
  }

  @IsTest
  static void rejectsHiddenRunButtonForManualSet() {
    Record_Health_Check_Set__mdt checkSet = validCheckSet();
    checkSet.RunButtonDisplay__c = 'HIDE';

    Test.startTest();
    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = RecordHealthCheckMetadataSetValidator.validate(
      checkSet
    );
    Test.stopTest();

    Assert.areEqual(
      1,
      issues.size(),
      'A Manual Check Set must retain a visible Run control.'
    );
    Assert.areEqual(
      'ERROR',
      issues[0].severity,
      'A permanently idle card is invalid configuration.'
    );
  }

  @IsTest
  static void rejectsUnknownSummaryDisplay() {
    Record_Health_Check_Set__mdt checkSet = validCheckSet();
    checkSet.SummaryDisplay__c = 'MIDDLE';

    Test.startTest();
    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = RecordHealthCheckMetadataSetValidator.validate(
      checkSet
    );
    Test.stopTest();

    Assert.areEqual(
      1,
      issues.size(),
      'The invalid summary position must be reported.'
    );
    Assert.areEqual(
      'SummaryDisplay__c',
      issues[0].fieldName,
      'The issue must identify Summary Display.'
    );
    Assert.areEqual(
      'INVALID_CONFIG',
      issues[0].reasonCode,
      'The invalid configuration reason must remain stable.'
    );
  }

  @IsTest
  static void warnsWhenHiddenAutomaticSetCannotPublishFromCard() {
    Record_Health_Check_Set__mdt checkSet = validCheckSet();
    checkSet.CardRunMode__c = 'RUN_ON_LOAD';
    checkSet.RunButtonDisplay__c = 'HIDE';
    checkSet.PublishUserRunEvent__c = true;

    Test.startTest();
    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = RecordHealthCheckMetadataSetValidator.validate(
      checkSet
    );
    Test.stopTest();

    Assert.areEqual(
      1,
      issues.size(),
      'A hidden automatic card should warn about its unreachable in-card publication path.'
    );
    Assert.areEqual(
      'WARNING',
      issues[0].severity,
      'Apex and Flow remain valid deliberate publication paths, so this is a warning.'
    );
    Assert.areEqual(
      'USER_RUN_PUBLICATION_UNREACHABLE',
      issues[0].reasonCode,
      'The finding should identify the lifecycle reachability problem.'
    );
  }

  private static Record_Health_Check_Set__mdt validCheckSet() {
    return RecordHealthCheckTestDataFactory.checkSet(
      new Map<String, Object>{
        'DeveloperName' => 'Valid_Set',
        'ObjectApiName__c' => 'Account',
        'CardTitle__c' => 'Account health',
        'CardRunMode__c' => 'RUN_ON_REQUEST',
        'CardRevealMode__c' => 'ALL_AT_ONCE',
        'PassedChecksDisplay__c' => 'SHOW_EACH_CHECK',
        'SkippedChecksDisplay__c' => 'SHOW_EACH_CHECK',
        'RunButtonDisplay__c' => 'LABEL_AND_ICON'
      }
    );
  }
}
