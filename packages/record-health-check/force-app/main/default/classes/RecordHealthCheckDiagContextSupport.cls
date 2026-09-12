/** Builds diagnostic context without reducing structured planning findings. */
public class RecordHealthCheckDiagContextSupport {
  public static RecordHealthCheckDiagnosticContext forResult(
    Record_Health_Check__mdt check,
    String checkSetQualifiedApiName,
    String runId,
    String reasonCode
  ) {
    return forResult(check, checkSetQualifiedApiName, runId, reasonCode, null);
  }

  public static RecordHealthCheckDiagnosticContext forResult(
    Record_Health_Check__mdt check,
    String checkSetQualifiedApiName,
    String runId,
    String reasonCode,
    RecordHealthCheckFormulaPlanService.Finding primaryFormulaFinding
  ) {
    String phase = RecordHealthCheckDiagContextBuilder.evaluatorPhase(check);
    Boolean pluginInvoked;
    if (isPlanningReason(reasonCode)) {
      phase = 'FIELD_PLAN';
      pluginInvoked = false;
    } else if (check.EvaluationType__c == 'APEX') {
      if (isPluginConfigurationReason(reasonCode)) {
        phase = reasonCode ==
          RecordHealthCheckReasonCodes.PLUGIN_CONSTRUCTOR_FAILED
          ? 'PLUGIN_CONSTRUCT'
          : 'PLUGIN_RESOLVE';
        pluginInvoked = false;
      } else {
        pluginInvoked = true;
      }
    }
    RecordHealthCheckDiagnosticContext context = RecordHealthCheckDiagContextBuilder.forCheck(
      check,
      checkSetQualifiedApiName,
      runId,
      reasonCode,
      phase
    );
    context.pluginInvoked = pluginInvoked;
    context.reasonOrigin = 'FRAMEWORK';
    if (primaryFormulaFinding != null) {
      context.configurationField = primaryFormulaFinding.configurationField;
      context.offendingToken = boundedToken(primaryFormulaFinding);
      context.tokenStart = primaryFormulaFinding.startOffset;
      context.tokenEnd = primaryFormulaFinding.endOffset;
      context.baseObject = primaryFormulaFinding.baseObject;
      context.dependencyPath = primaryFormulaFinding.code ==
        RecordHealthCheckReasonCodes.FIELD_NOT_ACCESSIBLE
        ? null
        : primaryFormulaFinding.dependencyPath;
    }
    return context;
  }

  public static RecordHealthCheckFormulaPlanService.Finding primaryFormulaFinding(
    List<RecordHealthCheckFormulaPlanService.Finding> findings
  ) {
    if (findings == null || findings.isEmpty()) {
      return null;
    }
    List<RecordHealthCheckFormulaPlanService.Finding> ordered = new List<RecordHealthCheckFormulaPlanService.Finding>();
    ordered.addAll(findings);
    ordered.sort(new FormulaFindingComparator());
    return ordered[0];
  }

  public static String primaryUnresolvedReasonCode(
    Map<String, String> reasonCodesByField
  ) {
    List<String> paths = new List<String>(reasonCodesByField.keySet());
    paths.sort();
    return reasonCodesByField.get(paths[0]);
  }

  private static String boundedToken(
    RecordHealthCheckFormulaPlanService.Finding finding
  ) {
    if (finding.code == RecordHealthCheckReasonCodes.FIELD_NOT_ACCESSIBLE) {
      return '[restricted field]';
    }
    String token = finding.offendingToken;
    return token == null ||
      token.length() <= 128
      ? token
      : token.substring(0, 128);
  }

  private static Boolean isPlanningReason(String reasonCode) {
    return reasonCode == RecordHealthCheckReasonCodes.FIELD_NOT_ACCESSIBLE ||
      reasonCode == RecordHealthCheckReasonCodes.FIELD_NOT_RESOLVED ||
      reasonCode == RecordHealthCheckReasonCodes.RELATIONSHIP_NOT_RESOLVED ||
      reasonCode ==
      RecordHealthCheckReasonCodes.FORMULA_DEPENDENCY_DEPTH_EXCEEDED;
  }

  private static Boolean isPluginConfigurationReason(String reasonCode) {
    return reasonCode == RecordHealthCheckReasonCodes.APEX_CLASS_INVALID ||
      reasonCode == RecordHealthCheckReasonCodes.APEX_CLASS_NOT_FOUND ||
      reasonCode == RecordHealthCheckReasonCodes.APEX_CLASS_LOAD_FAILED ||
      reasonCode == RecordHealthCheckReasonCodes.PLUGIN_CONSTRUCTOR_FAILED ||
      reasonCode == RecordHealthCheckReasonCodes.PLUGIN_DEFINITION_INVALID ||
      reasonCode == RecordHealthCheckReasonCodes.PLUGIN_INTERFACE_INVALID ||
      reasonCode == RecordHealthCheckReasonCodes.INVALID_APEX_PARAMETERS;
  }

  private class FormulaFindingComparator implements Comparator<RecordHealthCheckFormulaPlanService.Finding> {
    public Integer compare(
      RecordHealthCheckFormulaPlanService.Finding left,
      RecordHealthCheckFormulaPlanService.Finding right
    ) {
      Integer fieldOrder = String.valueOf(left.configurationField)
        .compareTo(String.valueOf(right.configurationField));
      if (fieldOrder != 0) {
        return fieldOrder;
      }
      Integer startOrder = (left.startOffset ?? -1) - (right.startOffset ?? -1);
      if (startOrder != 0) {
        return startOrder;
      }
      Integer tokenOrder = String.valueOf(left.offendingToken)
        .compareTo(String.valueOf(right.offendingToken));
      return tokenOrder != 0
        ? tokenOrder
        : String.valueOf(left.code).compareTo(String.valueOf(right.code));
    }
  }
}
