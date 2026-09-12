/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * @description Validates prerequisite references and cycles.
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
    }

    Set<String> cycleMembers = RHCDefinitionDependencyIdentity.cycleMembers(
      checks
    );
    for (Record_Health_Check__mdt check : checks) {
      if (cycleMembers.contains(identityOf(check))) {
        issues.add(
          issue(
            check,
            'PrerequisiteCheck__c',
            'Prerequisite Checks must not form a dependency cycle.',
            'INVALID_DEPENDENCY'
          )
        );
      }
    }
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
