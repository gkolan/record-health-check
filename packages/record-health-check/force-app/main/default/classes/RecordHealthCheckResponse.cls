/**
 * Stable response envelope shared by Check and Check Set selections.
 */
global class RecordHealthCheckResponse {
  /** Server-only ordered sources retained only when diagnostic 2.0 was requested. */
  public transient List<RecordHealthCheckResultItem> diagnosticItems;
  /** Server-only authorization outcome for the requested diagnostic projection. */
  public transient Boolean diagnosticProjectionAuthorized = false;
  @AuraEnabled
  /** Correlation identifier for the evaluation. */
  global String runId;
  @AuraEnabled
  /** Ordered normalized record scope. */
  global List<Id> recordIds = new List<Id>();
  @AuraEnabled
  /** Ordered qualified Check identities selected for evaluation. */
  global List<String> checkQualifiedApiNames = new List<String>();
  @AuraEnabled
  /** Ordered result items included by the selected result mode. */
  global List<RecordHealthCheckResultItem> results = new List<RecordHealthCheckResultItem>();
  @AuraEnabled
  /** Aggregate terminal-status counts. */
  global RecordHealthCheckRunSummary summary = new RecordHealthCheckRunSummary();

  /** Returns authorized diagnostic contract 2.0, or null when it was not requested or authorized. */
  global RecordHealthCheckDiagnosticResponse diagnostics() {
    return diagnosticProjectionAuthorized && diagnosticItems != null
      ? RecordHealthCheckDiagnosticProjection.project(diagnosticItems)
      : null;
  }
}
