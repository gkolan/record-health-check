/** Finalizes legacy strings, structured display, and authorized evidence. */
public with sharing class RecordHealthCheckScopeDisplayFinalizer {
  private RecordHealthCheckFormulaEvaluator formulaEvaluator;

  public RecordHealthCheckScopeDisplayFinalizer(
    RecordHealthCheckFormulaEvaluator evaluator
  ) {
    formulaEvaluator = evaluator;
  }

  public void finalizeDisplay(
    Record_Health_Check__mdt check,
    SObject record,
    RecordHealthCheckInternalResult result,
    Boolean showDiagnostics,
    Boolean includeStructuredDisplay,
    Map<Id, SObject> recordsById
  ) {
    if (result == null) {
      return;
    }
    if (result.displayPlanningFailed == true) {
      if (result.message != null && result.message.contains('{!')) {
        result.message = 'This check could not be evaluated. Contact your administrator.';
      }
      attachDiagnostics(check, record, result, showDiagnostics);
      return;
    }
    String authoredMessage = result.message;
    resolveMessage(check, record, result);
    resolveFixAndAction(check, record, result);
    if (includeStructuredDisplay && check.EvaluationType__c == 'APEX') {
      RecordHealthCheckPresentationResolver.apply(check, result);
    }
    attachDiagnostics(check, record, result, showDiagnostics);
    if (includeStructuredDisplay) {
      new RecordHealthCheckStructuredDisplay(formulaEvaluator)
        .attach(check, record, result, authoredMessage, recordsById);
    }
  }

  private void resolveMessage(
    Record_Health_Check__mdt check,
    SObject record,
    RecordHealthCheckInternalResult result
  ) {
    if (record != null && String.isNotBlank(result.message)) {
      result.message = formulaEvaluator.resolveMergeFields(
        result.message,
        record,
        check,
        result,
        true
      );
    }
  }

  private void resolveFixAndAction(
    Record_Health_Check__mdt check,
    SObject record,
    RecordHealthCheckInternalResult result
  ) {
    if (result.status == RecordHealthCheckStatus.FAIL && record != null) {
      result.fixInstructions = String.isBlank(check.FixMessage__c)
        ? null
        : formulaEvaluator.resolveMergeFields(
            check.FixMessage__c,
            record,
            check,
            result,
            true
          );
      if (String.isNotBlank(check.ActionUrl__c)) {
        try {
          String url = RecordHealthCheckActionUrlPolicy.sanitize(
            formulaEvaluator.resolveUrlMergeFields(
              check.ActionUrl__c,
              record,
              check,
              result
            )
          );
          if (url != null) {
            result.actionUrl = url;
            result.actionLabel = String.isBlank(check.ActionLabel__c)
              ? 'Fix this'
              : formulaEvaluator.resolveMergeFields(
                  check.ActionLabel__c,
                  record,
                  check,
                  result,
                  true
                );
          }
        } catch (RecordHealthCheckTemplateService.TemplateException error) {
          result.detailMessage = error.getMessage();
        }
      }
    }
  }

  private void attachDiagnostics(
    Record_Health_Check__mdt check,
    SObject record,
    RecordHealthCheckInternalResult result,
    Boolean showDiagnostics
  ) {
    Boolean restricted = RecordHealthCheckReasonCodes.isDiagnosticsOnly(
      result.reasonCode
    );
    if (showDiagnostics && RecordHealthCheckAccess.canViewDetails()) {
      result.adminDetail = new RecordHealthCheckAdminDetail();
      result.adminDetail.containsRestrictedDetail = restricted;
      result.adminDetail.reasonCode = result.reasonCode;
      result.adminDetail.message = result.detailMessage;
      result.adminDetail.incident = result.diagnosticIncident;
      RecordHealthCheckDiagnosticTrace.populate(
        check,
        record,
        result,
        result.adminDetail
      );
    }
    if (restricted) {
      result.reasonCode = RecordHealthCheckReasonCodes.CANNOT_EVALUATE;
    }
  }
}
