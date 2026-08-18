/** Applies category-specific explanation and remediation to diagnostic incidents. */
public with sharing class RecordHealthCheckDiagnosticGuidance {
  public static void pluginRuntime(
    RecordHealthCheckDiagnosticIncident incident
  ) {
    setBase(incident, 'APEX_EXCEPTION', 'DEVELOPER', false);
    incident.summary = 'The custom Apex Check stopped with an unhandled exception.';
    incident.likelyCause = causeOr(
      incident,
      'The plugin failed during ' + incident.phase + '.'
    );
    addAction(
      incident,
      'REVIEW_APEX',
      'Correct the Apex Check',
      'Open the configured plugin at the reported location, correct the exception, and confirm the running principal can access every referenced object and field.',
      locationTarget(incident),
      'Rerun this Check with the same record and principal and confirm it returns a valid health outcome without a new incident.'
    );
    if (String.isNotBlank(incident.exceptionType)) {
      incident.evidence.add('Exception type: ' + incident.exceptionType);
    }
  }

  public static void pluginContract(
    RecordHealthCheckDiagnosticIncident incident,
    String summary,
    String instruction
  ) {
    setBase(incident, 'APEX_CONTRACT', 'DEVELOPER', false);
    incident.summary = summary;
    incident.likelyCause = causeOr(
      incident,
      'The plugin response did not satisfy the RecordHealthCheckPlugin contract.'
    );
    addAction(
      incident,
      'CORRECT_PLUGIN_CONTRACT',
      'Correct the plugin result',
      instruction,
      incident.component,
      'Run the plugin contract tests, then rerun the Check and confirm every requested record receives one valid outcome.'
    );
  }

  public static void pluginConfiguration(
    RecordHealthCheckDiagnosticIncident incident,
    String reason
  ) {
    setBase(
      incident,
      'APEX_CONFIGURATION',
      reason == RecordHealthCheckReasonCodes.PLUGIN_CONSTRUCTOR_FAILED
        ? 'DEVELOPER'
        : 'ADMINISTRATOR',
      false
    );
    incident.status = reason ==
      RecordHealthCheckReasonCodes.PLUGIN_CONSTRUCTOR_FAILED
      ? 'ERROR'
      : 'UNABLE_TO_EVALUATE';
    incident.severity = incident.status == 'ERROR' ? 'CRITICAL' : 'WARNING';
    incident.configurationField = reason == 'INVALID_APEX_PARAMETERS'
      ? 'ApexParametersJson__c'
      : 'ApexClass__c';
    incident.summary = pluginConfigurationSummary(reason);
    incident.likelyCause = causeOr(
      incident,
      'The Apex Check configuration does not resolve to a usable plugin.'
    );
    addAction(
      incident,
      reason == 'INVALID_APEX_PARAMETERS'
        ? 'EDIT_CONFIGURATION'
        : 'VERIFY_APEX_CLASS',
      'Correct the Apex Check configuration',
      reason == 'INVALID_APEX_PARAMETERS'
        ? 'Edit Apex Parameters JSON so it contains one valid JSON object accepted by the plugin.'
        : 'Verify the class API name, namespace, deployment, constructor, and RecordHealthCheckPlugin implementation.',
      incident.configurationField,
      'Validate the Check metadata, then rerun this Check with the production principal.'
    );
  }

  public static void pluginSideEffect(
    RecordHealthCheckDiagnosticIncident incident,
    RecordHealthCheckDiagnosticContext context
  ) {
    setBase(incident, 'APEX_CONTRACT', 'DEVELOPER', false);
    incident.summary = 'The custom Apex Check attempted a prohibited side effect.';
    incident.likelyCause = String.isBlank(context?.sideEffect)
      ? 'The plugin changed state or invoked an external effect.'
      : 'The plugin attempted ' + context.sideEffect + '.';
    incident.evidence.add(
      'Rollback protection: ' +
      (context?.sideEffectReversible == true
        ? 'the detected effect was rolled back'
        : 'the detected effect may not be reversible')
    );
    addAction(
      incident,
      'REMOVE_SIDE_EFFECT',
      'Make the Apex Check read-only',
      'Remove DML, callouts, email, event publication, and asynchronous dispatch from the plugin execution path.',
      incident.component,
      'Run the side-effect contract tests and rerun the Check without any resource-counter change.'
    );
  }

  public static void accessFailure(
    RecordHealthCheckDiagnosticIncident incident,
    String reason
  ) {
    setUnable(incident, 'ACCESS', 'SECURITY_ADMINISTRATOR');
    incident.summary = reason ==
      RecordHealthCheckReasonCodes.FIELD_NOT_ACCESSIBLE
      ? 'A field required by this Check is not readable by the running principal.'
      : 'The requested record is not available to the running principal.';
    incident.likelyCause = 'Object, field, sharing, restriction-rule, or scoping-rule access prevented a reliable evaluation.';
    addAction(
      incident,
      'REVIEW_ACCESS',
      'Review principal access',
      'Test as the production principal. Grant access only when business policy permits, or change the Check to use data that principal may read.',
      incident.configurationField,
      'Rerun with the same production principal and confirm the Check reaches a determinate result.'
    );
  }

  public static void configurationFailure(
    RecordHealthCheckDiagnosticIncident incident
  ) {
    setUnable(incident, 'CONFIGURATION', 'ADMINISTRATOR');
    incident.summary = 'Record Health Check configuration prevented evaluation.';
    incident.likelyCause = causeOr(
      incident,
      'One or more Check settings are invalid or unavailable.'
    );
    addAction(
      incident,
      'EDIT_CONFIGURATION',
      'Correct the Check configuration',
      'Review the identified Check and metadata field, correct the invalid value, and run metadata validation.',
      incident.configurationField,
      'Validate the metadata and rerun the affected Check.'
    );
  }

  public static void formulaFailure(
    RecordHealthCheckDiagnosticIncident incident
  ) {
    setUnable(incident, 'FORMULA', 'ADMINISTRATOR');
    incident.summary = 'A configured Formula could not be evaluated.';
    incident.likelyCause = causeOr(
      incident,
      'The Formula is invalid, returned the wrong type, or depends on unavailable data.'
    );
    addAction(
      incident,
      'EDIT_FORMULA',
      'Correct the Formula',
      'Review the Formula for this phase, its return type, relationship paths, and field access.',
      incident.configurationField,
      'Validate the Formula and rerun the Check with the same record.'
    );
  }

  public static void queryFailure(
    RecordHealthCheckDiagnosticIncident incident
  ) {
    setUnable(incident, 'QUERY', 'ADMINISTRATOR');
    incident.summary = 'A configured query could not be prepared or executed.';
    incident.likelyCause = causeOr(
      incident,
      'The query template, bind value, schema, access, or result shape is invalid.'
    );
    addAction(
      incident,
      'EDIT_QUERY',
      'Correct the query configuration',
      'Review the identified query side, object and field API names, bind tokens, user access, and expected result shape.',
      incident.configurationField,
      'Validate the query and rerun the Check as the same principal.'
    );
  }

  public static void limitFailure(
    RecordHealthCheckDiagnosticIncident incident
  ) {
    setBase(incident, 'LIMIT', 'ADMINISTRATOR', true);
    incident.summary = 'The evaluation reached or approached a protected Salesforce limit.';
    incident.likelyCause = causeOr(
      incident,
      'The selected scope or evaluator consumed more transaction resources than allowed.'
    );
    addAction(
      incident,
      'REDUCE_SCOPE',
      'Reduce evaluation work',
      'Narrow the query or reduce the number of Checks or records evaluated in one transaction.',
      incident.component,
      'Rerun with the reduced scope and confirm limit use remains below the protected ceiling.'
    );
  }

  public static void frameworkFailure(
    RecordHealthCheckDiagnosticIncident incident
  ) {
    setBase(incident, 'FRAMEWORK', 'DEVELOPER', true);
    incident.summary = 'Record Health Check encountered an unexpected framework error.';
    incident.likelyCause = causeOr(
      incident,
      'The failure is not yet classified. The phase and Diagnostic ID narrow the investigation.'
    );
    addAction(
      incident,
      'ESCALATE_DIAGNOSTIC',
      'Escalate with the Diagnostic ID',
      'Retry once. If the incident repeats, provide the safe diagnostic report to the Record Health Check maintainer.',
      incident.diagnosticId,
      'Rerun once and compare the new Diagnostic ID, phase, and fingerprint.'
    );
  }

  private static void setUnable(
    RecordHealthCheckDiagnosticIncident incident,
    String category,
    String owner
  ) {
    setBase(incident, category, owner, false);
    incident.status = 'UNABLE_TO_EVALUATE';
    incident.severity = 'WARNING';
  }

  private static void setBase(
    RecordHealthCheckDiagnosticIncident incident,
    String category,
    String owner,
    Boolean retryable
  ) {
    incident.category = category;
    incident.owner = owner;
    incident.retryable = retryable;
  }

  private static void addAction(
    RecordHealthCheckDiagnosticIncident incident,
    String kind,
    String label,
    String instruction,
    String target,
    String verification
  ) {
    RecordHealthCheckDiagnosticAction action = new RecordHealthCheckDiagnosticAction();
    action.kind = kind;
    action.label = label;
    action.instruction = instruction;
    action.target = target;
    incident.remediationActions.add(action);
    incident.verificationSteps.add(verification);
  }

  private static String pluginConfigurationSummary(String reason) {
    if (reason == 'INVALID_APEX_PARAMETERS') {
      return 'The custom Apex Check parameters are not a valid JSON object.';
    }
    if (reason == RecordHealthCheckReasonCodes.PLUGIN_INTERFACE_INVALID) {
      return 'The configured Apex class does not implement RecordHealthCheckPlugin.';
    }
    if (reason == RecordHealthCheckReasonCodes.PLUGIN_CONSTRUCTOR_FAILED) {
      return 'The configured Apex class failed during construction.';
    }
    return 'The configured Apex class could not be found.';
  }

  private static String causeOr(
    RecordHealthCheckDiagnosticIncident incident,
    String fallback
  ) {
    return String.isBlank(incident.exceptionMessage)
      ? fallback
      : incident.exceptionMessage;
  }

  private static String locationTarget(
    RecordHealthCheckDiagnosticIncident incident
  ) {
    if (String.isBlank(incident.topFrameClass)) {
      return incident.component;
    }
    return incident.topFrameClass +
      (String.isBlank(incident.topFrameMethod)
        ? ''
        : '.' + incident.topFrameMethod) +
      (incident.topFrameLine == null
        ? ''
        : ', line ' + String.valueOf(incident.topFrameLine));
  }
}
