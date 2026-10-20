/**
 * Verifies deploy-time guidance for display fields that Apex Checks do not consume.
 */
@IsTest
private class RHCMetadataValidatorWarningTest {
  @IsTest
  static void warnsWhenApexDisplayTextWouldBeIgnored() {
    Id setId = Id.valueOf('m00' + '000000000008');
    Record_Health_Check_Set__mdt checkSet = RecordHealthCheckTestDataFactory.checkSet(
      new Map<String, Object>{
        'DeveloperName' => String.valueOf(setId),
        'ObjectApiName__c' => 'Account',
        'CardTitle__c' => 'Apex display warning',
        'CardRunMode__c' => 'RUN_ON_REQUEST',
        'CardRevealMode__c' => 'ALL_AT_ONCE',
        'PassedChecksDisplay__c' => 'SHOW_EACH_CHECK',
        'SkippedChecksDisplay__c' => 'SHOW_EACH_CHECK'
      }
    );
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'Apex_Display_Text_Warning',
        'MasterLabel' => 'Apex Display Text Warning',
        'CheckTitle__c' => 'Apex Display Text Warning',
        'EvaluationType__c' => 'APEX',
        'FailureSeverity__c' => 'WARNING',
        'FailureMessage__c' => 'Apex failure',
        'UnableToEvaluateMessage__c' => 'Cannot evaluate Apex Check.',
        'EvaluationOrder__c' => 10,
        'ApplicabilityMode__c' => 'ALL_RECORDS',
        'NoRowsResult__c' => 'FAIL',
        'EmptyValueHandling__c' => 'SKIP_RECORD',
        'ApexClass__c' => 'AccountHasRecentActivityCheck',
        'ApexParametersJson__c' => '{}',
        'DisplayFoundText__c' => 'Found text that will be ignored',
        'DisplayExpectedText__c' => 'Expected text that will be ignored',
        'Record_Health_Check_Set__c' => setId
      }
    );

    Test.startTest();
    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = new RecordHealthCheckMetadataValidator()
      .validateRecords(
        new List<Record_Health_Check_Set__mdt>{ checkSet },
        new List<Record_Health_Check__mdt>{ check }
      );
    Test.stopTest();

    Set<String> warnedFields = new Set<String>();
    for (RecordHealthCheckMetadataValidator.ValidationIssue issue : issues) {
      if (issue.reasonCode == 'APEX_DISPLAY_TEXT_IGNORED') {
        Assert.areEqual(
          'WARNING',
          issue.severity,
          'Ignored Apex display text should remain a non-blocking warning.'
        );
        warnedFields.add(issue.fieldName);
      }
    }
    Assert.areEqual(
      new Set<String>{ 'DisplayFoundText__c', 'DisplayExpectedText__c' },
      warnedFields,
      'The validator should identify both ignored display fields.'
    );
  }

  @IsTest
  static void warnsWhenHiddenAutomaticSetHasPublishingCheck() {
    Id setId = Id.valueOf('m00' + '000000000009');
    Record_Health_Check_Set__mdt checkSet = RecordHealthCheckTestDataFactory.checkSet(
      new Map<String, Object>{
        'DeveloperName' => String.valueOf(setId),
        'ObjectApiName__c' => 'Account',
        'CardTitle__c' => 'Passive health',
        'CardRunMode__c' => 'RUN_ON_LOAD',
        'RunButtonDisplay__c' => 'HIDE',
        'CardRevealMode__c' => 'ALL_AT_ONCE',
        'PassedChecksDisplay__c' => 'SHOW_EACH_CHECK',
        'SkippedChecksDisplay__c' => 'SHOW_EACH_CHECK'
      }
    );
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'Publishing_Check',
        'MasterLabel' => 'Publishing Check',
        'CheckTitle__c' => 'Publishing Check',
        'EvaluationType__c' => 'FORMULA',
        'FailureSeverity__c' => 'WARNING',
        'PassConditionFormula__c' => 'TRUE',
        'FailureMessage__c' => 'Formula failure',
        'UnableToEvaluateMessage__c' => 'Cannot evaluate Formula Check.',
        'EvaluationOrder__c' => 10,
        'ApplicabilityMode__c' => 'ALL_RECORDS',
        'NoRowsResult__c' => 'FAIL',
        'EmptyValueHandling__c' => 'SKIP_RECORD',
        'PublishUserResultEvent__c' => true,
        'Record_Health_Check_Set__c' => setId
      }
    );

    Test.startTest();
    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = new RecordHealthCheckMetadataValidator()
      .validateRecords(
        new List<Record_Health_Check_Set__mdt>{ checkSet },
        new List<Record_Health_Check__mdt>{ check }
      );
    Test.stopTest();

    Boolean foundLifecycleWarning = false;
    for (RecordHealthCheckMetadataValidator.ValidationIssue issue : issues) {
      if (issue.reasonCode == 'USER_RESULT_PUBLICATION_UNREACHABLE') {
        foundLifecycleWarning = true;
        Assert.areEqual(
          'WARNING',
          issue.severity,
          'Apex and Flow can still publish deliberately.'
        );
        Assert.areEqual(
          'PublishUserResultEvent__c',
          issue.fieldName,
          'The finding should identify the unreachable Check switch.'
        );
      }
    }
    Assert.isTrue(
      foundLifecycleWarning,
      'The validator should warn when a hidden automatic card cannot publish an enabled Check event.'
    );
  }

  @IsTest
  static void warnsWhenHiddenAutomaticHeadingHasPublishingCheck() {
    Id setId = Id.valueOf('m00' + '000000000010');
    Record_Health_Check_Set__mdt checkSet = RecordHealthCheckTestDataFactory.checkSet(
      new Map<String, Object>{
        'DeveloperName' => String.valueOf(setId),
        'ObjectApiName__c' => 'Account',
        'CardTitle__c' => 'Passive headingless health',
        'CardRunMode__c' => 'RUN_ON_LOAD',
        'RunButtonDisplay__c' => 'LABEL_AND_ICON',
        'CardHeadingDisplay__c' => 'HIDE',
        'CardRevealMode__c' => 'ALL_AT_ONCE',
        'PassedChecksDisplay__c' => 'SHOW_EACH_CHECK',
        'SkippedChecksDisplay__c' => 'SHOW_EACH_CHECK'
      }
    );
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'Headingless_Publishing_Check',
        'MasterLabel' => 'Headingless Publishing Check',
        'CheckTitle__c' => 'Headingless Publishing Check',
        'EvaluationType__c' => 'FORMULA',
        'FailureSeverity__c' => 'WARNING',
        'PassConditionFormula__c' => 'TRUE',
        'FailureMessage__c' => 'Formula failure',
        'UnableToEvaluateMessage__c' => 'Cannot evaluate Formula Check.',
        'EvaluationOrder__c' => 10,
        'ApplicabilityMode__c' => 'ALL_RECORDS',
        'NoRowsResult__c' => 'FAIL',
        'EmptyValueHandling__c' => 'SKIP_RECORD',
        'PublishUserResultEvent__c' => true,
        'Record_Health_Check_Set__c' => setId
      }
    );

    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = new RecordHealthCheckMetadataValidator()
      .validateRecords(
        new List<Record_Health_Check_Set__mdt>{ checkSet },
        new List<Record_Health_Check__mdt>{ check }
      );

    Boolean foundLifecycleWarning = false;
    for (RecordHealthCheckMetadataValidator.ValidationIssue issue : issues) {
      foundLifecycleWarning =
        foundLifecycleWarning ||
        issue.reasonCode == 'USER_RESULT_PUBLICATION_UNREACHABLE';
    }
    Assert.isTrue(
      foundLifecycleWarning,
      'A hidden automatic heading must warn when it removes an enabled Check publication path.'
    );
  }

  /**
   * Card Run/Rerun publication re-evaluates the whole Check Set for one record
   * in one transaction. Each Formula Check below plans 1 + 8 + 8 = 17
   * FormulaEval calls (condition plus two Automatic display formulas): six
   * plan 102, above the 95-call budget, and five plan 85.
   */
  @IsTest
  static void warnsWhenCardPublicationCannotFitOneTransaction() {
    Assert.areEqual(
      new List<String>{ 'PublishUserRunEvent__c' },
      publicationBudgetWarnings(6, true, false),
      'Six such Checks cannot fit the completion evaluation of a publishing Check Set.'
    );
    Assert.areEqual(
      new List<String>{ 'PublishUserResultEvent__c' },
      publicationBudgetWarnings(6, false, true),
      'Check-level publication triggers the same whole-Set evaluation.'
    );
    Assert.areEqual(
      new List<String>(),
      publicationBudgetWarnings(5, true, true),
      'Five active Checks fit; the inactive sixth is never evaluated.'
    );
    Assert.areEqual(
      new List<String>(),
      publicationBudgetWarnings(6, false, false),
      'Without card publication there is no completion evaluation to warn about.'
    );
  }

  /** Fields named by budget warnings for a Set of heavy Formula Checks plus one inactive one. */
  private static List<String> publicationBudgetWarnings(
    Integer activeChecks,
    Boolean setPublishes,
    Boolean checksPublish
  ) {
    Id setId = Id.valueOf('m00' + '000000000011');
    Record_Health_Check_Set__mdt checkSet = RecordHealthCheckTestDataFactory.checkSet(
      new Map<String, Object>{
        'DeveloperName' => String.valueOf(setId),
        'ObjectApiName__c' => 'Account',
        'CardTitle__c' => 'Publication budget',
        'CardRunMode__c' => 'RUN_ON_REQUEST',
        'CardRevealMode__c' => 'ALL_AT_ONCE',
        'PassedChecksDisplay__c' => 'SHOW_EACH_CHECK',
        'SkippedChecksDisplay__c' => 'SHOW_EACH_CHECK',
        'PublishUserRunEvent__c' => setPublishes
      }
    );
    List<Record_Health_Check__mdt> checks = new List<Record_Health_Check__mdt>();
    for (Integer index = 0; index <= activeChecks; index++) {
      checks.add(
        RecordHealthCheckTestDataFactory.check(
          new Map<String, Object>{
            'DeveloperName' => 'Publication_Budget_' + index,
            'MasterLabel' => 'Publication Budget ' + index,
            'CheckTitle__c' => 'Publication Budget ' + index,
            'IsActive__c' => index < activeChecks,
            'EvaluationType__c' => 'FORMULA',
            'FailureSeverity__c' => 'WARNING',
            'PassConditionFormula__c' => 'TRUE',
            'DisplayFoundFormula__c' => 'Name',
            'DisplayExpectedFormula__c' => 'Name',
            'FailureMessage__c' => 'Formula failure',
            'UnableToEvaluateMessage__c' => 'Cannot evaluate Formula Check.',
            'EvaluationOrder__c' => index + 1,
            'ApplicabilityMode__c' => 'ALL_RECORDS',
            'NoRowsResult__c' => 'FAIL',
            'EmptyValueHandling__c' => 'SKIP_RECORD',
            'PublishUserResultEvent__c' => checksPublish,
            'Record_Health_Check_Set__c' => setId
          }
        )
      );
    }
    List<String> warnedFields = new List<String>();
    for (
      RecordHealthCheckMetadataValidator.ValidationIssue issue : new RecordHealthCheckMetadataValidator()
        .validateRecords(
          new List<Record_Health_Check_Set__mdt>{ checkSet },
          checks
        )
    ) {
      if (issue.reasonCode == 'USER_PUBLICATION_OVER_BUDGET') {
        Assert.areEqual(
          'WARNING',
          issue.severity,
          'The card still runs; only publication is affected.'
        );
        warnedFields.add(issue.fieldName);
      }
    }
    return warnedFields;
  }
}
