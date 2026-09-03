/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** Central authorization checks for privileged Record Health Check features. */
public with sharing class RecordHealthCheckAccess {
  @TestVisible
  private static Boolean runPermissionOverride;

  private static Map<Id, Boolean> detailsByUser = new Map<Id, Boolean>();

  /** Stable authorization failure raised when the runner entitlement is absent. */
  public class AuthorizationException extends Exception {
  }

  /** Returns whether the current user may initiate health-check execution. */
  public static Boolean canRunChecks() {
    if (runPermissionOverride != null) {
      return runPermissionOverride;
    }
    return FeatureManagement.checkPermission('Record_Health_Check_Run');
  }

  /** Overrides runner authorization only within an Apex test transaction. */
  @TestVisible
  private static void setRunPermissionForTest(Boolean allowed) {
    runPermissionOverride = allowed;
  }

  /**
   * Requires the current user to hold the framework run entitlement.
   *
   * @throws AuthorizationException when the entitlement is absent.
   */
  public static void requireCanRunChecks() {
    if (!canRunChecks()) {
      throw new AuthorizationException(
        'NOT_AUTHORIZED: You do not have permission to run Record Health Checks.'
      );
    }
  }

  /**
   * Advanced detail requires a direct, active assignment of this package's
   * Admin or Diagnostics Viewer permission set. Installation profile grants
   * never authorize diagnostics. ShowDiagnostics__c still controls presentation.
   */
  public static Boolean canViewDetails() {
    Id userId = UserInfo.getUserId();
    if (!detailsByUser.containsKey(userId)) {
      detailsByUser.put(userId, hasDirectDiagnosticsAssignment(userId));
    }
    return detailsByUser.get(userId);
  }

  /**
   * Reads only the caller's authorization metadata, not business records.
   * PermissionSetAssignment is unavailable to minimum-access users in USER_MODE.
   * This bounded SYSTEM_MODE query accepts no client-supplied user or set identity
   * and returns only a Boolean; it does not grant Setup access to the caller.
   */
  private static Boolean hasDirectDiagnosticsAssignment(Id userId) {
    String typeName = Record_Health_Check__mdt.SObjectType.getDescribe()
      .getName();
    String packageNamespace = typeName == 'Record_Health_Check__mdt'
      ? null
      : typeName.substringBefore('__');
    Set<String> names = new Set<String>{
      'Record_Health_Check_Admin',
      'Record_Health_Check_Diagnostics_Viewer'
    };
    try {
      return ![
          SELECT Id
          FROM PermissionSetAssignment
          WHERE
            AssigneeId = :userId
            AND IsActive = TRUE
            AND PermissionSetGroupId = NULL
            AND PermissionSet.IsOwnedByProfile = FALSE
            AND PermissionSet.NamespacePrefix = :packageNamespace
            AND PermissionSet.Name IN :names
          WITH SYSTEM_MODE
          LIMIT 1
        ]
        .isEmpty();
    } catch (QueryException denied) {
      // Inability to verify an assignment must never disclose restricted detail.
      return false;
    }
  }
}
