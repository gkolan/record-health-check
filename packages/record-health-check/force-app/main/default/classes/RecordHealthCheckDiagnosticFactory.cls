/** Classifies technical failures into actionable, disclosure-safe incidents. */
public with sharing class RecordHealthCheckDiagnosticFactory {
  private static final Integer MESSAGE_MAX = 1000;

  /** Creates a classified incident from a caught exception and its context. */
  public static RecordHealthCheckDiagnosticIncident fromException(
    Exception error,
    RecordHealthCheckDiagnosticContext context
  ) {
    RecordHealthCheckDiagnosticIncident incident = baseIncident(context);
    incident.exceptionType = error == null ? null : error.getTypeName();
    incident.exceptionMessage = error == null
      ? null
      : sanitizeMessage(error.getMessage());
    incident.topFrameLine = error == null ? null : error.getLineNumber();
    String stackTrace = error == null ? null : error.getStackTraceString();
    if (error instanceof RecordHealthCheckPluginDispatch.ContractException) {
      RecordHealthCheckPluginDispatch.ContractException contractError = (RecordHealthCheckPluginDispatch.ContractException) error;
      incident.exceptionType = String.isBlank(
          contractError.originalExceptionType
        )
        ? incident.exceptionType
        : contractError.originalExceptionType;
      incident.exceptionMessage = String.isBlank(
          contractError.originalExceptionMessage
        )
        ? incident.exceptionMessage
        : sanitizeMessage(contractError.originalExceptionMessage);
      incident.topFrameLine = contractError.originalLineNumber ??
        incident.topFrameLine;
      stackTrace = String.isBlank(contractError.originalStackTrace)
        ? stackTrace
        : contractError.originalStackTrace;
    }
    incident.apexClass = isPluginPhase(context?.phase)
      ? context?.component
      : null;
    populateTopFrame(incident, stackTrace);
    classify(incident, context);
    finish(incident);
    return incident;
  }

  /** Creates a classified incident from a stable reason and context. */
  public static RecordHealthCheckDiagnosticIncident fromReason(
    RecordHealthCheckDiagnosticContext context
  ) {
    RecordHealthCheckDiagnosticIncident incident = baseIncident(context);
    classify(incident, context);
    finish(incident);
    return incident;
  }

  private static RecordHealthCheckDiagnosticIncident baseIncident(
    RecordHealthCheckDiagnosticContext context
  ) {
    RecordHealthCheckDiagnosticIncident incident = new RecordHealthCheckDiagnosticIncident();
    incident.diagnosticId =
      'RHC-' +
      String.valueOf(Datetime.now().getTime()) +
      '-' +
      String.valueOf(Math.abs(Crypto.getRandomInteger())).left(8);
    incident.runId = context?.runId;
    incident.occurredAt = System.now();
    incident.status = String.isBlank(context?.status)
      ? RecordHealthCheckStatus.ERROR
      : context.status;
    incident.severity = String.isBlank(context?.severity)
      ? 'CRITICAL'
      : context.severity;
    incident.phase = String.isBlank(context?.phase) ? 'UNKNOWN' : context.phase;
    incident.component = context?.component;
    incident.evaluatorType = context?.evaluatorType;
    incident.checkSetQualifiedApiName = context?.checkSetQualifiedApiName;
    incident.checkQualifiedApiName = context?.checkQualifiedApiName;
    incident.configurationField = context?.configurationField;
    incident.querySide = context?.querySide;
    incident.reasonCode = String.isBlank(context?.reasonCode)
      ? RecordHealthCheckReasonCodes.FRAMEWORK_UNEXPECTED
      : context.reasonCode;
    incident.exceptionMessage = sanitizeMessage(context?.technicalMessage);
    incident.affectedRecordCount = context?.affectedRecordCount;
    incident.scopeImpact = context?.scopeImpact;
    return incident;
  }

  private static void classify(
    RecordHealthCheckDiagnosticIncident incident,
    RecordHealthCheckDiagnosticContext context
  ) {
    String reason = incident.reasonCode;
    if (reason == RecordHealthCheckReasonCodes.PLUGIN_SIDE_EFFECT_DETECTED) {
      RecordHealthCheckDiagnosticGuidance.pluginSideEffect(incident, context);
    } else if (reason == RecordHealthCheckReasonCodes.PLUGIN_RESULT_MISSING) {
      RecordHealthCheckDiagnosticGuidance.pluginContract(
        incident,
        'The custom Apex Check did not return a result for every requested record.',
        'Return one outcome keyed by every requested record ID.'
      );
    } else if (
      reason == RecordHealthCheckReasonCodes.PLUGIN_RESULT_UNKNOWN_KEY
    ) {
      RecordHealthCheckDiagnosticGuidance.pluginContract(
        incident,
        'The custom Apex Check returned a result outside its requested scope.',
        'Return outcomes only for IDs supplied in the evaluation scope.'
      );
    } else if (isPluginResultReason(reason)) {
      pluginResultGuidance(incident, reason);
    } else if (isPluginConfigurationReason(reason)) {
      RecordHealthCheckDiagnosticGuidance.pluginConfiguration(incident, reason);
    } else if (
      reason == RecordHealthCheckReasonCodes.PLUGIN_THREW ||
      isPluginPhase(incident.phase)
    ) {
      RecordHealthCheckDiagnosticGuidance.pluginRuntime(incident);
    } else if (isAccessReason(reason)) {
      RecordHealthCheckDiagnosticGuidance.accessFailure(incident, reason);
    } else if (isConfigurationPhase(incident.phase)) {
      RecordHealthCheckDiagnosticGuidance.configurationFailure(incident);
    } else if (isFormulaPhase(incident.phase)) {
      RecordHealthCheckDiagnosticGuidance.formulaFailure(incident);
    } else if (
      isQueryPhase(incident.phase) ||
      incident.exceptionType == 'System.QueryException'
    ) {
      RecordHealthCheckDiagnosticGuidance.queryFailure(incident);
    } else if (
      incident.exceptionType == 'System.LimitException' ||
      incident.phase == 'LIMIT'
    ) {
      RecordHealthCheckDiagnosticGuidance.limitFailure(incident);
    } else {
      RecordHealthCheckDiagnosticGuidance.frameworkFailure(incident);
    }
  }

  private static void pluginResultGuidance(
    RecordHealthCheckDiagnosticIncident incident,
    String reason
  ) {
    String summary = reason ==
      RecordHealthCheckReasonCodes.PLUGIN_STATUS_INVALID
      ? 'The custom Apex Check returned an unsupported status.'
      : reason == RecordHealthCheckReasonCodes.PLUGIN_DISPLAY_INVALID
          ? 'The custom Apex Check returned an invalid display value or format.'
          : 'The custom Apex Check omitted required Found or Expected values.';
    String instruction = reason ==
      RecordHealthCheckReasonCodes.PLUGIN_STATUS_INVALID
      ? 'Return PASS, FAIL, SKIPPED, UNABLE_TO_EVALUATE, or ERROR.'
      : reason == RecordHealthCheckReasonCodes.PLUGIN_DISPLAY_INVALID
          ? 'Return a supported typed value and canonical uppercase display format.'
          : 'Return both Found and Expected for every PASS or FAIL outcome.';
    RecordHealthCheckDiagnosticGuidance.pluginContract(
      incident,
      summary,
      instruction
    );
  }

  private static void finish(RecordHealthCheckDiagnosticIncident incident) {
    String source = String.join(
      new List<String>{
        incident.category,
        incident.phase,
        incident.reasonCode,
        incident.component,
        incident.exceptionType,
        incident.topFrameClass,
        incident.topFrameMethod,
        String.valueOf(incident.topFrameLine)
      },
      '|'
    );
    incident.fingerprint = EncodingUtil.convertToHex(
        Crypto.generateDigest('SHA-256', Blob.valueOf(source))
      )
      .left(24);
    incident.supportReference = incident.diagnosticId;
    if (String.isNotBlank(incident.component)) {
      incident.evidence.add('Component: ' + incident.component);
    }
    incident.evidence.add('Phase: ' + incident.phase);
  }

  private static void populateTopFrame(
    RecordHealthCheckDiagnosticIncident incident,
    String stackTrace
  ) {
    if (String.isBlank(stackTrace)) {
      return;
    }
    String location = stackTrace.substringBefore('\n')
      .trim()
      .substringBefore(': line');
    if (location.startsWith('Class.')) {
      location = location.substring(6);
    }
    Integer split = location.lastIndexOf('.');
    if (split > 0) {
      incident.topFrameClass = location.substring(0, split);
      incident.topFrameMethod = location.substring(split + 1);
    } else {
      incident.topFrameClass = location;
    }
  }

  private static String sanitizeMessage(String message) {
    if (String.isBlank(message)) {
      return null;
    }
    String value = message.replaceAll('[\\r\\n\\t]', ' ').trim();
    return value.length() <= MESSAGE_MAX
      ? value
      : value.substring(0, MESSAGE_MAX);
  }

  private static Boolean isPluginResultReason(String reason) {
    return reason == RecordHealthCheckReasonCodes.PLUGIN_STATUS_INVALID ||
      reason == RecordHealthCheckReasonCodes.PLUGIN_VALUES_MISSING ||
      reason == RecordHealthCheckReasonCodes.PLUGIN_DISPLAY_INVALID;
  }

  private static Boolean isPluginConfigurationReason(String reason) {
    return reason == 'APEX_CLASS_NOT_FOUND' ||
      reason == RecordHealthCheckReasonCodes.PLUGIN_CONSTRUCTOR_FAILED ||
      reason == RecordHealthCheckReasonCodes.PLUGIN_INTERFACE_INVALID ||
      reason == 'INVALID_APEX_PARAMETERS';
  }

  private static Boolean isPluginPhase(String phase) {
    return String.isNotBlank(phase) && phase.startsWith('PLUGIN_');
  }

  private static Boolean isConfigurationPhase(String phase) {
    return phase == 'CONFIG_LOAD' ||
      phase == 'CONFIG_VALIDATE' ||
      phase == 'PLANNING';
  }

  private static Boolean isFormulaPhase(String phase) {
    return String.isNotBlank(phase) && phase.contains('FORMULA');
  }

  private static Boolean isQueryPhase(String phase) {
    return phase == 'SOURCE_QUERY' ||
      phase == 'COMPARISON_QUERY' ||
      phase == 'APPLICABILITY_QUERY';
  }

  private static Boolean isAccessReason(String reason) {
    return reason == RecordHealthCheckReasonCodes.FIELD_NOT_ACCESSIBLE ||
      reason == RecordHealthCheckReasonCodes.RECORD_NOT_ACCESSIBLE ||
      reason == 'RECORD_NOT_VISIBLE';
  }
}
