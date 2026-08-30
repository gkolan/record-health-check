/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * @description Validates prerequisite references and ordering.
 * SPDX-License-Identifier: Apache-2.0
 */
public with sharing class RHCMetadataDependencyValidator {
  // ─── Dependency graph validation ──────────────────────────────────────────

  public static List<RecordHealthCheckMetadataValidator.ValidationIssue> validate(
    String checkSetName,
    List<Record_Health_Check__mdt> checks
  ) {
    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = new List<RecordHealthCheckMetadataValidator.ValidationIssue>();
    Map<String, Record_Health_Check__mdt> checksByIdentity = new Map<String, Record_Health_Check__mdt>();
    Set<String> identities = new Set<String>();
    for (Record_Health_Check__mdt check : checks) {
      String identity = identityOf(check);
      identities.add(identity);
      checksByIdentity.put(identity, check);
    }

    for (Record_Health_Check__mdt check : checks) {
      if (String.isBlank(check.PrerequisiteCheck__c)) {
        continue;
      }

      String depDevName = check.PrerequisiteCheck__c.trim();
      String depIdentity = RHCDefinitionDependencyIdentity.resolveQualified(
        check,
        identities
      );
      Record_Health_Check__mdt dep = checksByIdentity.get(depIdentity);

      if (dep == null) {
        issues.add(
          issue(
            check,
            'PrerequisiteCheck__c',
            'Prerequisite Check must reference an existing check DeveloperName. ' +
              '"' +
              depDevName +
              '" was not found.',
            'INVALID_DEPENDENCY'
          )
        );
        continue;
      }

      if (dep.EvaluationOrder__c == null || check.EvaluationOrder__c == null) {
        issues.add(
          issue(
            check,
            'PrerequisiteCheck__c',
            'Both this Check and its Prerequisite Check must have an Evaluation Order.',
            'INVALID_DEPENDENCY'
          )
        );
        continue;
      }

      // Must have strictly lower Evaluation Order
      if (dep.EvaluationOrder__c >= check.EvaluationOrder__c) {
        issues.add(
          issue(
            check,
            'PrerequisiteCheck__c',
            'Prerequisite Check must reference a check with a strictly lower Evaluation Order. ' +
              '"' +
              depDevName +
              '" has Evaluation Order ' +
              dep.EvaluationOrder__c +
              ' which is not lower than this check\'s Evaluation Order ' +
              check.EvaluationOrder__c +
              '.',
            'INVALID_DEPENDENCY'
          )
        );
        continue;
      }
    }

    // Strictly decreasing Evaluation Order makes cycles impossible: following
    // prerequisites must decrease at every edge and cannot return to the start.
    return issues;
  }

  private static RecordHealthCheckMetadataValidator.ValidationIssue issue(
    Record_Health_Check__mdt check,
    String fieldName,
    String message,
    String reasonCode
  ) {
    return new RecordHealthCheckMetadataValidator.ValidationIssue(
      'ERROR',
      check.DeveloperName,
      fieldName,
      message,
      reasonCode
    );
  }

  private static String identityOf(Record_Health_Check__mdt check) {
    return String.isBlank(check.QualifiedApiName)
      ? check.DeveloperName
      : check.QualifiedApiName;
  }
}
