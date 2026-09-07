/** Generates bounded, collision-resistant identifiers for lifecycle events. */
public with sharing class RecordHealthCheckEventId {
  private static Integer sequence = 0;

  /**
   * Generates a collision-resistant event ID with a recognizable run prefix.
   * The sequence guarantees separation within one transaction and the 128-bit
   * random suffix separates concurrent transactions that share a run ID.
   *
   * @param runId Caller-owned correlation identifier.
   * @return A unique identifier that fits EventId__c (Text 80).
   */
  public static String newId(String runId) {
    sequence++;
    String safeRunId = runId == null ? 'null' : runId;
    // Hex of a random key rather than Math.abs of a random Integer: Apex
    // Integers are two's complement, so Math.abs(Integer.MIN_VALUE) stays
    // negative and would put a second '-' in the identifier. Preserve all 128
    // random bits and shorten only the caller-owned prefix to fit Text(80).
    String randomSuffix = EncodingUtil.convertToHex(Crypto.generateAesKey(128));
    String sequencePart = String.valueOf(sequence);
    Integer prefixLength =
      80 -
      sequencePart.length() -
      randomSuffix.length() -
      2;
    return safeRunId.left(prefixLength) +
      '-' +
      sequencePart +
      '-' +
      randomSuffix;
  }
}
