/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * @description Validates Record Health Check Set metadata fields.
 * SPDX-License-Identifier: Apache-2.0
 */
public with sharing class RecordHealthCheckMetadataSetValidator {
  private static final Set<String> VALID_DISPLAY_MODES = RecordHealthCheckConstants.validDisplayModes;
  private static final Set<String> VALID_SUMMARY_DISPLAYS = RecordHealthCheckConstants.validSummaryDisplays;
  private static final Set<String> VALID_TRIGGER_MODES = RecordHealthCheckConstants.validTriggerModes;
  private static final Set<String> VALID_RUN_BUTTON_DISPLAYS = RecordHealthCheckConstants.validRunButtonDisplays;
  private static final Set<String> VALID_REVEAL_MODES = RecordHealthCheckConstants.validRevealModes;
  private static final Set<String> VALID_COMPARISON_DISPLAYS = RecordHealthCheckConstants.validComparisonDisplays;

  // ─── Check Set validation ─────────────────────────────────────────────────

  public static List<RecordHealthCheckMetadataValidator.ValidationIssue> validate(
    Record_Health_Check_Set__mdt cs
  ) {
    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = new List<RecordHealthCheckMetadataValidator.ValidationIssue>();

    if (String.isBlank(cs.ObjectApiName__c)) {
      issues.add(
        new RecordHealthCheckMetadataValidator.ValidationIssue(
          'ERROR',
          cs.DeveloperName,
          'ObjectApiName__c',
          'Base Object API Name is required.',
          'MISSING_REQUIRED_FIELD'
        )
      );
    }
    if (
      String.isNotBlank(cs.ObjectApiName__c) &&
      !RecordHealthCheckConfigValidator.isValidObjectApiName(
        cs.ObjectApiName__c
      )
    ) {
      issues.add(
        new RecordHealthCheckMetadataValidator.ValidationIssue(
          'ERROR',
          cs.DeveloperName,
          'ObjectApiName__c',
          'Object API Name does not identify an object in this org.',
          'INVALID_CONFIG'
        )
      );
    }

    if (String.isBlank(cs.CardTitle__c)) {
      issues.add(
        new RecordHealthCheckMetadataValidator.ValidationIssue(
          'ERROR',
          cs.DeveloperName,
          'CardTitle__c',
          'Card Title is required.',
          'MISSING_REQUIRED_FIELD'
        )
      );
    }

    if (!VALID_DISPLAY_MODES.contains(cs.PassedChecksDisplay__c)) {
      issues.add(
        new RecordHealthCheckMetadataValidator.ValidationIssue(
          'ERROR',
          cs.DeveloperName,
          'PassedChecksDisplay__c',
          'Passed Checks Display "' +
            cs.PassedChecksDisplay__c +
            '" is not recognized.',
          'INVALID_CONFIG'
        )
      );
    }

    if (!VALID_DISPLAY_MODES.contains(cs.SkippedChecksDisplay__c)) {
      issues.add(
        new RecordHealthCheckMetadataValidator.ValidationIssue(
          'ERROR',
          cs.DeveloperName,
          'SkippedChecksDisplay__c',
          'Skipped Checks Display "' +
            cs.SkippedChecksDisplay__c +
            '" is not recognized.',
          'INVALID_CONFIG'
        )
      );
    }

    String summaryDisplay = RecordHealthCheckConstants.normalizedSummaryDisplay(
      cs.SummaryDisplay__c
    );
    if (!VALID_SUMMARY_DISPLAYS.contains(summaryDisplay)) {
      issues.add(
        new RecordHealthCheckMetadataValidator.ValidationIssue(
          'ERROR',
          cs.DeveloperName,
          'SummaryDisplay__c',
          'Summary Display "' + cs.SummaryDisplay__c + '" is not recognized.',
          'INVALID_CONFIG'
        )
      );
    }

    // Parity with RecordHealthCheckConfigService runtime validation so a Check
    // Set that deploys clean cannot still fail at definition-load time.
    if (!VALID_TRIGGER_MODES.contains(cs.CardRunMode__c)) {
      issues.add(
        new RecordHealthCheckMetadataValidator.ValidationIssue(
          'ERROR',
          cs.DeveloperName,
          'CardRunMode__c',
          'When Checks Run "' +
            cs.CardRunMode__c +
            '" is not recognized. Valid values: RUN_ON_LOAD, RUN_ON_REQUEST.',
          'INVALID_CONFIG'
        )
      );
    }

    String runButtonDisplay = RecordHealthCheckConstants.normalizedRunButtonDisplay(
      cs.RunButtonDisplay__c
    );
    if (!VALID_RUN_BUTTON_DISPLAYS.contains(runButtonDisplay)) {
      issues.add(
        new RecordHealthCheckMetadataValidator.ValidationIssue(
          'ERROR',
          cs.DeveloperName,
          'RunButtonDisplay__c',
          'Run Button Display "' +
            cs.RunButtonDisplay__c +
            '" is not recognized.',
          'INVALID_CONFIG'
        )
      );
    } else if (
      cs.CardRunMode__c == 'RUN_ON_REQUEST' &&
      runButtonDisplay == 'HIDE'
    ) {
      issues.add(
        new RecordHealthCheckMetadataValidator.ValidationIssue(
          'ERROR',
          cs.DeveloperName,
          'RunButtonDisplay__c',
          'Run Button Display cannot be Hide when checks run only after a user clicks Run.',
          'INVALID_CONFIG'
        )
      );
    } else if (
      cs.CardRunMode__c == 'RUN_ON_LOAD' &&
      runButtonDisplay == 'HIDE' &&
      cs.PublishUserRunEvent__c == true
    ) {
      issues.add(
        new RecordHealthCheckMetadataValidator.ValidationIssue(
          'WARNING',
          cs.DeveloperName,
          'PublishUserRunEvent__c',
          'Publish User Run Event is enabled, but a hidden automatic card has no in-card Run or Rerun action. Page refreshes do not publish; use a visible action or a deliberate Apex or Flow invocation.',
          'USER_RUN_PUBLICATION_UNREACHABLE'
        )
      );
    }

    if (!VALID_REVEAL_MODES.contains(cs.CardRevealMode__c)) {
      issues.add(
        new RecordHealthCheckMetadataValidator.ValidationIssue(
          'ERROR',
          cs.DeveloperName,
          'CardRevealMode__c',
          'Reveal Mode "' +
            cs.CardRevealMode__c +
            '" is not recognized. Valid values: ALL_AT_ONCE, ONE_BY_ONE.',
          'INVALID_CONFIG'
        )
      );
    }

    if (
      String.isNotBlank(cs.FoundExpectedDisplay__c) &&
      !VALID_COMPARISON_DISPLAYS.contains(cs.FoundExpectedDisplay__c)
    ) {
      issues.add(
        new RecordHealthCheckMetadataValidator.ValidationIssue(
          'ERROR',
          cs.DeveloperName,
          'FoundExpectedDisplay__c',
          'Found/Expected Display "' +
            cs.FoundExpectedDisplay__c +
            '" is not recognized. Valid values: ON_DEMAND, FAILURES_ONLY, ALL_ROWS.',
          'INVALID_CONFIG'
        )
      );
    }

    return issues;
  }
}
