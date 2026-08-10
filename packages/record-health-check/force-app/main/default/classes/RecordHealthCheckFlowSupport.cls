/** Shared normalization and result-alignment behavior for Flow actions. */
public with sharing class RecordHealthCheckFlowSupport {
  /** Version of the public Flow response contract. */
  public static final String CONTRACT_VERSION = '2.0';
  @TestVisible
  private static Map<Id, List<RecordHealthCheckResultItem>> itemsByRecordOverride;
  @TestVisible
  private static Boolean nullItemsByRecordOverride = false;
  @TestVisible
  private static Integer payloadBudgetStartOverride;

  public class FlowSupportException extends Exception {
  }

  /** Aggregate Flow response exceeded its safe transaction budget. */
  public class PayloadBudgetException extends Exception {
  }

  /**
   * Accounts for one serialized Flow result without allowing aggregate output to
   * consume the synchronous transaction heap.
   *
   * @param consumedChars Characters already accepted for this invocation.
   * @param payload Candidate serialized result.
   * @return New aggregate character count.
   * @throws FlowSupportException when the aggregate response budget is exceeded.
   */
  public static Integer consumePayloadBudget(
    Integer consumedChars,
    String payload
  ) {
    Integer current = consumedChars;
    if (current == null) {
      current = 0;
    }
    Integer candidateLength = payload == null ? 0 : payload.length();
    if (
      current < 0 ||
      candidateLength >
      RecordHealthCheckConstants.MAX_FLOW_RESPONSE_CHARS - current
    ) {
      throw new PayloadBudgetException(
        'FLOW_RESPONSE_BUDGET_EXCEEDED: ceiling=' +
          RecordHealthCheckConstants.MAX_FLOW_RESPONSE_CHARS +
          '.'
      );
    }
    return current + candidateLength;
  }

  /** Finds the aligned response item for one record. */
  public static RecordHealthCheckResultItem itemForRecord(
    RecordHealthCheckResponse response,
    Id recordId
  ) {
    for (RecordHealthCheckResultItem item : response.results) {
      if (item.evaluation.recordId == recordId) {
        return item;
      }
    }
    throw new FlowSupportException(
      'No result was returned for ' + recordId + '.'
    );
  }

  /** Indexes response items once for constant-time Flow row alignment. */
  public static Map<Id, List<RecordHealthCheckResultItem>> itemsByRecord(
    RecordHealthCheckResponse response
  ) {
    if (nullItemsByRecordOverride) {
      return null;
    }
    if (itemsByRecordOverride != null) {
      return itemsByRecordOverride;
    }
    Map<Id, List<RecordHealthCheckResultItem>> indexed = new Map<Id, List<RecordHealthCheckResultItem>>();
    if (response == null) {
      return indexed;
    }
    for (RecordHealthCheckResultItem item : response.results) {
      Id recordId = item?.evaluation?.recordId;
      if (recordId == null) {
        continue;
      }
      if (!indexed.containsKey(recordId)) {
        indexed.put(recordId, new List<RecordHealthCheckResultItem>());
      }
      indexed.get(recordId).add(item);
    }
    return indexed;
  }

  /** Returns the initial aggregate response size for one Flow call. */
  public static Integer initialPayloadChars() {
    return payloadBudgetStartOverride == null ? 0 : payloadBudgetStartOverride;
  }

  /** Normalizes a required Flow publication string. */
  public static String normalizedPublication(String value) {
    if (String.isBlank(value)) {
      throw new FlowSupportException(
        'Event Publication is required. Use NONE, ACTIONABLE, or ALL.'
      );
    }
    return value.trim().toUpperCase();
  }

  /** Maps a normalized Flow publication string to the public enum. */
  public static RecordHealthCheckEventPublication publication(String value) {
    if (value == 'NONE') {
      return RecordHealthCheckEventPublication.NONE;
    }
    if (value == 'ACTIONABLE') {
      return RecordHealthCheckEventPublication.ACTIONABLE;
    }
    if (value == 'ALL') {
      return RecordHealthCheckEventPublication.ALL;
    }
    throw new FlowSupportException(
      'INVALID_EVENT_PUBLICATION: expected NONE, ACTIONABLE, or ALL.'
    );
  }

  /** Returns the highest-priority status represented by a run summary. */
  public static String overallStatus(RecordHealthCheckRunSummary summary) {
    if (summary.systemError > 0) {
      return 'ERROR';
    }
    if (summary.unable > 0) {
      return 'UNABLE_TO_EVALUATE';
    }
    if (summary.failed > 0) {
      return 'FAIL';
    }
    if (summary.passed > 0) {
      return 'PASS';
    }
    return 'SKIPPED';
  }
}
