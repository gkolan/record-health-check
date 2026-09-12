/** Regression tests for conventional query authoring contracts. */
@IsTest
private class RHCConventionalQueryTest {
  private static Record_Health_Check__mdt check(String query, String template) {
    return RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'EvaluationType__c' => 'QUERY',
        'SourceQuery__c' => query,
        'FailureMessage__c' => template
      }
    );
  }

  @IsTest
  static void acceptsBusinessOrderWithoutId() {
    Test.startTest();
    RecordHealthCheckTokenIssue issue = RecordHealthCheckQueryTokenRules.firstIssue(
      check(
        'SELECT Id, LastName FROM Contact ORDER BY CreatedDate DESC LIMIT 1',
        '{!rhcQuery.sourceRows[0].LastName}'
      )
    );
    Test.stopTest();
    Assert.isNull(
      issue,
      'An ordered business selection must not require an Id tiebreaker.'
    );
  }

  @IsTest
  static void suggestsBusinessOrderWhenOrderIsMissing() {
    Test.startTest();
    RecordHealthCheckTokenIssue issue = RecordHealthCheckQueryTokenRules.firstIssue(
      check(
        'SELECT Id, LastName FROM Contact',
        '{!rhcQuery.sourceRows[0].LastName}'
      )
    );
    Test.stopTest();
    Assert.areEqual(
      'QUERY_ORDER_NOT_DETERMINISTIC',
      issue.reasonCode,
      'An unordered multirow selection must retain the deterministic-order reason.'
    );
    Assert.isTrue(
      issue.message.contains('CreatedDate DESC'),
      'The order diagnostic must suggest the business ordering example.'
    );
  }

  @IsTest
  static void acceptsOuterScalarBesideChildSubquery() {
    Test.startTest();
    RecordHealthCheckTokenIssue issue = RecordHealthCheckQueryTokenRules.firstIssue(
      check(
        'SELECT Id, Website, (SELECT Id FROM Contacts LIMIT 1) ' +
        'FROM Account WHERE Id = {!record.Id}',
        '{!rhcQuery.sourceRows[0].Website}'
      )
    );
    Test.stopTest();
    Assert.isNull(
      issue,
      'An outer scalar beside a child subquery must remain supported.'
    );
  }

  @IsTest
  static void rejectsScalarBesideInvalidOuterExpression() {
    RecordHealthCheckTokenIssue issue = RecordHealthCheckQueryTokenRules.firstIssue(
      check(
        'SELECT Website, FORMAT(Name) FROM Account ORDER BY CreatedDate DESC',
        '{!rhcQuery.sourceRows[0].Website}'
      )
    );
    Assert.areEqual(
      'QUERY_PROJECTION_NOT_ANALYZABLE',
      issue.reasonCode,
      'An unsupported outer expression must reject projection analysis.'
    );
  }

  @IsTest
  static void acceptsSelfQueryWithoutOrder() {
    Test.startTest();
    RecordHealthCheckTokenIssue issue = RecordHealthCheckQueryTokenRules.firstIssue(
      check(
        'SELECT Id, Website FROM Account WHERE Id = {!record.Id} LIMIT 2',
        '{!rhcQuery.sourceRows[0].Website}'
      )
    );
    Test.stopTest();
    Assert.isNull(
      issue,
      'A self query must not require ordering even with a larger row limit.'
    );
  }

  @IsTest
  static void keepsTopThreeRowsPerRecord() {
    RecordHealthCheckTestDataFactory.assignRunPermissionToCurrentUser();
    User current = RecordHealthCheckTestDataFactory.currentUser();
    Map<Id, SObject> users = new Map<Id, SObject>{ current.Id => current };

    Test.startTest();
    RecordHealthCheckBulkQuerySupport.Result result = RecordHealthCheckBulkQuerySupport.execute(
      'SELECT Id, PermissionSetId FROM PermissionSetAssignment ' +
        'WHERE AssigneeId = {!record.Id} ' +
        'ORDER BY SystemModstamp DESC, Id DESC LIMIT 3',
      users,
      20
    );
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckBulkQuerySupport.ORDERED_PICK_IN_MEMORY,
      result.strategy,
      'An ordered indirect query must use in-memory per-record selection.'
    );
    Assert.isTrue(
      result.rowsByRecordId.get(current.Id).size() > 0,
      'The assigned user must retain at least one permission-set result.'
    );
    Assert.isTrue(
      result.rowsByRecordId.get(current.Id).size() <= 3,
      'The per-record ordered selection must retain at most three rows.'
    );
  }
}
