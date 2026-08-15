@RestResource(urlMapping='/record-health-check/contract-1/evaluations')
/**
 * Versioned read-only REST boundary for approved Agentforce and MCP tools.
 */
global with sharing class RecordHealthCheckAgentRestResource {
  private static final String CONTRACT_VERSION = '1.0';
  private static final String RUN_CHECK = 'RUN_CHECK';
  private static final String RUN_CHECK_SET = 'RUN_CHECK_SET';
  private static final Integer MAX_REQUEST_BYTES = 16384;
  private static final String AUTHORIZATION_MESSAGE = 'You do not have permission to run Record Health Checks.';
  private static final String EXECUTION_MESSAGE = 'The evaluation could not be completed.';

  /** Version 1 JSON request. */
  global class AgentToolRequest {
    /** Approved operation name. */
    global String operation;
    /** One Salesforce record ID. */
    global String recordId;
    /** Exact Check or Check Set QualifiedApiName. */
    global String qualifiedApiName;
    /** Optional safe operational correlation identifier. */
    global String correlationId;
  }

  /** Version 1 JSON response. */
  global class AgentToolResponse {
    /** Agent tool contract version. */
    global String contractVersion;
    /** Safe operational correlation identifier. */
    global String correlationId;
    /** Whether the response contains a completed health evaluation. */
    global Boolean success;
    /** Completed operation name. */
    global String operation;
    /** Five-state health result. */
    global String status;
    /** Stable single-Check reason code. */
    global String reasonCode;
    /** Number of passing Check results. */
    global Integer passed;
    /** Number of failing Check results. */
    global Integer failed;
    /** Number of skipped Check results. */
    global Integer skipped;
    /** Number of inconclusive Check results. */
    global Integer unable;
    /** Number of system-error Check results. */
    global Integer systemError;
    /** Stable adapter error category. */
    global String errorType;
    /** Safe adapter error explanation. */
    global String errorMessage;
  }

  @HttpPost
  /**
   * Evaluates one exact Check or Check Set for one record.
   *
   * @return A versioned evaluation or safe adapter-error response.
   */
  global static AgentToolResponse doPost() {
    RestRequest request = RestContext.request;
    RestResponse response = RestContext.response;
    response.addHeader('Content-Type', 'application/json;charset=UTF-8');
    String correlationId = generatedCorrelationId();

    if (!RecordHealthCheckAccess.canRunChecks()) {
      return errorResponse(
        response,
        403,
        correlationId,
        'AUTHORIZATION',
        AUTHORIZATION_MESSAGE
      );
    }
    if (request == null || request.requestBody == null) {
      return errorResponse(
        response,
        400,
        correlationId,
        'VALIDATION',
        'A JSON request body is required.'
      );
    }
    if (request.requestBody.size() > MAX_REQUEST_BYTES) {
      return errorResponse(
        response,
        413,
        correlationId,
        'LIMIT',
        'REQUEST_BODY_TOO_LARGE: the request must not exceed 16384 bytes.'
      );
    }
    String contentType = request.headers.get('Content-Type');
    if (
      String.isBlank(contentType) ||
      !contentType.toLowerCase().startsWith('application/json')
    ) {
      return errorResponse(
        response,
        415,
        correlationId,
        'VALIDATION',
        'Content-Type must be application/json.'
      );
    }

    AgentToolRequest input;
    try {
      input = (AgentToolRequest) JSON.deserializeStrict(
        request.requestBody.toString(),
        AgentToolRequest.class
      );
    } catch (JSONException error) {
      return errorResponse(
        response,
        400,
        correlationId,
        'VALIDATION',
        'The JSON request does not match agent tool contract version 1.0.'
      );
    }

    correlationId = safeCorrelationId(input?.correlationId);
    String validationError = validate(input);
    if (validationError != null) {
      return errorResponse(
        response,
        400,
        correlationId,
        'VALIDATION',
        validationError
      );
    }

    Id recordId;
    try {
      recordId = Id.valueOf(input.recordId);
    } catch (Exception error) {
      return errorResponse(
        response,
        400,
        correlationId,
        'VALIDATION',
        'Record ID is not valid for Salesforce.'
      );
    }

    try {
      RecordHealthCheckRequest evaluationRequest = input.operation == RUN_CHECK
        ? RecordHealthCheckRequest.forCheck(
            input.qualifiedApiName.trim(),
            recordId
          )
        : RecordHealthCheckRequest.forCheckSet(
            input.qualifiedApiName.trim(),
            recordId
          );
      evaluationRequest = evaluationRequest
        .withExecutionOrigin(RecordHealthCheckExecutionOrigin.AGENT)
        .withEventPublication(RecordHealthCheckEventPublication.NONE);
      if (!String.isBlank(input.correlationId)) {
        evaluationRequest = evaluationRequest.withRunId(
          input.correlationId.trim()
        );
      }
      RecordHealthCheckResponse evaluation = RecordHealthCheck.evaluate(
        evaluationRequest
      );
      AgentToolResponse output = input.operation == RUN_CHECK
        ? checkResponse(evaluation)
        : checkSetResponse(evaluation);
      response.statusCode = 200;
      return output;
    } catch (RecordHealthCheckScopePipeline.ScopePipelineException error) {
      return errorResponse(
        response,
        400,
        correlationId,
        'VALIDATION',
        'The requested Check or Check Set could not be selected.'
      );
    } catch (Exception error) {
      return errorResponse(
        response,
        500,
        correlationId,
        'EXECUTION',
        EXECUTION_MESSAGE
      );
    }
  }

  private static String validate(AgentToolRequest input) {
    if (input == null) {
      return 'A JSON request body is required.';
    }
    if (input.operation != RUN_CHECK && input.operation != RUN_CHECK_SET) {
      return 'Operation must be RUN_CHECK or RUN_CHECK_SET.';
    }
    if (
      String.isBlank(input.recordId) ||
      !Pattern.matches('^[a-zA-Z0-9]{15}(?:[a-zA-Z0-9]{3})?$', input.recordId)
    ) {
      return 'Record ID must be a 15- or 18-character Salesforce ID.';
    }
    if (String.isBlank(input.qualifiedApiName)) {
      return 'Qualified API Name is required.';
    }
    String identity = input.qualifiedApiName.trim();
    if (
      identity.length() >
      RecordHealthCheckConstants.MAX_QUALIFIED_API_NAME_LENGTH ||
      !Pattern.matches(
        '^[a-zA-Z][a-zA-Z0-9_]*(?:__[a-zA-Z][a-zA-Z0-9_]*)?$',
        identity
      )
    ) {
      return 'Qualified API Name has an invalid format or exceeds 255 characters.';
    }
    if (
      !String.isBlank(input.correlationId) &&
      !isValidCorrelationId(input.correlationId.trim())
    ) {
      return 'Correlation ID must use 1 to 120 letters, numbers, periods, underscores, colons, or hyphens.';
    }
    return null;
  }

  private static AgentToolResponse checkResponse(
    RecordHealthCheckResponse evaluation
  ) {
    if (
      evaluation == null ||
      evaluation.results.size() != 1 ||
      evaluation.results[0]?.evaluation == null ||
      String.isBlank(evaluation.results[0].evaluation.status)
    ) {
      throw new AgentRestException(EXECUTION_MESSAGE);
    }
    RecordHealthCheckEvaluationResult result = evaluation.results[0].evaluation;
    AgentToolResponse output = baseResponse(evaluation.runId);
    output.success = true;
    output.operation = RUN_CHECK;
    output.status = result.status;
    output.reasonCode = result.reasonCode;
    return output;
  }

  private static AgentToolResponse checkSetResponse(
    RecordHealthCheckResponse evaluation
  ) {
    if (evaluation == null || evaluation.summary == null) {
      throw new AgentRestException(EXECUTION_MESSAGE);
    }
    AgentToolResponse output = baseResponse(evaluation.runId);
    output.success = true;
    output.operation = RUN_CHECK_SET;
    output.status = RecordHealthCheckFlowSupport.overallStatus(
      evaluation.summary
    );
    output.passed = evaluation.summary.passed;
    output.failed = evaluation.summary.failed;
    output.skipped = evaluation.summary.skipped;
    output.unable = evaluation.summary.unable;
    output.systemError = evaluation.summary.systemError;
    return output;
  }

  private static AgentToolResponse errorResponse(
    RestResponse response,
    Integer statusCode,
    String correlationId,
    String errorType,
    String errorMessage
  ) {
    response.statusCode = statusCode;
    AgentToolResponse output = baseResponse(correlationId);
    output.success = false;
    output.errorType = errorType;
    output.errorMessage = errorMessage;
    return output;
  }

  private static AgentToolResponse baseResponse(String correlationId) {
    AgentToolResponse output = new AgentToolResponse();
    output.contractVersion = CONTRACT_VERSION;
    output.correlationId = correlationId;
    return output;
  }

  private static Boolean isValidCorrelationId(String value) {
    return value.length() <= 120 &&
      Pattern.matches('^[a-zA-Z0-9._:-]+$', value);
  }

  private static String safeCorrelationId(String value) {
    return !String.isBlank(value) && isValidCorrelationId(value.trim())
      ? value.trim()
      : generatedCorrelationId();
  }

  private static String generatedCorrelationId() {
    return 'agent-' + String.valueOf(DateTime.now().getTime());
  }

  private class AgentRestException extends Exception {
  }
}
