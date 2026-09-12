/** Verifies isolated subscriber outcomes and propagation of fatal failures. */
@IsTest
private class RHCSubscriberRecordIsolationTest {
  @IsTest
  static void isolateOneRecord() {
    Id passingId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      7101
    );
    Id throwingId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      7102
    );
    Id failingId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      7103
    );
    ControlledRecordEvaluator evaluator = new ControlledRecordEvaluator(
      new Map<Id, String>{
        passingId => 'PASS',
        throwingId => 'THROW',
        failingId => 'FAIL'
      }
    );
    Map<Id, RecordHealthCheckOutcome> outcomes = new Map<Id, RecordHealthCheckOutcome>();

    for (Id recordId : new List<Id>{ passingId, throwingId, failingId }) {
      outcomes.put(
        recordId,
        RecordHealthCheckOutcome.tryEvaluate(recordId, evaluator)
      );
    }

    Assert.areEqual(
      3,
      outcomes.size(),
      'Per-record isolation must retain all three requested outcomes.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.PASS,
      outcomes.get(passingId).status,
      'A sibling record exception must not change the passing record outcome.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.UNABLE_TO_EVALUATE,
      outcomes.get(throwingId).status,
      'An ordinary record exception must become an unable-to-evaluate outcome.'
    );
    Assert.areEqual(
      'RECORD_EVALUATION_FAILED',
      outcomes.get(throwingId).reasonCode,
      'An isolated record exception must use a safe stable failure reason.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.FAIL,
      outcomes.get(failingId).status,
      'A sibling record exception must not change the failing record outcome.'
    );
    Assert.areEqual(
      3,
      evaluator.invocationCount,
      'Isolation must evaluate each requested record exactly once.'
    );
  }

  @IsTest
  static void fatalNotSwallowed() {
    Id recordId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      7201
    );
    ControlledRecordEvaluator evaluator = new ControlledRecordEvaluator(
      new Map<Id, String>{ recordId => 'SIDE_EFFECT' }
    );
    Boolean escaped = false;
    try {
      RecordHealthCheckOutcome.tryEvaluate(recordId, evaluator);
    } catch (RecordHealthCheckPluginDispatch.SideEffectException expected) {
      escaped = true;
    }
    Assert.isTrue(
      escaped,
      'A side-effect exception must escape per-record isolation.'
    );
    Assert.areEqual(
      1,
      evaluator.invocationCount,
      'A fatal side effect must not retry record evaluation.'
    );
    evaluator = new ControlledRecordEvaluator(
      new Map<Id, String>{ recordId => 'FATAL_MARKER' }
    );
    escaped = false;
    try {
      RecordHealthCheckOutcome.tryEvaluate(recordId, evaluator);
    } catch (FatalRecordException expected) {
      escaped = true;
    }
    Assert.isTrue(
      escaped,
      'A framework-fatal marker must escape per-record isolation.'
    );
    Assert.areEqual(
      1,
      evaluator.invocationCount,
      'A framework-fatal marker must not retry record evaluation.'
    );
    assertInvalidRecordEvaluator(null, evaluator);
    assertInvalidRecordEvaluator(recordId, null);
  }

  private static void assertInvalidRecordEvaluator(
    Id recordId,
    RecordHealthCheckRecordEvaluator evaluator
  ) {
    Boolean rejected = false;
    try {
      RecordHealthCheckOutcome.tryEvaluate(recordId, evaluator);
    } catch (RecordHealthCheckOutcomeBuilderException expected) {
      rejected = expected.getMessage() == 'INVALID_RECORD_EVALUATOR';
    }
    Assert.isTrue(
      rejected,
      'A missing record identity or evaluator must raise the builder contract error.'
    );
  }

  private class ControlledRecordEvaluator implements RecordHealthCheckRecordEvaluator {
    private Map<Id, String> modes;
    private Integer invocationCount = 0;

    private ControlledRecordEvaluator(Map<Id, String> modes) {
      this.modes = modes;
    }

    public RecordHealthCheckOutcome evaluateRecord(Id recordId) {
      invocationCount++;
      String mode = modes.get(recordId);
      if (mode == 'THROW') {
        throw new DeliberateRecordException('secret record-specific detail');
      }
      if (mode == 'SIDE_EFFECT') {
        RecordHealthCheckPluginDispatch.SideEffectException fatal = new RecordHealthCheckPluginDispatch.SideEffectException(
          'Synthetic fatal side effect.'
        );
        fatal.reasonCode = RecordHealthCheckReasonCodes.PLUGIN_SIDE_EFFECT_DETECTED;
        throw fatal;
      }
      if (mode == 'FATAL_MARKER') {
        throw new FatalRecordException('Synthetic framework-fatal marker.');
      }
      return mode == 'PASS'
        ? RecordHealthCheckOutcome.passEquals(
            'RECORD_OK',
            RecordHealthCheckValue.ofBoolean(true),
            RecordHealthCheckValue.ofBoolean(true)
          )
        : RecordHealthCheckOutcome.failEquals(
            'RECORD_REVIEW',
            RecordHealthCheckValue.ofBoolean(false),
            RecordHealthCheckValue.ofBoolean(true)
          );
    }
  }

  private class DeliberateRecordException extends Exception {
  }

  private class FatalRecordException extends Exception implements RecordHealthCheckFatalFailure {
  }
}
