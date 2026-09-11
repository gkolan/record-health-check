/** Imperative LWC adapter for the detached-preview global service. */
public with sharing class RecordHealthCheckPreviewController {
  /** Validates JSON-shaped Custom Metadata only after explicit user action. */
  @AuraEnabled
  public static String preview(
    String draftJson,
    String qualifiedSetName,
    List<Id> recordIds,
    String mode,
    Boolean readinessReceiptRequested
  ) {
    try {
      if (String.isBlank(draftJson)) {
        throw new RecordHealthCheckPreviewService.PreviewException(
          'Draft Check JSON is required.'
        );
      }
      Record_Health_Check__mdt draft = (Record_Health_Check__mdt) JSON.deserialize(
        draftJson,
        Record_Health_Check__mdt.class
      );
      RecordHealthCheckPreviewRequest request = RecordHealthCheckPreviewRequest.forDraftCheck(
          draft,
          qualifiedSetName,
          recordIds == null ? new List<Id>() : recordIds
        )
        .withMode(mode)
        .withReadinessReceipt(readinessReceiptRequested);
      return JSON.serialize(RecordHealthCheckPreviewService.preview(request));
    } catch (Exception invalid) {
      throw new AuraHandledException(invalid.getMessage());
    }
  }

  /** Deletes one confirmed bounded batch of expired readiness receipts. */
  @AuraEnabled
  public static Integer deleteExpiredReceipts(Boolean confirmed) {
    try {
      return RecordHealthCheckPreviewService.deleteExpiredReadinessReceipts(
        confirmed
      );
    } catch (Exception invalid) {
      throw new AuraHandledException(invalid.getMessage());
    }
  }
}
