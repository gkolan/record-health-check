/** Captured plugin execution exposed only through RecordHealthCheckPluginTest. */
global class RecordHealthCheckPluginVerification {
  private Set<Id> requestedIds;
  private RecordHealthCheckPluginDispatch.TestDispatchCapture capture;
  private RecordHealthCheckPluginDispatch.ContractException dispatchFailure;

  private RecordHealthCheckPluginVerification() {
    requestedIds = new Set<Id>();
  }

  /** Package-owned construction entry used by the test facade. */
  public static RecordHealthCheckPluginVerification create(
    RecordHealthCheckPlugin plugin,
    RecordHealthCheckScope scope
  ) {
    if (plugin == null || scope == null) {
      throw new VerificationException('PLUGIN_AND_SCOPE_REQUIRED');
    }
    RecordHealthCheckPluginVerification verification = new RecordHealthCheckPluginVerification();
    verification.requestedIds = new Set<Id>(scope.recordIds);
    try {
      RecordHealthCheckPluginDispatch.run(plugin, scope);
    } catch (RecordHealthCheckPluginDispatch.SideEffectException fatal) {
      throw fatal;
    } catch (RecordHealthCheckPluginDispatch.ContractException invalid) {
      verification.dispatchFailure = invalid;
    }
    verification.capture = RecordHealthCheckPluginDispatch.consumeTestCapture();
    return verification;
  }

  /** Asserts raw result identity and cardinality. */
  global RecordHealthCheckPluginVerification assertComplete() {
    if (dispatchFailure != null) {
      throw new VerificationException(
        dispatchFailure.reasonCode + ': ' + dispatchFailure.getMessage()
      );
    }
    if (capture == null || capture.rawResults == null) {
      throw new VerificationException(
        RecordHealthCheckReasonCodes.PLUGIN_RESULT_MISSING +
        ': raw result map is missing.'
      );
    }
    Set<Id> returnedIds = capture.rawResults.keySet();
    Set<Id> missingIds = requestedIds.clone();
    missingIds.removeAll(returnedIds);
    if (!missingIds.isEmpty()) {
      throw new VerificationException(
        RecordHealthCheckReasonCodes.PLUGIN_RESULT_MISSING +
        ': raw result keys are missing.'
      );
    }
    Set<Id> unknownIds = returnedIds.clone();
    unknownIds.removeAll(requestedIds);
    if (!unknownIds.isEmpty()) {
      throw new VerificationException(
        RecordHealthCheckReasonCodes.PLUGIN_RESULT_UNKNOWN_KEY +
        ': raw result contains an unknown key.'
      );
    }
    for (Id recordId : requestedIds) {
      if (capture.rawResults.get(recordId) == null) {
        throw new VerificationException(
          RecordHealthCheckReasonCodes.PLUGIN_RESULT_MISSING +
          ': raw outcome is missing.'
        );
      }
    }
    return this;
  }

  /** Asserts the guarded execution observed no forbidden effects. */
  global RecordHealthCheckPluginVerification assertNoSideEffects() {
    if (
      capture == null ||
      capture.dmlStatements != 0 ||
      capture.dmlRows != 0 ||
      capture.callouts != 0 ||
      capture.queueables != 0 ||
      capture.futures != 0 ||
      capture.emails != 0
    ) {
      throw new VerificationException('PLUGIN_SIDE_EFFECT_DETECTED');
    }
    return this;
  }

  /** Asserts every raw outcome satisfies typed validation and rendering. */
  global RecordHealthCheckPluginVerification assertRenderable() {
    assertComplete();
    for (Id recordId : requestedIds) {
      RecordHealthCheckOutcome outcome = capture.rawResults.get(recordId);
      List<RecordHealthCheckOutcomeValidator.Violation> violations = RecordHealthCheckOutcomeValidator.validate(
        outcome
      );
      if (!violations.isEmpty()) {
        throw new VerificationException(
          violations[0].reasonCode + ': ' + violations[0].message
        );
      }
      RecordHealthCheckApexResultFinalizer.renderValue(outcome.found);
      RecordHealthCheckApexResultFinalizer.renderValue(outcome.expected);
    }
    return this;
  }

  /** Package-only detached raw results used by the legacy contract harness. */
  public Map<Id, RecordHealthCheckOutcome> rawResults() {
    return capture?.rawResults == null
      ? null
      : new Map<Id, RecordHealthCheckOutcome>(capture.rawResults);
  }

  /** Stable assertion failure from the plugin contract facade. */
  global class VerificationException extends Exception {
  }
}
