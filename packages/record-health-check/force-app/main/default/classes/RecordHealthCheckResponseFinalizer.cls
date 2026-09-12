/** Publishes the complete result set and attaches optional diagnostics. */
public with sharing class RecordHealthCheckResponseFinalizer {
  public static void finish(
    RecordHealthCheckResponse response,
    List<RecordHealthCheckResultItem> allItems,
    RecordHealthCheckOptions options,
    RecordHealthCheckScopePipeline.SelectionContext context
  ) {
    new RecordHealthCheckResponseDisplayBudget().apply(response, allItems);
    RecordHealthCheckResponse publication = new RecordHealthCheckResponse();
    publication.runId = response.runId;
    publication.recordIds.addAll(response.recordIds);
    publication.checkQualifiedApiNames.addAll(response.checkQualifiedApiNames);
    publication.results.addAll(allItems);
    publication.summary = response.summary;
    RecordHealthCheckLifecyclePublisher.publishResponse(
      publication,
      options.eventPublication,
      context.checkSetQualifiedApiName,
      String.valueOf(options.executionOrigin)
    );
    RecordHealthCheckDiagnosticRuntime.attach(
      response,
      allItems,
      options.diagnosticContractVersion,
      context.showDiagnostics
    );
  }
}
