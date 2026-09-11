/** Projects server-only incidents and traces into bounded diagnostic contract 2.0. */
public with sharing class RecordHealthCheckDiagnosticProjection {
  private static final Integer BYTE_BUDGET = 128 * 1024;

  public static RecordHealthCheckDiagnosticResponse project(
    List<RecordHealthCheckResultItem> items
  ) {
    RecordHealthCheckDiagnosticResponse response = new RecordHealthCheckDiagnosticResponse();
    Integer usedBytes = Blob.valueOf(JSON.serialize(response)).size();
    for (RecordHealthCheckResultItem item : items) {
      RecordHealthCheckInternalResult source = item.diagnosticSource;
      if (source == null) {
        continue;
      }
      RecordHealthCheckDiagnosticEnvelope candidate = envelope(item, source);
      Integer candidateBytes =
        Blob.valueOf(JSON.serialize(candidate)).size() + 1;
      if (usedBytes + candidateBytes <= BYTE_BUDGET) {
        response.diagnostics.add(candidate);
        usedBytes += candidateBytes;
      } else {
        response.omittedDiagnosticCount++;
      }
    }
    while (
      !response.diagnostics.isEmpty() &&
      Blob.valueOf(JSON.serialize(response)).size() > BYTE_BUDGET
    ) {
      response.diagnostics.remove(response.diagnostics.size() - 1);
      response.omittedDiagnosticCount++;
    }
    return response;
  }

  private static RecordHealthCheckDiagnosticEnvelope envelope(
    RecordHealthCheckResultItem item,
    RecordHealthCheckInternalResult source
  ) {
    RecordHealthCheckDiagnosticIncident incident = source.diagnosticIncident;
    RecordHealthCheckDiagnosticEnvelope result = new RecordHealthCheckDiagnosticEnvelope();
    result.contractVersion = '2.0';
    result.runId = source.runId;
    result.checkIdentity = item.evaluation.checkQualifiedApiName;
    result.recordId = item.evaluation.recordId;
    result.phase = source.executionTrace?.activePhase() ?? incident?.phase;
    result.pluginInvoked = source.pluginInvoked ?? incident?.pluginInvoked;
    result.reasonCode = source.reasonCode;
    result.reasonOrigin = source.reasonOrigin ?? incident?.reasonOrigin;
    result.configurationField = incident?.configurationField;
    result.offendingToken = incident?.offendingToken;
    result.tokenStart = incident?.tokenStart;
    result.tokenEnd = incident?.tokenEnd;
    result.baseObject = incident?.baseObject;
    result.dependencyPath = incident?.dependencyPath;
    result.exceptionDetail = exceptionProjection(incident);
    if (source.executionTrace != null) {
      for (
        RecordHealthCheckExecutionTrace.Entry entry : source.executionTrace.entries()
      ) {
        RecordHealthCheckDiagnosticTraceEntry projected = new RecordHealthCheckDiagnosticTraceEntry();
        projected.sequence = entry.sequence;
        projected.stage = entry.stage;
        projected.durationMs = entry.durationMs;
        result.trace.add(projected);
      }
      result.traceTruncated = source.executionTrace.isTruncated();
      result.terminalFailure = source.executionTrace.terminalFailure();
    }
    return result;
  }

  private static RecordHealthCheckDiagnosticErrorDetail exceptionProjection(
    RecordHealthCheckDiagnosticIncident incident
  ) {
    if (String.isBlank(incident?.exceptionType)) {
      return null;
    }
    RecordHealthCheckDiagnosticErrorDetail result = new RecordHealthCheckDiagnosticErrorDetail();
    result.type = incident.exceptionType;
    result.message = incident.exceptionMessage;
    result.topFrameClass = incident.topFrameClass;
    result.topFrameMethod = incident.topFrameMethod;
    result.topFrameLine = incident.topFrameLine;
    result.pluginClass = incident.apexClass;
    result.operation = incident.phase;
    result.affectedRecordCount = incident.affectedRecordCount;
    return result;
  }
}
