/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** Bulk Flow adapter for qualified Check requests. */
public with sharing class RecordHealthCheckRunCheckFlowAction {
  /** One Flow input for a qualified Check evaluation. */
  public class Request {
    @InvocableVariable(
      required=true
      label='Check Qualified API Name'
      description='QualifiedApiName of the Check to run.'
    )
    public String checkQualifiedApiName;

    @InvocableVariable(required=true label='Record ID')
    public Id recordId;

    @InvocableVariable(
      required=true
      label='Event Publication'
      description='Required: NONE, ACTIONABLE, or ALL.'
    )
    public String eventPublication;
  }

  /** One aligned Flow output for a Check request. */
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
    @InvocableVariable(label='Reason Code')
    public String reasonCode;
    @InvocableVariable(label='Result JSON')
    public String resultJson;
  }

  /**
   * Runs each valid Check request in bulk and returns an output at the same index.
   *
   * @param requests Flow requests to validate and evaluate.
   * @return Aligned success or recoverable-error responses.
   */
  @InvocableMethod(
    label='Run Record Health Check'
    description='Runs one qualified Record Health Check for each input record.'
    category='Record Health Check'
  )
  public static List<Response> runCheck(List<Request> requests) {
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
    RecordHealthCheckFlowGroupExecutor.Plan plan = prepare(requests);
    if (RecordHealthCheckFlowGroupExecutor.exceedsGroupLimit(plan)) {
      return groupLimitResponses(requests.size(), plan.failuresByIndex);
    }
    RecordHealthCheckFlowGroupExecutor.execute(
      plan,
      RecordHealthCheckFlowGroupExecutor.SelectionKind.CHECK
    );
    return buildResponses(requests, plan);
  }

  private static RecordHealthCheckFlowGroupExecutor.Plan prepare(
    List<Request> requests
  ) {
    RecordHealthCheckFlowGroupExecutor.Plan plan = new RecordHealthCheckFlowGroupExecutor.Plan();
    for (Integer index = 0; index < requests.size(); index++) {
      Request input = requests[index];
      RecordHealthCheckFlowGroupExecutor.add(
        plan,
        index,
        input?.checkQualifiedApiName,
        'Check',
        input?.recordId,
        input?.eventPublication
      );
    }
    return plan;
  }

  private static List<Response> buildResponses(
    List<Request> requests,
    RecordHealthCheckFlowGroupExecutor.Plan plan
  ) {
    List<Response> outputs = new List<Response>();
    Integer responseChars = RecordHealthCheckFlowSupport.initialPayloadChars();
    Boolean payloadExhausted = false;
    for (Integer index = 0; index < requests.size(); index++) {
      if (plan.failuresByIndex.containsKey(index)) {
        RecordHealthCheckFlowGroupExecutor.Failure failure = plan.failuresByIndex.get(
          index
        );
        outputs.add(errorResponse(failure.errorType, failure.errorMessage));
        continue;
      }
      Request input = requests[index];
      String key = plan.groupKeyByIndex.get(index);
      RecordHealthCheckFlowGroupExecutor.Result grouped = plan.resultByGroup.get(
        key
      );
      if (grouped.errorMessage != null) {
        outputs.add(
          errorResponse(
            String.isBlank(grouped.errorType) ? 'EXECUTION' : grouped.errorType,
            grouped.errorMessage
          )
        );
        continue;
      }
      if (payloadExhausted) {
        outputs.add(
          errorResponse(
            'LIMIT',
            RecordHealthCheckFlowSupport.payloadBudgetMessage()
          )
        );
        continue;
      }
      try {
        List<RecordHealthCheckResultItem> items = grouped.itemsByRecord.get(
          input.recordId
        );
        if (items == null || items.isEmpty()) {
          throw new RecordHealthCheckFlowSupport.FlowSupportException(
            'No aligned Check result was returned.'
          );
        }
        RecordHealthCheckResultItem item = items[0];
        Response output = new Response();
        output.isSuccess = true;
        output.contractVersion = RecordHealthCheckFlowSupport.CONTRACT_VERSION;
        output.status = item.evaluation.status;
        output.reasonCode = item.evaluation.reasonCode;
        RecordHealthCheckFlowSupport.requirePayloadSerializationCapacity(
          responseChars
        );
        String resultJson = JSON.serialize(item);
        responseChars = RecordHealthCheckFlowSupport.consumePayloadBudget(
          responseChars,
          resultJson
        );
        output.resultJson = resultJson;
        outputs.add(output);
      } catch (RecordHealthCheckFlowSupport.PayloadBudgetException ex) {
        payloadExhausted = true;
        outputs.add(errorResponse('LIMIT', ex.getMessage()));
      } catch (RecordHealthCheckFlowSupport.FlowSupportException ex) {
        outputs.add(errorResponse('EXECUTION', ex.getMessage()));
      } catch (Exception ex) {
        outputs.add(
          errorResponse(
            'EXECUTION',
            'The Check response could not be prepared.'
          )
        );
      }
    }
    return outputs;
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
