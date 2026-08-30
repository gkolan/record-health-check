/** Tests the supported scope-wide query shapes and zero-row seeding. */
@IsTest
private with sharing class RecordHealthCheckBulkQuerySupportIT {
  @IsTest
  static void classifierMatchesEveryNamedStrategyAndRejectsUnknownShape() {
    Map<String, String> cases = new Map<String, String>{
      'SELECT Rating FROM Account WHERE Id = {!record.Id} LIMIT 1' => RecordHealthCheckBulkQuerySupport.SELF,
      'SELECT COUNT() FROM Case WHERE AccountId = {!record.Id}' => RecordHealthCheckBulkQuerySupport.CHILD_DIRECT,
      'SELECT COUNT() FROM OpportunityContactRole WHERE Opportunity.AccountId = {!record.Id}' => RecordHealthCheckBulkQuerySupport.CHILD_PATH,
      'SELECT COUNT() FROM User WHERE Id = {!record.OwnerId} AND IsActive = true' => RecordHealthCheckBulkQuerySupport.INDIRECT_REFERENCE,
      'SELECT Name FROM Account WHERE Name != null' => RecordHealthCheckBulkQuerySupport.SCOPE_INVARIANT,
      'SELECT Name FROM Account WHERE Name != null ORDER BY Industry, Name' => RecordHealthCheckBulkQuerySupport.SCOPE_INVARIANT,
      'SELECT CloseDate FROM Opportunity WHERE AccountId = {!record.Id} ORDER BY CloseDate ASC LIMIT 1' => RecordHealthCheckBulkQuerySupport.ORDERED_PICK_AGGREGATE,
      'SELECT Amount FROM Opportunity WHERE AccountId = {!record.Id} ORDER BY CloseDate ASC LIMIT 1' => RecordHealthCheckBulkQuerySupport.ORDERED_PICK_IN_MEMORY,
      'SELECT CloseDate FROM Opportunity WHERE AccountId = {!record.Id} ORDER BY CloseDate DESC, Amount DESC LIMIT 1' => RecordHealthCheckBulkQuerySupport.UNCLASSIFIED,
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
  static void classifierRejectsSelfQueryWithUnsupportedLimit() {
    Test.startTest();
    String strategy = RecordHealthCheckBulkQuerySupport.classify(
      'SELECT Id FROM Account WHERE Id = {!record.Id} LIMIT 2'
    );
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckBulkQuerySupport.UNCLASSIFIED,
      strategy,
      'A self-correlated limit larger than one has no per-record contract.'
    );
  }

  @IsTest
  static void selfAggregateCountsEachScopedRecord() {
    Account account = RHCIntegrationTestDataFactory.createAccount(
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
      1,
      result.rowsByRecordId.get(account.Id).size(),
      'A self aggregate should return one correlated aggregate row.'
    );
    Assert.areEqual(
      1,
      result.rowsByRecordId.get(account.Id)[0].get('total'),
      'The aggregate should count the scoped Account exactly once.'
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
    RHCIntegrationTestDataFactory.createAccounts(
      new List<Account>{ withChild, withoutChild }
    );
    RHCIntegrationTestDataFactory.createContact(
      RecordHealthCheckTestDataFactory.contact(
        new Map<String, Object>{
          'LastName' => 'One',
          'AccountId' => withChild.Id
        }
      )
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
      'SELF should execute once for the scope.'
    );
    Assert.areEqual(
      1,
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
      'CHILD_DIRECT should execute once for the scope.'
    );
    Assert.areEqual(
      1,
      childResult.rowsByRecordId.get(withChild.Id).size(),
      'The parent with a child should receive an aggregate row.'
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
    RHCIntegrationTestDataFactory.createAccount(account);
    RHCIntegrationTestDataFactory.createOpportunities(
      new List<Opportunity>{
        RecordHealthCheckTestDataFactory.opportunity(
          new Map<String, Object>{
            'Name' => 'Later',
            'AccountId' => account.Id,
            'StageName' => 'Prospecting',
            'CloseDate' => Date.today().addDays(5),
            'Amount' => 50
          }
        ),
        RecordHealthCheckTestDataFactory.opportunity(
          new Map<String, Object>{
            'Name' => 'Earlier',
            'AccountId' => account.Id,
            'StageName' => 'Prospecting',
            'CloseDate' => Date.today(),
            'Amount' => 10
          }
        )
      }
    );
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
      1,
      ordered.rowsByRecordId.get(account.Id).size(),
      'The in-memory pick should retain one row per parent.'
    );
    Assert.areEqual(
      10,
      ordered.rowsByRecordId.get(account.Id)[0].get('Amount'),
      'The earliest row should win per parent.'
    );

    RecordHealthCheckBulkQuerySupport.Result indirect = RecordHealthCheckBulkQuerySupport.execute(
      'SELECT IsActive FROM User WHERE Id = {!record.OwnerId}',
      records,
      20
    );
    Assert.areEqual(
      1,
      indirect.rowsByRecordId.get(account.Id).size(),
      'A token-indirect row should map back through OwnerId.'
    );
  }

  @IsTest
  static void nullIndirectTokensReturnSeededEmptyRowsWithoutQuerying() {
    Account account = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'No Parent' }
    );
    RHCIntegrationTestDataFactory.createAccount(account);
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
    Assert.areEqual(0, Limits.getQueries() - beforeQueries);
    Assert.areEqual(0, result.rowsByRecordId.get(account.Id).size());
  }

  @IsTest
  static void rejectsMultipleRecordTokensBeforeExecutingQuery() {
    Account account = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Multiple Tokens' }
    );
    RHCIntegrationTestDataFactory.createAccount(account);
    Map<Id, SObject> records = accountRecords(
      new Set<Id>{ account.Id },
      'Id, BillingState'
    );

    try {
      RecordHealthCheckBulkQuerySupport.execute(
        'SELECT Id FROM Contact WHERE AccountId = {!record.Id} AND MailingState = \'{!record.BillingState}\'',
        records,
        20
      );
      Assert.fail(
        'Multiple record tokens must be rejected before query execution.'
      );
    } catch (RecordHealthCheckEvaluatorException error) {
      Assert.areEqual(
        'UNSUPPORTED_BULK_QUERY_SHAPE',
        error.reasonCode,
        'The failure should use the stable unsupported-shape reason code.'
      );
    }
  }

  @IsTest
  static void rejectsNonIdIndirectCorrelationCleanly() {
    Account account = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Text Correlation' }
    );
    RHCIntegrationTestDataFactory.createAccount(account);
    Map<Id, SObject> records = accountRecords(
      new Set<Id>{ account.Id },
      'Id, Name'
    );

    try {
      RecordHealthCheckBulkQuerySupport.execute(
        'SELECT Id FROM Account WHERE Name = {!record.Name}',
        records,
        20
      );
      Assert.fail(
        'A non-Id indirect token must be rejected deterministically.'
      );
    } catch (RecordHealthCheckEvaluatorException error) {
      Assert.areEqual(
        'UNSUPPORTED_BULK_QUERY_SHAPE',
        error.reasonCode,
        'The cast must not escape as a StringException.'
      );
    }
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
      'A null scope must be empty.'
    );
    Assert.areEqual(
      RecordHealthCheckBulkQuerySupport.SCOPE_INVARIANT,
      emptyScope.strategy,
      'An empty scope must still report the template strategy.'
    );
  }

  @IsTest
  static void orderedAggregatePickReturnsOneValuePerRecord() {
    Account account = RHCIntegrationTestDataFactory.createAccount(
      'Aggregate ordered pick'
    );
    RHCIntegrationTestDataFactory.createOpportunities(
      new List<Opportunity>{
        RecordHealthCheckTestDataFactory.opportunity(
          new Map<String, Object>{
            'Name' => 'Later',
            'AccountId' => account.Id,
            'StageName' => 'Prospecting',
            'CloseDate' => Date.today().addDays(10)
          }
        ),
        RecordHealthCheckTestDataFactory.opportunity(
          new Map<String, Object>{
            'Name' => 'Earlier',
            'AccountId' => account.Id,
            'StageName' => 'Prospecting',
            'CloseDate' => Date.today()
          }
        )
      }
    );
    Map<Id, SObject> records = accountRecords(new Set<Id>{ account.Id }, 'Id');

    Test.startTest();
    RecordHealthCheckBulkQuerySupport.Result result = RecordHealthCheckBulkQuerySupport.execute(
      'SELECT CloseDate FROM Opportunity WHERE AccountId = {!record.Id} ORDER BY CloseDate ASC LIMIT 1',
      records,
      null
    );
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckBulkQuerySupport.ORDERED_PICK_AGGREGATE,
      result.strategy,
      'Selecting the ordered field must use the aggregate rewrite.'
    );
    Assert.areEqual(
      Date.today(),
      result.rowsByRecordId.get(account.Id)[0].get('CloseDate'),
      'The aggregate rewrite must retain the earliest value.'
    );
  }

  @IsTest
  static void invariantQueryIsSharedAcrossEveryScopedRecord() {
    Account first = RHCIntegrationTestDataFactory.createAccount(
      'Invariant first'
    );
    Account second = RHCIntegrationTestDataFactory.createAccount(
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

    Assert.areEqual(2, result.rowsByRecordId.get(first.Id).size());
    Assert.areEqual(2, result.rowsByRecordId.get(second.Id).size());
  }

  @IsTest
  static void invalidAndUnresolvedTemplatesFailClosed() {
    Account account = RHCIntegrationTestDataFactory.createAccount(
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
        RecordHealthCheckBulkQuerySupport.execute(template, records, 10);
        Assert.fail('The invalid template must fail closed: ' + template);
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
    Account account = RHCIntegrationTestDataFactory.createAccount(
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
        'Blank templates must use the stable bulk-shape reason.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void unresolvedTokenAfterRewriteIsRejectedBeforeQueryExecution() {
    Account account = RHCIntegrationTestDataFactory.createAccount(
      'Unresolved projection token'
    );
    Map<Id, SObject> records = accountRecords(new Set<Id>{ account.Id }, 'Id');

    Test.startTest();
    try {
      RecordHealthCheckBulkQuerySupport.execute(
        'SELECT Id FROM Contact WHERE AccountId = {!record.Id} AND LastName = {!record.Name}',
        records,
        10
      );
      Assert.fail('A token left in the rewritten query must be rejected.');
    } catch (RecordHealthCheckEvaluatorException error) {
      Assert.areEqual(
        'UNSUPPORTED_BULK_QUERY_SHAPE',
        error.reasonCode,
        'The unresolved token must fail with the stable bulk-shape reason.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void rowBudgetRejectsInvariantOverflow() {
    Account first = RHCIntegrationTestDataFactory.createAccount('Budget first');
    Account second = RHCIntegrationTestDataFactory.createAccount(
      'Budget second'
    );
    Map<Id, SObject> records = accountRecords(
      new Set<Id>{ first.Id, second.Id },
      'Id'
    );

    Test.startTest();
    try {
      RecordHealthCheckBulkQuerySupport.execute(
        'SELECT Id FROM Account WHERE Id IN (\'' +
          first.Id +
          '\', \'' +
          second.Id +
          '\')',
        records,
        1
      );
      Assert.fail('The scope row budget must reject an overflowing query.');
    } catch (RecordHealthCheckEvaluatorException error) {
      Assert.areEqual(
        'SCOPE_ROW_CAP_EXCEEDED',
        error.reasonCode,
        'Overflow must use the stable row-cap reason code.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void classifierRejectsUnsupportedLimitCardinality() {
    Assert.areEqual(
      RecordHealthCheckBulkQuerySupport.UNCLASSIFIED,
      RecordHealthCheckBulkQuerySupport.classify(
        'SELECT CloseDate FROM Opportunity WHERE AccountId = {!record.Id} ORDER BY CloseDate LIMIT 2'
      ),
      'An ordered pick may select only one row.'
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
    return new Map<Id, SObject>(
      Database.query(
        'SELECT ' + fields + ' FROM Account WHERE Id IN :recordIds'
      )
    );
  }
}
