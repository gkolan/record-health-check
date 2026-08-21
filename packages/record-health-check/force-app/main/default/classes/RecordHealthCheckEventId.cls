/** Generates bounded, unique application-level identifiers for lifecycle events. */
public with sharing class RecordHealthCheckEventId {
  private static Integer sequence = 0;

  /**
   * Generates a unique event ID while retaining a recognizable run prefix.
   *
   * @param runId Caller-owned correlation identifier.
   * @param eventIdentity Check/result identity within the publication.
   * @return A unique identifier that fits EventId__c (Text 80).
   */
  public static String newId(String runId, String eventIdentity) {
    sequence++;
    String safeRunId = runId == null ? 'null' : runId;
    String nonce =
      String.valueOf(DateTime.now().getTime()) +
      '|' +
      String.valueOf(Crypto.getRandomInteger()) +
      '|' +
      sequence;
    String identity =
      safeRunId +
      '|' +
      String.valueOf(eventIdentity) +
      '|' +
      nonce;
    String digest = EncodingUtil.convertToHex(
      Crypto.generateDigest('SHA-256', Blob.valueOf(identity))
    );
    return safeRunId.left(50) + '-' + digest.left(16);
  }
}
