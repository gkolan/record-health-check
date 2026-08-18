/** Builds diagnostic context consistently at evaluator boundaries. */
public with sharing class RecordHealthCheckDiagContextBuilder {
  /** Creates context for one Check failure. */
  public static RecordHealthCheckDiagnosticContext forCheck(
    Record_Health_Check__mdt check,
    String checkSetQualifiedApiName,
    String runId,
    String reasonCode,
    String phase
  ) {
    RecordHealthCheckDiagnosticContext context = new RecordHealthCheckDiagnosticContext();
    context.runId = runId;
    context.checkSetQualifiedApiName = checkSetQualifiedApiName;
    context.checkQualifiedApiName = check.QualifiedApiName;
    context.evaluatorType = check.EvaluationType__c;
    context.phase = phase;
    context.component = check.EvaluationType__c == 'APEX'
      ? check.ApexClass__c
      : check.QualifiedApiName;
    context.reasonCode = reasonCode;
    context.querySide = phase == 'SOURCE_QUERY'
      ? 'SOURCE'
      : phase == 'COMPARISON_QUERY' ? 'COMPARISON' : null;
    return context;
  }

  /** Returns the primary evaluator phase for one Check type. */
  public static String evaluatorPhase(Record_Health_Check__mdt check) {
    if (check.EvaluationType__c == 'APEX') {
      return 'PLUGIN_EXECUTE';
    }
    if (check.EvaluationType__c == 'FORMULA') {
      return 'PASS_CONDITION_FORMULA';
    }
    if (check.EvaluationType__c == 'COMPARE_TWO_QUERIES') {
      return 'COMPARISON_QUERY';
    }
    if (check.EvaluationType__c == 'QUERY') {
      return 'SOURCE_QUERY';
    }
    return 'EVALUATE';
  }
}
