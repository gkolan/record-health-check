/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** Central authorization checks for privileged Record Health Check features. */
public with sharing class RecordHealthCheckAccess {
  @TestVisible
  private static Boolean runPermissionOverride;

  /** Stable authorization failure raised when the runner entitlement is absent. */
  public class AuthorizationException extends Exception {
  }

  /** Returns whether the current user may initiate health-check execution. */
  public static Boolean canRunChecks() {
    if (runPermissionOverride != null) {
      return runPermissionOverride;
    }
    Boolean hasRunPermission = FeatureManagement.checkPermission(
      'Record_Health_Check_Run'
    );
    return Test.isRunningTest() ? true : hasRunPermission;
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
   * Single Advanced-tier permission. Power-user explanation (Passes when,
   * value source) and troubleshooting internals (raw exceptions, timings) are one
   * audience, so they share one grant: Record_Health_Check_View_Diagnostics.
   * The Check Set's ShowDiagnostics__c flag still decides *when* the troubleshooting
   * subset is shown — it is a per-set switch, not a second permission.
   */
  public static Boolean canViewDetails() {
    return FeatureManagement.checkPermission(
      'Record_Health_Check_View_Diagnostics'
    );
  }
}
