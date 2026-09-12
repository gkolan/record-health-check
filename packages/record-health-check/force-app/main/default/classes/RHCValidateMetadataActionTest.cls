@IsTest
private class RHCValidateMetadataActionTest {
  @IsTest
  static void returnsStructuredValidationSummary() {
    Test.startTest();
    List<RecordHealthCheckValidateMetadataAction.Result> results = RecordHealthCheckValidateMetadataAction.validateConfiguration();
    Test.stopTest();

    Assert.areEqual(
      1,
      results.size(),
      'The validation action must return one summary.'
    );
    Assert.isNotNull(
      results[0].isValid,
      'The validation summary must report validity.'
    );
    Assert.isNotNull(
      results[0].errorCount,
      'The validation summary must report its error count.'
    );
    Assert.isNotNull(
      results[0].warningCount,
      'The validation summary must report its warning count.'
    );
    Assert.isNotNull(
      results[0].reportJson,
      'The validation summary must include its JSON report.'
    );
  }
}
