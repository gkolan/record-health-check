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
    Assert.isNull(issue);
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
    Assert.areEqual('QUERY_ORDER_NOT_DETERMINISTIC', issue.reasonCode);
    Assert.isTrue(issue.message.contains('CreatedDate DESC'));
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
    Assert.isNull(issue);
  }

  @IsTest
  static void rejectsScalarBesideInvalidOuterExpression() {
    RecordHealthCheckTokenIssue issue = RecordHealthCheckQueryTokenRules.firstIssue(
      check(
        'SELECT Website, FORMAT(Name) FROM Account ORDER BY CreatedDate DESC',
        '{!rhcQuery.sourceRows[0].Website}'
      )
    );
    Assert.areEqual('QUERY_PROJECTION_NOT_ANALYZABLE', issue.reasonCode);
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
    Assert.isNull(issue);
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
      result.strategy
    );
    Assert.isTrue(result.rowsByRecordId.get(current.Id).size() > 0);
    Assert.isTrue(result.rowsByRecordId.get(current.Id).size() <= 3);
  }
}
