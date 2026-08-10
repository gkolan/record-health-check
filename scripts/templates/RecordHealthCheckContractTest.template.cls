@IsTest
global class ExampleBulkCheckContractTest extends RecordHealthCheckContractTest {
  global override RecordHealthCheckPlugin newCheck() {
    return new ExampleBulkCheck();
  }

  global override RecordHealthCheckContractTestData testData() {
    return new ExampleData();
  }

  @IsTest
  static void verifiesBulkContract() {
    new ExampleBulkCheckContractTest().verifyContract();
  }

  @IsTest
  static void returnsPassWhenAContactExists() {
    RecordHealthCheckScope scope = new ExampleData().createScope(1);
    insert new Contact(
      LastName = 'Contract contact',
      AccountId = scope.recordIds[0]
    );

    Map<Id, RecordHealthCheckOutcome> outcomes = RecordHealthCheckPluginDispatch.run(
      new ExampleBulkCheck(),
      scope
    );

    System.Assert.areEqual(
      RecordHealthCheckStatus.PASS,
      outcomes.get(scope.recordIds[0]).status
    );
  }

  global class ExampleData extends RecordHealthCheckContractTestData {
    global override RecordHealthCheckScope createScope(Integer size) {
      List<Account> records = new List<Account>();
      for (Integer index = 0; index < size; index++) {
        records.add(new Account(Name = 'Bulk contract ' + size + '-' + index));
      }
      insert records;
      return new RecordHealthCheckScope(
        'Account',
        new List<Id>(new Map<Id, Account>(records).keySet()),
        new Map<String, Object>(),
        'Example_Bulk_Check',
        'Example_Check_Set',
        'contract-' + size
      );
    }
  }
}
