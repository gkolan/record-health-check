/** Adversarial literal and subquery-depth coverage for bulk classification. */
@IsTest
private with sharing class RecordHealthCheckBulkQueryDepthTest {
  @IsTest
  static void classifierIgnoresClauseTextInsideStringLiterals() {
    Map<String, String> cases = new Map<String, String>{
      'SELECT Id FROM Account WHERE Id = {!record.Id} AND Name = \'LIMIT 2\'' => RecordHealthCheckBulkQuerySupport.SELF,
      'SELECT Id FROM Account WHERE Id = {!record.Id} AND Name = \'ORDER BY Name, Industry\'' => RecordHealthCheckBulkQuerySupport.SELF,
      'SELECT Id FROM Account WHERE Name = \'Id = {!record.Id}\'' => RecordHealthCheckBulkQuerySupport.UNCLASSIFIED
    };

    Test.startTest();
    for (String soql : cases.keySet()) {
      Assert.areEqual(
        cases.get(soql),
        RecordHealthCheckBulkQuerySupport.classify(soql),
        'Literal contents must never change the outer bulk-query strategy: ' +
        soql
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void classifierRejectsCorrelationFoundOnlyInsideSubquery() {
    String soql =
      'SELECT Id, (SELECT Id FROM Contacts WHERE AccountId = {!record.Id}) ' +
      'FROM Account WHERE Name != null';

    Test.startTest();
    String strategy = RecordHealthCheckBulkQuerySupport.classify(soql);
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckBulkQuerySupport.UNCLASSIFIED,
      strategy,
      'A nested correlation cannot safely drive an outer scope-wide rewrite.'
    );
  }

  @IsTest
  static void classifierIgnoresNestedLimitAndOrderingClauses() {
    String soql =
      'SELECT Id, (SELECT Id FROM Contacts ORDER BY CreatedDate LIMIT 2) ' +
      'FROM Account WHERE Id = {!record.Id}';

    Test.startTest();
    String strategy = RecordHealthCheckBulkQuerySupport.classify(soql);
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckBulkQuerySupport.SELF,
      strategy,
      'Nested tail clauses must not alter the outer self-query contract.'
    );
  }
}
