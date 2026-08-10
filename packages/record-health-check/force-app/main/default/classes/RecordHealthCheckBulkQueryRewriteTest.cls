/** Tests fail-closed bulk-query rewriting and correlation-field handling. */
@IsTest
private with sharing class RecordHealthCheckBulkQueryRewriteTest {
  @IsTest
  static void selfQueryDoesNotDuplicateAnExistingCorrelationField() {
    Account account = RecordHealthCheckTestDataFactory.createAccount(
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'Name' => 'Existing correlation field' }
      )
    );

    Test.startTest();
    RecordHealthCheckBulkQuerySupport.Result result = RecordHealthCheckBulkQuerySupport.execute(
      'SELECT Id FROM Account WHERE Id = {!record.Id}',
      new Map<Id, SObject>{ account.Id => account },
      10
    );
    Test.stopTest();

    Assert.isFalse(
      result.executedSoql.toLowerCase().contains('select id, id'),
      'Scope rewriting must not emit a duplicate Id selection.'
    );
    Assert.areEqual(
      1,
      result.rowsByRecordId.get(account.Id).size(),
      'The rewritten SELF query must still attribute its row to the record.'
    );
  }

  @IsTest
  static void rewriteHelpersFailClosedAndPreserveTailClauses() {
    Test.startTest();
    String missingSelect = RecordHealthCheckBulkQueryRewriter.injectSelectField(
      'FROM Account',
      'Id'
    );
    String existingSelect = RecordHealthCheckBulkQueryRewriter.injectSelectField(
      'SELECT Id FROM Account WHERE Id = {!record.Id}',
      'Id'
    );
    String missingAliasSelect = RecordHealthCheckBulkQueryRewriter.aliasCorrelation(
      'FROM Contact',
      'AccountId'
    );
    String unmatchedAliasPrefix = RecordHealthCheckBulkQueryRewriter.aliasCorrelation(
      'SELECT Name FROM Contact',
      'AccountId'
    );
    String grouped = RecordHealthCheckBulkQueryRewriter.appendGroupBy(
      'SELECT COUNT(Id) FROM Contact ORDER BY CreatedDate',
      'AccountId'
    );
    List<String> missingFields = RecordHealthCheckBulkQueryRewriter.selectedFields(
      'FROM Account'
    );
    Assert.areEqual(
      'SELECT Id FROM Account WHERE Id = {!record.Id}',
      existingSelect,
      'An existing correlation field must not be selected twice.'
    );
    try {
      RecordHealthCheckBulkQueryRewriter.rewriteOrderedPickAggregate(
        'SELECT CloseDate, Amount FROM Opportunity WHERE AccountId = {!record.Id} ORDER BY CloseDate LIMIT 1',
        'AccountId'
      );
      Assert.fail(
        'An ordered aggregate pick with two selected fields must fail.'
      );
    } catch (RecordHealthCheckEvaluatorException error) {
      Assert.areEqual(
        'UNSUPPORTED_BULK_QUERY_SHAPE',
        error.reasonCode,
        'The malformed aggregate must use the stable shape reason code.'
      );
    }
    Test.stopTest();

    Assert.areEqual('FROM Account', missingSelect);
    Assert.areEqual('FROM Contact', missingAliasSelect);
    Assert.areEqual('SELECT Name FROM Contact', unmatchedAliasPrefix);
    Assert.isTrue(
      grouped.contains('GROUP BY AccountId ORDER BY'),
      'GROUP BY must be inserted before the existing outer tail clause.'
    );
    Assert.areEqual(0, missingFields.size());
  }
}
