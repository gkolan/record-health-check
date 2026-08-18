/**
 * Runs one Record Health Check Set as a native Agentforce action.
 */
public with sharing class RecordHealthCheckRunSetAgentAction {
  private static final String CONTRACT_VERSION = '1.0';
  private static final String OPERATION = 'RUN_CHECK_SET';
  private static final String PERMISSION_DENIED_MESSAGE = 'You do not have permission to run Record Health Checks.';
  private static final String EXECUTION_MESSAGE = 'The Check Set request could not be evaluated.';

  /** One native Agentforce Check Set request. */
  public class Request {
    @InvocableVariable(
      required=true
      label='Record ID'
      description='ID of the single Salesforce record to evaluate.'
    )
    public Id recordId;

    @InvocableVariable(
      required=true
      label='Check Set Qualified API Name'
      description='Exact QualifiedApiName of the Record Health Check Set. Never add or remove a namespace.'
    )
    public String qualifiedApiName;

    @InvocableVariable(
      label='Correlation ID'
      description='Optional safe identifier of at most 120 characters for operational correlation.'
    )
    public String correlationId;
  }

  /** One structured native Agentforce Check Set response. */
  public class Response {
    @InvocableVariable(label='Contract Version')
    public String contractVersion;
    @InvocableVariable(label='Correlation ID')
    public String correlationId;
    @InvocableVariable(label='Success')
    public Boolean success;
    @InvocableVariable(label='Operation')
    public String operation;
    @InvocableVariable(label='Status')
    public String status;
    @InvocableVariable(label='Passed Count')
    public Integer passed;
    @InvocableVariable(label='Failed Count')
    public Integer failed;
    @InvocableVariable(label='Skipped Count')
    public Integer skipped;
    @InvocableVariable(label='Unable Count')
    public Integer unable;
    @InvocableVariable(label='System Error Count')
    public Integer systemError;
    @InvocableVariable(label='Error Type')
    public String errorType;
    @InvocableVariable(label='Error Message')
    public String errorMessage;
    @InvocableVariable(label='Diagnostic ID')
    public String diagnosticId;
    @InvocableVariable(label='Diagnostic Category')
    public String diagnosticCategory;
    @InvocableVariable(label='Diagnostic Summary')
    public String diagnosticSummary;
    @InvocableVariable(label='Recommended Action')
    public String recommendedAction;
  }

  /**
   * Evaluates one exact Check Set for one record without modifying the record.
   *
   * @param requests Agentforce request list; exactly one item is supported.
   * @return One structured response, or one aligned limit response per excessive input.
   */
  @InvocableMethod(
    label='Run Record Health Check Set for Agentforce'
    description='Use when a user asks for the actual health of one Salesforce record under one named Record Health Check Set. FAIL is a completed business finding. UNABLE_TO_EVALUATE and ERROR are not PASS.'
    category='Record Health Check'
  )
  public static List<Response> runSet(List<Request> requests) {
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
      RecordHealthCheckRequest request = RecordHealthCheckRequest.forCheckSet(
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
      Response output = baseResponse(evaluation.runId);
      output.success =
        evaluation.summary.systemError == 0 &&
        evaluation.summary.unable == 0;
      output.operation = OPERATION;
      output.status = RecordHealthCheckFlowSupport.overallStatus(
        evaluation.summary
      );
      output.passed = evaluation.summary.passed;
      output.failed = evaluation.summary.failed;
      output.skipped = evaluation.summary.skipped;
      output.unable = evaluation.summary.unable;
      output.systemError = evaluation.summary.systemError;
      populateFirstDiagnosis(output, evaluation.results);
      return new List<Response>{ output };
    } catch (Exception error) {
      RecordHealthCheckLogger.log(
        RecordHealthCheckLogger.Level.ERROR,
        correlationId,
        input?.qualifiedApiName,
        input?.recordId,
        null,
        'AGENT_SET_EXECUTION_FAILED',
        new Map<String, Object>{ 'surface' => 'AGENTFORCE' },
        error
      );
      RecordHealthCheckLogger.flush();
      return new List<Response>{
        errorResponse(correlationId, 'EXECUTION', EXECUTION_MESSAGE)
      };
    }
  }

  private static void populateFirstDiagnosis(
    Response output,
    List<RecordHealthCheckResultItem> results
  ) {
    for (RecordHealthCheckResultItem item : results) {
      RecordHealthCheckEvaluationResult result = item?.evaluation;
      if (String.isBlank(result?.diagnosticId)) {
        continue;
      }
      output.diagnosticId = result.diagnosticId;
      output.diagnosticCategory = result.diagnosticCategory;
      output.diagnosticSummary = result.diagnosticSummary;
      output.recommendedAction = result.recommendedAction;
      return;
    }
  }

  private static String validate(Request input) {
    if (input == null || input.recordId == null) {
      return 'Record ID is required.';
    }
    if (String.isBlank(input.qualifiedApiName)) {
      return 'Check Set Qualified API Name is required.';
    }
    String identity = input.qualifiedApiName.trim();
    if (
      identity.length() >
      RecordHealthCheckConstants.MAX_QUALIFIED_API_NAME_LENGTH
    ) {
      return 'Check Set Qualified API Name must not exceed 255 characters.';
    }
    if (
      !Pattern.matches(
        '^[a-zA-Z][a-zA-Z0-9_]*(?:__[a-zA-Z][a-zA-Z0-9_]*)?$',
        identity
      )
    ) {
      return 'Check Set Qualified API Name has an invalid format.';
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
