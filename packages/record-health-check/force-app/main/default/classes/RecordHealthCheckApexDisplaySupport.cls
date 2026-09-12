/** Attaches optional plugin presentation without rewriting machine operands. */
public class RecordHealthCheckApexDisplaySupport {
  public static Boolean hasValidEvaluation(
    Map<Id, RecordHealthCheckInternalResult> results
  ) {
    for (RecordHealthCheckInternalResult result : results.values()) {
      if (!isInvalid(result?.reasonCode)) {
        return true;
      }
    }
    return false;
  }

  public static void attach(
    Map<Id, RecordHealthCheckInternalResult> results,
    Map<Id, RecordHealthCheckDisplayOverride> displayByRecord
  ) {
    if (displayByRecord == null) {
      return;
    }
    for (Id recordId : results.keySet()) {
      RecordHealthCheckDisplayOverride value = displayByRecord.get(recordId);
      if (value == null) {
        continue;
      }
      RecordHealthCheckInternalResult result = results.get(recordId);
      result.presentationOverride = value;
      result.displayContent = new RecordHealthCheckDisplayContent();
      if (value.found != null) {
        result.displayContent.found = value.found.copyNodes();
        result.actualValue = RecordHealthCheckDisplayComposer.plain(
          result.displayContent.found
        );
      }
      if (value.expected != null) {
        result.displayContent.expected = value.expected.copyNodes();
        result.expectedValue = RecordHealthCheckDisplayComposer.plain(
          result.displayContent.expected
        );
      }
    }
  }

  private static Boolean isInvalid(String reasonCode) {
    return reasonCode == RecordHealthCheckReasonCodes.PLUGIN_RESULT_MISSING ||
      reasonCode == RecordHealthCheckReasonCodes.PLUGIN_STATUS_INVALID ||
      reasonCode == RecordHealthCheckReasonCodes.PLUGIN_REASON_CODE_INVALID ||
      reasonCode == RecordHealthCheckReasonCodes.PLUGIN_VALUES_MISSING ||
      reasonCode == RecordHealthCheckReasonCodes.PLUGIN_DISPLAY_INVALID;
  }
}
