/** Enforces and enriches the result contract returned by custom Apex Checks. */
public with sharing class RecordHealthCheckApexResultFinalizer {
  private static final Integer REASON_CODE_MAX = 80;
  private static final Set<String> VALID_STATUSES = new Set<String>{
    'PASS',
    'FAIL',
    'SKIPPED',
    'UNABLE_TO_EVALUATE',
    'ERROR'
  };

  /** Converts a plugin outcome to the framework's internal result shape. */
  public static RecordHealthCheckInternalResult toInternalResult(
    RecordHealthCheckOutcome outcome,
    RecordHealthCheckInternalResult template
  ) {
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.checkDeveloperName = template.checkDeveloperName;
    result.label = template.label;
    result.priority = template.priority;
    result.evaluatorType = template.evaluatorType;
    result.status = outcome.status;
    result.reasonCode = outcome.reasonCode;
    result.reasonOrigin = 'PLUGIN';
    result.pluginInvoked = true;
    result.actualValue = renderValue(outcome.found);
    result.expectedValue = renderValue(outcome.expected);
    result.operandsRecorded = true;
    result.evaluationFound = outcome.found;
    result.evaluationExpected = outcome.expected;
    result.evaluationComparisonOperator = outcome.comparisonOperator;
    result.evidence = outcome.evidence?.snapshot();
    List<RecordHealthCheckOutcomeValidator.Violation> violations = RecordHealthCheckOutcomeValidator.validate(
      outcome
    );
    result.pluginValueViolation = violations.isEmpty() ? null : violations[0];
    return result;
  }

  /** Renders the stored representation of one plugin value. */
  public static String renderValue(RecordHealthCheckValue value) {
    if (value == null) {
      return null;
    }
    if (value.isList()) {
      List<String> members = value.storedValues;
      return members == null
        ? null
        : members.isEmpty() ? '0 items' : String.join(members, ', ');
    }
    return value.storedValue;
  }

  /**
   * Validates one plugin result and applies framework-owned display metadata.
   *
   * @param check Check metadata governing the plugin result.
   * @param record Record evaluated by the plugin.
   * @param fallbackResult Safe framework result used for contract violations.
   * @param apexResult Result returned by the plugin.
   * @param formulaEvaluator Merge-token resolver carrying the current run context.
   * @return The finalized plugin result or the supplied safe fallback.
   */
  public static RecordHealthCheckInternalResult finalizeResult(
    Record_Health_Check__mdt check,
    SObject record,
    RecordHealthCheckInternalResult fallbackResult,
    RecordHealthCheckInternalResult apexResult,
    RecordHealthCheckFormulaEvaluator formulaEvaluator
  ) {
    if (
      apexResult.pluginValueViolation?.reasonCode ==
      RecordHealthCheckReasonCodes.PLUGIN_STATUS_INVALID ||
      (!VALID_STATUSES.contains(apexResult.status) &&
      apexResult.pluginValueViolation == null)
    ) {
      return contractError(
        check,
        fallbackResult,
        RecordHealthCheckReasonCodes.PLUGIN_STATUS_INVALID,
        apexResult.reasonCode,
        '"' +
          check.ApexClass__c +
          '" returned an unsupported status: "' +
          apexResult.status +
          '". Expected one of PASS, FAIL, SKIPPED, UNABLE_TO_EVALUATE, ERROR.'
      );
    }
    if (
      apexResult.pluginValueViolation?.reasonCode ==
      RecordHealthCheckReasonCodes.PLUGIN_REASON_CODE_INVALID ||
      (apexResult.pluginValueViolation == null &&
      apexResult.reasonCode != null &&
      apexResult.reasonCode.length() > REASON_CODE_MAX)
    ) {
      return contractError(
        check,
        fallbackResult,
        RecordHealthCheckReasonCodes.PLUGIN_REASON_CODE_INVALID,
        apexResult.reasonCode,
        '"' +
          check.ApexClass__c +
          '" returned a reason code longer than ' +
          REASON_CODE_MAX +
          ' characters.'
      );
    }
    String displayContractError = applyTypedDisplayValues(apexResult);
    if (displayContractError != null) {
      return contractError(
        check,
        fallbackResult,
        RecordHealthCheckReasonCodes.PLUGIN_DISPLAY_INVALID,
        apexResult.reasonCode,
        '"' + check.ApexClass__c + '" ' + displayContractError
      );
    }
    if (
      (apexResult.status == 'PASS' || apexResult.status == 'FAIL') &&
      (apexResult.pluginValueViolation?.reasonCode ==
      RecordHealthCheckReasonCodes.PLUGIN_VALUES_MISSING ||
      (apexResult.pluginValueViolation == null &&
      (String.isBlank(apexResult.actualValue) ||
      String.isBlank(apexResult.expectedValue))))
    ) {
      return contractError(
        check,
        fallbackResult,
        RecordHealthCheckReasonCodes.PLUGIN_VALUES_MISSING,
        apexResult.reasonCode,
        apexResult.pluginValueViolation == null
          ? 'A ' +
            apexResult.status +
            ' outcome must include a nonblank ' +
            (String.isBlank(apexResult.actualValue) ? 'Found' : 'Expected') +
            ' value.'
          : apexResult.pluginValueViolation.message,
        apexResult.pluginValueViolation
      );
    }
    if (apexResult.status == 'FAIL') {
      apexResult.severity = check.FailureSeverity__c;
      if (String.isBlank(apexResult.message)) {
        String resolved = formulaEvaluator.resolveMergeFields(
          check.FailureMessage__c,
          record,
          check,
          apexResult,
          true
        );
        apexResult.message = String.isNotBlank(resolved)
          ? resolved
          : 'Check failed.';
      }
    } else if (apexResult.status == 'UNABLE_TO_EVALUATE') {
      apexResult.message = String.isNotBlank(check.UnableToEvaluateMessage__c)
        ? check.UnableToEvaluateMessage__c
        : 'This check could not be evaluated. Contact your administrator.';
    } else if (apexResult.status == 'SKIPPED') {
      apexResult.message = String.isNotBlank(
          check.ApplicabilityNotMetMessage__c
        )
        ? check.ApplicabilityNotMetMessage__c
        : 'This check does not apply to this record.';
    }
    apexResult.checkDeveloperName = check.DeveloperName;
    apexResult.label = check.CheckTitle__c;
    apexResult.priority = check.EvaluationOrder__c;
    apexResult.evaluatorType = 'APEX';
    return apexResult;
  }

  private static RecordHealthCheckInternalResult contractError(
    Record_Health_Check__mdt check,
    RecordHealthCheckInternalResult fallbackResult,
    String reasonCode,
    String priorReasonCode,
    String detailMessage
  ) {
    return contractError(
      check,
      fallbackResult,
      reasonCode,
      priorReasonCode,
      detailMessage,
      null
    );
  }

  private static RecordHealthCheckInternalResult contractError(
    Record_Health_Check__mdt check,
    RecordHealthCheckInternalResult fallbackResult,
    String reasonCode,
    String priorReasonCode,
    String detailMessage,
    RecordHealthCheckOutcomeValidator.Violation valueViolation
  ) {
    fallbackResult.status = 'ERROR';
    fallbackResult.reasonCode = reasonCode;
    fallbackResult.reasonOrigin = 'FRAMEWORK';
    fallbackResult.priorReasonCode = priorReasonCode;
    fallbackResult.pluginInvoked = true;
    fallbackResult.message = safeCannotEvaluateMessage(check);
    fallbackResult.detailMessage = detailMessage;
    fallbackResult.pluginValueViolation = valueViolation;
    return fallbackResult;
  }

  private static String applyTypedDisplayValues(
    RecordHealthCheckInternalResult apexResult
  ) {
    if (
      String.isBlank(apexResult.actualValue) &&
      apexResult.actualDisplayValue != null
    ) {
      if (!isValidPluginFormat(apexResult.actualDisplayFormat)) {
        return 'returned an invalid actualDisplayFormat. Use a canonical uppercase format API name.';
      }
      apexResult.actualValue = RecordHealthCheckDisplayFormat.render(
        apexResult.actualDisplayValue,
        apexResult.actualDisplayFormat,
        apexResult.actualCurrencyIsoCode
      );
    }
    if (
      String.isBlank(apexResult.expectedValue) &&
      apexResult.expectedDisplayValue != null
    ) {
      if (!isValidPluginFormat(apexResult.expectedDisplayFormat)) {
        return 'returned an invalid expectedDisplayFormat. Use a canonical uppercase format API name.';
      }
      apexResult.expectedValue = RecordHealthCheckDisplayFormat.render(
        apexResult.expectedDisplayValue,
        apexResult.expectedDisplayFormat,
        apexResult.expectedCurrencyIsoCode
      );
    }
    return null;
  }

  private static Boolean isValidPluginFormat(String formatName) {
    return String.isBlank(formatName) ||
      RecordHealthCheckDisplayFormat.isFormatApiName(formatName);
  }

  private static String safeCannotEvaluateMessage(
    Record_Health_Check__mdt check
  ) {
    return String.isNotBlank(check.UnableToEvaluateMessage__c)
      ? check.UnableToEvaluateMessage__c
      : 'This check could not be evaluated. Contact your administrator.';
  }
}
