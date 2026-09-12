/** Verifies administrator fixture attribution through both validation paths. */
@IsTest
private class RHCDefinitionFindingFixtureTest {
  @IsTest
  static void definitionFailureKeepsItsReasonAndField() {
    Record_Health_Check__mdt check = Record_Health_Check__mdt.getInstance(
      'RHC_SP_Definition_Throws'
    );
    Assert.isNotNull(
      check,
      'The administrator definition fixture must be deployed.'
    );
    RHCInvalidDefinitionFixturePlugin.evaluateCalls = 0;
    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = new RecordHealthCheckMetadataValidator()
      .validateCheck(check);
    Integer definitions = 0;
    for (RecordHealthCheckMetadataValidator.ValidationIssue issue : issues) {
      Assert.areNotEqual(
        'INVALID_CONFIG',
        issue.reasonCode,
        'A known definition failure must not lose attribution to a generic error.'
      );
      if (
        issue.reasonCode ==
        RecordHealthCheckReasonCodes.PLUGIN_DEFINITION_INVALID
      ) {
        definitions++;
        Assert.areEqual(
          'ApexParametersJson__c',
          issue.fieldName,
          'The definition failure must retain the dedicated mapper field.'
        );
      }
    }
    Assert.areEqual(
      1,
      definitions,
      'The real metadata validator must expose one specific definition failure.'
    );
    Account record = RecordHealthCheckTestDataFactory.accountFixture(
      'Definition mapping'
    );
    RecordHealthCheckInternalResult result = new RecordHealthCheckApexEvaluator()
      .evaluate(check, record.Id, record);
    Assert.areEqual(
      'UNABLE_TO_EVALUATE',
      result.status,
      'A definition failure must stop business evaluation.'
    );
    Assert.areEqual(
      RecordHealthCheckReasonCodes.PLUGIN_DEFINITION_INVALID,
      result.reasonCode,
      'Runtime must retain the same specific definition reason.'
    );
    Assert.areEqual(
      0,
      RHCInvalidDefinitionFixturePlugin.evaluateCalls,
      'Neither validation path may invoke evaluation after definition failure.'
    );
  }
}
