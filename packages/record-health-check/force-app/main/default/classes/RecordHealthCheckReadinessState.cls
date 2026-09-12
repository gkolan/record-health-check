/** Resolves current draft readiness from authorized, unexpired receipts. */
public with sharing class RecordHealthCheckReadinessState {
  /**
   * Computes ACTIVE, LIVE_VERIFIED, VALIDATED, or DRAFT without treating a receipt as access.
   * @param checkActive Current metadata activation state.
   * @param receipts Candidate receipts already selected for the Check identity.
   * @param fingerprint Current effective definition fingerprint.
   * @param nowAt Caller-supplied current time for deterministic expiry evaluation.
   * @param accessAllowed Whether current metadata/run access was revalidated.
   * @return Current readiness state.
   */
  public static String determine(
    Boolean checkActive,
    List<Record_Health_Check_Readiness__c> receipts,
    String fingerprint,
    Datetime nowAt,
    Boolean accessAllowed
  ) {
    if (checkActive == true) {
      return 'ACTIVE';
    }
    if (accessAllowed != true || String.isBlank(fingerprint)) {
      return 'DRAFT';
    }
    Boolean validated = false;
    for (
      Record_Health_Check_Readiness__c receipt : receipts == null
        ? new List<Record_Health_Check_Readiness__c>()
        : receipts
    ) {
      if (!matchesCurrentContext(receipt, fingerprint, nowAt)) {
        continue;
      }
      validated = true;
      if (isLiveVerified(receipt)) {
        return 'LIVE_VERIFIED';
      }
    }
    return validated ? 'VALIDATED' : 'DRAFT';
  }

  private static Boolean matchesCurrentContext(
    Record_Health_Check_Readiness__c receipt,
    String fingerprint,
    Datetime nowAt
  ) {
    return receipt != null &&
      receipt.Fingerprint__c == fingerprint &&
      receipt.Actor__c == UserInfo.getUserId() &&
      receipt.OrgIdentity__c == UserInfo.getOrganizationId() &&
      receipt.ExpiresAt__c != null &&
      receipt.ExpiresAt__c > nowAt;
  }

  private static Boolean isLiveVerified(
    Record_Health_Check_Readiness__c receipt
  ) {
    if (
      receipt.Mode__c != 'EXECUTE' ||
      value(receipt.ErrorCount__c) != 0 ||
      value(receipt.UnableCount__c) != 0 ||
      value(receipt.PassCount__c) + value(receipt.FailCount__c) == 0
    ) {
      return false;
    }
    if (String.isBlank(receipt.CapabilitiesJson__c)) {
      return false;
    }
    try {
      Map<String, Object> capabilities = (Map<String, Object>) JSON.deserializeUntyped(
        receipt.CapabilitiesJson__c
      );
      if (capabilities.isEmpty()) {
        return false;
      }
      for (Object status : capabilities.values()) {
        if (status != 'COMPLETE') {
          return false;
        }
      }
      return true;
    } catch (JSONException malformed) {
      return false;
    }
  }

  private static Decimal value(Decimal count) {
    return count == null ? 0 : count;
  }
}
