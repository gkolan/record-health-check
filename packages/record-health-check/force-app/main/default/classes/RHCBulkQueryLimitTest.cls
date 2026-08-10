/** Verifies per-record LIMIT behavior across a bulk query scope. */
@IsTest
private with sharing class RHCBulkQueryLimitTest {
  @IsTest
  static void shouldRetainOneChildForEveryRecord() {
    List<Account> accounts = new List<Account>{
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'Name' => 'First limited parent' }
      ),
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'Name' => 'Second limited parent' }
      )
    };
    RecordHealthCheckTestDataFactory.createAccounts(accounts);
    List<Contact> contacts = new List<Contact>();
    for (Account account : accounts) {
      contacts.add(
        RecordHealthCheckTestDataFactory.contact(
          new Map<String, Object>{
            'LastName' => account.Name + ' first',
            'AccountId' => account.Id
          }
        )
      );
      contacts.add(
        RecordHealthCheckTestDataFactory.contact(
          new Map<String, Object>{
            'LastName' => account.Name + ' second',
            'AccountId' => account.Id
          }
        )
      );
    }
    RecordHealthCheckTestDataFactory.createContacts(contacts);
    Set<Id> accountIds = new Map<Id, Account>(accounts).keySet();
    Map<Id, SObject> records = new Map<Id, SObject>(
      [SELECT Id FROM Account WHERE Id IN :accountIds]
    );

    Test.startTest();
    Integer queriesBefore = Limits.getQueries();
    RecordHealthCheckBulkQuerySupport.Result result = RecordHealthCheckBulkQuerySupport.execute(
      'SELECT Id FROM Contact WHERE AccountId = {!record.Id} LIMIT 1',
      records,
      20
    );
    Assert.areEqual(
      queriesBefore + 1,
      Limits.getQueries(),
      'The child query should execute once for the complete scope.'
    );
    for (Account account : accounts) {
      Assert.areEqual(
        1,
        result.rowsByRecordId.get(account.Id).size(),
        'Every parent should retain one independently limited child row.'
      );
    }
    Assert.isFalse(
      result.executedSoql.containsIgnoreCase('LIMIT 1'),
      'The scope-wide query must not retain the template LIMIT.'
    );
    Test.stopTest();
  }

  @IsTest
  static void shouldRejectIndirectLimitGreaterThanOneBeforeQuerying() {
    Account account = RecordHealthCheckTestDataFactory.createAccount(
      'Indirect limit parent'
    );
    Map<Id, SObject> records = new Map<Id, SObject>(
      [SELECT Id, OwnerId FROM Account WHERE Id = :account.Id]
    );

    Test.startTest();
    Integer queriesBefore = Limits.getQueries();
    try {
      RecordHealthCheckBulkQuerySupport.execute(
        'SELECT Id FROM User WHERE Id = {!record.OwnerId} LIMIT 50',
        records,
        20
      );
      Assert.fail('An indirect LIMIT greater than one must be rejected.');
    } catch (RecordHealthCheckEvaluatorException error) {
      Assert.areEqual(
        'UNSUPPORTED_BULK_QUERY_SHAPE',
        error.reasonCode,
        'The unsupported limit must use the stable bulk-shape reason code.'
      );
    }
    Assert.areEqual(
      queriesBefore,
      Limits.getQueries(),
      'The unsupported indirect query must be rejected before execution.'
    );
    Test.stopTest();
  }
}
