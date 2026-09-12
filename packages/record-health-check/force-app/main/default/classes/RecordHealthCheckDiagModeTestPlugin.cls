/** Controlled plugin used only by subscriber diagnostic contract tests. */
public class RecordHealthCheckDiagModeTestPlugin implements RecordHealthCheckPlugin, RecordHealthCheckDisplayPlugin {
  public static String mode;

  public Map<Id, RecordHealthCheckOutcome> evaluate(
    RecordHealthCheckScope scope
  ) {
    if (mode == 'THROW_SECRET') {
      throw new SecretFailureException(
        'token=secret123 user@example.test https://private.example.test'
      );
    }
    Map<Id, RecordHealthCheckOutcome> outcomes = new Map<Id, RecordHealthCheckOutcome>();
    for (Id recordId : scope.recordIds) {
      addOutcome(recordId, outcomes);
    }
    return outcomes;
  }

  private static void addOutcome(
    Id recordId,
    Map<Id, RecordHealthCheckOutcome> outcomes
  ) {
    if (mode == 'DISPLAY_THROW_SECRET') {
      outcomes.put(
        recordId,
        RecordHealthCheckOutcome.pass('DISPLAY_EVALUATION_PRESERVED')
          .withFound(RecordHealthCheckValue.ofString('Evaluated found'))
          .withComparison(
            'EQUALS',
            RecordHealthCheckValue.ofString('Evaluated found')
          )
      );
    } else if (mode == 'SPOOF_FRAMEWORK_REASON') {
      outcomes.put(
        recordId,
        RecordHealthCheckOutcome.unableToEvaluate(
          RecordHealthCheckReasonCodes.FIELD_NOT_RESOLVED
        )
      );
    } else if (mode == 'MISSING_VALUES') {
      outcomes.put(
        recordId,
        RecordHealthCheckOutcome.pass(
          RecordHealthCheckReasonCodes.FIELD_NOT_RESOLVED
        )
      );
    } else if (mode == 'EMPTY_LIST') {
      outcomes.put(
        recordId,
        RecordHealthCheckOutcome.pass('EMPTY_LIST_PRESENT')
          .withFound(RecordHealthCheckValue.ofList(new List<String>()))
          .withComparison('EQUALS', RecordHealthCheckValue.ofList(null))
      );
    } else if (mode == 'FALSE') {
      outcomes.put(
        recordId,
        RecordHealthCheckOutcome.pass('FALSE_PRESENT')
          .withFound(RecordHealthCheckValue.ofBoolean(false))
          .withComparison('EQUALS', RecordHealthCheckValue.ofBoolean(false))
      );
    } else if (mode == 'ZERO') {
      outcomes.put(
        recordId,
        RecordHealthCheckOutcome.pass('ZERO_PRESENT')
          .withFound(RecordHealthCheckValue.ofNumber(0))
          .withComparison('EQUALS', RecordHealthCheckValue.ofNumber(0))
      );
    } else if (mode == 'MISSING_FOUND') {
      outcomes.put(
        recordId,
        RecordHealthCheckOutcome.pass('MISSING_FOUND')
          .withComparison('EQUALS', RecordHealthCheckValue.ofString('Expected'))
      );
    } else if (mode == 'MISSING_EXPECTED') {
      outcomes.put(
        recordId,
        RecordHealthCheckOutcome.pass('MISSING_EXPECTED')
          .withFound(RecordHealthCheckValue.ofString('Found'))
          .withComparison('EQUALS', null)
      );
    } else {
      outcomes.put(
        recordId,
        RecordHealthCheckOutcome.unableToEvaluate('PREVIEW_FAILED')
      );
    }
  }

  public Map<Id, RecordHealthCheckDisplayOverride> getDisplay(
    RecordHealthCheckScope scope
  ) {
    if (mode == 'DISPLAY_THROW_SECRET') {
      throw new SecretFailureException(
        'token=display-secret user@example.test https://private.example.test'
      );
    }
    return null;
  }

  public class SecretFailureException extends Exception {
  }
}
