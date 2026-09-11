/** Owns diagnostic-version validation and authorized response attachment. */
public with sharing class RecordHealthCheckDiagnosticRuntime {
  public static void validateVersion(String requestedVersion) {
    if (String.isNotBlank(requestedVersion) && requestedVersion != '2.0') {
      throw new RecordHealthCheckScopePipeline.ScopePipelineException(
        'UNSUPPORTED_DIAGNOSTIC_VERSION'
      );
    }
  }

  public static void attach(
    RecordHealthCheckResponse response,
    List<RecordHealthCheckResultItem> items,
    String requestedVersion,
    Boolean showDiagnostics
  ) {
    if (requestedVersion != '2.0') {
      return;
    }
    response.diagnosticProjectionAuthorized =
      showDiagnostics == true && RecordHealthCheckAccess.canViewDetails();
    response.diagnosticItems = response.diagnosticProjectionAuthorized
      ? items
      : null;
  }
}
