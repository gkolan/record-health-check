/** Runtime regressions for parsed SOQL tokens and ordered relationship picks. */
@IsTest
private with sharing class RHCBulkQueryRuntimeRegressionIT {
  @IsTest
  static void optionalLookupFallbackCorrelatesNullAndPopulatedRecords() {
    Account actualParent = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Name' => 'Actual fallback-test parent',
        'AnnualRevenue' => 125
      }
    );
    Account fallbackParent = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Name' => 'Configured fallback-test parent',
        'AnnualRevenue' => 250
      }
    );
    RHCIntegrationTestDataFactory.createAccounts(
      new List<Account>{ actualParent, fallbackParent }
    );
    Account withParent = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Name' => 'Record with parent',
        'ParentId' => actualParent.Id
      }
    );
    Account withoutParent = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Record without parent' }
    );
    RHCIntegrationTestDataFactory.createAccounts(
      new List<Account>{ withParent, withoutParent }
    );
    Set<Id> scopeIds = new Set<Id>{ withParent.Id, withoutParent.Id };
    Map<Id, SObject> loadedRecords = new Map<Id, SObject>(
      [SELECT Id, ParentId FROM Account WHERE Id IN :scopeIds]
    );
    String template =
      'SELECT AnnualRevenue FROM Account WHERE Id = {!record.ParentId fallback="' +
      fallbackParent.Id +
      '"}';

    Test.startTest();
    RecordHealthCheckBulkQuerySupport.Result result = RecordHealthCheckBulkQuerySupport.execute(
      template,
      loadedRecords,
      10
    );
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckBulkQuerySupport.INDIRECT_REFERENCE,
      result.strategy,
      'A fallback attribute must remain an indirect scope correlation, not be misclassified as invariant SOQL.'
    );
    Assert.areEqual(
      Decimal.valueOf('125'),
      result.rowsByRecordId.get(withParent.Id)[0].get('AnnualRevenue'),
      'A populated lookup must retain its native correlation value.'
    );
    Assert.areEqual(
      Decimal.valueOf('250'),
      result.rowsByRecordId.get(withoutParent.Id)[0].get('AnnualRevenue'),
      'A null lookup must use the typed fallback value documented for SOQL tokens.'
    );
  }

  @IsTest
  static void relationshipOrderedPickUsesSafeInMemoryReduction() {
    Account first = RHCIntegrationTestDataFactory.createAccount(
      'Ordered relationship first'
    );
    Account second = RHCIntegrationTestDataFactory.createAccount(
      'Ordered relationship second'
    );
    Set<Id> scopeIds = new Set<Id>{ first.Id, second.Id };
    Map<Id, SObject> loadedRecords = new Map<Id, SObject>(
      [SELECT Id FROM Account WHERE Id IN :scopeIds]
    );
    String expectedOwnerName = [
      SELECT Name
      FROM User
      WHERE Id = :UserInfo.getUserId()
    ]
    .Name;

    Test.startTest();
    RecordHealthCheckBulkQuerySupport.Result result = RecordHealthCheckBulkQuerySupport.execute(
      'SELECT Owner.Name FROM Account WHERE Id = {!record.Id} ORDER BY Owner.Name ASC LIMIT 1',
      loadedRecords,
      10
    );
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckBulkQuerySupport.ORDERED_PICK_IN_MEMORY,
      result.strategy,
      'A relationship path cannot be reused as an aggregate alias and must use the safe ordered-row strategy.'
    );
    Assert.isFalse(
      result.executedSoql.contains('MIN(Owner.Name)'),
      'The rewrite must never emit the illegal aggregate alias "Owner.Name".'
    );
    for (Id recordId : scopeIds) {
      Assert.areEqual(
        expectedOwnerName,
        RecordHealthCheckValueResolver.singleValueFromRow(
          result.rowsByRecordId.get(recordId)[0],
          'Owner.Name'
        ),
        'Each scoped record must preserve the selected relationship value.'
      );
    }
  }
}
