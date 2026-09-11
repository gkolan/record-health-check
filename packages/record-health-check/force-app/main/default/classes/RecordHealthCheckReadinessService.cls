/** Persists, resolves, and cleans up private readiness receipts. */
public with sharing class RecordHealthCheckReadinessService {
  private static final String RECEIPT_WARNING = 'The preview completed, but the readiness receipt could not be saved.';

  /** Saves an explicitly requested eligible receipt in user mode. */
  public static RecordHealthCheckReadinessReceipt save(
    RecordHealthCheckPreviewRequest request,
    RecordHealthCheckPreviewResponse response,
    String checkIdentity,
    String setIdentity
  ) {
    RecordHealthCheckReadinessReceipt outcome = new RecordHealthCheckReadinessReceipt();
    if (request.readinessReceiptRequested != true) {
      outcome.receiptStatus = 'NOT_REQUESTED';
      return outcome;
    }
    if (response.validationStatus != 'VALID') {
      outcome.receiptStatus = 'NOT_ELIGIBLE';
      return outcome;
    }

    Datetime verifiedAt = System.now();
    Map<String, Integer> counts = resultCounts(response.results);
    Record_Health_Check_Readiness__c receipt = new Record_Health_Check_Readiness__c(
      Fingerprint__c = response.definitionFingerprint,
      CheckIdentity__c = checkIdentity,
      SetIdentity__c = setIdentity,
      Actor__c = UserInfo.getUserId(),
      OrgIdentity__c = UserInfo.getOrganizationId(),
      ContractVersion__c = response.version,
      Mode__c = response.mode,
      VerifiedAt__c = verifiedAt,
      ExpiresAt__c = verifiedAt.addDays(30),
      ScopeCount__c = request.recordIds.size(),
      PassCount__c = counts.get('PASS'),
      FailCount__c = counts.get('FAIL'),
      SkippedCount__c = counts.get('SKIPPED'),
      UnableCount__c = counts.get('UNABLE_TO_EVALUATE'),
      ErrorCount__c = counts.get('ERROR'),
      CapabilitiesJson__c = JSON.serialize(response.capabilities),
      ScopeDigest__c = scopeDigest(request.recordIds)
    );
    try {
      Database.SaveResult saved = Database.insert(
        receipt,
        AccessLevel.USER_MODE
      );
      if (!saved.isSuccess()) {
        return notSaved(outcome);
      }
      outcome.receiptStatus = 'SAVED';
      outcome.receiptId = saved.getId();
      outcome.expiresAt = receipt.ExpiresAt__c;
    } catch (DmlException denied) {
      return notSaved(outcome);
    }
    return outcome;
  }

  /** Adds authorized current readiness without exposing receipt scope data. */
  public static void decorate(
    RecordHealthCheckPreviewResponse response,
    Record_Health_Check__mdt draft,
    String setIdentity
  ) {
    String checkIdentity = String.isBlank(draft.QualifiedApiName)
      ? draft.DeveloperName
      : draft.QualifiedApiName;
    String orgIdentity = UserInfo.getOrganizationId();
    Id actorId = UserInfo.getUserId();
    List<Record_Health_Check_Readiness__c> receipts = [
      SELECT
        Fingerprint__c,
        Actor__c,
        OrgIdentity__c,
        Mode__c,
        ExpiresAt__c,
        PassCount__c,
        FailCount__c,
        UnableCount__c,
        ErrorCount__c,
        CapabilitiesJson__c
      FROM Record_Health_Check_Readiness__c
      WHERE
        CheckIdentity__c = :checkIdentity
        AND SetIdentity__c = :setIdentity
        AND Actor__c = :actorId
        AND OrgIdentity__c = :orgIdentity
        AND Fingerprint__c = :response.definitionFingerprint
      WITH USER_MODE
      ORDER BY VerifiedAt__c DESC
      LIMIT 200
    ];
    Datetime nowAt = System.now();
    response.readinessState = RecordHealthCheckReadinessState.determine(
      draft.IsActive__c,
      receipts,
      response.definitionFingerprint,
      nowAt,
      true
    );
    response.hasCurrentLiveVerification =
      RecordHealthCheckReadinessState.determine(
        false,
        receipts,
        response.definitionFingerprint,
        nowAt,
        true
      ) == 'LIVE_VERIFIED';
  }

  /** Deletes at most 200 expired rows visible to the authorized administrator. */
  public static Integer deleteExpired(Boolean confirmed) {
    if (confirmed != true) {
      throw new RecordHealthCheckPreviewService.PreviewException(
        'Confirmation is required before deleting expired receipts.'
      );
    }
    Datetime nowAt = System.now();
    List<Record_Health_Check_Readiness__c> expired = [
      SELECT Id
      FROM Record_Health_Check_Readiness__c
      WHERE ExpiresAt__c <= :nowAt
      WITH USER_MODE
      ORDER BY ExpiresAt__c ASC
      LIMIT 200
    ];
    if (expired.isEmpty()) {
      return 0;
    }
    List<Database.DeleteResult> deleted = Database.delete(
      expired,
      AccessLevel.USER_MODE
    );
    Integer count = 0;
    for (Database.DeleteResult result : deleted) {
      if (result.isSuccess()) {
        count++;
      }
    }
    return count;
  }

  private static RecordHealthCheckReadinessReceipt notSaved(
    RecordHealthCheckReadinessReceipt outcome
  ) {
    outcome.receiptStatus = 'NOT_SAVED';
    outcome.warning = RECEIPT_WARNING;
    return outcome;
  }

  private static Map<String, Integer> resultCounts(
    List<RecordHealthCheckResultItem> results
  ) {
    Map<String, Integer> counts = new Map<String, Integer>{
      'PASS' => 0,
      'FAIL' => 0,
      'SKIPPED' => 0,
      'UNABLE_TO_EVALUATE' => 0,
      'ERROR' => 0
    };
    for (RecordHealthCheckResultItem item : results) {
      String status = item == null ||
        item.evaluation == null
        ? 'ERROR'
        : item.evaluation.status;
      if (counts.containsKey(status)) {
        counts.put(status, counts.get(status) + 1);
      }
    }
    return counts;
  }

  private static String scopeDigest(List<Id> recordIds) {
    List<String> normalized = new List<String>();
    for (Id recordId : recordIds) {
      normalized.add(String.valueOf(recordId));
    }
    normalized.sort();
    return EncodingUtil.convertToHex(
        Crypto.generateDigest(
          'SHA-256',
          Blob.valueOf(String.join(normalized, '\n'))
        )
      )
      .toLowerCase();
  }
}
