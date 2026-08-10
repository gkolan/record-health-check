/** Verifies reason-code classification and merge-token registry boundaries. */
@IsTest
private with sharing class RecordHealthCheckContractRegistryTest {
  @IsTest
  static void reasonCodeClassificationCoversBothOutcomes() {
    Assert.isTrue(
      RecordHealthCheckReasonCodes.isDiagnosticsOnly(
        RecordHealthCheckReasonCodes.FIELD_NOT_ACCESSIBLE
      ),
      'Access diagnostics must remain restricted to diagnostic output.'
    );
    Assert.isFalse(
      RecordHealthCheckReasonCodes.isDiagnosticsOnly(
        RecordHealthCheckReasonCodes.PREREQUISITE_NOT_MET
      ),
      'Ordinary Check outcomes must remain visible to normal callers.'
    );
  }

  @IsTest
  static void tokenRegistryRejectsUnknownNamespace() {
    Test.startTest();
    Boolean containsUnknown = RecordHealthCheckTokenRegistry.contains(
      'unknown',
      'value'
    );
    Test.stopTest();

    Assert.isFalse(
      containsUnknown,
      'An unknown merge-token namespace must not be accepted.'
    );
  }
}
