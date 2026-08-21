@IsTest
private class RHCValidateMetadataActionTest {
  @IsTest
  static void returnsStructuredValidationSummary() {
    Test.startTest();
    List<RecordHealthCheckValidateMetadataAction.Result> results = RecordHealthCheckValidateMetadataAction.validateConfiguration();
    Test.stopTest();

    Assert.areEqual(1, results.size());
    Assert.isNotNull(results[0].isValid);
    Assert.isNotNull(results[0].errorCount);
    Assert.isNotNull(results[0].warningCount);
    Assert.isNotNull(results[0].reportJson);
  }
}
