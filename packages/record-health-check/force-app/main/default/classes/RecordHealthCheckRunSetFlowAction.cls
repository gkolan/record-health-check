/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** Bulk Flow adapter for qualified Check Set requests. */
public with sharing class RecordHealthCheckRunSetFlowAction {
  /** One Flow input for a qualified Check Set evaluation. */
  public class Request {
    @InvocableVariable(
      required=true
      label='Check Set Qualified API Name'
      description='QualifiedApiName of the Check Set to run.'
    )
    public String checkSetQualifiedApiName;

    @InvocableVariable(required=true label='Record ID')
    public Id recordId;

    @InvocableVariable(
      required=true
      label='Event Publication'
      description='Required: NONE, ACTIONABLE, or ALL.'
    )
    public String eventPublication;
  }

  /** One aligned Flow output for a Check Set request. */
  public class Response {
    @InvocableVariable(label='Success')
    public Boolean isSuccess;
    @InvocableVariable(label='Error Message')
    public String errorMessage;
    @InvocableVariable(label='Error Type')
    public String errorType;
    @InvocableVariable(label='Contract Version')
    public String contractVersion;
    @InvocableVariable(label='Status')
    public String status;
    @InvocableVariable(label='Passed Count')
    public Integer passedCount;
    @InvocableVariable(label='Failed Count')
    public Integer failedCount;
    @InvocableVariable(label='Skipped Count')
    public Integer skippedCount;
    @InvocableVariable(label='Unable Count')
    public Integer unableCount;
    @InvocableVariable(label='System Error Count')
    public Integer systemErrorCount;
    @InvocableVariable(label='Result JSON')
    public String resultJson;
  }

  /**
   * Runs each valid Check Set request in bulk and returns an output at the same index.
   *
   * @param requests Flow requests to validate and evaluate.
   * @return Aligned success or recoverable-error responses.
   */
  @InvocableMethod(
    label='Run Record Health Check Set'
    description='Runs one qualified Record Health Check Set for each input record.'
    category='Record Health Check'
  )
  public static List<Response> runSet(List<Request> requests) {
    if (requests == null) {
      return new List<Response>();
    }
    if (!RecordHealthCheckAccess.canRunChecks()) {
      return errorResponses(
        requests.size(),
        'AUTHORIZATION',
        'You do not have permission to run Record Health Checks.'
      );
    }
    if (requests.size() > RecordHealthCheckConstants.MAX_RECORDS_PER_SCOPE) {
      return errorResponses(
        requests.size(),
        'LIMIT',
        countError(requests.size())
      );
    }
    RecordHealthCheckFlowGroupExecutor.Plan plan = prepare(requests);
    if (RecordHealthCheckFlowGroupExecutor.exceedsGroupLimit(plan)) {
      return groupLimitResponses(requests.size(), plan.failuresByIndex);
    }
    RecordHealthCheckFlowGroupExecutor.execute(
      plan,
      RecordHealthCheckFlowGroupExecutor.SelectionKind.CHECK_SET
    );
    return buildResponses(requests, plan);
  }

  private static RecordHealthCheckFlowGroupExecutor.Plan prepare(
    List<Request> requests
  ) {
    RecordHealthCheckFlowGroupExecutor.Plan plan = new RecordHealthCheckFlowGroupExecutor.Plan();
    for (Integer index = 0; index < requests.size(); index++) {
      Request input = requests[index];
      String normalizedIdentity = RecordHealthCheckFlowGroupExecutor.add(
        plan,
        index,
        input?.checkSetQualifiedApiName,
        'Check Set',
        input?.recordId,
        input?.eventPublication
      );
      if (normalizedIdentity != null) {
        input.checkSetQualifiedApiName = normalizedIdentity;
      }
    }
    return plan;
  }

  private static List<Response> buildResponses(
    List<Request> requests,
    RecordHealthCheckFlowGroupExecutor.Plan plan
  ) {
    List<Response> outputs = new List<Response>();
    Integer responseChars = RecordHealthCheckFlowSupport.initialPayloadChars();
    for (Integer index = 0; index < requests.size(); index++) {
      if (plan.failuresByIndex.containsKey(index)) {
        RecordHealthCheckFlowGroupExecutor.Failure failure = plan.failuresByIndex.get(
          index
        );
        outputs.add(errorResponse(failure.errorType, failure.errorMessage));
        continue;
      }
      Request input = requests[index];
      String key = RecordHealthCheckFlowGroupExecutor.key(
        input.checkSetQualifiedApiName,
        input.eventPublication
      );
      RecordHealthCheckFlowGroupExecutor.Result grouped = plan.resultByGroup.get(
        key
      );
      if (grouped.errorMessage != null) {
        outputs.add(errorResponse('EXECUTION', grouped.errorMessage));
        continue;
      }
      try {
        RecordHealthCheckResponse individual = responseForRecord(
          grouped.response,
          input.recordId,
          grouped.itemsByRecord
        );
        Response output = new Response();
        output.isSuccess = true;
        output.contractVersion = RecordHealthCheckFlowSupport.CONTRACT_VERSION;
        output.status = RecordHealthCheckFlowSupport.overallStatus(
          individual.summary
        );
        output.passedCount = individual.summary.passed;
        output.failedCount = individual.summary.failed;
        output.skippedCount = individual.summary.skipped;
        output.unableCount = individual.summary.unable;
        output.systemErrorCount = individual.summary.systemError;
        String resultJson = JSON.serialize(individual);
        responseChars = RecordHealthCheckFlowSupport.consumePayloadBudget(
          responseChars,
          resultJson
        );
        output.resultJson = resultJson;
        outputs.add(output);
      } catch (RecordHealthCheckFlowSupport.PayloadBudgetException ex) {
        outputs.add(errorResponse('LIMIT', ex.getMessage()));
      } catch (Exception ex) {
        // prettier-ignore
        outputs.add(errorResponse('EXECUTION', 'No aligned Check Set result was returned.'));
      }
    }
    return outputs;
  }

  private static RecordHealthCheckResponse responseForRecord(
    RecordHealthCheckResponse groupedResponse,
    Id recordId,
    Map<Id, List<RecordHealthCheckResultItem>> itemsByRecord
  ) {
    RecordHealthCheckResponse result = new RecordHealthCheckResponse();
    result.runId = groupedResponse.runId;
    result.recordIds.add(recordId);
    result.checkQualifiedApiNames.addAll(
      groupedResponse.checkQualifiedApiNames
    );
    List<RecordHealthCheckResultItem> items = itemsByRecord == null
      ? null
      : itemsByRecord.get(recordId);
    if (items == null) {
      return result;
    }
    for (RecordHealthCheckResultItem item : items) {
      result.results.add(item);
      result.summary.add(item.evaluation.status);
    }
    return result;
  }

  private static String countError(Integer count) {
    return 'MAX_RECORDS_PER_SCOPE_EXCEEDED: suppliedCount=' +
      count +
      ', ceiling=' +
      RecordHealthCheckConstants.MAX_RECORDS_PER_SCOPE;
  }

  private static List<Response> groupLimitResponses(
    Integer count,
    Map<Integer, RecordHealthCheckFlowGroupExecutor.Failure> failuresByIndex
  ) {
    List<Response> outputs = new List<Response>();
    for (Integer index = 0; index < count; index++) {
      outputs.add(
        failuresByIndex.containsKey(index)
          ? errorResponse(
              failuresByIndex.get(index).errorType,
              failuresByIndex.get(index).errorMessage
            )
          : errorResponse(
              'LIMIT',
              'MAX_FLOW_GROUPS_EXCEEDED: ceiling=' +
                RecordHealthCheckConstants.MAX_FLOW_GROUPS +
                '.'
            )
      );
    }
    return outputs;
  }

  private static List<Response> errorResponses(
    Integer count,
    String errorType,
    String message
  ) {
    List<Response> outputs = new List<Response>();
    for (Integer index = 0; index < count; index++) {
      outputs.add(errorResponse(errorType, message));
    }
    return outputs;
  }

  private static Response errorResponse(String errorType, String message) {
    Response output = new Response();
    output.contractVersion = RecordHealthCheckFlowSupport.CONTRACT_VERSION;
    output.isSuccess = false;
    output.errorType = errorType;
    output.errorMessage = message;
    return output;
  }
}
