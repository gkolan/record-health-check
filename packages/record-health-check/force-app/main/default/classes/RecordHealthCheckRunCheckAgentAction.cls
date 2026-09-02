/**
 * Runs one Record Health Check as a native Agentforce action.
 */
global with sharing class RecordHealthCheckRunCheckAgentAction {
  private static final String CONTRACT_VERSION = '1.0';
  private static final String OPERATION = 'RUN_CHECK';
  private static final String PERMISSION_DENIED_MESSAGE = 'You do not have permission to run Record Health Checks.';
  private static final String EXECUTION_MESSAGE = 'The Check request could not be evaluated.';

  /** One native Agentforce Check request. */
  global class Request {
    @InvocableVariable(
      required=true
      label='Record ID'
      description='ID of the single Salesforce record to evaluate.'
    )
    global Id recordId;

    @InvocableVariable(
      required=true
      label='Check Qualified API Name'
      description='Exact QualifiedApiName of the Record Health Check. Never add or remove a namespace.'
    )
    global String qualifiedApiName;

    @InvocableVariable(
      label='Correlation ID'
      description='Optional safe identifier of at most 120 characters for operational correlation.'
    )
    global String correlationId;
  }

  /** One structured native Agentforce Check response. */
  global class Response {
    @InvocableVariable(label='Contract Version')
    global String contractVersion;
    @InvocableVariable(label='Correlation ID')
    global String correlationId;
    @InvocableVariable(label='Success')
    global Boolean success;
    @InvocableVariable(label='Operation')
    global String operation;
    @InvocableVariable(label='Status')
    global String status;
    @InvocableVariable(label='Reason Code')
    global String reasonCode;
    @InvocableVariable(label='Error Type')
    global String errorType;
    @InvocableVariable(label='Error Message')
    global String errorMessage;
    @InvocableVariable(label='Diagnostic ID')
    global String diagnosticId;
    @InvocableVariable(label='Diagnostic Category')
    global String diagnosticCategory;
    @InvocableVariable(label='Diagnostic Summary')
    global String diagnosticSummary;
    @InvocableVariable(label='Recommended Action')
    global String recommendedAction;
  }

  /**
   * Evaluates one exact Check for one record without modifying the record.
   *
   * @param requests Agentforce request list; exactly one item is supported.
   * @return One structured response, or one aligned limit response per excessive input.
   */
  @InvocableMethod(
    label='Run Record Health Check for Agentforce'
    description='Use when a user asks for the actual result of one named Record Health Check on one Salesforce record. FAIL is a completed business finding. UNABLE_TO_EVALUATE and ERROR are not PASS.'
    category='Record Health Check'
  )
  global static List<Response> runCheck(List<Request> requests) {
    if (requests == null || requests.isEmpty()) {
      return new List<Response>();
    }
    if (requests.size() != 1) {
      return repeatedErrors(
        requests,
        'LIMIT',
        'AGENT_SINGLE_RECORD_REQUIRED: supply exactly one request.'
      );
    }
    Request input = requests[0];
    String correlationId = safeCorrelationId(input?.correlationId);
    if (!RecordHealthCheckAccess.canRunChecks()) {
      return new List<Response>{
        errorResponse(correlationId, 'AUTHORIZATION', PERMISSION_DENIED_MESSAGE)
      };
    }
    String validationError = validate(input);
    if (validationError != null) {
      return new List<Response>{
        errorResponse(correlationId, 'VALIDATION', validationError)
      };
    }

    try {
      RecordHealthCheckRequest request = RecordHealthCheckRequest.forCheck(
          input.qualifiedApiName.trim(),
          input.recordId
        )
        .withExecutionOrigin(RecordHealthCheckExecutionOrigin.AGENT)
        .withEventPublication(RecordHealthCheckEventPublication.NONE);
      if (!String.isBlank(input.correlationId)) {
        request = request.withRunId(input.correlationId.trim());
      }
      RecordHealthCheckResponse evaluation = RecordHealthCheck.evaluate(
        request
      );
      RecordHealthCheckEvaluationResult result = evaluation.results[0]
        ?.evaluation;
      Response output = baseResponse(evaluation.runId);
      output.success = true;
      output.operation = OPERATION;
      output.status = result.status;
      output.reasonCode = result.reasonCode;
      output.diagnosticId = result.diagnosticId;
      output.diagnosticCategory = result.diagnosticCategory;
      output.diagnosticSummary = result.diagnosticSummary;
      output.recommendedAction = result.recommendedAction;
      return new List<Response>{ output };
    } catch (Exception error) {
      RecordHealthCheckLogger.log(
        RecordHealthCheckLogger.Level.ERROR,
        correlationId,
        null,
        input?.recordId,
        input?.qualifiedApiName,
        'AGENT_CHECK_EXECUTION_FAILED',
        new Map<String, Object>{ 'surface' => 'AGENTFORCE' },
        error
      );
      RecordHealthCheckLogger.flush();
      return new List<Response>{
        errorResponse(correlationId, 'EXECUTION', EXECUTION_MESSAGE)
      };
    }
  }

  private static String validate(Request input) {
    if (input == null || input.recordId == null) {
      return 'Record ID is required.';
    }
    if (String.isBlank(input.qualifiedApiName)) {
      return 'Check Qualified API Name is required.';
    }
    String identity = input.qualifiedApiName.trim();
    if (
      identity.length() >
      RecordHealthCheckConstants.MAX_QUALIFIED_API_NAME_LENGTH
    ) {
      return 'Check Qualified API Name must not exceed 255 characters.';
    }
    if (
      !Pattern.matches(
        '^[a-zA-Z][a-zA-Z0-9_]*(?:__[a-zA-Z][a-zA-Z0-9_]*)?$',
        identity
      )
    ) {
      return 'Check Qualified API Name has an invalid format.';
    }
    if (
      !String.isBlank(input.correlationId) &&
      !isValidCorrelationId(input.correlationId.trim())
    ) {
      return 'Correlation ID must use 1 to 120 letters, numbers, periods, underscores, colons, or hyphens.';
    }
    return null;
  }

  private static Boolean isValidCorrelationId(String value) {
    return value.length() <= 120 &&
      Pattern.matches('^[a-zA-Z0-9._:-]+$', value);
  }

  private static String safeCorrelationId(String value) {
    if (!String.isBlank(value) && isValidCorrelationId(value.trim())) {
      return value.trim();
    }
    return 'agent-' + String.valueOf(DateTime.now().getTime());
  }

  private static Response baseResponse(String correlationId) {
    Response output = new Response();
    output.contractVersion = CONTRACT_VERSION;
    output.correlationId = correlationId;
    return output;
  }

  private static Response errorResponse(
    String correlationId,
    String errorType,
    String errorMessage
  ) {
    Response output = baseResponse(correlationId);
    output.success = false;
    output.errorType = errorType;
    output.errorMessage = errorMessage;
    return output;
  }

  private static List<Response> repeatedErrors(
    List<Request> requests,
    String errorType,
    String errorMessage
  ) {
    List<Response> outputs = new List<Response>();
    for (Request input : requests) {
      outputs.add(
        errorResponse(
          safeCorrelationId(input?.correlationId),
          errorType,
          errorMessage
        )
      );
    }
    return outputs;
  }
}
