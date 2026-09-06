/** Generates bounded, unique application-level identifiers for lifecycle events. */
public with sharing class RecordHealthCheckEventId {
  private static Integer sequence = 0;

  /**
   * Generates a unique event ID while retaining a recognizable run prefix.
   * The sequence separates publications within one transaction and the random
   * suffix separates concurrent transactions that share a run ID.
   *
   * @param runId Caller-owned correlation identifier.
   * @return A unique identifier that fits EventId__c (Text 80).
   */
  public static String newId(String runId) {
    sequence++;
    String safeRunId = runId == null ? 'null' : runId;
    return safeRunId.left(50) +
      '-' +
      sequence +
      '-' +
      String.valueOf(Math.abs(Crypto.getRandomInteger()));
  }
}
