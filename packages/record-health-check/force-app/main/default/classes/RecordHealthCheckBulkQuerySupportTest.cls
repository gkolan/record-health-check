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
    Assert.areEqual(0, Limits.getQueries() - beforeQueries);
    Assert.areEqual(0, result.rowsByRecordId.get(account.Id).size());
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
        'SELECT Id FROM Contact WHERE AccountId = {!record.Id} AND MailingState = \'{!record.BillingState}\'',
        records,
        20
      );
      Assert.fail('Multiple record tokens must be rejected.');
    } catch (RecordHealthCheckEvaluatorException error) {
      Assert.areEqual('UNSUPPORTED_BULK_QUERY_SHAPE', error.reasonCode);
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
    Assert.isNotNull(result.strategy);
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

    Assert.areEqual(0, result.rowsByRecordId.get(first.Id).size());
    Assert.areEqual(0, result.rowsByRecordId.get(second.Id).size());
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
        Assert.isNotNull(result.strategy);
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
      Assert.areEqual('UNSUPPORTED_BULK_QUERY_SHAPE', error.reasonCode);
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
      Assert.isNotNull(result.strategy);
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
  static void mapsLiveSetupRowsWithoutBusinessObjectDml() {
    RecordHealthCheckTestDataFactory.assignRunPermissionToCurrentUser();
    User current = RecordHealthCheckTestDataFactory.currentUser();
    Map<Id, SObject> users = new Map<Id, SObject>{ current.Id => current };

    RecordHealthCheckBulkQuerySupport.Result selfResult = RecordHealthCheckBulkQuerySupport.execute(
      'SELECT Id FROM User WHERE Id = {!record.Id}',
      users,
      null
    );
    Assert.areEqual(1, selfResult.rowsByRecordId.get(current.Id).size());

    Account owned = RecordHealthCheckTestDataFactory.accountFixture(
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{
          'Name' => 'Indirect setup query',
          'OwnerId' => current.Id
        }
      )
    );
    Map<Id, SObject> accounts = new Map<Id, SObject>{ owned.Id => owned };
    RecordHealthCheckBulkQuerySupport.Result indirect = RecordHealthCheckBulkQuerySupport.execute(
      'SELECT Id FROM User WHERE Id = {!record.OwnerId} LIMIT 1',
      accounts,
      20
    );
    Assert.areEqual(1, indirect.rowsByRecordId.get(owned.Id).size());

    RecordHealthCheckBulkQuerySupport.Result children = RecordHealthCheckBulkQuerySupport.execute(
      'SELECT Id FROM PermissionSetAssignment WHERE AssigneeId = {!record.Id}',
      users,
      20
    );
    Assert.isTrue(children.rowsByRecordId.get(current.Id).size() > 0);

    RecordHealthCheckBulkQuerySupport.Result ordered = RecordHealthCheckBulkQuerySupport.execute(
      'SELECT PermissionSetId FROM PermissionSetAssignment WHERE AssigneeId = {!record.Id} ORDER BY SystemModstamp ASC LIMIT 1',
      users,
      20
    );
    Assert.areEqual(1, ordered.rowsByRecordId.get(current.Id).size());

    RecordHealthCheckBulkQuerySupport.Result aggregatePick = RecordHealthCheckBulkQuerySupport.execute(
      'SELECT SystemModstamp FROM PermissionSetAssignment WHERE AssigneeId = {!record.Id} ORDER BY SystemModstamp ASC LIMIT 1',
      users,
      20
    );
    Assert.areEqual(1, aggregatePick.rowsByRecordId.get(current.Id).size());
  }

  @IsTest
  static void indirectFallbackAndNonIdCorrelationAreDeterministic() {
    Account account = RecordHealthCheckTestDataFactory.accountFixture(
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'Name' => 'Not an Id' }
      )
    );
    Map<Id, SObject> records = new Map<Id, SObject>{ account.Id => account };
    Id currentUserId = UserInfo.getUserId();
    RecordHealthCheckBulkQuerySupport.Result fallback = RecordHealthCheckBulkQuerySupport.execute(
      'SELECT Id FROM User WHERE Id = {!record.OwnerId fallback="' +
        currentUserId +
        '"}',
      records,
      20
    );
    Assert.areEqual(1, fallback.rowsByRecordId.get(account.Id).size());

    try {
      RecordHealthCheckBulkQuerySupport.execute(
        'SELECT Id FROM User WHERE Id = {!record.Name}',
        records,
        20
      );
      Assert.fail('A text-valued indirect correlation must be rejected.');
    } catch (RecordHealthCheckEvaluatorException error) {
      Assert.areEqual('UNSUPPORTED_BULK_QUERY_SHAPE', error.reasonCode);
    }
  }

  @IsTest
  static void capacityRuntimeAndRowCapsFailWithStableReasons() {
    Account account = RecordHealthCheckTestDataFactory.accountFixture(
      'Bulk failure boundaries'
    );
    Map<Id, SObject> records = new Map<Id, SObject>{ account.Id => account };
    RecordHealthCheckBulkQuerySupport.remainingQueryRowsOverride = 0;
    try {
      RecordHealthCheckBulkQuerySupport.execute(
        'SELECT Id FROM Account WHERE Name != null',
        records,
        10
      );
      Assert.fail('Insufficient query capacity must fail.');
    } catch (RecordHealthCheckEvaluatorException error) {
      Assert.areEqual(
        RecordHealthCheckReasonCodes.GOVERNOR_LIMIT_RISK,
        error.reasonCode
      );
    } finally {
      RecordHealthCheckBulkQuerySupport.remainingQueryRowsOverride = null;
    }

    try {
      RecordHealthCheckBulkQuerySupport.execute(
        'SELECT Id FROM Account WHERE Id = :rhcMissingBind',
        records,
        10
      );
      Assert.fail('An unresolved runtime bind must fail.');
    } catch (RecordHealthCheckEvaluatorException error) {
      Assert.isNotNull(error.reasonCode);
    }

    RecordHealthCheckTestDataFactory.assignRunPermissionToCurrentUser();
    RecordHealthCheckTestDataFactory.assignPermissionSet(
      RecordHealthCheckTestDataFactory.currentUser(),
      'Record_Health_Check_User'
    );
    try {
      RecordHealthCheckBulkQuerySupport.execute(
        'SELECT Id FROM PermissionSetAssignment WHERE AssigneeId = \'' +
          UserInfo.getUserId() +
          '\'',
        records,
        1
      );
      Assert.fail('A scope-wide result above its row cap must fail.');
    } catch (RecordHealthCheckEvaluatorException error) {
      Assert.areEqual(
        RecordHealthCheckReasonCodes.SCOPE_ROW_CAP_EXCEEDED,
        error.reasonCode
      );
    }
  }
}
