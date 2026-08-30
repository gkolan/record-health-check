/** Tests fail-closed bulk-query rewriting and correlation-field handling. */
@IsTest
private with sharing class RecordHealthCheckBulkQueryRewriteTest {
  @IsTest
  static void appendGroupByDoesNotDuplicateExistingCorrelation() {
    String original = 'SELECT AccountId, COUNT(Id) total FROM Contact GROUP BY AccountId';

    Test.startTest();
    String rewritten = RecordHealthCheckBulkQueryRewriter.appendGroupBy(
      original,
      'AccountId'
    );
    Test.stopTest();

    Assert.areEqual(original, rewritten);
  }

  @IsTest
  static void appendGroupByKeepsUserModeBeforeGrouping() {
    Test.startTest();
    String createdGroup = RecordHealthCheckBulkQueryRewriter.appendGroupBy(
      'SELECT COUNT(Id) FROM Contact WHERE AccountId = {!record.Id} WITH USER_MODE',
      'AccountId'
    );
    String extendedGroup = RecordHealthCheckBulkQueryRewriter.appendGroupBy(
      'SELECT Industry, COUNT(Id) FROM Account WHERE ParentId = {!record.Id} WITH USER_MODE GROUP BY Industry ORDER BY Industry',
      'ParentId'
    );
    Test.stopTest();

    Assert.areEqual(
      'SELECT COUNT(Id) FROM Contact WHERE AccountId = {!record.Id} WITH USER_MODE GROUP BY AccountId',
      createdGroup,
      'A new GROUP BY must follow the query access-level clause.'
    );
    Assert.areEqual(
      'SELECT Industry, COUNT(Id) FROM Account WHERE ParentId = {!record.Id} WITH USER_MODE GROUP BY Industry, ParentId ORDER BY Industry',
      extendedGroup,
      'An existing GROUP BY must be extended without treating WITH USER_MODE as its tail.'
    );
  }

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
    String extendedGroup = RecordHealthCheckBulkQueryRewriter.appendGroupBy(
      'SELECT CurrencyIsoCode, SUM(Amount) total FROM Opportunity WHERE AccountId = {!record.Id} GROUP BY CurrencyIsoCode HAVING SUM(Amount) > 0 ORDER BY CurrencyIsoCode',
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
    Assert.isTrue(
      extendedGroup.contains(
        'GROUP BY CurrencyIsoCode, AccountId HAVING SUM(Amount) > 0 ORDER BY'
      ),
      'An existing GROUP BY must be extended before HAVING instead of duplicated.'
    );
    Assert.areEqual(
      1,
      extendedGroup.split('(?i)GROUP BY').size() - 1,
      'The scope rewrite must emit exactly one GROUP BY clause.'
    );
    Assert.areEqual(0, missingFields.size());
  }

  @IsTest
  static void groupedRollupFailsClosed() {
    try {
      RecordHealthCheckBulkQueryRewriter.appendGroupBy(
        'SELECT CurrencyIsoCode, SUM(Amount) FROM Opportunity GROUP BY ROLLUP(CurrencyIsoCode)',
        'AccountId'
      );
      Assert.fail('ROLLUP cannot be safely extended for scope correlation.');
    } catch (RecordHealthCheckEvaluatorException error) {
      Assert.areEqual('UNSUPPORTED_BULK_QUERY_SHAPE', error.reasonCode);
    }
  }

  @IsTest
  static void scalarCurrencyQueryCarriesIsoEvidence() {
    if (!UserInfo.isMultiCurrencyOrganization()) {
      return;
    }
    Account accountRecord = RecordHealthCheckTestDataFactory.createAccount(
      'Currency evidence account'
    );
    RecordHealthCheckTestDataFactory.createOpportunity(
      new Map<String, Object>{
        'Name' => 'Currency evidence opportunity',
        'AccountId' => accountRecord.Id,
        'StageName' => 'Prospecting',
        'CloseDate' => Date.today().addDays(30),
        'Amount' => 100,
        'CurrencyIsoCode' => UserInfo.getDefaultCurrency()
      }
    );

    Test.startTest();
    RecordHealthCheckBulkQuerySupport.Result result = RecordHealthCheckBulkQuerySupport.execute(
      'SELECT Amount FROM Opportunity WHERE AccountId = {!record.Id}',
      new Map<Id, SObject>{ accountRecord.Id => accountRecord },
      10
    );
    Test.stopTest();

    Assert.isTrue(
      result.executedSoql.contains('CurrencyIsoCode'),
      'A scalar Currency query must inject ISO evidence into executed SOQL.'
    );
    Assert.areEqual(
      UserInfo.getDefaultCurrency(),
      result.rowsByRecordId.get(accountRecord.Id)[0].get('CurrencyIsoCode'),
      'The returned row must retain the unit needed for a safe comparison.'
    );
  }
}
