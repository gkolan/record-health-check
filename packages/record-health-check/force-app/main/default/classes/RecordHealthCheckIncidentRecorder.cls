/** Atomically creates aligned technical results and their structured telemetry. */
public with sharing class RecordHealthCheckIncidentRecorder {
  /**
   * Records one scope-wide failure and returns aligned results referencing it.
   * @param check Check that was being evaluated.
   * @param recordIds Affected record IDs.
   * @param context Diagnostic phase and run context.
   * @param error Caught exception, when present.
   * @return One internal result per affected record.
   */
  public static Map<Id, RecordHealthCheckInternalResult> recordScopeFailure(
    Record_Health_Check__mdt check,
    List<Id> recordIds,
    RecordHealthCheckDiagnosticContext context,
    Exception error
  ) {
    List<Id> affectedIds = recordIds == null ? new List<Id>() : recordIds;
    context.affectedRecordCount = affectedIds.size();
    context.scopeImpact = affectedIds.size() > 1 ? 'SCOPE_WIDE' : 'ONE_RECORD';
    RecordHealthCheckDiagnosticIncident incident = error == null
      ? RecordHealthCheckDiagnosticFactory.fromReason(context)
      : RecordHealthCheckDiagnosticFactory.fromException(error, context);
    logIncident(incident, affectedIds, error);

    Map<Id, RecordHealthCheckInternalResult> results = new Map<Id, RecordHealthCheckInternalResult>();
    for (Id recordId : affectedIds) {
      RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
      result.checkDeveloperName = check?.DeveloperName;
      result.label = check?.CheckTitle__c;
      result.priority = check?.EvaluationOrder__c;
      result.evaluatorType = String.isBlank(context.evaluatorType)
        ? check?.EvaluationType__c
        : context.evaluatorType;
      result.status = incident.status;
      result.reasonCode = incident.reasonCode;
      result.message = safeOutcomeMessage(check, incident.status);
      result.detailMessage = incident.likelyCause;
      result.diagnosticIncident = incident;
      results.put(recordId, result);
    }
    return results;
  }

  /**
   * Records a fatal failure before the caller rethrows it to preserve rollback.
   * @param recordIds Affected record IDs.
   * @param context Diagnostic context.
   * @param error Fatal exception.
   * @return Recorded incident for tests and boundary adapters.
   */
  public static RecordHealthCheckDiagnosticIncident recordFatalFailure(
    List<Id> recordIds,
    RecordHealthCheckDiagnosticContext context,
    Exception error
  ) {
    List<Id> affectedIds = recordIds == null ? new List<Id>() : recordIds;
    context.affectedRecordCount = affectedIds.size();
    context.scopeImpact = affectedIds.size() > 1 ? 'SCOPE_WIDE' : 'ONE_RECORD';
    RecordHealthCheckDiagnosticIncident incident = RecordHealthCheckDiagnosticFactory.fromException(
      error,
      context
    );
    logIncident(incident, affectedIds, error);
    return incident;
  }

  /** Adds a diagnosis to an existing technical result that has no caught exception. */
  public static void attachResultFailure(
    Record_Health_Check__mdt check,
    Id recordId,
    RecordHealthCheckDiagnosticContext context,
    RecordHealthCheckInternalResult result
  ) {
    if (
      result == null ||
      result.diagnosticIncident != null ||
      (result.status != RecordHealthCheckStatus.ERROR &&
      result.status != RecordHealthCheckStatus.UNABLE_TO_EVALUATE)
    ) {
      return;
    }
    context.reasonCode = result.reasonCode;
    context.status = result.status;
    context.severity = result.status == RecordHealthCheckStatus.ERROR
      ? 'CRITICAL'
      : 'WARNING';
    context.technicalMessage = result.detailMessage;
    context.affectedRecordCount = 1;
    context.scopeImpact = 'ONE_RECORD';
    RecordHealthCheckDiagnosticIncident incident = RecordHealthCheckDiagnosticFactory.fromReason(
      context
    );
    result.diagnosticIncident = incident;
    if (String.isBlank(result.detailMessage)) {
      result.detailMessage = incident.likelyCause;
    }
    logIncident(incident, new List<Id>{ recordId }, null);
  }

  private static void logIncident(
    RecordHealthCheckDiagnosticIncident incident,
    List<Id> recordIds,
    Exception error
  ) {
    Map<String, Object> fields = new Map<String, Object>{
      'affectedRecordCount' => incident.affectedRecordCount,
      'category' => incident.category,
      'diagnosticId' => incident.diagnosticId,
      'exceptionType' => incident.exceptionType,
      'fingerprint' => incident.fingerprint,
      'owner' => incident.owner,
      'phase' => incident.phase,
      'reasonCode' => incident.reasonCode,
      'retryable' => incident.retryable,
      'scopeImpact' => incident.scopeImpact,
      'topFrame' => topFrame(incident)
    };
    RecordHealthCheckLogger.log(
      RecordHealthCheckLogger.Level.ERROR,
      incident.runId,
      incident.checkSetQualifiedApiName,
      recordIds.isEmpty() ? null : recordIds[0],
      incident.checkQualifiedApiName,
      'DIAGNOSTIC_INCIDENT',
      fields,
      error
    );
  }

  private static String safeOutcomeMessage(
    Record_Health_Check__mdt check,
    String status
  ) {
    if (
      status == RecordHealthCheckStatus.UNABLE_TO_EVALUATE &&
      String.isNotBlank(check?.UnableToEvaluateMessage__c)
    ) {
      return check.UnableToEvaluateMessage__c;
    }
    return status == RecordHealthCheckStatus.UNABLE_TO_EVALUATE
      ? 'This check could not be evaluated. Contact your administrator.'
      : 'A system error prevented this check from completing. An authorized administrator can open the diagnosis.';
  }

  private static String topFrame(RecordHealthCheckDiagnosticIncident incident) {
    if (String.isBlank(incident.topFrameClass)) {
      return null;
    }
    return incident.topFrameClass +
      (String.isBlank(incident.topFrameMethod)
        ? ''
        : '.' + incident.topFrameMethod) +
      (incident.topFrameLine == null
        ? ''
        : ':' + String.valueOf(incident.topFrameLine));
  }
}
