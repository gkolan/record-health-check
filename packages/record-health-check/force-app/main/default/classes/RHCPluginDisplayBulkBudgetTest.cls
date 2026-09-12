/** Exercises optional display copying at the supported bulk scope boundary. */
@IsTest
private class RHCPluginDisplayBulkBudgetTest {
  @IsTest
  static void fullScopeRetainsOneBoundedCopy() {
    List<Id> ids = new List<Id>();
    for (Integer index = 1; index <= 200; index++) {
      ids.add(
        RecordHealthCheckTestDataFactory.syntheticId(Account.SObjectType, index)
      );
    }
    RecordHealthCheckScope scope = new RecordHealthCheckScope(
      'Account',
      ids,
      null,
      'BulkBudget',
      null,
      'bulk-budget-run'
    );
    BulkDisplayPlugin plugin = new BulkDisplayPlugin();
    Test.startTest();
    Integer queriesBefore = Limits.getQueries();
    Map<Id, RecordHealthCheckDisplayOverride> copied = RecordHealthCheckPluginDisplayDispatch.run(
      plugin,
      scope
    );
    Integer retainedHeap = Limits.getHeapSize();
    Integer queriesAfter = Limits.getQueries();
    Test.stopTest();
    Assert.areEqual(
      200,
      copied.size(),
      'Every requested record must remain represented after optional allocation is exhausted.'
    );
    Assert.isTrue(
      Blob.valueOf(JSON.serialize(copied)).size() <= 262144,
      'The complete two-hundred-record copy must remain within the shared byte limit.'
    );
    Assert.areEqual(
      queriesBefore,
      queriesAfter,
      'Bulk display copying must not issue a query.'
    );
    Assert.isTrue(
      retainedHeap < 4 * 1024 * 1024,
      'This bounded fixture must retain less than 4 MiB, leaving headroom below the synchronous heap limit. Measured bytes: ' +
      retainedHeap
    );
    Assert.isNotNull(
      copied.get(ids[0]).message,
      'The first record must receive message allocation first.'
    );
    Assert.isNull(
      copied.get(ids[199]).message,
      'Later records must not retain fields after the shared budget is exhausted.'
    );
    Integer findings = 0;
    for (RecordHealthCheckDisplayOverride value : copied.values()) {
      if (value.invalidFields.contains('displayBudget')) {
        findings++;
      }
    }
    Assert.areEqual(
      1,
      findings,
      'A full bulk scope must receive only one aggregate overflow finding.'
    );
  }

  private class BulkDisplayPlugin implements RecordHealthCheckPlugin, RecordHealthCheckDisplayPlugin {
    private RecordHealthCheckDisplayText text;

    public BulkDisplayPlugin() {
      text = new RecordHealthCheckDisplayText();
      String href = 'https://example.com/' + ''.leftPad(1950, 'a');
      for (Integer index = 0; index < 30; index++) {
        text.link('Evidence', href);
      }
    }

    public Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      return new Map<Id, RecordHealthCheckOutcome>();
    }

    public Map<Id, RecordHealthCheckDisplayOverride> getDisplay(
      RecordHealthCheckScope scope
    ) {
      Map<Id, RecordHealthCheckDisplayOverride> values = new Map<Id, RecordHealthCheckDisplayOverride>();
      for (Id recordId : scope.recordIds) {
        values.put(
          recordId,
          new RecordHealthCheckDisplayOverride()
            .withMessage(text)
            .withFix(text)
            .withFound(text)
            .withExpected(text)
        );
      }
      return values;
    }
  }
}
