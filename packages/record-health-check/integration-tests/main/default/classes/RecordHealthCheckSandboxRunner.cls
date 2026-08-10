/**
 * Runs Record Health Check requests from sandbox verification utilities.
 */
public with sharing class RecordHealthCheckSandboxRunner {
  /**
   * Runs one qualified Check Set for a detached record scope.
   *
   * @param checkSetQualifiedApiName QualifiedApiName of the Check Set.
   * @param recordIds Record IDs to evaluate.
   * @param runId Optional correlation ID; a sandbox value is generated when blank.
   * @return The common Record Health Check response envelope.
   * @throws SandboxRunException when the request is incomplete.
   */
  public static RecordHealthCheckResponse runCheckSet(
    String checkSetQualifiedApiName,
    List<Id> recordIds,
    String runId
  ) {
    validate(checkSetQualifiedApiName, recordIds);
    String correlationId = String.isBlank(runId)
      ? 'rhc-sandbox-' + String.valueOf(Datetime.now().getTime())
      : runId.trim();
    return RecordHealthCheck.evaluate(
      RecordHealthCheckRequest.forCheckSet(
          checkSetQualifiedApiName.trim(),
          recordIds
        )
        .withRunId(correlationId)
        .withResultMode(RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY)
        .withEventPublication(RecordHealthCheckEventPublication.NONE)
    );
  }

  /**
   * Produces a compact JSON summary suitable for debug logs and AsyncApexJob review.
   *
   * @param response Response to summarize.
   * @return JSON containing the run ID, scope size, Check count, and status totals.
   */
  public static String summarize(RecordHealthCheckResponse response) {
    if (response == null) {
      return JSON.serialize(
        new Map<String, Object>{ 'status' => 'NO_RESPONSE' }
      );
    }
    return JSON.serialize(
      new Map<String, Object>{
        'runId' => response.runId,
        'recordCount' => response.recordIds.size(),
        'checkCount' => response.checkQualifiedApiNames.size(),
        'passed' => response.summary.passed,
        'failed' => response.summary.failed,
        'skipped' => response.summary.skipped,
        'unable' => response.summary.unable,
        'systemError' => response.summary.systemError
      }
    );
  }

  private static void validate(
    String checkSetQualifiedApiName,
    List<Id> recordIds
  ) {
    if (String.isBlank(checkSetQualifiedApiName)) {
      throw new SandboxRunException('Check Set QualifiedApiName is required.');
    }
    if (recordIds == null || recordIds.isEmpty()) {
      throw new SandboxRunException('At least one record ID is required.');
    }
  }

  /** Raised when a sandbox verification request is incomplete. */
  public class SandboxRunException extends Exception {
  }
}
