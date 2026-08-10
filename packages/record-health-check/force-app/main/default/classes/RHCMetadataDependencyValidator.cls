/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * @description Validates prerequisite references, ordering, and dependency cycles.
 * SPDX-License-Identifier: Apache-2.0
 */
public with sharing class RHCMetadataDependencyValidator {
  // ─── Dependency graph validation ──────────────────────────────────────────

  public static List<RecordHealthCheckMetadataValidator.ValidationIssue> validate(
    String checkSetName,
    List<Record_Health_Check__mdt> checks,
    Map<String, Record_Health_Check__mdt> checksByDevName
  ) {
    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = new List<RecordHealthCheckMetadataValidator.ValidationIssue>();
    Map<String, String> dependsOnMap = new Map<String, String>(); // devName → dependsOnDevName

    for (Record_Health_Check__mdt check : checks) {
      if (String.isBlank(check.PrerequisiteCheck__c)) {
        continue;
      }

      String depDevName = check.PrerequisiteCheck__c.trim();
      Record_Health_Check__mdt dep = checksByDevName.get(depDevName);

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

      // Must be in same Check Set. Use the relationship field value directly;
      // parent relationship traversal is not supported for all custom metadata operations.
      if (dep.Record_Health_Check_Set__c != check.Record_Health_Check_Set__c) {
        issues.add(
          issue(
            check,
            'PrerequisiteCheck__c',
            'Prerequisite Check must reference a check in the same Check Set. ' +
              '"' +
              depDevName +
              '" belongs to a different Check Set.',
            'INVALID_DEPENDENCY'
          )
        );
        continue;
      }

      // Must have strictly lower Priority
      if (
        dep != null &&
        dep.EvaluationOrder__c != null &&
        check.EvaluationOrder__c != null &&
        dep.EvaluationOrder__c >= check.EvaluationOrder__c
      ) {
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

      dependsOnMap.put(check.DeveloperName, depDevName);
    }

    // Cycle detection using DFS
    Set<String> visited = new Set<String>();
    Set<String> inStack = new Set<String>();

    for (String devName : dependsOnMap.keySet()) {
      if (!visited.contains(devName)) {
        List<String> cycle = detectCycle(
          devName,
          dependsOnMap,
          visited,
          inStack
        );
        if (!cycle.isEmpty()) {
          // cycle is the closed walk (e.g. [A, B, C, A]); the repeated start
          // node makes cycleStr read as a full loop ("A → B → C → A"). Dedupe
          // the members when emitting issues so each check in the cycle gets
          // exactly one issue row rather than the start node getting two.
          // For display, drop the repeated closing node: "A → B → C" not "A → B → C → A".
          List<String> cycleForDisplay = new List<String>(cycle);
          if (
            cycleForDisplay.size() > 1 &&
            cycleForDisplay[0] == cycleForDisplay[cycleForDisplay.size() - 1]
          ) {
            cycleForDisplay.remove(cycleForDisplay.size() - 1);
          }
          String cycleStr = String.join(cycleForDisplay, ' → ');
          Set<String> reportedMembers = new Set<String>();
          for (String cycleMember : cycle) {
            if (!reportedMembers.add(cycleMember)) {
              continue;
            }
            Record_Health_Check__mdt r = checksByDevName.get(cycleMember);
            if (r != null) {
              issues.add(
                issue(
                  r,
                  'PrerequisiteCheck__c',
                  'Dependency cycle detected: ' + cycleStr,
                  'INVALID_DEPENDENCY'
                )
              );
            }
          }
          break; // report once per set
        }
      }
    }

    return issues;
  }

  private static List<String> detectCycle(
    String node,
    Map<String, String> dependsOnMap,
    Set<String> visited,
    Set<String> inStack
  ) {
    visited.add(node);
    inStack.add(node);

    String next = dependsOnMap.get(node);
    if (next != null) {
      if (!visited.contains(next)) {
        List<String> cycle = detectCycle(next, dependsOnMap, visited, inStack);
        if (!cycle.isEmpty()) {
          cycle.add(0, node);
          return cycle;
        }
      } else if (inStack.contains(next)) {
        return new List<String>{ node, next };
      }
    }

    inStack.remove(node);
    return new List<String>();
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
}
