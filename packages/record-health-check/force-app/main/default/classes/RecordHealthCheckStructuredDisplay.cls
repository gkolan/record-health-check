/** Builds structured display envelopes from authored templates or legacy plain strings. */
public class RecordHealthCheckStructuredDisplay {
  private RecordHealthCheckFormulaEvaluator evaluator;

  public RecordHealthCheckStructuredDisplay(
    RecordHealthCheckFormulaEvaluator evaluator
  ) {
    this.evaluator = evaluator;
  }

  public void attach(
    Record_Health_Check__mdt check,
    SObject record,
    RecordHealthCheckInternalResult result,
    String authoredMessage
  ) {
    attach(
      check,
      record,
      result,
      authoredMessage,
      record == null ||
        record.Id == null
        ? new Map<Id, SObject>()
        : new Map<Id, SObject>{ record.Id => record }
    );
  }

  public void attach(
    Record_Health_Check__mdt check,
    SObject record,
    RecordHealthCheckInternalResult result,
    String authoredMessage,
    Map<Id, SObject> recordsById
  ) {
    RecordHealthCheckDisplayContent content = result.displayContent == null
      ? new RecordHealthCheckDisplayContent()
      : result.displayContent;
    if (content.message == null) {
      content.message = nodes(
        authoredMessage,
        messageSurface(result.status),
        result.message,
        record,
        check,
        result
      );
    }
    if (content.fix == null) {
      content.fix = result.status == RecordHealthCheckStatus.FAIL
        ? nodes(
            check?.FixMessage__c,
            RecordHealthCheckTokenSurfaces.FIX_MESSAGE,
            result.fixInstructions,
            record,
            check,
            result
          )
        : null;
    }
    attachComparison(check, record, result, content);
    result.displayContent = content;
    Id recordId = record == null ? null : (Id) record.get('Id');
    result.evidenceEnvelope = RecordHealthCheckEvidenceProjection.project(
      result.evidence,
      result.runId,
      check.QualifiedApiName,
      recordId,
      recordsById
    );
  }

  private void attachComparison(
    Record_Health_Check__mdt check,
    SObject record,
    RecordHealthCheckInternalResult result,
    RecordHealthCheckDisplayContent content
  ) {
    if (content.found == null) {
      content.found = nodes(
        check?.EvaluationType__c == 'APEX' ? null : check?.DisplayFoundText__c,
        RecordHealthCheckTokenSurfaces.DISPLAY_FOUND,
        result.actualValue,
        record,
        check,
        result
      );
    }
    if (content.expected == null) {
      content.expected = nodes(
        check?.EvaluationType__c == 'APEX'
          ? null
          : check?.DisplayExpectedText__c,
        RecordHealthCheckTokenSurfaces.DISPLAY_EXPECTED,
        result.expectedValue,
        record,
        check,
        result
      );
    }
  }

  private List<RecordHealthCheckDisplayNode> nodes(
    String authored,
    String surface,
    String plainValue,
    SObject record,
    Record_Health_Check__mdt check,
    RecordHealthCheckInternalResult result
  ) {
    if (authored != null && authored.contains('{!link')) {
      List<RecordHealthCheckDisplayNode> composed = evaluator.resolveDisplayNodes(
        authored,
        surface,
        record,
        check,
        result
      );
      if (composed != null) {
        return composed;
      }
    }
    return plainValue == null
      ? null
      : new RecordHealthCheckDisplayText().text(plainValue).copyNodes();
  }

  private static String messageSurface(String status) {
    if (status == RecordHealthCheckStatus.FAIL) {
      return RecordHealthCheckTokenSurfaces.FAILURE_MESSAGE;
    }
    return status == RecordHealthCheckStatus.SKIPPED
      ? RecordHealthCheckTokenSurfaces.NOT_APPLICABLE_MESSAGE
      : RecordHealthCheckTokenSurfaces.UNABLE_MESSAGE;
  }
}
