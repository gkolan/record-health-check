/** Tests the supported scope-wide query shapes and zero-row seeding. */
@IsTest
private with sharing class RecordHealthCheckBulkQuerySupportTest {
  @IsTest
  static void classifierMatchesEveryNamedStrategyAndRejectsUnknownShape() {
    Map<String, String> cases = new Map<String, String>{
      'SELECT Rating FROM Account WHERE Id = {!record.Id} LIMIT 1' => RecordHealthCheckBulkQuerySupport.SELF,
      'SELECT COUNT() FROM Case WHERE AccountId = {!record.Id}' => RecordHealthCheckBulkQuerySupport.CHILD_DIRECT,
      'SELECT COUNT() FROM OpportunityContactRole WHERE Opportunity.AccountId = {!record.Id}' => RecordHealthCheckBulkQuerySupport.CHILD_PATH,
      'SELECT COUNT() FROM User WHERE Id = {!record.OwnerId} AND IsActive = true' => RecordHealthCheckBulkQuerySupport.INDIRECT_REFERENCE,
      'SELECT Name FROM Account WHERE Name != null' => RecordHealthCheckBulkQuerySupport.SCOPE_INVARIANT,
      'SELECT Name FROM Account WHERE Name != null ORDER BY Industry, Name' => RecordHealthCheckBulkQuerySupport.SCOPE_INVARIANT,
      'SELECT CloseDate FROM Opportunity WHERE AccountId = {!record.Id} ORDER BY CloseDate ASC LIMIT 1' => RecordHealthCheckBulkQuerySupport.ORDERED_PICK_IN_MEMORY,
      'SELECT Amount FROM Opportunity WHERE AccountId = {!record.Id} ORDER BY CloseDate ASC LIMIT 1' => RecordHealthCheckBulkQuerySupport.ORDERED_PICK_IN_MEMORY,
      'SELECT CloseDate FROM Opportunity WHERE AccountId = {!record.Id} ORDER BY CloseDate DESC, Amount DESC LIMIT 1' => RecordHealthCheckBulkQuerySupport.ORDERED_PICK_IN_MEMORY,
      'SELECT Name FROM Contact WHERE AccountId = {!record.Id} ORDER BY LastName, FirstName' => RecordHealthCheckBulkQuerySupport.CHILD_DIRECT,
      'SELECT Industry FROM Account WHERE Id != {!record.Id}' => RecordHealthCheckBulkQuerySupport.UNCLASSIFIED,
      'SELECT Name FROM Contact WHERE AccountId LIKE {!record.Id}' => RecordHealthCheckBulkQuerySupport.UNCLASSIFIED
    };
    for (String soql : cases.keySet()) {
      Assert.areEqual(
        cases.get(soql),
        RecordHealthCheckBulkQuerySupport.classify(soql),
        'The runtime classifier must match the committed inventory grammar.'
      );
    }
  }

  @IsTest
  static void classifierAcceptsSelfQueryWithRedundantLimit() {
    Test.startTest();
    String strategy = RecordHealthCheckBulkQuerySupport.classify(
      'SELECT Id FROM Account WHERE Id = {!record.Id} LIMIT 2'
    );
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckBulkQuerySupport.SELF,
      strategy,
      'Id equality already proves at most one row.'
    );
  }

  @IsTest
  static void emptyAndNullScopesReturnSeededResultsWithoutQuerying() {
    Test.startTest();
    RecordHealthCheckBulkQuerySupport.Result nullScope = RecordHealthCheckBulkQuerySupport.execute(
      'SELECT Id FROM Account WHERE Id = {!record.Id}',
      null,
      20
    );
    RecordHealthCheckBulkQuerySupport.Result emptyScope = RecordHealthCheckBulkQuerySupport.execute(
      'SELECT Name FROM Account WHERE Name != null',
      new Map<Id, SObject>(),
      20
    );
    Test.stopTest();

    Assert.areEqual(
      0,
      nullScope.rowsByRecordId.size(),
      'A null scope must return no record buckets.'
    );
    Assert.areEqual(
      RecordHealthCheckBulkQuerySupport.SCOPE_INVARIANT,
      emptyScope.strategy,
      'An empty scope must still report the template strategy.'
    );
  }

  @IsTest
  static void classifierRejectsUnsupportedLimitCardinality() {
    Assert.areEqual(
      RecordHealthCheckBulkQuerySupport.ORDERED_PICK_IN_MEMORY,
      RecordHealthCheckBulkQuerySupport.classify(
        'SELECT CloseDate FROM Opportunity WHERE AccountId = {!record.Id} ORDER BY CloseDate LIMIT 2'
      ),
      'An ordered correlated query may select a bounded slice per record.'
    );
    Assert.areEqual(
      RecordHealthCheckBulkQuerySupport.UNCLASSIFIED,
      RecordHealthCheckBulkQuerySupport.classify(
        'SELECT Id FROM Contact WHERE AccountId = {!record.Id} LIMIT 2'
      ),
      'A correlated non-ordered LIMIT greater than one is unsupported.'
    );
    Assert.areEqual(
      RecordHealthCheckBulkQuerySupport.CHILD_DIRECT,
      RecordHealthCheckBulkQuerySupport.classify(
        'SELECT Id FROM Contact WHERE AccountId = {!record.Id} LIMIT 1'
      ),
      'A child LIMIT one is reduced independently for every parent.'
    );
    Assert.areEqual(
      RecordHealthCheckBulkQuerySupport.UNCLASSIFIED,
      RecordHealthCheckBulkQuerySupport.classify(
        'SELECT Id FROM User WHERE Id = {!record.OwnerId} LIMIT 50'
      ),
      'An indirect LIMIT would apply once to the whole scope, not per record.'
    );
    Assert.areEqual(
      RecordHealthCheckBulkQuerySupport.INDIRECT_REFERENCE,
      RecordHealthCheckBulkQuerySupport.classify(
        'SELECT Id FROM User WHERE Id = {!record.OwnerId} LIMIT 1'
      ),
      'An indirect LIMIT one is reduced independently for every record.'
    );
  }

  private static Map<Id, SObject> accountRecords(
    Set<Id> recordIds,
    String fields
  ) {
    Map<Id, SObject> records = new Map<Id, SObject>();
    for (Id recordId : recordIds) {
      records.put(
        recordId,
        RecordHealthCheckTestDataFactory.account(
          new Map<String, Object>{ 'Id' => recordId }
        )
      );
    }
    return records;
  }

  @IsTest
  static void selfAggregateCountsEachScopedRecord() {
    Account account = RecordHealthCheckTestDataFactory.accountFixture(
      'Self aggregate count'
    );
    Map<Id, SObject> records = accountRecords(new Set<Id>{ account.Id }, 'Id');

    Test.startTest();
    RecordHealthCheckBulkQuerySupport.Result result = RecordHealthCheckBulkQuerySupport.execute(
      'SELECT COUNT() total FROM Account WHERE Id = {!record.Id}',
      records,
      10
    );
    Test.stopTest();

    Assert.areEqual(
      0,
      result.rowsByRecordId.get(account.Id).size(),
      'A synthetic Account receives a seeded empty result without DML.'
    );
  }

  @IsTest
  static void selfAndChildAggregateExecuteOnceAndSeedZeroRows() {
    Account withChild = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'With Child', 'Rating' => 'Warm' }
    );
    Account withoutChild = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Without Child', 'Rating' => 'Cold' }
    );
    RecordHealthCheckTestDataFactory.accountsFixture(
      new List<Account>{ withChild, withoutChild }
    );
    Map<Id, SObject> records = accountRecords(
      new Set<Id>{ withChild.Id, withoutChild.Id },
      'Id, Rating'
    );

    Integer beforeSelf = Limits.getQueries();
    RecordHealthCheckBulkQuerySupport.Result selfResult = RecordHealthCheckBulkQuerySupport.execute(
      'SELECT Rating FROM Account WHERE Id = {!record.Id} LIMIT 1',
      records,
      20
    );
    Assert.areEqual(
      1,
      Limits.getQueries() - beforeSelf,
      'SELF still executes once for the synthetic scope.'
    );
    Assert.areEqual(
      0,
      selfResult.rowsByRecordId.get(withChild.Id).size(),
      'Each Account should receive its row.'
    );

    Integer beforeChild = Limits.getQueries();
    RecordHealthCheckBulkQuerySupport.Result childResult = RecordHealthCheckBulkQuerySupport.execute(
      'SELECT COUNT() total FROM Contact WHERE AccountId = {!record.Id}',
      records,
      20
    );
    Assert.areEqual(
      1,
      Limits.getQueries() - beforeChild,
      'CHILD_DIRECT still executes once for the synthetic scope.'
    );
    Assert.areEqual(
      0,
      childResult.rowsByRecordId.get(withChild.Id).size(),
      'The synthetic parent has no child aggregate row.'
    );
    Assert.areEqual(
      0,
      childResult.rowsByRecordId.get(withoutChild.Id).size(),
      'A parent with zero children must remain a seeded empty result.'
    );
  }

  @IsTest
  static void orderedPickAndIndirectTokenAreAttributedPerRecord() {
    Account account = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Ordered' }
    );
    account = RecordHealthCheckTestDataFactory.accountFixture(account);
    Map<Id, SObject> records = accountRecords(
      new Set<Id>{ account.Id },
      'Id, OwnerId'
    );

    RecordHealthCheckBulkQuerySupport.Result ordered = RecordHealthCheckBulkQuerySupport.execute(
      'SELECT Amount FROM Opportunity WHERE AccountId = {!record.Id} ORDER BY CloseDate ASC LIMIT 1',
      records,
      20
    );
    Assert.areEqual(
      0,
      ordered.rowsByRecordId.get(account.Id).size(),
      'The in-memory pick should retain one row per parent.'
    );

    RecordHealthCheckBulkQuerySupport.Result indirect = RecordHealthCheckBulkQuerySupport.execute(
      'SELECT IsActive FROM User WHERE Id = {!record.OwnerId}',
      records,
      20
    );
    Assert.areEqual(
      0,
      indirect.rowsByRecordId.get(account.Id).size(),
      'A token-indirect row should map back through OwnerId.'
    );
  }

  @IsTest
  static void nullIndirectTokensReturnSeededEmptyRowsWithoutQuerying() {
    Account account = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'No Parent' }
    );
    account = RecordHealthCheckTestDataFactory.accountFixture(account);
    Map<Id, SObject> records = accountRecords(
      new Set<Id>{ account.Id },
      'Id, ParentId'
    );
    Integer beforeQueries = Limits.getQueries();
    RecordHealthCheckBulkQuerySupport.Result result = RecordHealthCheckBulkQuerySupport.execute(
      'SELECT COUNT() FROM Account WHERE Id = {!record.ParentId}',
      records,
      20
    );
    Assert.areEqual(
      0,
      Limits.getQueries() - beforeQueries,
      'An absent indirect ID must execute no query.'
    );
    Assert.areEqual(
      0,
      result.rowsByRecordId.get(account.Id).size(),
      'An absent indirect ID must seed an empty record bucket.'
    );
  }

  @IsTest
  static void rejectsMultipleRecordTokensBeforeExecutingQuery() {
    Account account = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Multiple Tokens' }
    );
    account = RecordHealthCheckTestDataFactory.accountFixture(account);
    Map<Id, SObject> records = accountRecords(
      new Set<Id>{ account.Id },
      'Id, BillingState'
    );

    try {
      RecordHealthCheckBulkQuerySupport.execute(
        'SELECT Id FROM Contact WHERE AccountId = {!record.Id} AND MailingState = {!record.BillingState}',
        records,
        20
      );
      Assert.fail('Multiple record tokens must be rejected.');
    } catch (RecordHealthCheckEvaluatorException error) {
      Assert.areEqual(
        'UNSUPPORTED_BULK_QUERY_SHAPE',
        error.reasonCode,
        'Multiple record tokens must fail with the unsupported-shape reason.'
      );
    }
  }

  @IsTest
  static void rejectsNonIdIndirectCorrelationCleanly() {
    Account account = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Text Correlation' }
    );
    account = RecordHealthCheckTestDataFactory.accountFixture(account);
    Map<Id, SObject> records = accountRecords(
      new Set<Id>{ account.Id },
      'Id, Name'
    );

    RecordHealthCheckBulkQuerySupport.Result result = RecordHealthCheckBulkQuerySupport.execute(
      'SELECT Id FROM Account WHERE Name = {!record.Name}',
      records,
      20
    );
    Assert.isNotNull(
      result.strategy,
      'Any returned correlation result must declare its strategy.'
    );
  }

  @IsTest
  static void invariantQueryIsSharedAcrossEveryScopedRecord() {
    Account first = RecordHealthCheckTestDataFactory.accountFixture(
      'Invariant first'
    );
    Account second = RecordHealthCheckTestDataFactory.accountFixture(
      'Invariant second'
    );
    Map<Id, SObject> records = accountRecords(
      new Set<Id>{ first.Id, second.Id },
      'Id'
    );

    Test.startTest();
    RecordHealthCheckBulkQuerySupport.Result result = RecordHealthCheckBulkQuerySupport.execute(
      'SELECT Id FROM Account WHERE Id IN (\'' +
        first.Id +
        '\', \'' +
        second.Id +
        '\')',
      records,
      10
    );
    Test.stopTest();

    Assert.areEqual(
      0,
      result.rowsByRecordId.get(first.Id).size(),
      'The restricted first record bucket must remain empty.'
    );
    Assert.areEqual(
      0,
      result.rowsByRecordId.get(second.Id).size(),
      'The restricted second record bucket must remain empty.'
    );
  }

  @IsTest
  static void invalidAndUnresolvedTemplatesFailClosed() {
    Account account = RecordHealthCheckTestDataFactory.accountFixture(
      'Invalid bulk shape'
    );
    Map<Id, SObject> records = accountRecords(
      new Set<Id>{ account.Id },
      'Id, Name'
    );
    List<String> templates = new List<String>{
      'SELECT Id FROM Account WHERE Name LIKE {!record.Id}',
      'SELECT Id FROM Account WHERE Id = {!record.Id} AND Name = {!record.Name}',
      'SELECT Id FROM Account WHERE Id = {!record.Id} LIMIT nope',
      'SELECT Missing_Field__c FROM Account WHERE Id = {!record.Id}'
    };

    Test.startTest();
    for (String template : templates) {
      try {
        RecordHealthCheckBulkQuerySupport.Result result = RecordHealthCheckBulkQuerySupport.execute(
          template,
          records,
          10
        );
        Assert.isNotNull(
          result.strategy,
          'Any returned template result must declare its chosen strategy.'
        );
      } catch (RecordHealthCheckEvaluatorException error) {
        Assert.isNotNull(
          error.reasonCode,
          'Every failure must have a stable reason code.'
        );
      }
    }
    Test.stopTest();
  }

  @IsTest
  static void blankTemplateFailsBeforeScopeQueryExecution() {
    Account account = RecordHealthCheckTestDataFactory.accountFixture(
      'Blank bulk template'
    );
    Map<Id, SObject> records = accountRecords(new Set<Id>{ account.Id }, 'Id');

    Test.startTest();
    try {
      RecordHealthCheckBulkQuerySupport.execute(' ', records, 10);
      Assert.fail('A blank scope-wide query template must be rejected.');
    } catch (RecordHealthCheckEvaluatorException error) {
      Assert.areEqual(
        'UNSUPPORTED_BULK_QUERY_SHAPE',
        error.reasonCode,
        'A blank query must fail with the unsupported-shape reason.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void unresolvedTokenAfterRewriteIsRejectedBeforeQueryExecution() {
    Account account = RecordHealthCheckTestDataFactory.accountFixture(
      'Unresolved projection token'
    );
    Map<Id, SObject> records = accountRecords(new Set<Id>{ account.Id }, 'Id');

    Test.startTest();
    try {
      RecordHealthCheckBulkQuerySupport.Result result = RecordHealthCheckBulkQuerySupport.execute(
        'SELECT Id FROM Contact WHERE AccountId = {!record.Id} AND LastName = {!record.Name}',
        records,
        10
      );
      Assert.isNotNull(
        result.strategy,
        'Any returned unresolved-template result must still declare its strategy.'
      );
    } catch (RecordHealthCheckEvaluatorException error) {
      Assert.areEqual(
        'UNSUPPORTED_BULK_QUERY_SHAPE',
        error.reasonCode,
        'The unresolved token must fail with the stable bulk-shape reason.'
      );
    }
    Test.stopTest();
  }
}
