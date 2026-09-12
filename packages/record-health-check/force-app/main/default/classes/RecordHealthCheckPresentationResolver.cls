/** Resolves optional Apex presentation over configured display fallbacks. */
public with sharing class RecordHealthCheckPresentationResolver {
  private static final Integer EXPECTED_LABEL_MAX = 255;

  /**
   * Applies a detached optional override without changing machine evaluation facts.
   *
   * @param check Administrator-owned Check configuration.
   * @param result Validated internal evaluation and display state.
   */
  public static void apply(
    Record_Health_Check__mdt check,
    RecordHealthCheckInternalResult result
  ) {
    if (check == null || result == null) {
      return;
    }
    RecordHealthCheckDisplayOverride presentation = result.presentationOverride;
    if (presentation?.invalidFields != null) {
      for (String fieldName : presentation.invalidFields) {
        recordInvalid(result, fieldName);
      }
    }
    applyMessageAndFix(result, presentation);
    applyAction(result, presentation);
    applyExpectedLabel(result, presentation);
    applyValueFormat(check, result, presentation, true);
    applyValueFormat(check, result, presentation, false);
  }

  private static void applyMessageAndFix(
    RecordHealthCheckInternalResult result,
    RecordHealthCheckDisplayOverride presentation
  ) {
    if (presentation?.message != null) {
      rememberFallback(result, 'message', result.message);
      ensureContent(result).message = presentation.message.copyNodes();
      result.message = RecordHealthCheckDisplayComposer.plain(
        result.displayContent.message
      );
    }
    if (
      result.status == RecordHealthCheckStatus.FAIL &&
      presentation?.fix != null
    ) {
      rememberFallback(result, 'fix', result.fixInstructions);
      ensureContent(result).fix = presentation.fix.copyNodes();
      result.fixInstructions = RecordHealthCheckDisplayComposer.plain(
        result.displayContent.fix
      );
    }
  }

  private static void rememberFallback(
    RecordHealthCheckInternalResult result,
    String fieldName,
    String value
  ) {
    if (result.presentationFallbacks == null) {
      result.presentationFallbacks = new Map<String, String>();
    }
    result.presentationFallbacks.put(fieldName, value);
  }

  private static void applyAction(
    RecordHealthCheckInternalResult result,
    RecordHealthCheckDisplayOverride presentation
  ) {
    if (
      result.status != RecordHealthCheckStatus.FAIL ||
      presentation?.action == null
    ) {
      return;
    }
    String label = presentation.action.label?.trim();
    String destination = RecordHealthCheckActionUrlPolicy.sanitize(
      presentation.action.destination
    );
    if (
      String.isBlank(label) ||
      label.length() > EXPECTED_LABEL_MAX ||
      destination == null
    ) {
      recordInvalid(result, 'action');
      return;
    }
    result.actionLabel = label;
    result.actionUrl = destination;
  }

  private static void applyExpectedLabel(
    RecordHealthCheckInternalResult result,
    RecordHealthCheckDisplayOverride presentation
  ) {
    if (String.isBlank(presentation?.expectedLabel)) {
      return;
    }
    String label = presentation.expectedLabel.trim();
    if (label.length() > EXPECTED_LABEL_MAX) {
      recordInvalid(result, 'expectedLabel');
      return;
    }
    result.expectedValueLabel = label;
  }

  private static void applyValueFormat(
    Record_Health_Check__mdt check,
    RecordHealthCheckInternalResult result,
    RecordHealthCheckDisplayOverride presentation,
    Boolean foundSide
  ) {
    if (
      foundSide ? presentation?.found != null : presentation?.expected != null
    ) {
      return;
    }
    String overrideFormat = foundSide
      ? presentation?.foundFormat
      : presentation?.expectedFormat;
    String overrideIsoCode = foundSide
      ? presentation?.foundCurrencyIsoCode
      : presentation?.expectedCurrencyIsoCode;
    String formatName = String.isBlank(overrideFormat)
      ? check.DisplayValueFormat__c
      : overrideFormat;
    if (String.isBlank(formatName)) {
      formatName = RecordHealthCheckDisplayFormat.FORMAT_AUTO;
    }
    if (!RecordHealthCheckDisplayFormat.isFormatApiName(formatName)) {
      recordInvalid(result, foundSide ? 'foundFormat' : 'expectedFormat');
      formatName = validConfiguredFormat(check.DisplayValueFormat__c);
      overrideIsoCode = null;
    }
    applyResolvedFormat(check, result, formatName, overrideIsoCode, foundSide);
  }

  private static void applyResolvedFormat(
    Record_Health_Check__mdt check,
    RecordHealthCheckInternalResult result,
    String formatName,
    String overrideIsoCode,
    Boolean foundSide
  ) {
    String isoCode = resolveIsoCode(
      result,
      formatName,
      overrideIsoCode,
      foundSide ? null : check.ExpectedCurrencyIsoCode__c,
      foundSide
    );
    RecordHealthCheckValue value = foundSide
      ? result.evaluationFound
      : result.evaluationExpected;
    if (value == null) {
      return;
    }
    String rendered = RecordHealthCheckDisplayFormat.render(
      displayValue(value),
      formatName,
      isoCode
    );
    if (foundSide) {
      result.actualValue = rendered;
      result.actualDisplayFormat = formatName;
      result.actualCurrencyIsoCode = isoCode;
    } else {
      result.expectedValue = rendered;
      result.expectedDisplayFormat = formatName;
      result.expectedCurrencyIsoCode = isoCode;
    }
  }

  private static String validConfiguredFormat(String value) {
    return RecordHealthCheckDisplayFormat.isFormatApiName(value)
      ? value
      : RecordHealthCheckDisplayFormat.FORMAT_AUTO;
  }

  private static String resolveIsoCode(
    RecordHealthCheckInternalResult result,
    String formatName,
    String overrideIsoCode,
    String configuredIsoCode,
    Boolean foundSide
  ) {
    if (formatName != RecordHealthCheckDisplayFormat.FORMAT_CURRENCY) {
      if (!String.isBlank(overrideIsoCode)) {
        recordInvalid(
          result,
          foundSide ? 'foundCurrencyIsoCode' : 'expectedCurrencyIsoCode'
        );
      }
      return null;
    }

    if (!String.isBlank(overrideIsoCode)) {
      String overrideCandidate = overrideIsoCode.trim().toUpperCase();
      if (Pattern.matches('[A-Z]{3}', overrideCandidate)) {
        return overrideCandidate;
      }
      recordInvalid(
        result,
        foundSide ? 'foundCurrencyIsoCode' : 'expectedCurrencyIsoCode'
      );
    }

    if (String.isBlank(configuredIsoCode)) {
      return null;
    }
    String configuredCandidate = configuredIsoCode.trim().toUpperCase();
    return Pattern.matches('[A-Z]{3}', configuredCandidate)
      ? configuredCandidate
      : null;
  }

  private static Object displayValue(RecordHealthCheckValue value) {
    if (!value.isList()) {
      return value.storedValue;
    }
    List<Object> members = new List<Object>();
    for (String member : value.storedValues) {
      members.add(member);
    }
    return members;
  }

  private static RecordHealthCheckDisplayContent ensureContent(
    RecordHealthCheckInternalResult result
  ) {
    if (result.displayContent == null) {
      result.displayContent = new RecordHealthCheckDisplayContent();
    }
    return result.displayContent;
  }

  private static void recordInvalid(
    RecordHealthCheckInternalResult result,
    String fieldName
  ) {
    String reasonCode = RecordHealthCheckReasonCodes.PLUGIN_DISPLAY_INVALID;
    String detail = reasonCode + ': ' + fieldName;
    if (String.isBlank(result.detailMessage)) {
      result.detailMessage = detail;
    } else if (!result.detailMessage.contains(reasonCode)) {
      result.detailMessage += '; ' + detail;
    } else if (!result.detailMessage.contains(fieldName)) {
      result.detailMessage += ', ' + fieldName;
    }
  }
}
