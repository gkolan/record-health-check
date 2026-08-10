/** Exercises schema-dependent multi-select display and SOQL binding behavior. */
@IsTest
private class RHCMultiPicklistIntegrationTest {
  @IsTest
  static void resolvesLabelsAndBuildsIncludesClause() {
    RHC_Event_Export__c row = RHCIntegrationTestDataFactory.eventExport(
      new Map<String, Object>{ 'Tags__c' => 'A;B' }
    );
    Schema.DescribeFieldResult field = RHC_Event_Export__c.Tags__c.getDescribe();

    RecordHealthCheckDisplayFieldResolver.Resolution resolution = RecordHealthCheckDisplayFieldResolver.resolve(
      row.Tags__c,
      field
    );
    String bound = RecordHealthCheckSoqlTokenBinder.bindTokens(
      'SELECT Id FROM RHC_Event_Export__c WHERE Tags__c INCLUDES {!record.Tags__c}',
      row
    );

    Assert.areEqual('Alpha, Beta', resolution.value);
    Assert.isTrue(resolution.isFinalText);
    Assert.isTrue(bound.contains('INCLUDES (\'A\', \'B\')'), bound);
  }
}
