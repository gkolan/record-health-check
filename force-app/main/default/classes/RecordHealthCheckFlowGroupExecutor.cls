/** Shared grouped execution for the Rule and Check Set Flow adapters. */
public with sharing class RecordHealthCheckFlowGroupExecutor {
  /** Supported grouped request selections. */
  public enum SelectionKind {
    RULE,
    CHECK_SET
  }

  /** One grouped engine result plus record-aligned items. */
  public class Result {
    public RecordHealthCheckResponse response;
    public Map<Id, List<RecordHealthCheckResultItem>> itemsByRecord;
    public String errorMessage;
  }

  /** Recoverable validation failure retained at its original Flow index. */
  public class Failure {
    public String errorType;
    public String errorMessage;
  }

  /** Shared grouped execution plan used by both public Flow adapters. */
  public class Plan {
    public Map<String, List<Id>> idsByGroup = new Map<String, List<Id>>();
    public Map<String, Result> resultByGroup = new Map<String, Result>();
    public Map<Integer, Failure> failuresByIndex = new Map<Integer, Failure>();
  }

  /** Validates and adds one request row while preserving recoverable failures. */
  public static String add(
    Plan plan,
    Integer index,
    String identity,
    String identityLabel,
    Id recordId,
    String publication
  ) {
    String normalizedIdentity;
    try {
      if (recordId == null) {
        throw new RecordHealthCheckFlowSupport.FlowSupportException(
          'A ' +
            identityLabel +
            ' Qualified API Name and Record ID are required.'
        );
      }
      normalizedIdentity = RecordHealthCheckQualifiedIdentity.normalize(
        identity,
        identityLabel
      );
      RecordHealthCheckFlowSupport.publication(
        RecordHealthCheckFlowSupport.normalizedPublication(publication)
      );
      String groupKey = key(normalizedIdentity, publication);
      if (!plan.idsByGroup.containsKey(groupKey)) {
        plan.idsByGroup.put(groupKey, new List<Id>());
      }
      plan.idsByGroup.get(groupKey).add(recordId);
      return normalizedIdentity;
    } catch (Exception error) {
      Failure failure = new Failure();
      failure.errorType = 'VALIDATION';
      failure.errorMessage = error.getMessage();
      plan.failuresByIndex.put(index, failure);
      return normalizedIdentity;
    }
  }

  /** Executes every valid group in a prepared plan. */
  public static void execute(Plan plan, SelectionKind selectionKind) {
    for (String groupKey : plan.idsByGroup.keySet()) {
      plan.resultByGroup.put(
        groupKey,
        evaluate(groupKey, plan.idsByGroup.get(groupKey), selectionKind)
      );
    }
  }

  /** Returns whether the plan exceeds the bounded Flow fan-out contract. */
  public static Boolean exceedsGroupLimit(Plan plan) {
    return plan.idsByGroup.size() > RecordHealthCheckConstants.MAX_FLOW_GROUPS;
  }

  /** Creates the official grouping key for one identity/publication pair. */
  public static String key(String identity, String publication) {
    return JSON.serialize(
      new List<String>{
        identity,
        RecordHealthCheckFlowSupport.normalizedPublication(publication)
      }
    );
  }

  /** Executes one Rule or Check Set group through the public engine. */
  public static Result evaluate(
    String key,
    List<Id> recordIds,
    SelectionKind selectionKind
  ) {
    Result result = new Result();
    try {
      List<Object> parts = (List<Object>) JSON.deserializeUntyped(key);
      Boolean isRuleSelection = String.valueOf(selectionKind) == 'RULE';
      RecordHealthCheckRequest request = isRuleSelection
        ? RecordHealthCheckRequest.forRule((String) parts[0], recordIds)
        : RecordHealthCheckRequest.forCheckSet((String) parts[0], recordIds);
      result.response = RecordHealthCheck.evaluate(
        request
          .withExecutionOrigin(RecordHealthCheckExecutionOrigin.FLOW)
          .withEventPublication(
            RecordHealthCheckFlowSupport.publication((String) parts[1])
          )
      );
      result.itemsByRecord = RecordHealthCheckFlowSupport.itemsByRecord(
        result.response
      );
    } catch (RecordHealthCheckPluginDispatch.SideEffectException ex) {
      throw ex;
    } catch (Exception ex) {
      result.errorMessage = String.valueOf(selectionKind) == 'RULE'
        ? 'The Rule request could not be evaluated.'
        : 'The Check Set request could not be evaluated.';
    }
    return result;
  }
}
